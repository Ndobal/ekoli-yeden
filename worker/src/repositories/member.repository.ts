import { newId, nowIso } from '../utils/id';
import { assertSafeIdentifier } from './base.repository';

export interface MemberProfileRecord {
  id: string;
  user_id: string;
  membership_number: string;
  handle: string;
  membership_status: string;
  joined_at: string;
  full_name: string | null;
  avatar_media_id: string | null;
  headline: string | null;
  bio: string | null;
  phone: string | null;
  whatsapp_number: string | null;
  /**
   * Who may write to this member: 'members' or 'nobody'.
   *
   * Defaults to 'members' rather than to everyone. Being reachable is the point
   * of the messaging module; being reachable by anybody who can type is how
   * people stop using it.
   */
  messages_from: string;
  /**
   * Whether they appear when somebody searches for a name to message.
   *
   * Separate from `listed_in_directory`: "do not put me in the published list"
   * and "do not let my cousin find me to say hello" are different wishes, and
   * many people hold the first without the second.
   */
  findable_for_messages: number;
  country: string | null;
  state_region: string | null;
  lga: string | null;
  community_area: string | null;
  city: string | null;
  is_in_ekoli_yeden: number;
  is_diaspora: number;
  connection: string | null;
  connection_note: string | null;
  /// Indigene, resident, friend, researcher, organisation. Never a permission.
  relationship: string | null;
  profession_id: string | null;
  profession_other: string | null;
  industry: string | null;
  employer: string | null;
  years_experience: number | null;
  education_level: string | null;
  education_field: string | null;
  institution: string | null;
  employment_status: string | null;
  open_to_opportunities: number;
  birth_year: number | null;
  profile_visibility: string;
  show_contact: number;
  show_employment: number;
  show_location: number;
  show_education: number;
  listed_in_directory: number;
  notify_opportunities: number;
  notify_forum: number;
  notify_community: number;
  completion_percent: number;
  created_at: string;
  updated_at: string;
}

export interface SkillRecord {
  id: string;
  slug: string;
  name: string;
  category: string | null;
  member_count: number;
}

/**
 * MEMBER PROFILES
 *
 * One row per Okoli, joined to the account it belongs to. Everything that made
 * the archive's other repositories careful applies here twice over: this table
 * holds personal data about living people — where they live, what they earn a
 * living at, whether they are currently out of work — and the platform's
 * promise is that none of it becomes public by accident.
 *
 * The reads below therefore return the raw row, and `visibleProfile` in
 * `services/membership.ts` decides what any given caller may actually see.
 * Nothing here should ever be handed to a response untouched.
 */
export class MemberRepository {
  constructor(private readonly db: D1Database) {}

  // -------------------------------------------------------------------------
  // Reading
  // -------------------------------------------------------------------------

  async findByUserId(userId: string): Promise<MemberProfileRecord | null> {
    const row = await this.db
      .prepare('SELECT * FROM "member_profiles" WHERE "user_id" = ? LIMIT 1')
      .bind(userId)
      .first<MemberProfileRecord>();
    return row ?? null;
  }

  async findByHandle(handle: string): Promise<MemberProfileRecord | null> {
    const row = await this.db
      .prepare('SELECT * FROM "member_profiles" WHERE "handle" = ? OR "id" = ? LIMIT 1')
      .bind(handle, handle)
      .first<MemberProfileRecord>();
    return row ?? null;
  }

  async handleExists(handle: string): Promise<boolean> {
    const row = await this.db
      .prepare('SELECT "id" FROM "member_profiles" WHERE "handle" = ? LIMIT 1')
      .bind(handle)
      .first<{ id: string }>();
    return row !== null;
  }

