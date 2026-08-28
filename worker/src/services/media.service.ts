import { MediaRepository } from '../repositories/media.repository';
import type { Env } from '../types/env';
import type { AuthenticatedUser } from '../types/auth';
import { CONTENT_STATUS } from '../types/models';
import { BadRequestError, NotFoundError } from '../utils/errors';
import {
  assertContentMatchesType,
  assertUploadAllowed,
  buildStorageKey,
  isR2Folder,
  publicMediaUrl,
  resolveMimeType,
  sanitizeFilename,
  type R2Folder,
} from '../utils/files';
import { sha256 } from '../utils/crypto';

/**
 * R2 media handling.
 *
 * The Flutter client never receives an R2 credential or a signed bucket URL.
 * It uploads through this Worker and reads back through `/api/media/file/*`,
 * which is the only place an object's bytes are ever served.
 */
export class MediaService {
  private readonly repository: MediaRepository;

  constructor(private readonly env: Env) {
    this.repository = new MediaRepository(env.DB);
  }

  private get maxBytes(): number {
    return Number(this.env.MAX_UPLOAD_BYTES) || 25 * 1024 * 1024;
  }

  /**
   * Accepts a `multipart/form-data` upload, validates it and writes it to R2.
   *
   * The stored record starts at `pending_review`: an uploaded photograph is
   * material for the archive, not yet part of it.
   */
  async upload(
    request: Request,
    actor: AuthenticatedUser | null,
    options: { defaultStatus?: string } = {},
  ): Promise<{ id: string; storageKey: string; url: string; sizeBytes: number; mimeType: string }> {
    const form = await request.formData();
    const file = form.get('file');
    const folderValue = String(form.get('folder') ?? '');

    if (!(file instanceof File)) {
      throw new BadRequestError('No file was included in the upload.');
    }
    if (!isR2Folder(folderValue)) {
      throw new BadRequestError('A valid media folder must be supplied with the upload.');
    }
    const folder: R2Folder = folderValue;

    const filename = sanitizeFilename(file.name || 'upload');
    // Browsers frequently send nothing, or `application/octet-stream`, for a
    // file picked on a phone. Falling back to the filename is what stops an
    // ordinary photograph being refused as an unknown binary.
    const mimeType = resolveMimeType(file.type, filename);

    assertUploadAllowed({ folder, mimeType, sizeBytes: file.size, filename }, this.maxBytes);

    const bytes = await file.arrayBuffer();
    // Re-check after reading: `File.size` is client-reported metadata.
    assertUploadAllowed({ folder, mimeType, sizeBytes: bytes.byteLength, filename }, this.maxBytes);
    // And the bytes themselves, so a renamed executable is not stored as an image.
    assertContentMatchesType(bytes, mimeType);

    const storageKey = buildStorageKey(folder, mimeType, filename);
    const checksum = await sha256(bytes);

    await this.env.MEDIA.put(storageKey, bytes, {
      httpMetadata: {
        contentType: mimeType,
        // Objects are content-addressed by a random key, so they may be cached
        // aggressively once served.
        cacheControl: 'public, max-age=31536000, immutable',
      },
      customMetadata: {
        originalFilename: filename,
        uploadedBy: actor?.id ?? 'anonymous',
      },
    });

    const id = await this.repository.create({
      storage_key: storageKey,
      folder,
      original_filename: filename,
      mime_type: mimeType,
      size_bytes: bytes.byteLength,
      checksum,
      title: asOptionalString(form.get('title')),
      description: asOptionalString(form.get('description')),
      alt_text: asOptionalString(form.get('alt_text')),
      credit: asOptionalString(form.get('credit')),
      status: options.defaultStatus ?? CONTENT_STATUS.PENDING_REVIEW,
      uploaded_by: actor?.id ?? null,
    });

    return {
      id,
      storageKey,
      url: publicMediaUrl(this.env.PUBLIC_MEDIA_BASE_URL, storageKey),
      sizeBytes: bytes.byteLength,
      mimeType,
    };
  }

  /**
   * Streams an object from R2.
   *
   * Anonymous visitors may read only `published` assets; a signed-in editor may
   * read anything, so the media library works before content goes live.
   */
  async serve(storageKey: string, viewer: AuthenticatedUser | null, request: Request): Promise<Response> {
    const record = await this.repository.findByStorageKey(storageKey);
    if (!record) throw new NotFoundError('That file was not found.');
    if (record.status !== CONTENT_STATUS.PUBLISHED && !viewer) {
      // Same message as a genuine miss, so the URL space cannot be probed for
      // unpublished heritage material.
      throw new NotFoundError('That file was not found.');
    }

    const object = await this.env.MEDIA.get(storageKey, {
      range: request.headers,
      onlyIf: request.headers,
    });
    if (!object) throw new NotFoundError('That file was not found.');

    const headers = new Headers();
    object.writeHttpMetadata(headers);
    headers.set('etag', object.httpEtag);
    headers.set('x-content-type-options', 'nosniff');
    // Never let a browser execute an archived document as a page.
    headers.set('content-disposition', `inline; filename="${record.original_filename}"`);
    if (record.status !== CONTENT_STATUS.PUBLISHED) headers.set('cache-control', 'no-store');

    // `onlyIf` returns a body-less object on a conditional hit (304).
    if (!('body' in object) || object.body === null) {
      return new Response(null, { status: 304, headers });
    }

    const status = request.headers.get('range') !== null ? 206 : 200;
    return new Response(object.body, { status, headers });
  }

  async delete(id: string): Promise<void> {
    const record = await this.repository.findById(id);
    if (!record) throw new NotFoundError('That media item was not found.');

    await this.env.MEDIA.delete(record.storage_key);
    await this.repository.delete(id);
  }

  /** Attaches a public URL to a stored record for the client. */
  decorate(record: Record<string, unknown>): Record<string, unknown> {
    const storageKey = record['storage_key'];
    if (typeof storageKey !== 'string') return record;
    return { ...record, url: publicMediaUrl(this.env.PUBLIC_MEDIA_BASE_URL, storageKey) };
  }

  get repo(): MediaRepository {
    return this.repository;
  }
}

/** Reads an optional text field off the multipart form. */
function asOptionalString(value: string | File | null): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed === '' ? null : trimmed;
}
