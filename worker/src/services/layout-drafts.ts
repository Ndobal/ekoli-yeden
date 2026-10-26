import type { RequestContext } from '../types/api';
import { hasPermission } from './auth.service';
import { ConflictError, ForbiddenError, NotFoundError, ValidationError } from '../utils/errors';
import { nowIso, newId } from '../utils/id';
import { AuditRepository } from '../repositories/audit.repository';
import { diffRecords } from '../repositories/editorial.repository';

export type LayoutKind = 'hero' | 'navigation';
interface Draft extends Record<string, unknown> {
  payload: string | null;
  state: string | null;
  revision: number;
}
const layouts = {
  hero: { table: 'hero_slides', column: 'slide_number', resource: 'hero_slide', edit: 'hero:update' },
  navigation: { table: 'navigation_items', column: 'id', resource: 'navigation_item', edit: 'navigation:update' },
} as const;

export function layoutKind(value: string): LayoutKind {
  if (value !== 'hero' && value !== 'navigation') throw new NotFoundError('That layout section does not exist.');
  return value;
}

function revisionFrom(body: Record<string, unknown>): number {
  const revision = body['expected_revision'];
  if (typeof revision !== 'number' || !Number.isInteger(revision) || revision < 0) {
    throw new ValidationError({ expected_revision: ['Reload the item before saving.'] });
  }
  return revision;
}

export async function withLayoutDrafts(db: D1Database, kind: LayoutKind, rows: Record<string, unknown>[]): Promise<Record<string, unknown>[]> {
  const result = await db.prepare('SELECT * FROM layout_drafts WHERE kind = ?').bind(kind).all<Draft>();
  const drafts = new Map((result.results ?? []).map(d => [String(d['resource_id']), d]));
  return rows.map(row => {
    const id = String(row[layouts[kind].column]);
    const draft = drafts.get(id);
    return { ...row, draft: draft ? { values: draft.payload ? JSON.parse(draft.payload) : null, state: draft.state, revision: draft.revision } : { values: null, state: null, revision: 0 } };
  });
}

async function liveRecord(db: D1Database, kind: LayoutKind, id: string): Promise<Record<string, unknown>> {
  const layout = layouts[kind];
  const row = await db.prepare(`SELECT * FROM "${layout.table}" WHERE "${layout.column}" = ?`).bind(id).first<Record<string, unknown>>();
  if (!row) throw new NotFoundError('That layout item was not found.');
  return row;
}

function requirePermission(context: RequestContext, permission: string): void {
  if (!context.user || !hasPermission(context.user, permission)) throw new ForbiddenError('You do not have permission for this action.');
}

/** Internal destinations only: the client uses these as application routes. */
export function validateDestination(value: unknown, field: string): void {
  if (typeof value !== 'string' || !value.startsWith('/') || value.startsWith('//') || /[\\\s\u0000-\u001f]/.test(value)) {
    throw new ValidationError({ [field]: ['Use a site path beginning with /, such as /history.'] });
  }
}

async function validateLayout(db: D1Database, kind: LayoutKind, values: Record<string, unknown>, publishing = false): Promise<void> {
  const titleField = kind === 'hero' ? 'title' : 'label';
  if (typeof values[titleField] !== 'string' || !String(values[titleField]).trim()) {
    throw new ValidationError({ [titleField]: ['Enter a title or label.'] });
  }
  if (values['status'] !== 'published' && values['status'] !== 'archived') {
    throw new ValidationError({ status: ['Choose visible or hidden.'] });
  }
  if (kind === 'navigation') validateDestination(values['path'], 'path');
  else {
    for (const prefix of ['primary', 'secondary']) {
      const label = values[`${prefix}_button_label`];
      const path = values[`${prefix}_button_path`];
      if (!!label !== !!path) throw new ValidationError({ [`${prefix}_button_path`]: ['Supply both the button label and destination, or clear both.'] });
      if (path) validateDestination(path, `${prefix}_button_path`);
    }
    if (values['image_media_id']) {
      const media = await db.prepare('SELECT mime_type, status FROM media_assets WHERE id = ?').bind(values['image_media_id']).first<{ mime_type: string; status: string }>();
      if (!media || !media.mime_type.startsWith('image/')) throw new ValidationError({ image_media_id: ['Choose an image from the media library.'] });
      if (publishing && media.status !== 'published') throw new ValidationError({ image_media_id: ['Publish the image in the media library first.'] });
      if (!values['image_alt_text']) throw new ValidationError({ image_alt_text: ['Describe the image for readers using a screen reader.'] });
    }
  }
}