  /**
   * A profile with the things that hang off it — the account's email and
   * display name, the profession's label, the avatar's storage key.
   *
   * One query rather than four, because every profile view needs all of it and
   * a member's own dashboard should not cost a round trip per field.
   */
  async findFullByUserId(userId: string): Promise<Record<string, unknown> | null> {
    const row = await this.db
      .prepare(
        `SELECT p.*, u."email", u."display_name", u."status" AS account_status,
                pr."name" AS profession, pr."slug" AS profession_slug,
                ma."storage_key" AS avatar_storage_key
         FROM "member_profiles" p
         INNER JOIN "users" u ON u."id" = p."user_id"
         LEFT JOIN "professions" pr ON pr."id" = p."profession_id"
         LEFT JOIN "media_assets" ma ON ma."id" = p."avatar_media_id"
         WHERE p."user_id" = ? LIMIT 1`,
      )
      .bind(userId)
      .first<Record<string, unknown>>();
    return row ?? null;
  }

  async findFullByHandle(handle: string): Promise<Record<string, unknown> | null> {
    const row = await this.db
      .prepare(
        `SELECT p.*, u."email", u."display_name", u."status" AS account_status,
                pr."name" AS profession, pr."slug" AS profession_slug,
                ma."storage_key" AS avatar_storage_key
         FROM "member_profiles" p
         INNER JOIN "users" u ON u."id" = p."user_id"
         LEFT JOIN "professions" pr ON pr."id" = p."profession_id"
         LEFT JOIN "media_assets" ma ON ma."id" = p."avatar_media_id"
         WHERE p."handle" = ? LIMIT 1`,
      )
      .bind(handle)
      .first<Record<string, unknown>>();
    return row ?? null;
  }

  // -------------------------------------------------------------------------
  // Writing
  // -------------------------------------------------------------------------

