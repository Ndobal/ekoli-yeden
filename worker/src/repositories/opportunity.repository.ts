import { assertSafeIdentifier } from './base.repository';
import { newId, nowIso } from '../utils/id';

export interface OpportunityRecord {
  id: string;
  slug: string;
  kind: string;
  title: string;
  organisation: string;
  summary: string | null;
  description: string | null;
  requirements: string | null;
  benefits: string | null;
  location_tier: string;
  location_text: string | null;
  is_remote: number;
  employment_type: string | null;
  pay_min: number | null;
  pay_max: number | null;
  pay_currency: string;
  pay_period: string | null;
  pay_note: string | null;
  application_url: string | null;
  application_email: string | null;
  application_phone: string | null;
  application_note: string | null;
  closes_at: string | null;
  posted_by: string | null;
  poster_name: string | null;
  source_url: string | null;
  verification_status: string;
  is_flagged: number;
  status: string;
  created_at: string;
  updated_at: string;
}

/** A listing with how well it fits one particular member. */
export interface MatchedOpportunity extends OpportunityRecord {
  matched_skills: number;
  required_skills: number;
  total_skills: number;
  location_distance: number;
  is_saved: number;
  report_count: number;
}

/**
 * YAKOLI OPPORTUNITIES
 *
 * Jobs, scholarships, training and grants — and the matching that decides which
 * of them a given member sees first.
 */
export class OpportunityRepository {
  constructor(private readonly db: D1Database) {}

  async findBySlugOrId(identifier: string, statuses: string[] | null): Promise<OpportunityRecord | null> {
    const conditions = ['("slug" = ? OR "id" = ?)'];
    const bindings: unknown[] = [identifier, identifier];

    if (statuses && statuses.length > 0) {
      conditions.push(`"status" IN (${statuses.map(() => '?').join(', ')})`);
      bindings.push(...statuses);
    }

    const row = await this.db
      .prepare(`SELECT * FROM "opportunities" WHERE ${conditions.join(' AND ')} LIMIT 1`)
      .bind(...bindings)
      .first<OpportunityRecord>();
    return row ?? null;
  }

  async slugExists(slug: string): Promise<boolean> {
    const row = await this.db
      .prepare('SELECT "id" FROM "opportunities" WHERE "slug" = ? LIMIT 1')
      .bind(slug)
      .first<{ id: string }>();
    return row !== null;
  }

