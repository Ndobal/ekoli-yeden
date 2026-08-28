import type { RequestContext } from '../types/api';
import { MediaService } from '../services/media.service';
import { AuditRepository, AUDIT_ACTIONS } from '../repositories/audit.repository';
import { ALL_CONTENT_STATUSES, CONTENT_STATUS } from '../types/models';
import {
  ALL_R2_FOLDERS,
  ALLOWED_MIME_TYPES,
  MAX_BYTES_BY_FOLDER,
  MAX_BYTES_BY_TYPE,
} from '../utils/files';
import { BadRequestError, UnauthorizedError } from '../utils/errors';
import { json, paginated, NO_STORE_HEADERS } from '../utils/responses';
import { parsePagination } from '../utils/pagination';
import { readJsonBody, Validator } from '../utils/validation';

/**
 * R2 media endpoints.
 *
 * `GET /api/media/file/*` is the only route that returns object bytes, and it
 * checks the D1 record first — so an unpublished heritage scan is not reachable
 * simply by knowing its key.
 */

/** `GET /api/media/file/<storage key>` */
export async function serveFile(context: RequestContext): Promise<Response> {
  const storageKey = context.params['wildcard'] ?? '';
  if (storageKey === '') throw new BadRequestError('No file was requested.');

  const service = new MediaService(context.env);
  return service.serve(storageKey, context.user, context.request);
}

/**
 * `GET /api/media/config`
 *
 * Tells the Flutter client which folders exist, what each accepts and how large
 * a file may be, so the upload form can validate before sending. The server
 * re-checks all of it — this is a convenience, not the enforcement point.
 */
export async function mediaConfig(context: RequestContext): Promise<Response> {
  const globalMax = Number(context.env.MAX_UPLOAD_BYTES) || 25 * 1024 * 1024;

  return json({
    folders: ALL_R2_FOLDERS.map((folder) => ({
      folder,
      acceptedMimeTypes: ALLOWED_MIME_TYPES[folder],
      maxBytes: Math.min(MAX_BYTES_BY_FOLDER[folder], globalMax),
    })),
    globalMaxBytes: globalMax,
    // Video carries its own ceiling, which is larger than the folder it sits
    // in and larger than the global figure. Reported separately so the upload
    // form does not warn about a limit that does not apply to a clip.
    maxVideoBytes: MAX_BYTES_BY_TYPE['video/mp4'] ?? globalMax,
    note: 'Short video may be uploaded alongside photographs. Anything longer than a few minutes '
      + 'belongs on YouTube — record its link instead.',
  });
}

/** `POST /api/admin/media` — upload by a Media Manager or Content Administrator. */
export async function upload(context: RequestContext): Promise<Response> {
  if (!context.user) throw new UnauthorizedError('Please sign in to continue.');

  const service = new MediaService(context.env);
  // An editor's own upload goes straight to `approved`; it still has to be
  // attached to content and published before a visitor can see it.
  const result = await service.upload(context.request, context.user, {
    defaultStatus: CONTENT_STATUS.APPROVED,
  });

  await new AuditRepository(context.env.DB).record({
    actorId: context.user.id,
    actorEmail: context.user.email,
    action: AUDIT_ACTIONS.MEDIA_UPLOADED,
    resourceType: 'media_asset',
    resourceId: result.id,
    changes: { storageKey: result.storageKey, sizeBytes: result.sizeBytes, mimeType: result.mimeType },
    requestId: context.requestId,
  });

  return json(result, { status: 201, headers: NO_STORE_HEADERS });
}

/**
 * `POST /api/contribute/media`
 *
 * A visitor attaching a photograph to a contribution. The asset is stored at
 * `pending_review` and is invisible to the public until a moderator approves it.
 */
export async function contributeUpload(context: RequestContext): Promise<Response> {
  const service = new MediaService(context.env);
  const result = await service.upload(context.request, context.user, {
    defaultStatus: CONTENT_STATUS.PENDING_REVIEW,
  });

  await new AuditRepository(context.env.DB).record({
    actorId: context.user?.id ?? null,
    actorEmail: context.user?.email ?? null,
    action: AUDIT_ACTIONS.MEDIA_UPLOADED,
    resourceType: 'media_asset',
    resourceId: result.id,
    changes: { via: 'community contribution', storageKey: result.storageKey },
    requestId: context.requestId,
  });

  return json(
    { id: result.id, sizeBytes: result.sizeBytes, mimeType: result.mimeType },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

/** `GET /api/admin/media` — the media library. */
export async function listMedia(context: RequestContext): Promise<Response> {
  const { page, perPage, offset } = parsePagination(context.query);
  const service = new MediaService(context.env);

  const requestedStatus = context.query.get('status');
  const statuses = requestedStatus
    ? ALL_CONTENT_STATUSES.filter((status) => status === requestedStatus)
    : ALL_CONTENT_STATUSES;

  const { items, total } = await service.repo.list({
    folder: context.query.get('folder'),
    statuses: statuses.length > 0 ? statuses : ALL_CONTENT_STATUSES,
    search: context.query.get('q'),
    limit: perPage,
    offset,
  });

  const decorated = items.map((item) => service.decorate(item as unknown as Record<string, unknown>));
  return paginated(decorated, page, perPage, total, NO_STORE_HEADERS);
}

/** `PATCH /api/admin/media/:id` — the cataloguing step that makes a file findable. */
export async function updateMedia(context: RequestContext): Promise<Response> {
  if (!context.user) throw new UnauthorizedError('Please sign in to continue.');

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('title', { max: 300, label: 'Title' })
    .string('description', { max: 4000, label: 'Description' })
    .string('alt_text', { max: 500, label: 'Alternative text' })
    .string('credit', { max: 300, label: 'Credit' })
    .string('location', { max: 300, label: 'Location' })
    .validated();

  if ('status' in body) {
    Object.assign(validated, new Validator(body).status('status').validated());
  }
  if ('captured_at' in body && body['captured_at']) {
    Object.assign(validated, new Validator(body).date('captured_at', { label: 'Date taken' }).validated());
  }

  const id = context.params['id'] ?? '';
  const service = new MediaService(context.env);
  const changed = await service.repo.update(id, validated);
  if (changed === 0) throw new BadRequestError('That media item was not found.');

  const record = await service.repo.findById(id);
  return json(service.decorate(record as unknown as Record<string, unknown>), { headers: NO_STORE_HEADERS });
}

/** `DELETE /api/admin/media/:id` — removes the D1 record and the R2 object. */
export async function deleteMedia(context: RequestContext): Promise<Response> {
  if (!context.user) throw new UnauthorizedError('Please sign in to continue.');

  const id = context.params['id'] ?? '';
  const service = new MediaService(context.env);
  await service.delete(id);

  await new AuditRepository(context.env.DB).record({
    actorId: context.user.id,
    actorEmail: context.user.email,
    action: AUDIT_ACTIONS.MEDIA_DELETED,
    resourceType: 'media_asset',
    resourceId: id,
    requestId: context.requestId,
  });

  return json({ id, deleted: true }, { headers: NO_STORE_HEADERS });
}
