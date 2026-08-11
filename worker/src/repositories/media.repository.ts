import type { MediaAssetRecord } from '../types/models';
import { newId, nowIso } from '../utils/id';
import { deleteRecord, findRecordBy, insertRecord, listRecords, updateRecord, type ListResult } from './base.repository';

/**
 * Metadata for every object stored in R2.
 *
 * D1 holds only the record; the bytes live in the bucket. Nothing reads an R2
 * object without first resolving it through this table, which is what lets the
 * moderation workflow keep unapproved material out of public view.
 */
export class MediaRepository {
  constructor(private readonly db: D1Database) {}

  async list(options: {
    folder?: string | null;
    statuses: string[];
    search?: string | null;
    limit: number;
    offset: number;
  }): Promise<ListResult<MediaAssetRecord>> {
    return listRecords<MediaAssetRecord>(this.db, 'media_assets', {
      status: options.statuses,
      search: options.search ?? null,
      searchColumns: ['title', 'description', 'original_filename', 'credit', 'location'],
      filters: options.folder ? { folder: options.folder } : undefined,
      sortColumn: 'created_at',
      sortDirection: 'DESC',
      limit: options.limit,
      offset: options.offset,
    });
  }

  async findById(id: string): Promise<MediaAssetRecord | null> {
    return findRecordBy<MediaAssetRecord>(this.db, 'media_assets', 'id', id);
  }

  async findByStorageKey(storageKey: string): Promise<MediaAssetRecord | null> {
    return findRecordBy<MediaAssetRecord>(this.db, 'media_assets', 'storage_key', storageKey);
  }

  async create(values: {
    storage_key: string;
    folder: string;
    original_filename: string;
    mime_type: string;
    size_bytes: number;
    checksum: string | null;
    title: string | null;
    description: string | null;
    alt_text: string | null;
    credit: string | null;
    status: string;
    uploaded_by: string | null;
  }): Promise<string> {
    const id = newId();
    const timestamp = nowIso();
    await insertRecord(this.db, 'media_assets', {
      ...values,
      id,
      captured_at: null,
      location: null,
      verification_status: 'unverified',
      created_at: timestamp,
      updated_at: timestamp,
    });
    return id;
  }

  async update(id: string, values: Record<string, unknown>): Promise<number> {
    return updateRecord(this.db, 'media_assets', id, values);
  }

  async delete(id: string): Promise<number> {
    return deleteRecord(this.db, 'media_assets', id);
  }
}
