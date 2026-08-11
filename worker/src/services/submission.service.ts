import { SubmissionRepository } from '../repositories/submission.repository';
import { AuditRepository, AUDIT_ACTIONS } from '../repositories/audit.repository';
import type { AuthenticatedUser } from '../types/auth';
import { CONTENT_STATUS } from '../types/models';
import { BadRequestError, NotFoundError } from '../utils/errors';
import { Validator } from '../utils/validation';

/**
 * CONTRIBUTE TO EKOLI YEDEN
 *
 * The single rule of this service: a submission enters `pending_review` and
 * stays there until a human moderator decides otherwise. There is no code path
 * that publishes a contribution automatically, and the status field is never
 * read from the submitter's payload.
 */
export const SUBMISSION_TYPES = [
  'historical_photograph',
  'historical_document',
  'story',
  'oral_history',
  'language_recording',
  'video',
  'notable_person',
  'cultural_material',
  'correction',
  'other',
] as const;

export type SubmissionType = (typeof SUBMISSION_TYPES)[number];

/** Statuses a moderator may move a submission to. */
export const SUBMISSION_REVIEW_STATUSES = [
  CONTENT_STATUS.APPROVED,
  CONTENT_STATUS.REJECTED,
  CONTENT_STATUS.ARCHIVED,
  CONTENT_STATUS.PENDING_REVIEW,
] as const;

export class SubmissionService {
  private readonly repository: SubmissionRepository;
  private readonly audit: AuditRepository;

  constructor(db: D1Database) {
    this.repository = new SubmissionRepository(db);
    this.audit = new AuditRepository(db);
  }

  async receive(
    payload: Record<string, unknown>,
    submitter: AuthenticatedUser | null,
    context: { requestId: string; ipHash: string | null; userAgent: string | null },
  ): Promise<{ id: string; referenceCode: string }> {
    const validated = new Validator(payload)
      .oneOf('submission_type', SUBMISSION_TYPES, { required: true })
      .string('title', { required: true, min: 3, max: 200, label: 'Title' })
      .string('description', { max: 5000, label: 'Description' })
      .string('submitter_name', { max: 150, label: 'Your name' })
      .string('submitter_phone', { max: 40, label: 'Phone number' })
      .string('submitter_relationship', { max: 200, label: 'Your connection to Ekoli-Yeden' })
      .email('submitter_email')
      .stringArray('media_asset_ids', { maxItems: 20 })
      .boolean('consent_given', { required: true })
      .validated();

    if (validated['consent_given'] !== 1) {
      throw new BadRequestError(
        'Please confirm that you have the right to share this material with the archive.',
      );
    }

    // A video contribution is a YouTube link, never an uploaded file.
    let youtubeUrl: string | null = null;
    if (payload['youtube_url'] !== undefined && payload['youtube_url'] !== null && payload['youtube_url'] !== '') {
      const urlCheck = new Validator({ youtube_url: payload['youtube_url'] }).url('youtube_url').validated();
      youtubeUrl = (urlCheck['youtube_url'] as string | undefined) ?? null;
    }

    const created = await this.repository.create({
      submission_type: validated['submission_type'] as string,
      title: validated['title'] as string,
      description: (validated['description'] as string | null) ?? null,
      submitter_name: (validated['submitter_name'] as string | null) ?? submitter?.displayName ?? null,
      submitter_email: (validated['submitter_email'] as string | null) ?? submitter?.email ?? null,
      submitter_phone: (validated['submitter_phone'] as string | null) ?? null,
      submitter_relationship: (validated['submitter_relationship'] as string | null) ?? null,
      media_asset_ids: (validated['media_asset_ids'] as string | null) ?? null,
      youtube_url: youtubeUrl,
      consent_given: 1,
      submitted_by: submitter?.id ?? null,
    });

    await this.audit.record({
      actorId: submitter?.id ?? null,
      actorEmail: submitter?.email ?? null,
      action: AUDIT_ACTIONS.SUBMISSION_RECEIVED,
      resourceType: 'submission',
      resourceId: created.id,
      changes: { submission_type: validated['submission_type'], reference: created.referenceCode },
      ipHash: context.ipHash,
      userAgent: context.userAgent,
      requestId: context.requestId,
    });

    return created;
  }

  async review(
    id: string,
    payload: Record<string, unknown>,
    moderator: AuthenticatedUser,
    context: { requestId: string },
  ): Promise<Record<string, unknown>> {
    const validated = new Validator(payload)
      .oneOf('status', SUBMISSION_REVIEW_STATUSES, { required: true })
      .string('review_notes', { max: 4000, label: 'Review notes' })
      .validated();

    const existing = await this.repository.findById(id);
    if (!existing) throw new NotFoundError('That submission was not found.');

    await this.repository.review(id, {
      status: validated['status'] as string,
      reviewNotes: (validated['review_notes'] as string | null) ?? null,
      reviewedBy: moderator.id,
    });

    await this.audit.record({
      actorId: moderator.id,
      actorEmail: moderator.email,
      action: AUDIT_ACTIONS.SUBMISSION_REVIEWED,
      resourceType: 'submission',
      resourceId: id,
      changes: { from: existing.status, to: validated['status'] },
      requestId: context.requestId,
    });

    const updated = await this.repository.findById(id);
    if (!updated) throw new NotFoundError('That submission was not found.');
    return updated as unknown as Record<string, unknown>;
  }

  get repo(): SubmissionRepository {
    return this.repository;
  }
}
