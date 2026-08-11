import type { RequestContext } from '../types/api';
import { SettingsRepository, settingsToMap } from '../repositories/settings.repository';
import { AuditRepository, AUDIT_ACTIONS } from '../repositories/audit.repository';
import { NotFoundError, UnauthorizedError } from '../utils/errors';
import { readJsonBody } from '../utils/validation';
import { json, publicCacheHeaders, NO_STORE_HEADERS } from '../utils/responses';

/**
 * Site settings.
 *
 * `GET /api/settings` returns only the rows flagged public — the site title,
 * tagline, contact details and feature switches the Flutter client needs to
 * render. Anything operational stays behind the admin endpoint.
 */
export async function publicSettings(context: RequestContext): Promise<Response> {
  const repository = new SettingsRepository(context.env.DB);
  const rows = await repository.publicSettings();

  return json(settingsToMap(rows), { headers: publicCacheHeaders(600) });
}

export async function adminSettings(context: RequestContext): Promise<Response> {
  const repository = new SettingsRepository(context.env.DB);
  const rows = await repository.all();

  return json(
    {
      groups: groupSettings(rows),
      values: settingsToMap(rows),
    },
    { headers: NO_STORE_HEADERS },
  );
}

/**
 * `PUT /api/admin/settings`
 *
 * Values only. The set of keys is defined by migrations so that a
 * misconfiguration cannot invent a setting the client does not understand.
 */
export async function updateSettings(context: RequestContext): Promise<Response> {
  if (!context.user) throw new UnauthorizedError('Please sign in to continue.');

  const body = await readJsonBody(context.request);
  const repository = new SettingsRepository(context.env.DB);
  const audit = new AuditRepository(context.env.DB);

  const updated: string[] = [];
  const unknown: string[] = [];

  for (const [key, value] of Object.entries(body)) {
    const existing = await repository.get(key);
    if (!existing) {
      unknown.push(key);
      continue;
    }
    const encoded = value === null ? null : typeof value === 'string' ? value : JSON.stringify(value);
    await repository.setValue(key, encoded);
    updated.push(key);
  }

  if (updated.length === 0 && unknown.length > 0) {
    throw new NotFoundError('None of the supplied settings exist.');
  }

  await audit.record({
    actorId: context.user.id,
    actorEmail: context.user.email,
    action: AUDIT_ACTIONS.SETTING_UPDATED,
    resourceType: 'site_setting',
    resourceId: null,
    changes: { updated, ignored: unknown },
    requestId: context.requestId,
  });

  const rows = await repository.all();
  return json({ updated, ignored: unknown, values: settingsToMap(rows) }, { headers: NO_STORE_HEADERS });
}

function groupSettings(
  rows: { key: string; value: string | null; value_type: string; group_name: string; is_public: number; description: string | null }[],
): Record<string, { key: string; value: string | null; type: string; isPublic: boolean; description: string | null }[]> {
  const groups: Record<string, { key: string; value: string | null; type: string; isPublic: boolean; description: string | null }[]> = {};

  for (const row of rows) {
    (groups[row.group_name] ??= []).push({
      key: row.key,
      value: row.value,
      type: row.value_type,
      isPublic: row.is_public === 1,
      description: row.description,
    });
  }
  return groups;
}
