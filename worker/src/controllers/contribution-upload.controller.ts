import type { RequestContext } from '../types/api';
import { ContributionUploadService } from '../services/contribution-upload.service';
import {
  ALL_R2_FOLDERS,
  ALLOWED_MIME_TYPES,
  MAX_BYTES_BY_FOLDER,
  MAX_BYTES_BY_TYPE,
} from '../utils/files';
import { UnauthorizedError } from '../utils/errors';
import { hashIp } from '../utils/crypto';
import { readJsonBody, Validator } from '../utils/validation';
import { json, paginated, NO_STORE_HEADERS, publicCacheHeaders } from '../utils/responses';
import { parsePagination } from '../utils/pagination';

/**
 * Endpoints for material contributed by the community.
 *
 * The public one accepts files from anybody, into a bucket kept apart from the
 * published archive. The rest are the review queue, which is not public and
 * never cached.
 */

function clientIp(request: Request): string | null {
  return (
    request.headers.get('cf-connecting-ip') ??
    request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
    null
  );
}

/**
 * `GET /api/contribute/upload-config`
 *
 * What may be uploaded and how large it may be, so the form can tell a
 * contributor before they wait for a rejected upload. The server enforces all
 * of it again.
 */
export async function uploadConfig(context: RequestContext): Promise<Response> {
  const globalMax = Number(context.env.MAX_UPLOAD_BYTES) || 25 * 1024 * 1024;

  return json(
    {
      folders: ALL_R2_FOLDERS.map((folder) => ({
        folder,
        acceptedMimeTypes: ALLOWED_MIME_TYPES[folder],
        maxBytes: Math.min(MAX_BYTES_BY_FOLDER[folder], globalMax),
      })),
      globalMaxBytes: globalMax,
      maxVideoBytes: MAX_BYTES_BY_TYPE['video/mp4'] ?? globalMax,
      guidance: [
        'Photographs, documents, audio recordings and short video are all welcome.',
        'A video longer than a few minutes belongs on YouTube — send us the link instead.',
        'Nothing you upload appears on the website until the Preservation Team has reviewed it.',
        'Please only send material you have the right to share.',
      ],
      usagePermissions: [
        { value: 'public_display_with_credit', label: 'It may be published, with my name credited' },
        { value: 'public_display', label: 'It may be published' },
        { value: 'archive_only', label: 'Keep it in the archive, but do not publish it' },
        { value: 'unspecified', label: 'I am not sure — please contact me' },
      ],
    },
    { headers: publicCacheHeaders(600) },
  );
}

/**
 * `POST /api/contribute/upload`
 *
 * Open to anybody, rate limited. Lands in the submissions bucket at
 * `pending_review` and is invisible to the public until approved.
 */
export async function uploadContribution(context: RequestContext): Promise<Response> {
  const secret = context.env.JWT_SECRET;
  const service = new ContributionUploadService(context.env);

  const result = await service.receive(context.request, context.user, {
    requestId: context.requestId,
    ipHash: secret ? await hashIp(clientIp(context.request), secret) : null,
  });

  return json(
    {
      ...result,
      status: 'pending_review',
      message:
        'Thank you. Your file has been received and is waiting for the Ekoli-Yeden Preservation ' +
        'Team to review it. It will not appear on the website until they have.',
    },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

/** `GET /api/admin/contributions` — the file review queue. */
export async function listContributions(context: RequestContext): Promise<Response> {
  const { page, perPage, offset } = parsePagination(context.query);
  const requested = context.query.get('status');
  const status = ['pending_review', 'approved', 'rejected', 'promoted', 'archived'].includes(
    requested ?? '',
  )
    ? requested
    : 'pending_review';

  const service = new ContributionUploadService(context.env);
  const { items, total } = await service.list(status, perPage, offset);

  return paginated(
    items.map((item) => ({
      ...item,
      // A reviewer needs to see the file; the URL is behind their permission.
      previewUrl: `/api/admin/contributions/${item.id}/file`,
    })),
    page,
    perPage,
    total,
    NO_STORE_HEADERS,
  );
}

/** `GET /api/admin/contributions/:id/file` — stream a file for review. */
export async function serveContributionFile(context: RequestContext): Promise<Response> {
  const service = new ContributionUploadService(context.env);
  return service.serveForReview(context.params['id'] ?? '');
}

/**
 * `POST /api/admin/contributions/:id/approve`
 *
 * Copies the file into the archive and credits the contributor. Approving is
 * not publishing: the resulting media record is `approved`, and putting it on
 * the site is a separate, deliberate act.
 */
export async function approveContribution(context: RequestContext): Promise<Response> {
  const reviewer = context.user;
  if (!reviewer) throw new UnauthorizedError('Please sign in to continue.');

  const body = await readJsonBody(context.request).catch(() => ({}) as Record<string, unknown>);
  const validated = new Validator(body)
    .string('review_notes', { max: 2000, label: 'Review notes' })
    .string('gallery_id', { max: 64, label: 'Album' })
    .boolean('publish')
    .validated();

  const service = new ContributionUploadService(context.env);
  const result = await service.approve(context.params['id'] ?? '', reviewer, {
    notes: (validated['review_notes'] as string | null) ?? null,
    // Both optional. Approving on its own still only accessions the file —
    // filing it into an album and putting it on the site are things the
    // reviewer asks for, not things that happen to them.
    galleryId: (validated['gallery_id'] as string | null) ?? null,
    publish: validated['publish'] === 1 || validated['publish'] === true,
    requestId: context.requestId,
  });

  return json(
    {
      ...result,
      message: messageFor(result),
    },
    { headers: NO_STORE_HEADERS },
  );
}

/**
 * What actually happened, said plainly.
 *
 * The old message told every reviewer to "publish the media item when you are
 * ready" and gave them nowhere to do it. Seven contributed files sat approved
 * and invisible behind that sentence.
 */
function messageFor(result: { published: boolean; galleryItemId: string | null }): string {
  if (result.published && result.galleryItemId) {
    return 'Approved, filed into the album and published. It is on the public site now.';
  }
  if (result.published) {
    return 'Approved and published. It is visible at its own address, but it is not in any album '
      + 'yet — add it to one so people can find it.';
  }
  if (result.galleryItemId) {
    return 'Approved and filed into the album, still as a draft. Publish it when you are ready.';
  }
  return 'Approved and copied into the archive. It is not in an album and not on the public site '
    + 'yet — until it is both, nobody outside this screen can see it.';
}

/** `POST /api/admin/contributions/:id/reject` */
export async function rejectContribution(context: RequestContext): Promise<Response> {
  const reviewer = context.user;
  if (!reviewer) throw new UnauthorizedError('Please sign in to continue.');

  const body = await readJsonBody(context.request).catch(() => ({}) as Record<string, unknown>);
  const notes = new Validator(body)
    .string('review_notes', { max: 2000, label: 'Review notes' })
    .validated()['review_notes'] as string | null;

  const service = new ContributionUploadService(context.env);
  await service.reject(context.params['id'] ?? '', reviewer, {
    notes: notes ?? null,
    requestId: context.requestId,
  });

  return json(
    {
      rejected: true,
      // The file is kept rather than deleted: a rejection is an editorial
      // decision, and the community may want to revisit it.
      message: 'Marked as rejected. The file is retained, not deleted.',
    },
    { headers: NO_STORE_HEADERS },
  );
}