  /**
   * The board, ordered for one particular member.
   *
   * ---------------------------------------------------------------------
   * WHAT "MATCHED" MEANS HERE, AND WHAT IT DELIBERATELY DOES NOT
   * ---------------------------------------------------------------------
   *
   * Two numbers decide the order: how many of the listing's skills the member
   * has, and how far away it is. Both are computed in SQL rather than by
   * loading every listing and sorting in the Worker — a jobs board is one of
   * the few things here that could plausibly reach thousands of rows.
   *
   * NOTHING IS FILTERED OUT FOR LACKING A SKILL. A member missing a required
   * skill still sees the listing, ranked lower, with the gap named. Being told
   * "this wants bookkeeping, which you have not listed" is more use to somebody
   * than the listing silently not existing — and a matching system that hides
   * work from people is a matching system that decides their future for them.
   *
   * `location_distance` is a plain integer so it sorts: 0 is Ekoli-Yeden
   * itself, and remote sits mid-table because it is available to everybody
   * without being local to anybody.
   */
  async listForMember(options: {
    userId: string | null;
    profileId: string | null;
    memberTier: string | null;
    kind?: string | null;
    tier?: string | null;
    search?: string | null;
    savedOnly?: boolean;
    limit: number;
    offset: number;
  }): Promise<{ items: MatchedOpportunity[]; total: number }> {
    const conditions = [`o."status" = 'published'`, 'o."is_flagged" = 0'];
    const bindings: unknown[] = [];

    // A closed listing is not an opportunity. Kept in the table for the record,
    // absent from the board.
    conditions.push(`(o."closes_at" IS NULL OR date(o."closes_at") >= date('now'))`);

    if (options.kind) {
      conditions.push('o."kind" = ?');
      bindings.push(options.kind);
    }
    if (options.tier) {
      conditions.push('o."location_tier" = ?');
      bindings.push(options.tier);
    }
    if (options.search) {
      const pattern = `%${options.search.replace(/[\\%_]/g, (char) => `\\${char}`)}%`;
      conditions.push(
        `(o."title" LIKE ? ESCAPE '\\' OR o."organisation" LIKE ? ESCAPE '\\' `
        + `OR o."summary" LIKE ? ESCAPE '\\')`,
      );
      bindings.push(pattern, pattern, pattern);
    }
    if (options.savedOnly && options.userId) {
      conditions.push(
        `EXISTS (SELECT 1 FROM "opportunity_saves" s
                 WHERE s."opportunity_id" = o."id" AND s."user_id" = ?)`,
      );
      bindings.push(options.userId);
    }

    const where = conditions.join(' AND ');

    // Bound once for the SELECT list, and again inside the ORDER BY expression
    // is avoided by aliasing — D1 allows referring to a select alias in ORDER BY.
    const profileId = options.profileId;
    const userId = options.userId;

    const matchedSkills = profileId
      ? `(SELECT COUNT(*) FROM "opportunity_skills" os
          INNER JOIN "member_skills" ms ON ms."skill_id" = os."skill_id"
          WHERE os."opportunity_id" = o."id" AND ms."profile_id" = ?)`
      : '0';

    const isSaved = userId
      ? `(SELECT COUNT(*) FROM "opportunity_saves" s
          WHERE s."opportunity_id" = o."id" AND s."user_id" = ?)`
      : '0';

    const distance = this.distanceExpression(options.memberTier);

    const selectBindings: unknown[] = [];
    if (profileId) selectBindings.push(profileId);
    if (userId) selectBindings.push(userId);

    const from = `FROM "opportunities" o WHERE ${where}`;

    const [countRow, rows] = await this.db.batch<Record<string, unknown>>([
      this.db.prepare(`SELECT COUNT(*) AS total ${from}`).bind(...bindings),
      this.db
        .prepare(
          `SELECT o.*,
                  ${matchedSkills} AS matched_skills,
                  (SELECT COUNT(*) FROM "opportunity_skills" os2
                    WHERE os2."opportunity_id" = o."id" AND os2."is_required" = 1) AS required_skills,
                  (SELECT COUNT(*) FROM "opportunity_skills" os3
                    WHERE os3."opportunity_id" = o."id") AS total_skills,
                  ${distance} AS location_distance,
                  ${isSaved} AS is_saved,
                  (SELECT COUNT(*) FROM "opportunity_reports" r
                    WHERE r."opportunity_id" = o."id" AND r."state" = 'open') AS report_count
           ${from}
           ORDER BY matched_skills DESC,
                    location_distance ASC,
                    o."closes_at" IS NULL,
                    o."closes_at" ASC,
                    o."created_at" DESC
           LIMIT ? OFFSET ?`,
        )
        .bind(...selectBindings, ...bindings, options.limit, options.offset),
    ]);

    return {
      items: (rows?.results ?? []) as unknown as MatchedOpportunity[],
      total: Number((countRow?.results?.[0]?.['total'] as number | undefined) ?? 0),
    };
  }

  /**
   * How far a listing is from where this member is, as a sortable integer.
   *
   * Built as a CASE rather than a lookup table because the answer depends on
   * the member: "cross_river" is near for somebody in Yakurr and far for
   * somebody in Lagos, and the same listing has to sort differently for each.
   *
   * A member with no location recorded gets the neutral ordering — nearest to
   * Ekoli-Yeden — rather than nothing at all. It is the best guess available
   * about somebody who has joined an Ekoli-Yeden archive.
   */
  private distanceExpression(memberTier: string | null): string {
    const order: Record<string, string[]> = {
      ekoli_yeden: ['ekoli_yeden', 'yakurr', 'cross_river', 'nigeria', 'remote', 'international'],
      yakurr: ['yakurr', 'ekoli_yeden', 'cross_river', 'nigeria', 'remote', 'international'],
      cross_river: ['cross_river', 'yakurr', 'ekoli_yeden', 'nigeria', 'remote', 'international'],
      nigeria: ['nigeria', 'cross_river', 'yakurr', 'ekoli_yeden', 'remote', 'international'],
      // Somebody abroad is served by remote work and international listings
      // first: a job in Ekori is not much use to a member in London, and
      // pretending otherwise would fill their board with things they cannot take.
      international: ['international', 'remote', 'nigeria', 'cross_river', 'yakurr', 'ekoli_yeden'],
    };

    const ranking = order[memberTier ?? 'ekoli_yeden'] ?? order['ekoli_yeden']!;

    const cases = ranking
      .map((tier, index) => `WHEN '${tier}' THEN ${index}`)
      .join(' ');

    return `CASE o."location_tier" ${cases} ELSE 9 END`;
  }

