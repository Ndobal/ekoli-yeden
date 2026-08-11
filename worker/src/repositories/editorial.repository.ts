import { newId, nowIso } from '../utils/id';
import { listRecords, type ListResult } from './base.repository';

export interface SourceRecord {
  id: string;
  title: string;
  author: string | null;
  url: string | null;
  publication: string | null;
  publisher: string | null;
  publication_date: string | null;
  accessed_date: string | null;
  source_type: string;
  reliability: string;
  citation_text: string | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
}

export interface ContributorRecord {
  id: string;
  resource_type: string;
  resource_id: string;
  user_id: string | null;
  contributor_name: string;
  contributor_type: string;
  attribution_prefix: string;
  submitted_at: string | null;
  approved_at: string | null;
  usage_permission: string;
  copyright_holder: string | null;
  is_public: number;
  sort_order: number;
}

export interface VersionRecord {
  id: string;
  resource_type: string;
  resource_id: string;
  version_number: number;
  snapshot: string;
  changed_fields: string | null;
  change_summary: string | null;
  status_at_time: string | null;
  changed_by: string | null;
  changed_by_name: string | null;
  created_at: string;
}

/**
 * Sources, contributor attribution and version history.
 *
 * Between them these three tables are what let the archive answer the
 * questions that matter about any entry: where did this claim come from, who
 * gave us this material, and what did the page say before somebody changed it.
 */
export class EditorialRepository {
  constructor(private readonly db: D1Database) {}

  // --- Sources -------------------------------------------------------------

  async listSources(options: {
    search?: string | null;
    limit: number;
    offset: number;
  }): Promise<ListResult<SourceRecord>> {
    return listRecords<SourceRecord>(this.db, 'sources', {
      search: options.search ?? null,
      searchColumns: ['title', 'author', 'publication', 'url'],
      sortColumn: 'title',
      sortDirection: 'ASC',
      limit: options.limit,
      offset: options.offset,
    });
  }

  async findSource(id: string): Promise<SourceRecord | null> {
    const row = await this.db
      .prepare('SELECT * FROM "sources" WHERE "id" = ? LIMIT 1')
      .bind(id)
      .first<SourceRecord>();
    return row ?? null;
  }

