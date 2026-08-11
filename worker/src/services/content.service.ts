import { ContentRepository } from '../repositories/content.repository';
import { EditorialRepository, diffRecords } from '../repositories/editorial.repository';
import type { ContentResource } from './content-registry';
import { CONTENT_STATUS, type ContentStatus, ALL_CONTENT_STATUSES } from '../types/models';
import type { AuthenticatedUser } from '../types/auth';
import { ConflictError, NotFoundError } from '../utils/errors';
import { nowIso } from '../utils/id';
import { slugify } from '../utils/slug';
import { parsePagination, parseSort } from '../utils/pagination';

/**
 * The rule that makes this an archive rather than a noticeboard:
 *
 *   A visitor sees `published` and nothing else.
 *
 * Draft, pending, approved, rejected and archived records exist only inside the
 * admin API, behind a permission check.
 */
export const PUBLIC_STATUSES: ContentStatus[] = [CONTENT_STATUS.PUBLISHED];

export interface ListQuery {
  statuses: ContentStatus[];
  search: string | null;
  filters: Record<string, string | number | null>;
  sortColumn: string;
  sortDirection: 'ASC' | 'DESC';
  page: number;
  perPage: number;
  offset: number;
}

export class ContentService {
  private readonly repository: ContentRepository;
  private readonly editorial: EditorialRepository;

  constructor(
    db: D1Database,
    private readonly resource: ContentResource,
  ) {
    this.repository = new ContentRepository(db, resource);
    this.editorial = new EditorialRepository(db);
  }

  /** Builds a list query from the URL, honouring what the caller may see. */
  buildQuery(query: URLSearchParams, isAdmin: boolean): ListQuery {
    const { page, perPage, offset } = parsePagination(query);
    const { column, direction } = parseSort(
      query,
      this.resource.sortableColumns,
      this.resource.defaultSort,
    );

    let statuses: ContentStatus[] = PUBLIC_STATUSES;
    if (isAdmin) {
      const requested = query.get('status');
      statuses = requested
        ? ALL_CONTENT_STATUSES.filter((status) => status === requested)
        : ALL_CONTENT_STATUSES;
      // An unrecognised `?status=` must not silently widen the result set.
      if (statuses.length === 0) statuses = ALL_CONTENT_STATUSES;
    }

    return {
      statuses,
      search: query.get('q') ?? query.get('search'),
      filters: this.buildFilters(query),
      sortColumn: column,
      sortDirection: direction,
      page,
      perPage,
      offset,
    };
  }

  /**
   * Column filters taken from the query string.
   *
   * Only columns the resource itself declares writable are eligible, so a
   * caller cannot filter on (and thereby probe) an internal column.
   */
  private buildFilters(query: URLSearchParams): Record<string, string | number | null> {
    const filters: Record<string, string | number | null> = {};
    const filterable = ['category', 'year', 'festival_id', 'category_id', 'is_featured', 'related_festival_id'];

    for (const column of filterable) {
      if (!this.resource.writableColumns.includes(column)) continue;
      const value = query.get(column);
      if (value === null || value === '') continue;
      const numeric = Number(value);
      filters[column] = Number.isFinite(numeric) && /^-?\d+$/.test(value) ? numeric : value;
    }
    return filters;
  }

  async list(query: ListQuery): Promise<{ items: Record<string, unknown>[]; total: number }> {
    return this.repository.list({
      statuses: query.statuses,
      search: query.search,
      filters: query.filters,
      sortColumn: query.sortColumn,
      sortDirection: query.sortDirection,
      limit: query.perPage,
      offset: query.offset,
    });
  }

  async findOne(identifier: string, isAdmin: boolean): Promise<Record<string, unknown>> {
    const statuses = isAdmin ? null : PUBLIC_STATUSES;
    const record = await this.repository.findBySlugOrId(identifier, statuses);
    if (!record) {
      throw new NotFoundError(`That ${this.resource.label.toLowerCase()} was not found.`);
    }
    return record;
  }

  /**
   * Creates a record.
   *
   * New content starts as a `draft` unless the editor explicitly asked for
   * another status — an entry never becomes public by accident.
   */
  async create(
    payload: Record<string, unknown>,
    actor: AuthenticatedUser,
  ): Promise<Record<string, unknown>> {
    const values = this.repository.pickWritable(payload);
    values['status'] = (values['status'] as ContentStatus | undefined) ?? CONTENT_STATUS.DRAFT;

    await this.ensureSlug(values, null);
    this.stampAuthorship(values, actor);
    values['author_id'] = actor.id;

    const id = await this.repository.create(values);
    const created = await this.repository.findById(id, null);
    if (!created) throw new NotFoundError('The record could not be read back after creation.');
    return created;
  }