  /** The skills a listing asks for, with their names. */
  async skillsFor(opportunityId: string): Promise<{ id: string; name: string; is_required: number }[]> {
    const result = await this.db
      .prepare(
        `SELECT s."id", s."name", os."is_required"
         FROM "opportunity_skills" os
         INNER JOIN "skills" s ON s."id" = os."skill_id"
         WHERE os."opportunity_id" = ?
         ORDER BY os."is_required" DESC, s."name" ASC`,
      )
      .bind(opportunityId)
      .all<{ id: string; name: string; is_required: number }>();
    return result.results ?? [];
  }

  /** Which of those skills this member already has. */
  async memberSkillIds(profileId: string): Promise<Set<string>> {
    const result = await this.db
      .prepare('SELECT "skill_id" FROM "member_skills" WHERE "profile_id" = ?')
      .bind(profileId)
      .all<{ skill_id: string }>();
    return new Set((result.results ?? []).map((row) => row.skill_id));
  }

  async create(values: Record<string, unknown>): Promise<string> {
    const id = newId();
    const timestamp = nowIso();

    const columns = Object.keys(values).filter((column) => values[column] !== undefined);
    const all = ['id', ...columns, 'created_at', 'updated_at'];
    const bound = [id, ...columns.map((column) => values[column] ?? null), timestamp, timestamp];

    await this.db
      .prepare(
        `INSERT INTO "opportunities" (${all.map((c) => `"${assertSafeIdentifier(c)}"`).join(', ')})
         VALUES (${all.map(() => '?').join(', ')})`,
      )
      .bind(...bound)
      .run();

    return id;
  }

  private static readonly WRITABLE = new Set<string>([
    'title', 'organisation', 'summary', 'description', 'requirements', 'benefits',
    'kind', 'location_tier', 'location_text', 'is_remote', 'employment_type',
    'pay_min', 'pay_max', 'pay_currency', 'pay_period', 'pay_note',
    'application_url', 'application_email', 'application_phone', 'application_note',
    'closes_at', 'source_url', 'poster_relationship',
    // Reviewer-only, guarded at the controller rather than here.
    'status', 'verification_status', 'verified_by', 'verified_at',
    'is_flagged', 'flag_reason',
  ]);

  async update(id: string, values: Record<string, unknown>): Promise<number> {
    const columns = Object.keys(values).filter(
      (column) => OpportunityRepository.WRITABLE.has(column) && values[column] !== undefined,
    );
    if (columns.length === 0) return 0;

    const assignments = columns.map((column) => `"${assertSafeIdentifier(column)}" = ?`).join(', ');
    const result = await this.db
      .prepare(`UPDATE "opportunities" SET ${assignments}, "updated_at" = ? WHERE "id" = ?`)
      .bind(...columns.map((column) => values[column] ?? null), nowIso(), id)
      .run();

    return result.meta.changes ?? 0;
  }

  async setSkills(opportunityId: string, skills: { skillId: string; required: boolean }[]): Promise<void> {
    await this.db
      .prepare('DELETE FROM "opportunity_skills" WHERE "opportunity_id" = ?')
      .bind(opportunityId)
      .run();

    for (const skill of skills) {
      await this.db
        .prepare(
          `INSERT OR IGNORE INTO "opportunity_skills"
             ("id", "opportunity_id", "skill_id", "is_required", "created_at")
           VALUES (?, ?, ?, ?, ?)`,
        )
        .bind(newId(), opportunityId, skill.skillId, skill.required ? 1 : 0, nowIso())
        .run();
    }
  }

