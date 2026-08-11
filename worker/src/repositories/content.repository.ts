import type { ContentResource } from '../services/content-registry';
import type { ContentStatus } from '../types/models';
import { newId, nowIso } from '../utils/id';
import {
  deleteRecord,
  findRecordBy,
  insertRecord,
  listRecords,
  updateRecord,
  type ListResult,
} from './base.repository';

/**
 * One repository serves every content type.
 *
 * The shape of each table is described by the content registry, so adding a
 * content type in Module 2 requires a migration and a registry entry — not a
 * new repository.
 */
export class ContentRepository {
  constructor(
    private readonly db: D1Database,
    private readonly resource: ContentResource,
  ) {}

  async list(options: {
    statuses: ContentStatus[];
    search?: string | null;
    filters?: Record<string, string | number | null>;
    sortColumn: string;
    sortDirection: 'ASC' | 'DESC';
    limit: number;
    offset: number;
    columns?: string[] | null;
  }): Promise<ListResult<Record<string, unknown>>> {
    return listRecords<Record<string, unknown>>(this.db, this.resource.table, {
      status: options.statuses,
      search: options.search ?? null,
      searchColumns: this.resource.searchableColumns,
      // The resource's own discriminator wins over anything from the request.
      filters: { ...options.filters, ...(this.resource.fixedFilters ?? {}) },
      sortColumn: options.sortColumn,
      sortDirection: options.sortDirection,
      limit: options.limit,
      offset: options.offset,
      columns: options.columns ?? this.resource.publicColumns,
    });
  }

  async findById(
    id: string,
    statuses: ContentStatus[] | null,
  ): Promise<Record<string, unknown> | null> {
    const record = await findRecordBy<Record<string, unknown>>(
      this.db,
      this.resource.table,
      'id',
      id,
      { status: statuses },
    );
    return this.matchesFixedFilters(record) ? record : null;
  }

  /**
   * Guards resources that share a table.
   *
   * A lookup by id would otherwise reach a row belonging to a different
   * `content_type`, letting one resource read or overwrite another's records.
   */
  private matchesFixedFilters(record: Record<string, unknown> | null): boolean {
    if (!record) return false;
    for (const [column, value] of Object.entries(this.resource.fixedFilters ?? {})) {
      if (record[column] !== value) return false;
    }
    return true;
  }

  /**
   * Looks a record up by its slug, falling back to the id.
   *
   * Public URLs use slugs, but admin screens and cross-references hold ids, and
   * both need to resolve through the same endpoint.
   */
  async findBySlugOrId(
    identifier: string,
    statuses: ContentStatus[] | null,
  ): Promise<Record<string, unknown> | null> {
    if (this.resource.slugColumn) {
      const bySlug = await findRecordBy<Record<string, unknown>>(
        this.db,
        this.resource.table,
        this.resource.slugColumn,
        identifier,
        { status: statuses },
      );
      if (bySlug) return bySlug;
    }
    return this.findById(identifier, statuses);
  }

  async slugExists(slug: string, exceptId?: string): Promise<boolean> {
    if (!this.resource.slugColumn) return false;
    const existing = await findRecordBy<{ id: string }>(
      this.db,
      this.resource.table,
      this.resource.slugColumn,
      slug,
      { columns: ['id'] },
    );
    return existing !== null && existing.id !== exceptId;
  }

  async create(values: Record<string, unknown>): Promise<string> {
    const id = newId();
    const timestamp = nowIso();
    await insertRecord(this.db, this.resource.table, {
      ...values,
      // Stamped last so a request cannot set its own discriminator and file a
      // record under a resource it does not belong to.
      ...(this.resource.fixedFilters ?? {}),
      id,
      created_at: timestamp,
      updated_at: timestamp,
    });
    return id;
  }

  async update(id: string, values: Record<string, unknown>): Promise<number> {
    return updateRecord(this.db, this.resource.table, id, values);
  }

  async delete(id: string): Promise<number> {
    return deleteRecord(this.db, this.resource.table, id);
  }

  /** Restricts an incoming payload to the columns an editor may actually set. */
  pickWritable(payload: Record<string, unknown>): Record<string, unknown> {
    const picked: Record<string, unknown> = {};
    for (const column of this.resource.writableColumns) {
      if (Object.prototype.hasOwnProperty.call(payload, column)) {
        picked[column] = payload[column];
      }
    }
    return picked;
  }
}
