import type { Handler, RequestContext } from '../types/api';
import type { ContentResource } from '../services/content-registry';
import { ContentService } from '../services/content.service';
import { decorateVideos, decorateVideo } from '../services/video.service';
import { AuditRepository, AUDIT_ACTIONS } from '../repositories/audit.repository';
import { permissionForStatus } from '../services/permissions';
import { hasPermission } from '../services/auth.service';
import { ALL_CONTENT_STATUSES, type ContentStatus } from '../types/models';
import { ForbiddenError, UnauthorizedError } from '../utils/errors';
import { publicMediaUrl } from '../utils/files';
import { readJsonBody, Validator } from '../utils/validation';
import { json, paginated, publicCacheHeaders, NO_STORE_HEADERS } from '../utils/responses';

/**
 * Generic CRUD handlers, generated per content type from the registry.
 *
 * A single implementation serves history, leaders, people, news, events,
 * festivals, language, galleries, videos, businesses, organizations and
 * community projects. Adding a content type is a migration plus a registry
 * entry, not a new controller.
 */

/** `GET /api/<resource>` — published records only. */
export function publicList(resource: ContentResource): Handler {
  return async (context: RequestContext) => {
    const service = new ContentService(context.env.DB, resource);
    const query = service.buildQuery(context.query, false);
    const { items, total } = await service.list(query);
    const withImages = await attachImages(context.env, resource, items);

    return paginated(
      decorate(resource, withImages),
      query.page,
      query.perPage,
      total,
      publicCacheHeaders(),
    );
  };
}

/** `GET /api/<resource>/:identifier` — by slug, falling back to id. */
export function publicShow(resource: ContentResource): Handler {
  return async (context: RequestContext) => {
    const service = new ContentService(context.env.DB, resource);
    const identifier = context.params['identifier'] ?? '';
    const record = await service.findOne(identifier, false);
    const [withImage] = await attachImages(context.env, resource, [record]);
    return json(decorateOne(resource, withImage ?? record), { headers: publicCacheHeaders() });
  };
}

/** `GET /api/admin/<resource>` — every status, for editors. */
export function adminList(resource: ContentResource): Handler {
  return async (context: RequestContext) => {
    const service = new ContentService(context.env.DB, resource);
    const query = service.buildQuery(context.query, true);
    const { items, total } = await service.list(query);
    return paginated(decorate(resource, items), query.page, query.perPage, total, NO_STORE_HEADERS);
  };
}

export function adminShow(resource: ContentResource): Handler {
  return async (context: RequestContext) => {
    const service = new ContentService(context.env.DB, resource);
    const record = await service.findOne(context.params['identifier'] ?? '', true);
    return json(decorateOne(resource, record), { headers: NO_STORE_HEADERS });
  };
}

export function adminCreate(resource: ContentResource): Handler {
  return async (context: RequestContext) => {
    const actor = requireActor(context);
    const body = await readJsonBody(context.request);
    validateCommonFields(resource, body);

    const service = new ContentService(context.env.DB, resource);
    const created = await service.create(body, actor);

    await audit(context, AUDIT_ACTIONS.CONTENT_CREATED, resource, String(created['id']), {
      status: created['status'],
    });

    return json(decorateOne(resource, created), { status: 201, headers: NO_STORE_HEADERS });
  };
}

export function adminUpdate(resource: ContentResource): Handler {
  return async (context: RequestContext) => {
    const actor = requireActor(context);
    const body = await readJsonBody(context.request);
    validateCommonFields(resource, body);

    const id = context.params['id'] ?? '';
    const service = new ContentService(context.env.DB, resource);
    const updated = await service.update(id, body, actor);

    await audit(context, AUDIT_ACTIONS.CONTENT_UPDATED, resource, id, {
      fields: Object.keys(body),
    });

    return json(decorateOne(resource, updated), { headers: NO_STORE_HEADERS });
  };
}

/**
 * `PATCH /api/admin/<resource>/:id/status`
 *
 * Moving content through draft → pending_review → approved → published is the
 * editorial act that makes an entry part of the archive, so it is a separate
 * endpoint with its own permission and its own audit entry.
 */
export function adminChangeStatus(resource: ContentResource): Handler {
  return async (context: RequestContext) => {
    const actor = requireActor(context);
    const body = await readJsonBody(context.request);
    const validated = new Validator(body)
      .status('status', { required: true })
      .string('review_notes', { max: 4000, label: 'Review notes' })
      .validated();

    const target = validated['status'] as ContentStatus;

    // The permission depends on where the content is going, not merely on the
    // fact that its status is changing. Submitting for review, approving, and
    // publishing are three different authorities — which is what lets the
    // community give a volunteer the right to write without the right to
    // publish. Checked here rather than in route middleware because the route
    // cannot know the target status in advance.
    const required = permissionForStatus(resource.key, target);
    if (!hasPermission(actor, required)) {
      throw new ForbiddenError(
        `You do not have permission to move this ${resource.label.toLowerCase()} to "${target}".`,
      );
    }

    const id = context.params['id'] ?? '';
    const service = new ContentService(context.env.DB, resource);
    const updated = await service.changeStatus(
      id,
      target,
      actor,
      (validated['review_notes'] as string | null) ?? null,
    );

    await audit(context, AUDIT_ACTIONS.CONTENT_STATUS_CHANGED, resource, id, {
      to: validated['status'],
    });

    return json(decorateOne(resource, updated), { headers: NO_STORE_HEADERS });
  };
}