  // --- Saving ---------------------------------------------------------------

  async save(opportunityId: string, userId: string, note: string | null): Promise<void> {
    await this.db
      .prepare(
        `INSERT OR REPLACE INTO "opportunity_saves"
           ("id", "opportunity_id", "user_id", "note", "created_at")
         VALUES (?, ?, ?, ?, ?)`,
      )
      .bind(newId(), opportunityId, userId, note, nowIso())
      .run();
  }

  async unsave(opportunityId: string, userId: string): Promise<void> {
    await this.db
      .prepare('DELETE FROM "opportunity_saves" WHERE "opportunity_id" = ? AND "user_id" = ?')
      .bind(opportunityId, userId)
      .run();
  }

  async savedCount(userId: string): Promise<number> {
    const row = await this.db
      .prepare('SELECT COUNT(*) AS total FROM "opportunity_saves" WHERE "user_id" = ?')
      .bind(userId)
      .first<{ total: number }>();
    return Number(row?.total ?? 0);
  }

  // --- Reporting ------------------------------------------------------------

  async report(values: {
    opportunityId: string;
    reportedBy: string | null;
    reporterName: string | null;
    reason: string;
    detail: string | null;
  }): Promise<string> {
    const id = newId();
    await this.db
      .prepare(
        `INSERT OR REPLACE INTO "opportunity_reports"
           ("id", "opportunity_id", "reported_by", "reporter_name", "reason", "detail",
            "state", "created_at")
         VALUES (?, ?, ?, ?, ?, ?, 'open', ?)`,
      )
      .bind(id, values.opportunityId, values.reportedBy, values.reporterName, values.reason, values.detail, nowIso())
      .run();
    return id;
  }

  async openReportCount(opportunityId: string): Promise<number> {
    const row = await this.db
      .prepare(
        `SELECT COUNT(*) AS total FROM "opportunity_reports"
         WHERE "opportunity_id" = ? AND "state" = 'open'`,
      )
      .bind(opportunityId)
      .first<{ total: number }>();
    return Number(row?.total ?? 0);
  }

  async listReports(state: string): Promise<Record<string, unknown>[]> {
    const result = await this.db
      .prepare(
        `SELECT r.*, o."title", o."organisation", o."slug"
         FROM "opportunity_reports" r
         INNER JOIN "opportunities" o ON o."id" = r."opportunity_id"
         WHERE r."state" = ?
         ORDER BY r."created_at" DESC
         LIMIT 200`,
      )
      .bind(state)
      .all<Record<string, unknown>>();
    return result.results ?? [];
  }

  async settleReport(
    id: string,
    values: { state: string; reviewedBy: string; note: string | null },
  ): Promise<number> {
    const result = await this.db
      .prepare(
        `UPDATE "opportunity_reports"
         SET "state" = ?, "reviewed_by" = ?, "reviewed_at" = ?, "review_note" = ?
         WHERE "id" = ?`,
      )
      .bind(values.state, values.reviewedBy, nowIso(), values.note, id)
      .run();
    return result.meta.changes ?? 0;
  }

  /** Listings awaiting review, for the Opportunities Editor. */
  async listForReview(status: string, limit: number, offset: number): Promise<{
    items: OpportunityRecord[];
    total: number;
  }> {
    const [countRow, rows] = await this.db.batch<Record<string, unknown>>([
      this.db.prepare('SELECT COUNT(*) AS total FROM "opportunities" WHERE "status" = ?').bind(status),
      this.db
        .prepare(
          `SELECT * FROM "opportunities" WHERE "status" = ?
           ORDER BY "created_at" DESC LIMIT ? OFFSET ?`,
        )
        .bind(status, limit, offset),
    ]);

    return {
      items: (rows?.results ?? []) as unknown as OpportunityRecord[],
      total: Number((countRow?.results?.[0]?.['total'] as number | undefined) ?? 0),
    };
  }

  async recordView(id: string): Promise<void> {
    await this.db
      .prepare('UPDATE "opportunities" SET "view_count" = "view_count" + 1 WHERE "id" = ?')
      .bind(id)
      .run();
  }
}
