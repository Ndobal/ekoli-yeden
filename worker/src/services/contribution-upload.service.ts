import { MediaRepository } from '../repositories/media.repository';
import { EditorialRepository } from '../repositories/editorial.repository';
import { AuditRepository } from '../repositories/audit.repository';
import type { Env } from '../types/env';
import type { AuthenticatedUser } from '../types/auth';
import { CONTENT_STATUS } from '../types/models';
import { BadRequestError, NotFoundError } from '../utils/errors';
import { sha256 } from '../utils/crypto';
import { newId, nowIso } from '../utils/id';
import {
  assertUploadAllowed,
  buildStorageKey,
  isR2Folder,
  sanitizeFilename,
  type R2Folder,
} from '../utils/files';

/**
 * CONTRIBUTOR UPLOADS
 *
 * Material sent in by the community, held apart from the published archive
 * until somebody has looked at it.
 *
 * The separation is a bucket, not a folder. Unreviewed material and the
 * archive have different audiences, different retention and different risk: a
 * bucket boundary means a mistake in the media-serving path cannot expose a
 * photograph nobody has checked, and the community can apply its own lifecycle
 * rules to submissions without touching the archive.
 *
 * On approval the object is COPIED into the archive bucket and a normal
 * media_assets record is created. The original stays where it is, so the chain
 * from "what was sent" to "what was published" is never broken — which matters
 * when the question later becomes "is this really the photograph she gave us?".
 */
export interface SubmissionUploadRecord {
  id: string;
  submission_id: string | null;
  storage_key: string;
  original_filename: string;
  mime_type: string;
  size_bytes: number;
  caption: string | null;
  people_pictured: string | null;
  taken_at: string | null;
  location: string | null;
  contributor_name: string | null;
  contributor_email: string | null;
  usage_permission: string;
  status: string;
  review_notes: string | null;
  media_asset_id: string | null;
  created_at: string;
}

export class ContributionUploadService {
  constructor(private readonly env: Env) {}

  private get maxBytes(): number {
    return Number(this.env.MAX_UPLOAD_BYTES) || 25 * 1024 * 1024;
  }