export function adminDelete(resource: ContentResource): Handler {
  return async (context: RequestContext) => {
    requireActor(context);
    const id = context.params['id'] ?? '';
    const service = new ContentService(context.env.DB, resource);
    await service.delete(id);

    await audit(context, AUDIT_ACTIONS.CONTENT_DELETED, resource, id);
    return json({ id, deleted: true }, { headers: NO_STORE_HEADERS });
  };
}

// --- Shared helpers ---------------------------------------------------------

function requireActor(context: RequestContext) {
  if (!context.user) throw new UnauthorizedError('Please sign in to continue.');
  return context.user;
}

async function audit(
  context: RequestContext,
  action: string,
  resource: ContentResource,
  resourceId: string,
  changes?: unknown,
): Promise<void> {
  await new AuditRepository(context.env.DB).record({
    actorId: context.user?.id ?? null,
    actorEmail: context.user?.email ?? null,
    action,
    resourceType: resource.key,
    resourceId,
    changes,
    userAgent: context.request.headers.get('user-agent'),
    requestId: context.requestId,
  });
}

/**
 * Field-level validation applied before anything reaches D1.
 *
 * The registry describes which columns exist; this adds the type rules that
 * matter for the fields the archive depends on. Anything not named here still
 * has to survive `pickWritable`, so no unknown column can be written.
 */
function validateCommonFields(resource: ContentResource, body: Record<string, unknown>): void {
  const validator = new Validator(body);

  if ('status' in body) validator.oneOf('status', ALL_CONTENT_STATUSES);
  if ('title' in body) validator.string('title', { max: 300, label: 'Title' });
  if ('name' in body) validator.string('name', { max: 300, label: 'Name' });
  if ('slug' in body) validator.string('slug', { max: 120, label: 'Address' });
  if ('year' in body) validator.integer('year', { min: 1800, max: 2200, label: 'Year' });
  if ('email' in body) validator.email('email');
  if ('website_url' in body && body['website_url']) validator.url('website_url');
  if ('youtube_video_id' in body) {
    validator.youtubeVideoId('youtube_video_id', { required: resource.key === 'videos' });
  }
  // A dictionary word is often several parts of speech at once — a noun and a
  // verb — so the column holds a JSON array. Accepted from the client as a real
  // array and stored as text; a client that already sends text is left alone.
  if (Array.isArray(body['parts_of_speech'])) {
    validator.stringArray('parts_of_speech', { maxItems: 8 });
  }

  const normalised = validator.validated();
  // Fold normalised values (lowercased email, extracted video id, parsed
  // integers) back into the payload so the repository stores the clean form.
  for (const [key, value] of Object.entries(normalised)) body[key] = value;
}

/** Videos gain their derived YouTube URLs; every other resource passes through. */
function decorate(resource: ContentResource, items: Record<string, unknown>[]): Record<string, unknown>[] {
  return resource.key === 'videos' ? decorateVideos(items) : items;
}

function decorateOne(resource: ContentResource, item: Record<string, unknown>): Record<string, unknown> {
  return resource.key === 'videos' ? decorateVideo(item) : item;
}

/**
 * Which column holds a record's picture.
 *
 * A person has a `photo_media_id`; everything else has a `cover_media_id`. The
 * distinction is in the schema and worth keeping — a portrait and a cover
 * photograph are different things — so it is resolved here rather than by
 * renaming a column.
 */
function imageColumnFor(resource: ContentResource): string {
  return resource.key === 'people' ? 'photo_media_id' : 'cover_media_id';
}

/**
 * Turns the media ids on a page of records into URLs.
 *
 * ---------------------------------------------------------------------------
 * WHY A SECOND QUERY RATHER THAN A JOIN
 * ---------------------------------------------------------------------------
 *
 * The content repository is generated from the registry and serves fourteen
 * resources from one query builder. Threading an optional join through it for
 * the sake of one column would complicate every read in the archive.
 *
 * This is one extra statement per page — an `IN` over at most a page of ids —
 * and it leaves the generic path exactly as simple as it was. If the archive
 * ever grows a second thing that needs joining, that is the moment to reach
 * into the builder, not now.
 */
async function attachImages(
  env: { DB: D1Database; PUBLIC_MEDIA_BASE_URL: string },
  resource: ContentResource,
  items: Record<string, unknown>[],
): Promise<Record<string, unknown>[]> {
  const column = imageColumnFor(resource);

  const ids = items
    .map((item) => item[column])
    .filter((id): id is string => typeof id === 'string' && id.length > 0);

  if (ids.length === 0) return items;

  const unique = [...new Set(ids)];
  const result = await env.DB
    .prepare(
      `SELECT "id", "storage_key", "alt_text" FROM "media_assets"
       WHERE "id" IN (${unique.map(() => '?').join(', ')})`,
    )
    .bind(...unique)
    .all<{ id: string; storage_key: string; alt_text: string | null }>();

  const urls = new Map<string, { url: string; alt: string | null }>();
  for (const row of result.results ?? []) {
    urls.set(row.id, {
      url: publicMediaUrl(env.PUBLIC_MEDIA_BASE_URL, row.storage_key),
      alt: row.alt_text,
    });
  }

  return items.map((item) => {
    const id = item[column];
    const found = typeof id === 'string' ? urls.get(id) : undefined;
    return found === undefined
      ? item
      : { ...item, image_url: found.url, image_alt: found.alt };
  });
}
