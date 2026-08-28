import type { RequestContext } from '../types/api';
import { SubmissionService, SUBMISSION_TYPES } from '../services/submission.service';
import { ALL_CONTENT_STATUSES } from '../types/models';
import { UnauthorizedError, NotFoundError } from '../utils/errors';
import { readJsonBody } from '../utils/validation';
import { json, paginated, NO_STORE_HEADERS } from '../utils/responses';
import { parsePagination } from '../utils/pagination';
import { hashIp } from '../utils/crypto';

/**
 * CONTRIBUTE TO EKOLI YEDEN
 *
 * The public endpoint is deliberately narrow: it accepts a description of the
 * material and returns a reference code. It cannot set a status, cannot write
 * to any content table, and cannot make anything visible on the website.
 */

/** `GET /api/contribute/types` — what a visitor may submit. */
export async function contributionTypes(_context: RequestContext): Promise<Response> {
  return json({
    types: [
      { slug: 'historical_photograph', label: 'Old photograph' },
      { slug: 'historical_document', label: 'Historical document' },
      { slug: 'story', label: 'Story' },
      { slug: 'oral_history', label: 'Oral history / interview' },
      { slug: 'language_recording', label: 'Ekoli language recording' },
      { slug: 'video', label: 'Video (upload a short clip, or send a YouTube link)' },
      { slug: 'notable_person', label: 'Information about a notable person' },
      { slug: 'cultural_material', label: 'Cultural material' },
      { slug: 'correction', label: 'A correction to something already published' },
      { slug: 'other', label: 'Something else' },
    ],
    workflow: [
      'You submit the material.',
      'It is recorded as pending review — it does not appear on the website.',
      'The Ekoli-Yeden Preservation Team verifies it.',
      'Once approved and published, it becomes part of the archive.',
    ],
    note: 'Please only submit material you have the right to share.',
  });
}

/** `POST /api/contribute` — open to visitors, rate-limited. */
export async function submit(context: RequestContext): Promise<Response> {
  const body = await readJsonBody(context.request);
  const service = new SubmissionService(context.env.DB);

  const secret = context.env.JWT_SECRET;
  const ip =
    context.request.headers.get('cf-connecting-ip') ??
    context.request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
    null;

  const created = await service.receive(body, context.user, {
    requestId: context.requestId,
    // The audit trail records a digest of the address, never the address.
    ipHash: secret ? await hashIp(ip, secret) : null,
    userAgent: context.request.headers.get('user-agent'),
  });

  return json(
    {
      id: created.id,
      referenceCode: created.referenceCode,
      status: 'pending_review',
      message:
        'Thank you. Your contribution has been received and is now awaiting review by the Ekoli-Yeden Preservation Team. Please keep your reference code.',
    },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

/**
 * `GET /api/contribute/status/:reference`
 *
 * Lets a contributor follow up using the code they were given. It returns only
 * the status and the moderator's notes — never another contributor's details.
 */
export async function checkStatus(context: RequestContext): Promise<Response> {
  const reference = context.params['reference'] ?? '';
  const service = new SubmissionService(context.env.DB);
  const record = await service.repo.findByReference(reference);

  if (!record) throw new NotFoundError('No contribution was found with that reference code.');

  return json(
    {
      referenceCode: record.reference_code,
      title: record.title,
      submissionType: record.submission_type,
      status: record.status,
      reviewNotes: record.review_notes,
      submittedAt: record.created_at,
      reviewedAt: record.reviewed_at,
    },
    { headers: NO_STORE_HEADERS },
  );
}

/** `GET /api/admin/submissions` — the moderation queue. */
export async function listSubmissions(context: RequestContext): Promise<Response> {
  const { page, perPage, offset } = parsePagination(context.query);
  const service = new SubmissionService(context.env.DB);

  const requestedStatus = context.query.get('status');
  const statuses = requestedStatus
    ? ALL_CONTENT_STATUSES.filter((status) => status === requestedStatus)
    : ALL_CONTENT_STATUSES;

  const requestedType = context.query.get('submission_type');
  const submissionType =
    requestedType && (SUBMISSION_TYPES as readonly string[]).includes(requestedType) ? requestedType : null;

  const { items, total } = await service.repo.list({
    statuses: statuses.length > 0 ? statuses : ALL_CONTENT_STATUSES,
    submissionType,
    search: context.query.get('q'),
    limit: perPage,
    offset,
  });

  return paginated(items, page, perPage, total, NO_STORE_HEADERS);
}

export async function showSubmission(context: RequestContext): Promise<Response> {
  const service = new SubmissionService(context.env.DB);
  const record = await service.repo.findById(context.params['id'] ?? '');
  if (!record) throw new NotFoundError('That submission was not found.');
  return json(record, { headers: NO_STORE_HEADERS });
}

/** `PATCH /api/admin/submissions/:id/review` — a moderator's decision. */
export async function review(context: RequestContext): Promise<Response> {
  if (!context.user) throw new UnauthorizedError('Please sign in to continue.');

  const body = await readJsonBody(context.request);
  const service = new SubmissionService(context.env.DB);
  const updated = await service.review(context.params['id'] ?? '', body, context.user, {
    requestId: context.requestId,
  });

  return json(updated, { headers: NO_STORE_HEADERS });
}