  /**
   * Updates a record, snapshotting it first.
   *
   * The version is written before the change is applied, so the archive keeps
   * its own memory of what every page said before somebody edited it. This is
   * the safeguard that makes an editable history section responsible rather
   * than dangerous.
   */
  async update(
    id: string,
    payload: Record<string, unknown>,
    actor: AuthenticatedUser,
  ): Promise<Record<string, unknown>> {
    const existing = await this.repository.findById(id, null);
    if (!existing) throw new NotFoundError(`That ${this.resource.label.toLowerCase()} was not found.`);

    const values = this.repository.pickWritable(payload);
    if (Object.keys(values).length > 0) {
      await this.ensureSlug(values, id);
      this.stampEditor(values, actor);

      const changedFields = diffRecords(existing, values);
      if (Object.keys(changedFields).length > 0) {
        await this.editorial.recordVersion({
          resourceType: this.resource.key,
          resourceId: id,
          snapshot: existing,
          changedFields,
          changeSummary: `${Object.keys(changedFields).length} field(s) changed`,
          statusAtTime: String(existing['status'] ?? ''),
          changedBy: actor.id,
          changedByName: actor.displayName,
        });
      }

      await this.repository.update(id, values);
    }

    const updated = await this.repository.findById(id, null);
    if (!updated) throw new NotFoundError('The record could not be read back after the update.');
    return updated;
  }

  /**
   * Moves a record through the editorial workflow, recording who did it.
   *
   * Each transition stamps the person responsible in its own column, so the
   * archive can always answer "who approved this?" and "who published this?"
   * without reading the audit log.
   */
  async changeStatus(
    id: string,
    status: ContentStatus,
    actor: AuthenticatedUser,
    reviewNotes?: string | null,
  ): Promise<Record<string, unknown>> {
    const existing = await this.repository.findById(id, null);
    if (!existing) {
      throw new NotFoundError(`That ${this.resource.label.toLowerCase()} was not found.`);
    }

    const values: Record<string, unknown> = { status };
    const timestamp = nowIso();

    switch (status) {
      case CONTENT_STATUS.PENDING_REVIEW:
        values['submitted_at'] = timestamp;
        break;
      case CONTENT_STATUS.APPROVED:
      case CONTENT_STATUS.REJECTED:
        values['reviewer_id'] = actor.id;
        if (reviewNotes !== undefined) values['review_notes'] = reviewNotes;
        break;
      case CONTENT_STATUS.PUBLISHED:
        values['published_by'] = actor.id;
        values['published_at_workflow'] = timestamp;
        break;
      default:
        break;
    }

    await this.editorial.recordVersion({
      resourceType: this.resource.key,
      resourceId: id,
      snapshot: existing,
      changedFields: { status: { from: existing['status'], to: status } },
      changeSummary: `Status changed from ${existing['status']} to ${status}`,
      statusAtTime: String(existing['status'] ?? ''),
      changedBy: actor.id,
      changedByName: actor.displayName,
    });

    await this.repository.update(id, values);

    const updated = await this.repository.findById(id, null);
    if (!updated) throw new NotFoundError('The record could not be read back.');
    return updated;
  }

  /** Records who last edited a record, where the table supports it. */
  private stampEditor(values: Record<string, unknown>, actor: AuthenticatedUser): void {
    values['editor_id'] = actor.id;
  }

  async delete(id: string): Promise<void> {
    const deleted = await this.repository.delete(id);
    if (deleted === 0) {
      throw new NotFoundError(`That ${this.resource.label.toLowerCase()} was not found.`);
    }
  }

  /** Fills in a slug from the title when the editor did not supply one. */
  private async ensureSlug(values: Record<string, unknown>, exceptId: string | null): Promise<void> {
    const slugColumn = this.resource.slugColumn;
    if (!slugColumn) return;

    let slug = typeof values[slugColumn] === 'string' ? (values[slugColumn] as string) : '';
    if (slug === '') {
      const source = values['title'] ?? values['name'] ?? values['word'];
      if (typeof source !== 'string' || source.trim() === '') return;
      slug = slugify(source);
    } else {
      slug = slugify(slug);
    }
    if (slug === '') return;

    if (await this.repository.slugExists(slug, exceptId ?? undefined)) {
      throw new ConflictError(
        `The address "${slug}" is already used by another ${this.resource.label.toLowerCase()}.`,
      );
    }
    values[slugColumn] = slug;
  }

  /** Records who contributed an entry, where the table supports it. */
  private stampAuthorship(values: Record<string, unknown>, actor: AuthenticatedUser): void {
    if (this.resource.writableColumns.includes('contributed_by') && !values['contributed_by']) {
      values['contributed_by'] = actor.displayName;
    }
  }
}