  /**
   * Accepts a file from the public contribution form.
   *
   * No account is required. An elder's grandchild with a photograph on their
   * phone should not have to register before they can help.
   */
  async receive(
    request: Request,
    contributor: AuthenticatedUser | null,
    context: { requestId: string; ipHash: string | null },
  ): Promise<{ id: string; filename: string; sizeBytes: number; mimeType: string }> {
    const form = await request.formData();
    const file = form.get('file');
    const folderValue = String(form.get('folder') ?? 'heritage');

    if (!(file instanceof File)) {
      throw new BadRequestError('No file was included in the upload.');
    }
    if (!isR2Folder(folderValue)) {
      throw new BadRequestError('That is not a folder material can be contributed to.');
    }
    const folder: R2Folder = folderValue;

    const mimeType = file.type || 'application/octet-stream';
    const filename = sanitizeFilename(file.name || 'contribution');

    assertUploadAllowed({ folder, mimeType, sizeBytes: file.size, filename }, this.maxBytes);
    const bytes = await file.arrayBuffer();
    // Re-checked after reading: `File.size` is client-reported metadata.
    assertUploadAllowed({ folder, mimeType, sizeBytes: bytes.byteLength, filename }, this.maxBytes);

    const storageKey = buildStorageKey(folder, mimeType, filename);

    await this.env.SUBMISSIONS.put(storageKey, bytes, {
      httpMetadata: { contentType: mimeType, cacheControl: 'private, no-store' },
      customMetadata: {
        originalFilename: filename,
        contributor: contributor?.id ?? 'anonymous',
        receivedAt: nowIso(),
      },
    });

    const id = newId();
    const timestamp = nowIso();

    await this.env.DB.prepare(
      `INSERT INTO "submission_uploads"
         ("id", "submission_id", "storage_key", "original_filename", "mime_type", "size_bytes",
          "checksum", "caption", "people_pictured", "taken_at", "location",
          "contributor_name", "contributor_email", "contributor_phone", "uploaded_by",
          "usage_permission", "status", "ip_hash", "created_at", "updated_at")
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    )
      .bind(
        id,
        asText(form.get('submission_id')),
        storageKey,
        filename,
        mimeType,
        bytes.byteLength,
        await sha256(bytes),
        asText(form.get('caption')),
        asText(form.get('people_pictured')),
        asText(form.get('taken_at')),
        asText(form.get('location')),
        asText(form.get('contributor_name')) ?? contributor?.displayName ?? null,
        asText(form.get('contributor_email')) ?? contributor?.email ?? null,
        asText(form.get('contributor_phone')),
        contributor?.id ?? null,
        asText(form.get('usage_permission')) ?? 'unspecified',
        'pending_review',
        context.ipHash,
        timestamp,
        timestamp,
      )
      .run();

    await new AuditRepository(this.env.DB).record({
      actorId: contributor?.id ?? null,
      actorEmail: contributor?.email ?? null,
      action: 'contribution.file.received',
      resourceType: 'submission_upload',
      resourceId: id,
      changes: { filename, sizeBytes: bytes.byteLength, mimeType, folder },
      ipHash: context.ipHash,
      requestId: context.requestId,
    });

    return { id, filename, sizeBytes: bytes.byteLength, mimeType };
  }

  /** The review queue. */
  async list(status: string | null, limit: number, offset: number): Promise<{
    items: SubmissionUploadRecord[];
    total: number;
  }> {
    const where = status ? ' WHERE "status" = ?' : '';
    const bindings = status ? [status] : [];

    const [countRow, rows] = await this.env.DB.batch<Record<string, unknown>>([
      this.env.DB.prepare(`SELECT COUNT(*) AS total FROM "submission_uploads"${where}`).bind(...bindings),
      this.env.DB.prepare(
        `SELECT * FROM "submission_uploads"${where} ORDER BY "created_at" DESC LIMIT ? OFFSET ?`,
      ).bind(...bindings, limit, offset),
    ]);

    return {
      items: (rows?.results ?? []) as unknown as SubmissionUploadRecord[],
      total: Number((countRow?.results?.[0]?.['total'] as number | undefined) ?? 0),
    };
  }

  /** Streams a contributed file to a reviewer. Never public. */
  async serveForReview(id: string): Promise<Response> {
    const record = await this.find(id);
    if (!record) throw new NotFoundError('That file was not found.');

    const object = await this.env.SUBMISSIONS.get(record.storage_key);
    if (!object) throw new NotFoundError('That file was not found.');

    const headers = new Headers();
    object.writeHttpMetadata(headers);
    headers.set('etag', object.httpEtag);
    headers.set('x-content-type-options', 'nosniff');
    // Nothing in this bucket may be cached anywhere: it has not been reviewed.
    headers.set('cache-control', 'private, no-store');
    headers.set('content-disposition', `inline; filename="${record.original_filename}"`);

    return new Response(object.body, { status: 200, headers });
  }

  /**
   * Approves a contributed file and copies it into the archive.
   *
   * The contributor is credited at this moment, into `content_contributors`,
   * which nothing in the editorial flow ever writes to — so the credit survives
   * every later edit of whatever the material becomes.
   */
  async approve(
    id: string,
    reviewer: AuthenticatedUser,
    options: { notes: string | null; requestId: string },
  ): Promise<{ mediaAssetId: string }> {
    const record = await this.find(id);
    if (!record) throw new NotFoundError('That file was not found.');
    if (record.status === 'promoted' && record.media_asset_id) {
      return { mediaAssetId: record.media_asset_id };
    }

    const object = await this.env.SUBMISSIONS.get(record.storage_key);
    if (!object) throw new NotFoundError('The contributed file is no longer in storage.');

    const bytes = await object.arrayBuffer();

    // Copied, not moved. The original stays so the provenance chain holds.
    await this.env.MEDIA.put(record.storage_key, bytes, {
      httpMetadata: {
        contentType: record.mime_type,
        cacheControl: 'public, max-age=31536000, immutable',
      },
      customMetadata: {
        originalFilename: record.original_filename,
        promotedFromSubmission: record.id,
        approvedBy: reviewer.id,
      },
    });

    const media = new MediaRepository(this.env.DB);
    const mediaAssetId = await media.create({
      storage_key: record.storage_key,
      folder: record.storage_key.split('/')[0] ?? 'heritage',
      original_filename: record.original_filename,
      mime_type: record.mime_type,
      size_bytes: record.size_bytes,
      checksum: null,
      title: record.caption,
      description: record.caption,
      alt_text: record.caption,
      credit: record.contributor_name,
      // Approved is not published. A second, deliberate act puts it on the site.
      status: CONTENT_STATUS.APPROVED,
      uploaded_by: null,
    });

    if (record.taken_at || record.location) {
      await media.update(mediaAssetId, {
        captured_at: record.taken_at,
        location: record.location,
      });
    }

    if (record.contributor_name) {
      await new EditorialRepository(this.env.DB).addContributor({
        resourceType: 'media_asset',
        resourceId: mediaAssetId,
        userId: null,
        contributorName: record.contributor_name,
        contributorType: 'individual',
        attributionPrefix: 'Contributed by',
        submissionId: record.submission_id,
        submittedAt: record.created_at,
        approvedBy: reviewer.id,
        usagePermission: record.usage_permission,
        copyrightHolder: record.contributor_name,
        copyrightNotes: null,
      });
    }

    await this.env.DB.prepare(
      `UPDATE "submission_uploads"
       SET "status" = 'promoted', "media_asset_id" = ?, "reviewed_by" = ?, "reviewed_at" = ?,
           "review_notes" = ?, "updated_at" = ?
       WHERE "id" = ?`,
    )
      .bind(mediaAssetId, reviewer.id, nowIso(), options.notes, nowIso(), id)
      .run();

    await new AuditRepository(this.env.DB).record({
      actorId: reviewer.id,
      actorEmail: reviewer.email,
      action: 'contribution.file.approved',
      resourceType: 'submission_upload',
      resourceId: id,
      changes: { mediaAssetId, contributor: record.contributor_name },
      requestId: options.requestId,
    });

    return { mediaAssetId };
  }

  /** Rejects a contributed file. The file itself is kept, not deleted. */
  async reject(
    id: string,
    reviewer: AuthenticatedUser,
    options: { notes: string | null; requestId: string },
  ): Promise<void> {
    const record = await this.find(id);
    if (!record) throw new NotFoundError('That file was not found.');

    await this.env.DB.prepare(
      `UPDATE "submission_uploads"
       SET "status" = 'rejected', "reviewed_by" = ?, "reviewed_at" = ?, "review_notes" = ?, "updated_at" = ?
       WHERE "id" = ?`,
    )
      .bind(reviewer.id, nowIso(), options.notes, nowIso(), id)
      .run();

    await new AuditRepository(this.env.DB).record({
      actorId: reviewer.id,
      actorEmail: reviewer.email,
      action: 'contribution.file.rejected',
      resourceType: 'submission_upload',
      resourceId: id,
      changes: { notes: options.notes },
      requestId: options.requestId,
    });
  }

  async find(id: string): Promise<SubmissionUploadRecord | null> {
    const row = await this.env.DB.prepare(
      'SELECT * FROM "submission_uploads" WHERE "id" = ? LIMIT 1',
    )
      .bind(id)
      .first<SubmissionUploadRecord>();
    return row ?? null;
  }
}

/** Reads an optional text field off the multipart form. */
function asText(value: string | File | null): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed === '' ? null : trimmed;
}