  async create(values: {
    userId: string;
    membershipNumber: string;
    handle: string;
    fullName: string | null;
    membershipStatus: string;
  }): Promise<string> {
    const id = newId();
    const timestamp = nowIso();

    await this.db
      .prepare(
        `INSERT INTO "member_profiles"
           ("id", "user_id", "membership_number", "handle", "membership_status", "joined_at",
            "full_name", "created_at", "updated_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        id,
        values.userId,
        values.membershipNumber,
        values.handle,
        values.membershipStatus,
        timestamp,
        values.fullName,
        timestamp,
        timestamp,
      )
      .run();

    return id;
  }

  /**
   * The columns a member may set on their own profile.
   *
   * An allow-list rather than "whatever was sent". `membership_status`,
   * `membership_number`, `user_id` and `completion_percent` are absent
   * deliberately — a member does not activate their own membership, does not
   * choose their own number, and does not score their own profile.
   */
  private static readonly WRITABLE = new Set<string>([
    'full_name',
    'headline',
    'bio',
    'avatar_media_id',
    'phone',
    'whatsapp_number',
    'country',
    'state_region',
    'lga',
    'community_area',
    'city',
    'connection',
    'connection_note',
    // What they are to Ekoli-Yeden. Grants nothing; see `membership.ts`.
    'relationship',
    'profession_id',
    'profession_other',
    'industry',
    'employer',
    'years_experience',
    'education_level',
    'education_field',
    'institution',
    'employment_status',
    'open_to_opportunities',
    'birth_year',
    'profile_visibility',
    'show_contact',
    'show_employment',
    'show_location',
    'show_education',
    'listed_in_directory',
    'notify_opportunities',
    'notify_forum',
    'notify_community',
    // Who may write to them, and whether they can be found to be written to.
    'messages_from',
    'findable_for_messages',
    // The full date of birth. Birthdays need the day and the month; the year
    // stays private and is only used for age-grade brackets.
    'birth_date',
    'show_birthday',
    'birthday_wishes_enabled',
    'show_age',
    // Where in Ekori they are from, and the clan.
    //
    // `place_text` is what the member typed and is kept exactly as typed;
    // `place_id` is what the archive matched it to and is written by
    // `MembershipService.update` rather than accepted from a request. Keeping
    // both means a wrong match can be spotted and corrected instead of
    // silently replacing what somebody said about their own home.
    'place_text',
    'place_id',
    'clan',
    // Derived on write by the service, never accepted from a request — see
    // `MembershipService.update`, which strips them from the payload first.
    'is_in_ekoli_yeden',
    'is_diaspora',
    'employment_updated_at',
    'completion_percent',
    'last_active_at',
    'birth_day',
    'birth_month',
    'phone_normalised',
    // `memorial_state` is absent on purpose: a member does not record their own
    // death, and nothing reachable from a profile edit should be able to.
  ]);

  async update(profileId: string, values: Record<string, unknown>): Promise<number> {
    const columns = Object.keys(values).filter(
      (column) => MemberRepository.WRITABLE.has(column) && values[column] !== undefined,
    );
    if (columns.length === 0) return 0;

    const assignments = columns.map((column) => `"${assertSafeIdentifier(column)}" = ?`).join(', ');
    const result = await this.db
      .prepare(`UPDATE "member_profiles" SET ${assignments}, "updated_at" = ? WHERE "id" = ?`)
      .bind(...columns.map((column) => values[column] ?? null), nowIso(), profileId)
      .run();

    return result.meta.changes ?? 0;
  }

  async touchActivity(profileId: string): Promise<void> {
    await this.db
      .prepare('UPDATE "member_profiles" SET "last_active_at" = ? WHERE "id" = ?')
      .bind(nowIso(), profileId)
      .run();
  }

  // -------------------------------------------------------------------------
  // Skills and interests
  // -------------------------------------------------------------------------

  async skillsFor(profileId: string): Promise<(SkillRecord & { proficiency: string; years: number | null })[]> {
    const result = await this.db
      .prepare(
        `SELECT s."id", s."slug", s."name", s."category", s."member_count",
                ms."proficiency", ms."years"
         FROM "member_skills" ms
         INNER JOIN "skills" s ON s."id" = ms."skill_id"
         WHERE ms."profile_id" = ?
         ORDER BY s."name" ASC`,
      )
      .bind(profileId)
      .all<SkillRecord & { proficiency: string; years: number | null }>();
    return result.results ?? [];
  }

  async interestsFor(profileId: string): Promise<{ id: string; slug: string; name: string }[]> {
    const result = await this.db
      .prepare(
        `SELECT i."id", i."slug", i."name"
         FROM "member_interests" mi
         INNER JOIN "interests" i ON i."id" = mi."interest_id"
         WHERE mi."profile_id" = ?
         ORDER BY i."sort_order" ASC`,
      )
      .bind(profileId)
      .all<{ id: string; slug: string; name: string }>();
    return result.results ?? [];
  }

  /**
   * Replaces a member's skills with the supplied list.
   *
   * Replace rather than merge, for the same reason the dictionary replaces an
   * entry's senses: the member is editing the whole list in front of them, and
   * reconciling a partial list against what is stored is how a skill somebody
   * removed survives the save.
   *
   * `skills.member_count` is recalculated for every skill touched — both the
   * ones being added and the ones being dropped — so the directory's "most
   * common skills" stays true rather than drifting upward forever.
   */
  async replaceSkills(
    profileId: string,
    skills: { skillId: string; proficiency: string; years: number | null }[],
  ): Promise<void> {
    const previous = await this.db
      .prepare('SELECT "skill_id" FROM "member_skills" WHERE "profile_id" = ?')
      .bind(profileId)
      .all<{ skill_id: string }>();

    const touched = new Set<string>((previous.results ?? []).map((row) => row.skill_id));

    await this.db.prepare('DELETE FROM "member_skills" WHERE "profile_id" = ?').bind(profileId).run();

    if (skills.length > 0) {
      const timestamp = nowIso();
      const seen = new Set<string>();
      const statements = [];

      for (const skill of skills) {
        if (seen.has(skill.skillId)) continue;
        seen.add(skill.skillId);
        touched.add(skill.skillId);

        statements.push(
          this.db
            .prepare(
              `INSERT INTO "member_skills"
                 ("id", "profile_id", "skill_id", "proficiency", "years", "created_at")
               VALUES (?, ?, ?, ?, ?, ?)`,
            )
            .bind(newId(), profileId, skill.skillId, skill.proficiency, skill.years, timestamp),
        );
      }

      if (statements.length > 0) await this.db.batch(statements);
    }

    await this.recountSkills([...touched]);
  }

  private async recountSkills(skillIds: string[]): Promise<void> {
    if (skillIds.length === 0) return;

    const statements = skillIds.map((id) =>
      this.db
        .prepare(
          `UPDATE "skills" SET "member_count" =
             (SELECT COUNT(*) FROM "member_skills" WHERE "skill_id" = ?), "updated_at" = ?
           WHERE "id" = ?`,
        )
        .bind(id, nowIso(), id),
    );

    await this.db.batch(statements);
  }

  async replaceInterests(profileId: string, interestIds: string[]): Promise<void> {
    await this.db
      .prepare('DELETE FROM "member_interests" WHERE "profile_id" = ?')
      .bind(profileId)
      .run();

    if (interestIds.length === 0) return;

    const timestamp = nowIso();
    const seen = new Set<string>();
    const statements = [];

    for (const interestId of interestIds) {
      if (seen.has(interestId)) continue;
      seen.add(interestId);
      statements.push(
        this.db
          .prepare(
            `INSERT INTO "member_interests" ("id", "profile_id", "interest_id", "created_at")
             VALUES (?, ?, ?, ?)`,
          )
          .bind(newId(), profileId, interestId, timestamp),
      );
    }

    if (statements.length > 0) await this.db.batch(statements);
  }

  // -------------------------------------------------------------------------
  // Vocabularies
  // -------------------------------------------------------------------------

  async professions(): Promise<Record<string, unknown>[]> {
    const result = await this.db
      .prepare(
        `SELECT "id", "slug", "name", "industry" FROM "professions"
         WHERE "is_approved" = 1 ORDER BY "sort_order" ASC, "name" ASC`,
      )
      .all<Record<string, unknown>>();
    return result.results ?? [];
  }

  async skills(options: { search?: string | null; category?: string | null } = {}): Promise<SkillRecord[]> {
    const conditions = ['"is_approved" = 1'];
    const bindings: unknown[] = [];

    if (options.category) {
      conditions.push('"category" = ?');
      bindings.push(options.category);
    }
    if (options.search) {
      conditions.push(`"name" LIKE ? ESCAPE '\\'`);
      bindings.push(`%${options.search.replace(/[\\%_]/g, (char) => `\\${char}`)}%`);
    }

    const result = await this.db
      .prepare(
        `SELECT "id", "slug", "name", "category", "member_count" FROM "skills"
         WHERE ${conditions.join(' AND ')}
         ORDER BY "member_count" DESC, "name" ASC LIMIT 500`,
      )
      .bind(...bindings)
      .all<SkillRecord>();
    return result.results ?? [];
  }

  async interests(): Promise<Record<string, unknown>[]> {
    const result = await this.db
      .prepare('SELECT "id", "slug", "name", "description" FROM "interests" ORDER BY "sort_order" ASC')
      .all<Record<string, unknown>>();
    return result.results ?? [];
  }

  /**
   * Records a skill a member named that the vocabulary did not have.
   *
   * Usable at once, flagged for an administrator to tidy. Refusing somebody's
   * own trade because it is not on a list is how a profile gets abandoned
   * half-finished, and the community knows its own skills better than a seed
   * list does.
   */
  async proposeSkill(name: string, proposedBy: string | null): Promise<SkillRecord> {
    const slug = name
      .normalize('NFKD')
      .replace(/[̀-ͯ]/g, '')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 60);

    const existing = await this.db
      .prepare('SELECT "id", "slug", "name", "category", "member_count" FROM "skills" WHERE "slug" = ? LIMIT 1')
      .bind(slug)
      .first<SkillRecord>();
    if (existing) return existing;

    const id = newId();
    const timestamp = nowIso();

    await this.db
      .prepare(
        `INSERT INTO "skills" ("id", "slug", "name", "category", "is_approved", "proposed_by",
                               "member_count", "created_at", "updated_at")
         VALUES (?, ?, ?, NULL, 0, ?, 0, ?, ?)`,
      )
      .bind(id, slug, name.trim().slice(0, 100), proposedBy, timestamp, timestamp)
      .run();

    return { id, slug, name: name.trim(), category: null, member_count: 0 };
  }

  // -------------------------------------------------------------------------
  // Statistics
  // -------------------------------------------------------------------------

  /**
   * The community snapshot, aggregated only.
   *
   * Counts, never names. An administrator planning community development needs
   * to know that three hundred and eighty members are seeking work; they do not
   * need, and this does not give them, a list of who those people are.
   */
  async statistics(): Promise<{
    total: number;
    byEmployment: Record<string, number>;
    byCountry: { country: string; total: number }[];
    topSkills: { name: string; total: number }[];
    inDirectory: number;
    inEkoliYeden: number;
    diaspora: number;
  }> {
    const [totals, employment, countries, skills] = await this.db.batch<Record<string, unknown>>([
      this.db.prepare(
        `SELECT COUNT(*) AS total,
                SUM(CASE WHEN "listed_in_directory" = 1 THEN 1 ELSE 0 END) AS in_directory,
                SUM(CASE WHEN "is_in_ekoli_yeden" = 1 THEN 1 ELSE 0 END) AS in_ekoli,
                SUM(CASE WHEN "is_diaspora" = 1 THEN 1 ELSE 0 END) AS diaspora
         FROM "member_profiles" WHERE "membership_status" = 'active'`,
      ),
      this.db.prepare(
        `SELECT COALESCE("employment_status", 'not_said') AS status, COUNT(*) AS total
         FROM "member_profiles" WHERE "membership_status" = 'active' GROUP BY status`,
      ),
      this.db.prepare(
        `SELECT COALESCE("country", 'Not said') AS country, COUNT(*) AS total
         FROM "member_profiles" WHERE "membership_status" = 'active'
         GROUP BY country ORDER BY total DESC LIMIT 20`,
      ),
      this.db.prepare(
        `SELECT "name", "member_count" AS total FROM "skills"
         WHERE "member_count" > 0 ORDER BY "member_count" DESC LIMIT 20`,
      ),
    ]);

    const summary = (totals?.results?.[0] ?? {}) as Record<string, number>;
    const byEmployment: Record<string, number> = {};
    for (const row of employment?.results ?? []) {
      byEmployment[String(row['status'])] = Number(row['total'] ?? 0);
    }

    return {
      total: Number(summary['total'] ?? 0),
      byEmployment,
      byCountry: (countries?.results ?? []).map((row) => ({
        country: String(row['country']),
        total: Number(row['total'] ?? 0),
      })),
      topSkills: (skills?.results ?? []).map((row) => ({
        name: String(row['name']),
        total: Number(row['total'] ?? 0),
      })),
      inDirectory: Number(summary['in_directory'] ?? 0),
      inEkoliYeden: Number(summary['in_ekoli'] ?? 0),
      diaspora: Number(summary['diaspora'] ?? 0),
    };
  }

  /**
   * THE YAKOLI DIRECTORY (Module 7)
   *
   * Members who have chosen to be findable, searchable by what they do, what
   * they can do, and where they are.
   *
   * ---------------------------------------------------------------------
   * `listed_in_directory = 1` IS THE WHOLE PRIVACY MODEL HERE
   * ---------------------------------------------------------------------
   *
   * It is opt-in, it defaults to off, and it is checked in the query rather
   * than filtered afterwards — so a bug in the shaping code cannot leak a
   * member who asked not to be listed. Nothing else in this method can
   * override it.
   *
   * A member who has opted in is still shaped through `visibleProfile` before
   * anything reaches a caller, because being findable is not the same as
   * publishing a phone number.
   */
  async searchDirectory(options: {
    query?: string | null;
    professionId?: string | null;
    skillId?: string | null;
    country?: string | null;
    stateRegion?: string | null;
    employmentStatus?: string | null;
    limit: number;
    offset: number;
  }): Promise<{ items: MemberProfileRecord[]; total: number }> {
    const conditions = [
      'p."listed_in_directory" = 1',
      `p."membership_status" = 'active'`,
      // A memorialised account stays readable where it was already public, but
      // it does not belong in a directory of people to contact.
      `COALESCE(p."memorial_state", 'living') = 'living'`,
    ];
    const bindings: unknown[] = [];

    if (options.query) {
      const pattern = `%${options.query.replace(/[\\%_]/g, (char) => `\\${char}`)}%`;
      conditions.push(
        `(p."full_name" LIKE ? ESCAPE '\\' OR p."headline" LIKE ? ESCAPE '\\' `
        + `OR p."profession_other" LIKE ? ESCAPE '\\' OR p."employer" LIKE ? ESCAPE '\\')`,
      );
      bindings.push(pattern, pattern, pattern, pattern);
    }
    if (options.professionId) {
      conditions.push('p."profession_id" = ?');
      bindings.push(options.professionId);
    }
    if (options.country) {
      conditions.push('LOWER(p."country") = LOWER(?)');
      bindings.push(options.country);
    }
    if (options.stateRegion) {
      conditions.push('LOWER(p."state_region") = LOWER(?)');
      bindings.push(options.stateRegion);
    }
    if (options.employmentStatus) {
      conditions.push('p."employment_status" = ?');
      bindings.push(options.employmentStatus);
    }
    if (options.skillId) {
      conditions.push(
        `EXISTS (SELECT 1 FROM "member_skills" ms
                 WHERE ms."profile_id" = p."id" AND ms."skill_id" = ?)`,
      );
      bindings.push(options.skillId);
    }

    const where = conditions.join(' AND ');
    const from = `FROM "member_profiles" p WHERE ${where}`;

    const [countRow, rows] = await this.db.batch<Record<string, unknown>>([
      this.db.prepare(`SELECT COUNT(*) AS total ${from}`).bind(...bindings),
      this.db
        .prepare(
          // A fuller profile sorts higher. Not vanity: a directory entry with
          // a profession and a location is useful to somebody searching, and
          // one with only a name is not, so the useful ones come first.
          `SELECT p.* ${from}
           ORDER BY p."completion_percent" DESC, p."full_name" ASC
           LIMIT ? OFFSET ?`,
        )
        .bind(...bindings, options.limit, options.offset),
    ]);

    return {
      items: (rows?.results ?? []) as unknown as MemberProfileRecord[],
      total: Number((countRow?.results?.[0]?.['total'] as number | undefined) ?? 0),
    };
  }

  /** The professions and places that actually have somebody behind them. */
  async directoryFacets(): Promise<{
    professions: { id: string; name: string; count: number }[];
    countries: { name: string; count: number }[];
  }> {
    const live = `p."listed_in_directory" = 1 AND p."membership_status" = 'active'`;

    const [professions, countries] = await this.db.batch<Record<string, unknown>>([
      this.db.prepare(
        `SELECT pr."id", pr."name", COUNT(*) AS count
         FROM "member_profiles" p
         INNER JOIN "professions" pr ON pr."id" = p."profession_id"
         WHERE ${live}
         GROUP BY pr."id" ORDER BY count DESC, pr."name" ASC LIMIT 40`,
      ),
      this.db.prepare(
        `SELECT p."country" AS name, COUNT(*) AS count
         FROM "member_profiles" p
         WHERE ${live} AND p."country" IS NOT NULL AND p."country" <> ''
         GROUP BY LOWER(p."country") ORDER BY count DESC LIMIT 30`,
      ),
    ]);

    return {
      professions: (professions?.results ?? []).map((row) => ({
        id: String(row['id']),
        name: String(row['name']),
        count: Number(row['count'] ?? 0),
      })),
      countries: (countries?.results ?? []).map((row) => ({
        name: String(row['name']),
        count: Number(row['count'] ?? 0),
      })),
    };
  }
}