export async function saveLayoutDraft(context: RequestContext, kind: LayoutKind, id: string, values: Record<string, unknown>, body: Record<string, unknown>): Promise<number> {
  requirePermission(context, layouts[kind].edit);
  const revision = revisionFrom(body);
  const live = await liveRecord(context.env.DB, kind, id);
  const previous = await context.env.DB.prepare('SELECT * FROM layout_drafts WHERE kind = ? AND resource_id = ?').bind(kind, id).first<Draft>();
  const merged = { ...live, ...(previous?.payload ? JSON.parse(previous.payload) : {}), ...values };
  // Only caller-validated fields enter the payload. Live values are used for
  // validation; keeping unrelated columns out also keeps publication narrow.
  const payload = { ...(previous?.payload ? JSON.parse(previous.payload) : {}), ...values };
  await validateLayout(context.env.DB, kind, merged);
  if ((previous?.revision ?? 0) !== revision) throw new ConflictError('Another editor changed this item. Reload it before saving.');
  const changed = await context.env.DB.prepare(
    `INSERT INTO layout_drafts (kind, resource_id, payload, state, revision, updated_by, updated_at)
     VALUES (?, ?, ?, 'draft', 1, ?, ?)
     ON CONFLICT(kind, resource_id) DO UPDATE SET payload = excluded.payload, state = 'draft', revision = layout_drafts.revision + 1,
       updated_by = excluded.updated_by, reviewed_by = NULL, updated_at = excluded.updated_at
     WHERE layout_drafts.revision = ?`,
  ).bind(kind, id, JSON.stringify(payload), context.user!.id, nowIso(), revision).run();
  if (!changed.meta.changes) throw new ConflictError('Another editor changed this item. Reload it before saving.');
  await log(context, kind, id, 'draft_saved');
  return revision + 1;
}

export async function changeLayoutDraft(context: RequestContext, kind: LayoutKind, id: string, action: string, body: Record<string, unknown>): Promise<void> {
  const layout = layouts[kind];
  const permission = action === 'publish' ? 'content.publish' : ['approve', 'reject'].includes(action) ? 'content.review' : layout.edit;
  requirePermission(context, permission);
  const revision = revisionFrom(body);
  const live = await liveRecord(context.env.DB, kind, id);
  const draft = await context.env.DB.prepare('SELECT * FROM layout_drafts WHERE kind = ? AND resource_id = ?').bind(kind, id).first<Draft>();
  if (!draft?.payload || draft.revision !== revision) throw new ConflictError('The draft changed or no longer exists. Reload it.');
  const allowed: Record<string, string[]> = { submit: ['draft', 'rejected'], approve: ['pending_review'], reject: ['pending_review'], publish: ['approved'], discard: ['draft', 'pending_review', 'approved', 'rejected'] };
  if (!allowed[action]?.includes(draft.state ?? '')) throw new ConflictError('This draft is not ready for that action.');
  const timestamp = nowIso();
  if (action === 'publish') {
    const values = JSON.parse(draft.payload) as Record<string, unknown>;
    await validateLayout(context.env.DB, kind, { ...live, ...values }, true);
    const columns = Object.keys(values);
    const gate = `EXISTS (SELECT 1 FROM layout_drafts WHERE kind = ? AND resource_id = ? AND revision = ? AND state = 'approved')`;
    // Version, live change and clearing the draft are one D1 transaction.
    const results = await context.env.DB.batch([
      context.env.DB.prepare(
        `INSERT INTO content_versions (id, resource_type, resource_id, version_number, snapshot, changed_fields, change_summary, status_at_time, changed_by, changed_by_name, created_at)
         SELECT ?, ?, ?, COALESCE((SELECT MAX(version_number) FROM content_versions WHERE resource_type = ? AND resource_id = ?), 0) + 1,
                ?, ?, 'Layout published', ?, ?, ?, ? WHERE ${gate}`,
      ).bind(newId(), layout.resource, id, layout.resource, id, JSON.stringify(live), JSON.stringify(diffRecords(live, values)), live['status'], context.user!.id, context.user!.displayName, timestamp, kind, id, revision),
      context.env.DB.prepare(`UPDATE "${layout.table}" SET ${columns.map(c => `"${c}" = ?`).join(', ')}, updated_at = ? WHERE "${layout.column}" = ? AND ${gate}`)
        .bind(...columns.map(c => values[c] ?? null), timestamp, id, kind, id, revision),
      context.env.DB.prepare(`UPDATE layout_drafts SET payload = NULL, state = NULL, revision = revision + 1, updated_at = ? WHERE kind = ? AND resource_id = ? AND revision = ? AND state = 'approved'`)
        .bind(timestamp, kind, id, revision),
    ]);
    if (!results[1]?.meta.changes) throw new ConflictError('The draft changed. Reload it before publishing.');
  } else {
    const states: Record<string, string | null> = { submit: 'pending_review', approve: 'approved', reject: 'rejected', discard: null };
    const nextState = states[action] ?? null;
    const changed = await context.env.DB.prepare(
      `UPDATE layout_drafts SET state = ?, payload = ?, revision = revision + 1, reviewed_by = ?, updated_at = ?
       WHERE kind = ? AND resource_id = ? AND revision = ? AND state = ?`,
    ).bind(nextState, action === 'discard' ? null : draft.payload, ['approve', 'reject'].includes(action) ? context.user!.id : null, timestamp, kind, id, revision, draft.state).run();
    if (!changed.meta.changes) throw new ConflictError('The draft changed. Reload it.');
  }
  await log(context, kind, id, action);
}

async function log(context: RequestContext, kind: LayoutKind, id: string, action: string): Promise<void> {
  await new AuditRepository(context.env.DB).record({ actorId: context.user!.id, actorEmail: context.user!.email, action: `layout.${action}`, resourceType: layouts[kind].resource, resourceId: id, requestId: context.requestId });
}
