import { newId, nowIso } from '../utils/id';
import { assertSafeIdentifier } from './base.repository';

export interface DeathReportRecord {
  id: string;
  subject_user_id: string | null;
  subject_name: string;
  reported_by: string | null;
  reporter_name: string | null;
  reporter_relationship: string | null;
  group_id: string | null;
  date_of_death: string | null;
  place_of_death: string | null;
  detail: string | null;
  state: string;
  confirmations: number;
  subject_notified_at: string | null;
  contest_closes_at: string | null;
  contested_at: string | null;
  contest_note: string | null;
  reviewed_by: string | null;
  reviewed_at: string | null;
  review_notes: string | null;
  ancestry_record_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface AncestryRecord {
  id: string;
  slug: string;
  user_id: string | null;
  full_name: string;
  also_known_as: string | null;
  birth_year: number | null;
  birth_date: string | null;
  death_date: string | null;
  death_year: number | null;
  place_of_origin: string | null;
  /// The quarter of Ekori they were from, where it is known.
  quarter: string | null;
  biography: string | null;
  contribution: string | null;
  survived_by: string | null;
  portrait_media_id: string | null;
  group_id: string | null;
  /// Unverified until the Preservation Team says otherwise — the same rule as
  /// every other record in the archive, and it applies to a memorial too.
  verification_status: string;
  status: string;
  created_at: string;
}

/**
 * REMEMBRANCE
 *
 * When somebody dies, their account is stilled rather than deleted, what they
 * made public stays public, and they are remembered on a page of their own.
 *
 * The care in here is almost all about the other case: somebody being reported
 * who has not died. A report changes nothing on its own; confirmation requires
 * a relative who was already a relative; and the account stays readable
 * throughout so its holder can say the report is wrong.
 */
export class RemembranceRepository {
  constructor(private readonly db: D1Database) {}

  // -------------------------------------------------------------------------
  // Reports
  // -------------------------------------------------------------------------

  async createReport(values: {
    subjectUserId: string | null;
    subjectName: string;
    reportedBy: string | null;
    reporterName: string | null;
    reporterRelationship: string | null;
    groupId: string | null;
    dateOfDeath: string | null;
    placeOfDeath: string | null;
    detail: string | null;
  }): Promise<string> {
    const id = newId();
    const timestamp = nowIso();

    await this.db
      .prepare(
        `INSERT INTO "death_reports"
           ("id", "subject_user_id", "subject_name", "reported_by", "reporter_name",
            "reporter_relationship", "group_id", "date_of_death", "place_of_death",
            "detail", "state", "confirmations", "created_at", "updated_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'reported', 0, ?, ?)`,
      )
      .bind(
        id,
        values.subjectUserId,
        values.subjectName,
        values.reportedBy,
        values.reporterName,
        values.reporterRelationship,
        values.groupId,
        values.dateOfDeath,
        values.placeOfDeath,
        values.detail,
        timestamp,
        timestamp,
      )
      .run();

    return id;
  }

  async findReport(id: string): Promise<DeathReportRecord | null> {
    const row = await this.db
      .prepare('SELECT * FROM "death_reports" WHERE "id" = ? LIMIT 1')
      .bind(id)
      .first<DeathReportRecord>();
    return row ?? null;
  }

  /** An open report about this account, if there is one. */
  async openReportFor(subjectUserId: string): Promise<DeathReportRecord | null> {
    const row = await this.db
      .prepare(
        `SELECT * FROM "death_reports"
         WHERE "subject_user_id" = ?
           AND "state" IN ('reported', 'family_confirmed', 'memorialised', 'contested')
         ORDER BY "created_at" DESC LIMIT 1`,
      )
      .bind(subjectUserId)
      .first<DeathReportRecord>();
    return row ?? null;
  }

  async listReports(state: string, limit: number, offset: number): Promise<{
    items: DeathReportRecord[];
    total: number;
  }> {
    const [countRow, rows] = await this.db.batch<Record<string, unknown>>([
      this.db.prepare('SELECT COUNT(*) AS total FROM "death_reports" WHERE "state" = ?').bind(state),
      this.db
        .prepare(
          'SELECT * FROM "death_reports" WHERE "state" = ? ORDER BY "created_at" DESC LIMIT ? OFFSET ?',
        )
        .bind(state, limit, offset),
    ]);

    return {
      items: (rows?.results ?? []) as unknown as DeathReportRecord[],
      total: Number((countRow?.results?.[0]?.['total'] as number | undefined) ?? 0),
    };
  }