  async createSource(values: Record<string, unknown>, createdBy: string): Promise<string> {
    const id = newId();
    const timestamp = nowIso();
    await this.db
      .prepare(
        `INSERT INTO "sources"
           ("id", "title", "author", "url", "publication", "publisher", "publication_date",
            "accessed_date", "source_type", "reliability", "citation_text", "notes",
            "created_by", "created_at", "updated_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        id,
        values['title'] ?? '',
        values['author'] ?? null,
        values['url'] ?? null,
        values['publication'] ?? null,
        values['publisher'] ?? null,
        values['publication_date'] ?? null,
        values['accessed_date'] ?? null,
        values['source_type'] ?? 'web',
        values['reliability'] ?? 'unassessed',
        values['citation_text'] ?? null,
        values['notes'] ?? null,
        createdBy,
        timestamp,
        timestamp,
      )
      .run();
    return id;
  }

  async updateSource(id: string, values: Record<string, unknown>): Promise<number> {
    const columns = Object.keys(values);
    if (columns.length === 0) return 0;

    const assignments = columns.map((column) => `"${column}" = ?`).join(', ');
    const result = await this.db
      .prepare(`UPDATE "sources" SET ${assignments}, "updated_at" = ? WHERE "id" = ?`)
      .bind(...columns.map((column) => values[column] ?? null), nowIso(), id)
      .run();
    return result.meta.changes ?? 0;
  }

  /** The citations attached to one record, in display order. */
  async sourcesFor(resourceType: string, resourceId: string): Promise<
    (SourceRecord & { supports: string | null; page_reference: string | null })[]
  > {
    const result = await this.db
      .prepare(
        `SELECT s.*, cs."supports", cs."page_reference"
         FROM "content_sources" cs
         INNER JOIN "sources" s ON s."id" = cs."source_id"
         WHERE cs."resource_type" = ? AND cs."resource_id" = ?
         ORDER BY cs."sort_order" ASC`,
      )
      .bind(resourceType, resourceId)
      .all<SourceRecord & { supports: string | null; page_reference: string | null }>();
    return result.results ?? [];
  }

  async attachSource(values: {
    resourceType: string;
    resourceId: string;
    sourceId: string;
    supports: string | null;
    pageReference: string | null;
    sortOrder: number;
  }): Promise<string> {
    const id = newId();
    await this.db
      .prepare(
        `INSERT OR IGNORE INTO "content_sources"
           ("id", "resource_type", "resource_id", "source_id", "supports", "page_reference", "sort_order", "created_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        id,
        values.resourceType,
        values.resourceId,
        values.sourceId,
        values.supports,
        values.pageReference,
        values.sortOrder,
        nowIso(),
      )
      .run();
    return id;
  }

  async detachSource(resourceType: string, resourceId: string, sourceId: string): Promise<number> {
    const result = await this.db
      .prepare(
        'DELETE FROM "content_sources" WHERE "resource_type" = ? AND "resource_id" = ? AND "source_id" = ?',
      )
      .bind(resourceType, resourceId, sourceId)
      .run();
    return result.meta.changes ?? 0;
  }

  // --- Contributor attribution ---------------------------------------------

  /**
   * Who supplied the material behind a record.
   *
   * Read on every public detail page. Nothing in the editorial flow writes to
   * this table, which is exactly why an acknowledgement survives every
   * rewrite of the article it belongs to.
   */
  async contributorsFor(resourceType: string, resourceId: string): Promise<ContributorRecord[]> {
    const result = await this.db
      .prepare(
        `SELECT * FROM "content_contributors"
         WHERE "resource_type" = ? AND "resource_id" = ? AND "is_public" = 1
         ORDER BY "sort_order" ASC, "created_at" ASC`,
      )
      .bind(resourceType, resourceId)
      .all<ContributorRecord>();
    return result.results ?? [];
  }

  async addContributor(values: {
    resourceType: string;
    resourceId: string;
    userId: string | null;
    contributorName: string;
    contributorType: string;
    attributionPrefix: string;
    submissionId: string | null;
    submittedAt: string | null;
    approvedBy: string | null;
    usagePermission: string;
    copyrightHolder: string | null;
    copyrightNotes: string | null;
  }): Promise<string> {
    const id = newId();
    const timestamp = nowIso();
    await this.db
      .prepare(
        `INSERT INTO "content_contributors"
           ("id", "resource_type", "resource_id", "user_id", "contributor_name", "contributor_type",
            "attribution_prefix", "submission_id", "submitted_at", "approved_at", "approved_by",
            "usage_permission", "copyright_holder", "copyright_notes", "is_public", "sort_order",
            "created_at", "updated_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 0, ?, ?)`,
      )
      .bind(
        id,
        values.resourceType,
        values.resourceId,
        values.userId,
        values.contributorName,
        values.contributorType,
        values.attributionPrefix,
        values.submissionId,
        values.submittedAt,
        values.approvedBy === null ? null : timestamp,
        values.approvedBy,
        values.usagePermission,
        values.copyrightHolder,
        values.copyrightNotes,
        timestamp,
        timestamp,
      )
      .run();
    return id;
  }

  // --- Versions ------------------------------------------------------------

  /**
   * Records what a row looked like before it was changed.
   *
   * Called before every editorial update. Versions are never deleted, so a
   * paragraph that somebody rewrites — or removes — remains recoverable.
   */
  async recordVersion(values: {
    resourceType: string;
    resourceId: string;
    snapshot: Record<string, unknown>;
    changedFields: Record<string, { from: unknown; to: unknown }> | null;
    changeSummary: string | null;
    statusAtTime: string | null;
    changedBy: string | null;
    changedByName: string | null;
  }): Promise<number> {
    const nextNumber = await this.nextVersionNumber(values.resourceType, values.resourceId);

    await this.db
      .prepare(
        `INSERT INTO "content_versions"
           ("id", "resource_type", "resource_id", "version_number", "snapshot", "changed_fields",
            "change_summary", "status_at_time", "changed_by", "changed_by_name", "created_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        newId(),
        values.resourceType,
        values.resourceId,
        nextNumber,
        JSON.stringify(values.snapshot),
        values.changedFields === null ? null : JSON.stringify(values.changedFields),
        values.changeSummary,
        values.statusAtTime,
        values.changedBy,
        values.changedByName,
        nowIso(),
      )
      .run();

    return nextNumber;
  }

  private async nextVersionNumber(resourceType: string, resourceId: string): Promise<number> {
    const row = await this.db
      .prepare(
        'SELECT MAX("version_number") AS highest FROM "content_versions" WHERE "resource_type" = ? AND "resource_id" = ?',
      )
      .bind(resourceType, resourceId)
      .first<{ highest: number | null }>();
    return Number(row?.highest ?? 0) + 1;
  }

  async versionsFor(resourceType: string, resourceId: string): Promise<VersionRecord[]> {
    const result = await this.db
      .prepare(
        `SELECT * FROM "content_versions"
         WHERE "resource_type" = ? AND "resource_id" = ?
         ORDER BY "version_number" DESC`,
      )
      .bind(resourceType, resourceId)
      .all<VersionRecord>();
    return result.results ?? [];
  }

  async findVersion(
    resourceType: string,
    resourceId: string,
    versionNumber: number,
  ): Promise<VersionRecord | null> {
    const row = await this.db
      .prepare(
        `SELECT * FROM "content_versions"
         WHERE "resource_type" = ? AND "resource_id" = ? AND "version_number" = ? LIMIT 1`,
      )
      .bind(resourceType, resourceId, versionNumber)
      .first<VersionRecord>();
    return row ?? null;
  }
}

/** Computes the changed-field map stored alongside a version snapshot. */
export function diffRecords(
  before: Record<string, unknown>,
  after: Record<string, unknown>,
): Record<string, { from: unknown; to: unknown }> {
  const changes: Record<string, { from: unknown; to: unknown }> = {};

  for (const [key, value] of Object.entries(after)) {
    // `updated_at` changes on every write and says nothing about the edit.
    if (key === 'updated_at') continue;
    if (before[key] !== value) changes[key] = { from: before[key] ?? null, to: value ?? null };
  }
  return changes;
}
