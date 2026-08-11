import type { SubmissionRecord } from '../types/models';
import { newId, nowIso, submissionReference } from '../utils/id';
import { findRecordBy, insertRecord, listRecords, updateRecord, type ListResult } from './base.repository';

/**
 * Community contributions.
 *
 * A submission is never content. It is a proposal that a moderator or the
 * Verification Team turns into content, or rejects. Nothing here is ever
 * published automatically.
 */
export class SubmissionRepository {
  constructor(private readonly db: D1Database) {}

  async list(options: {
    statuses: string[];
    submissionType?: string | null;
    search?: string | null;
    limit: number;
    offset: number;
  }): Promise<ListResult<SubmissionRecord>> {
    return listRecords<SubmissionRecord>(this.db, 'submissions', {
      status: options.statuses,
      search: options.search ?? null,
      searchColumns: ['title', 'description', 'submitter_name', 'reference_code'],
      filters: options.submissionType ? { submission_type: options.submissionType } : undefined,
      sortColumn: 'created_at',
      sortDirection: 'DESC',
      limit: options.limit,
      offset: options.offset,
    });
  }

  async findById(id: string): Promise<SubmissionRecord | null> {
    return findRecordBy<SubmissionRecord>(this.db, 'submissions', 'id', id);
  }

  async findByReference(referenceCode: string): Promise<SubmissionRecord | null> {
    return findRecordBy<SubmissionRecord>(this.db, 'submissions', 'reference_code', referenceCode);
  }

  /**
   * Creates a submission. The status is forced to `pending_review` here rather
   * than taken from the payload, so no caller can ever create published
   * content through this route.
   */
  async create(values: {
    submission_type: string;
    title: string;
    description: string | null;
    submitter_name: string | null;
    submitter_email: string | null;
    submitter_phone: string | null;
    submitter_relationship: string | null;
    media_asset_ids: string | null;
    youtube_url: string | null;
    consent_given: number;
    submitted_by: string | null;
  }): Promise<{ id: string; referenceCode: string }> {
    const id = newId();
    const referenceCode = submissionReference();
    const timestamp = nowIso();

    await insertRecord(this.db, 'submissions', {
      ...values,
      id,
      reference_code: referenceCode,
      status: 'pending_review',
      reviewed_by: null,
      reviewed_at: null,
      review_notes: null,
      published_record_type: null,
      published_record_id: null,
      created_at: timestamp,
      updated_at: timestamp,
    });

    return { id, referenceCode };
  }

  async review(
    id: string,
    values: { status: string; reviewNotes: string | null; reviewedBy: string },
  ): Promise<number> {
    return updateRecord(this.db, 'submissions', id, {
      status: values.status,
      review_notes: values.reviewNotes,
      reviewed_by: values.reviewedBy,
      reviewed_at: nowIso(),
    });
  }

  /** Records which published record a submission eventually became. */
  async linkPublishedRecord(id: string, recordType: string, recordId: string): Promise<number> {
    return updateRecord(this.db, 'submissions', id, {
      published_record_type: recordType,
      published_record_id: recordId,
    });
  }

  async countPending(): Promise<number> {
    const row = await this.db
      .prepare('SELECT COUNT(*) AS total FROM "submissions" WHERE "status" = ?')
      .bind('pending_review')
      .first<{ total: number }>();
    return Number(row?.total ?? 0);
  }
}