  /** An allow-list, so a caller cannot set arbitrary columns on a report. */
  private static readonly REPORT_WRITABLE = new Set<string>([
    'state',
    'confirmations',
    'subject_notified_at',
    'contest_closes_at',
    'contested_at',
    'contest_note',
    'reviewed_by',
    'reviewed_at',
    'review_notes',
    'ancestry_record_id',
    'date_of_death',
    'place_of_death',
    'detail',
  ]);

  async updateReport(id: string, values: Record<string, unknown>): Promise<number> {
    const columns = Object.keys(values).filter(
      (column) =>
        RemembranceRepository.REPORT_WRITABLE.has(column) && values[column] !== undefined,
    );
    if (columns.length === 0) return 0;

    const assignments = columns.map((column) => `"${assertSafeIdentifier(column)}" = ?`).join(', ');
    const result = await this.db
      .prepare(`UPDATE "death_reports" SET ${assignments}, "updated_at" = ? WHERE "id" = ?`)
      .bind(...columns.map((column) => values[column] ?? null), nowIso(), id)
      .run();

    return result.meta.changes ?? 0;
  }

  // -------------------------------------------------------------------------
  // Confirmations
  // -------------------------------------------------------------------------

  async addConfirmation(values: {
    reportId: string;
    confirmedBy: string;
    confirmerName: string | null;
    relationshipId: string | null;
    relationship: string | null;
    isOfficial: boolean;
    note: string | null;
  }): Promise<string> {
    const id = newId();

    await this.db
      .prepare(
        `INSERT OR IGNORE INTO "death_confirmations"
           ("id", "report_id", "confirmed_by", "confirmer_name", "relationship_id",
            "relationship", "is_official", "note", "created_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        id,
        values.reportId,
        values.confirmedBy,
        values.confirmerName,
        values.relationshipId,
        values.relationship,
        values.isOfficial ? 1 : 0,
        values.note,
        nowIso(),
      )
      .run();

    // Recounted from the rows rather than incremented, so a repeated
    // confirmation cannot inflate the number that decides a memorialisation.
    await this.db
      .prepare(
        `UPDATE "death_reports" SET "confirmations" =
           (SELECT COUNT(*) FROM "death_confirmations" WHERE "report_id" = ?)
         WHERE "id" = ?`,
      )
      .bind(values.reportId, values.reportId)
      .run();

    return id;
  }

  async confirmationsFor(reportId: string): Promise<Record<string, unknown>[]> {
    const result = await this.db
      .prepare(
        'SELECT * FROM "death_confirmations" WHERE "report_id" = ? ORDER BY "created_at" ASC',
      )
      .bind(reportId)
      .all<Record<string, unknown>>();
    return result.results ?? [];
  }

  /** How many confirmations came from family, as opposed to the team. */
  async familyConfirmationCount(reportId: string): Promise<number> {
    const row = await this.db
      .prepare(
        `SELECT COUNT(*) AS total FROM "death_confirmations"
         WHERE "report_id" = ? AND "is_official" = 0 AND "relationship_id" IS NOT NULL`,
      )
      .bind(reportId)
      .first<{ total: number }>();
    return Number(row?.total ?? 0);
  }

  // -------------------------------------------------------------------------
  // The memorial itself
  // -------------------------------------------------------------------------

  async createAncestryRecord(values: {
    slug: string;
    userId: string | null;
    fullName: string;
    birthYear: number | null;
    birthDate: string | null;
    deathDate: string | null;
    deathYear: number | null;
    biography: string | null;
    groupId: string | null;
    recordedBy: string | null;
    deathReportId: string | null;
    portraitMediaId: string | null;
    status: string;
  }): Promise<string> {
    const id = newId();
    const timestamp = nowIso();

    await this.db
      .prepare(
        `INSERT INTO "ancestry_records"
           ("id", "slug", "user_id", "full_name", "birth_year", "birth_date",
            "death_date", "death_year", "biography", "group_id", "recorded_by",
            "death_report_id", "portrait_media_id", "author_id", "status",
            "created_at", "updated_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        id,
        values.slug,
        values.userId,
        values.fullName,
        values.birthYear,
        values.birthDate,
        values.deathDate,
        values.deathYear,
        values.biography,
        values.groupId,
        values.recordedBy,
        values.deathReportId,
        values.portraitMediaId,
        values.recordedBy,
        values.status,
        timestamp,
        timestamp,
      )
      .run();

    return id;
  }

  async findAncestryRecord(identifier: string): Promise<AncestryRecord | null> {
    const row = await this.db
      .prepare('SELECT * FROM "ancestry_records" WHERE "slug" = ? OR "id" = ? LIMIT 1')
      .bind(identifier, identifier)
      .first<AncestryRecord>();
    return row ?? null;
  }

  async ancestrySlugExists(slug: string): Promise<boolean> {
    const row = await this.db
      .prepare('SELECT "id" FROM "ancestry_records" WHERE "slug" = ? LIMIT 1')
      .bind(slug)
      .first<{ id: string }>();
    return row !== null;
  }

  /**
   * The memorial page.
   *
   * Ordered by year of death, most recent first, with the undated at the end —
   * an elder whose year nobody remembers should still be listed, and putting
   * the unknowns last is the only ordering that does not imply a date.
   */
  async listAncestry(options: {
    limit: number;
    offset: number;
    search?: string | null;
    groupId?: string | null;
  }): Promise<{ items: Record<string, unknown>[]; total: number }> {
    const conditions = [`a."status" = 'published'`];
    const bindings: unknown[] = [];

    if (options.groupId) {
      conditions.push('a."group_id" = ?');
      bindings.push(options.groupId);
    }
    if (options.search) {
      const pattern = `%${options.search.replace(/[\\%_]/g, (char) => `\\${char}`)}%`;
      conditions.push(
        `(a."full_name" LIKE ? ESCAPE '\\' OR a."also_known_as" LIKE ? ESCAPE '\\'
          OR a."biography" LIKE ? ESCAPE '\\')`,
      );
      bindings.push(pattern, pattern, pattern);
    }

    const where = conditions.join(' AND ');

    const [countRow, rows] = await this.db.batch<Record<string, unknown>>([
      this.db.prepare(`SELECT COUNT(*) AS total FROM "ancestry_records" a WHERE ${where}`).bind(...bindings),
      this.db
        .prepare(
          `SELECT a.*, ma."storage_key" AS portrait_key, g."title" AS group_title, g."slug" AS group_slug
           FROM "ancestry_records" a
           LEFT JOIN "media_assets" ma ON ma."id" = a."portrait_media_id"
           LEFT JOIN "community_groups" g ON g."id" = a."group_id"
           WHERE ${where}
           ORDER BY a."death_year" IS NULL, a."death_year" DESC, a."full_name" ASC
           LIMIT ? OFFSET ?`,
        )
        .bind(...bindings, options.limit, options.offset),
    ]);

    return {
      items: (rows?.results ?? []) as Record<string, unknown>[],
      total: Number((countRow?.results?.[0]?.['total'] as number | undefined) ?? 0),
    };
  }

  // -------------------------------------------------------------------------
  // Tributes
  // -------------------------------------------------------------------------

  async addTribute(values: {
    recordId: string;
    authorId: string | null;
    authorName: string | null;
    relationship: string | null;
    message: string;
  }): Promise<string> {
    const id = newId();
    const timestamp = nowIso();

    await this.db
      .prepare(
        `INSERT INTO "ancestry_tributes"
           ("id", "record_id", "author_id", "author_name", "relationship", "message",
            "status", "created_at", "updated_at")
         VALUES (?, ?, ?, ?, ?, ?, 'published', ?, ?)`,
      )
      .bind(
        id,
        values.recordId,
        values.authorId,
        values.authorName,
        values.relationship,
        values.message,
        timestamp,
        timestamp,
      )
      .run();

    return id;
  }

  async tributesFor(recordId: string): Promise<Record<string, unknown>[]> {
    const result = await this.db
      .prepare(
        `SELECT * FROM "ancestry_tributes"
         WHERE "record_id" = ? AND "status" = 'published'
         ORDER BY "created_at" ASC`,
      )
      .bind(recordId)
      .all<Record<string, unknown>>();
    return result.results ?? [];
  }

  // -------------------------------------------------------------------------
  // The account itself
  // -------------------------------------------------------------------------

  /**
   * Moves an account between living, reported, memorialised and contested.
   *
   * Writes ONLY to `member_profiles.memorial_state`. `users.status` is
   * deliberately untouched: an account locked out of contesting its own death
   * has no way to correct a mistake, so a memorialised account still signs in
   * and simply cannot write.
   */
  async setMemorialState(userId: string, state: string): Promise<number> {
    const result = await this.db
      .prepare(
        'UPDATE "member_profiles" SET "memorial_state" = ?, "updated_at" = ? WHERE "user_id" = ?',
      )
      .bind(state, nowIso(), userId)
      .run();
    return result.meta.changes ?? 0;
  }

  async memorialStateOf(userId: string): Promise<string> {
    const row = await this.db
      .prepare('SELECT "memorial_state" FROM "member_profiles" WHERE "user_id" = ? LIMIT 1')
      .bind(userId)
      .first<{ memorial_state: string }>();
    return row?.memorial_state ?? 'living';
  }
}
