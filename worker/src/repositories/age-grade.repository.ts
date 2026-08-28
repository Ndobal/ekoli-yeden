import { newId, nowIso } from '../utils/id';
import { CONTENT_STATUS } from '../types/models';
import { assertSafeIdentifier } from './base.repository';

export interface AgeGradeRecord {
  id: string;
  slug: string;
  title: string;
  subtitle: string | null;
  formed_year: number | null;
  birth_years: string | null;
  excerpt: string | null;
  body: string | null;
  motto: string | null;
  category: string | null;
  sort_order: number;
  cover_media_id: string | null;
  gallery_id: string | null;
  created_by: string | null;
  contact_name: string | null;
  contact_phone: string | null;
  contact_email: string | null;
  verification_status: string;
  status: string;
  created_at: string;
  updated_at: string;
}

export interface AgeGradeAdminRecord {
  id: string;
  age_grade_id: string;
  user_id: string;
  admin_role: 'lead' | 'admin';
  office: string | null;
  appointed_by: string | null;
  created_at: string;
}

export interface AgeGradePostRecord {
  id: string;
  age_grade_id: string;
  slug: string;
  title: string;
  excerpt: string | null;
  body: string | null;
  post_type: string;
  cover_media_id: string | null;
  gallery_id: string | null;
  author_id: string | null;
  author_name: string | null;
  event_date: string | null;
  published_at: string | null;
  status: string;
  review_notes: string | null;
  created_at: string;
  updated_at: string;
}

export interface AgeGradeMemberRecord {
  id: string;
  age_grade_id: string;
  full_name: string;
  user_id: string | null;
  person_id: string | null;
  office: string | null;
  joined_year: number | null;
  notes: string | null;
  photo_media_id: string | null;
  is_deceased: number;
  deceased_year: number | null;
  sort_order: number;
  status: string;
  created_at: string;
  updated_at: string;
}

/**
 * AGE GRADES
 *
 * An age grade is not an article. It is a standing body with living members,
 * its own officers and its own news, which is why it owns rows rather than
 * being one — and why this repository exists alongside the generic content
 * one that serves history, culture and the rest.
 */
export class AgeGradeRepository {
  constructor(private readonly db: D1Database) {}

  async findBySlugOrId(identifier: string, statuses: string[] | null): Promise<AgeGradeRecord | null> {
    const conditions = ['("slug" = ? OR "id" = ?)'];
    const bindings: unknown[] = [identifier, identifier];

    if (statuses && statuses.length > 0) {
      conditions.push(`"status" IN (${statuses.map(() => '?').join(', ')})`);
      bindings.push(...statuses);
    }

    const row = await this.db
      .prepare(`SELECT * FROM "age_grades" WHERE ${conditions.join(' AND ')} LIMIT 1`)
      .bind(...bindings)
      .first<AgeGradeRecord>();
    return row ?? null;
  }

  async slugExists(slug: string): Promise<boolean> {
    const row = await this.db
      .prepare('SELECT "id" FROM "age_grades" WHERE "slug" = ? LIMIT 1')
      .bind(slug)
      .first<{ id: string }>();
    return row !== null;
  }

  async create(values: {
    slug: string;
    title: string;
    subtitle: string | null;
    formedYear: number | null;
    birthYears: string | null;
    excerpt: string | null;
    body: string | null;
    motto: string | null;
    contactName: string | null;
    contactPhone: string | null;
    contactEmail: string | null;
    createdBy: string | null;
    status: string;
  }): Promise<string> {
    const id = newId();
    const timestamp = nowIso();

    await this.db
      .prepare(
        `INSERT INTO "age_grades"
           ("id", "slug", "title", "subtitle", "formed_year", "birth_years", "excerpt", "body",
            "motto", "contact_name", "contact_phone", "contact_email", "created_by", "author_id",
            "submitted_at", "sort_order", "verification_status", "status", "created_at", "updated_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'unverified', ?, ?, ?)`,
      )
      .bind(
        id,
        values.slug,
        values.title,
        values.subtitle,
        values.formedYear,
        values.birthYears,
        values.excerpt,
        values.body,
        values.motto,
        values.contactName,
        values.contactPhone,
        values.contactEmail,
        values.createdBy,
        values.createdBy,
        values.status === CONTENT_STATUS.PENDING_REVIEW ? timestamp : null,
        // Grades sort by the year they were formed where one is known, which is
        // the order the community itself lists them in.
        values.formedYear ?? 0,
        values.status,
        timestamp,
        timestamp,
      )
      .run();

    return id;
  }

  /**
   * Updates the fields a grade's own administrators may change.
   *
   * Deliberately narrow: `status`, `verification_status` and `sort_order` are
   * not here. A grade writes its own page; whether that page is published, and
   * whether the archive vouches for it, stay with the Preservation Team.
   */
  async updateOwnFields(
    id: string,
    values: Partial<
      Pick<
        AgeGradeRecord,
        | 'title'
        | 'subtitle'
        | 'formed_year'
        | 'birth_years'
        | 'excerpt'
        | 'body'
        | 'motto'
        | 'contact_name'
        | 'contact_phone'
        | 'contact_email'
        | 'cover_media_id'
      >
    >,
  ): Promise<number> {
    const columns = Object.keys(values).filter(
      (column) => values[column as keyof typeof values] !== undefined,
    );
    if (columns.length === 0) return 0;

    const assignments = columns.map((column) => `"${assertSafeIdentifier(column)}" = ?`).join(', ');
    const result = await this.db
      .prepare(`UPDATE "age_grades" SET ${assignments}, "updated_at" = ? WHERE "id" = ?`)
      .bind(...columns.map((column) => values[column as keyof typeof values] ?? null), nowIso(), id)
      .run();

    return result.meta.changes ?? 0;
  }

  // --- Administrators -------------------------------------------------------

  async admins(ageGradeId: string): Promise<(AgeGradeAdminRecord & { display_name: string; email: string })[]> {
    const result = await this.db
      .prepare(
        `SELECT a.*, u."display_name", u."email"
         FROM "age_grade_admins" a
         INNER JOIN "users" u ON u."id" = a."user_id"
         WHERE a."age_grade_id" = ?
         ORDER BY CASE a."admin_role" WHEN 'lead' THEN 0 ELSE 1 END, a."created_at" ASC`,
      )
      .bind(ageGradeId)
      .all<AgeGradeAdminRecord & { display_name: string; email: string }>();
    return result.results ?? [];
  }

  /** The one query the whole grade-scoped authorisation model rests on. */
  async adminFor(ageGradeId: string, userId: string): Promise<AgeGradeAdminRecord | null> {
    const row = await this.db
      .prepare('SELECT * FROM "age_grade_admins" WHERE "age_grade_id" = ? AND "user_id" = ? LIMIT 1')
      .bind(ageGradeId, userId)
      .first<AgeGradeAdminRecord>();
    return row ?? null;
  }

  /** The grades one person administers — their own workspace. */
  async gradesAdministeredBy(userId: string): Promise<(AgeGradeRecord & { admin_role: string })[]> {
    const result = await this.db
      .prepare(
        `SELECT g.*, a."admin_role"
         FROM "age_grade_admins" a
         INNER JOIN "age_grades" g ON g."id" = a."age_grade_id"
         WHERE a."user_id" = ?
         ORDER BY g."formed_year" ASC, g."title" ASC`,
      )
      .bind(userId)
      .all<AgeGradeRecord & { admin_role: string }>();
    return result.results ?? [];
  }

  async addAdmin(values: {
    ageGradeId: string;
    userId: string;
    adminRole: 'lead' | 'admin';
    office: string | null;
    appointedBy: string | null;
  }): Promise<string> {
    const id = newId();
    await this.db
      .prepare(
        `INSERT OR REPLACE INTO "age_grade_admins"
           ("id", "age_grade_id", "user_id", "admin_role", "office", "appointed_by", "created_at")
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(id, values.ageGradeId, values.userId, values.adminRole, values.office, values.appointedBy, nowIso())
      .run();
    return id;
  }

  async removeAdmin(ageGradeId: string, userId: string): Promise<number> {
    const result = await this.db
      .prepare('DELETE FROM "age_grade_admins" WHERE "age_grade_id" = ? AND "user_id" = ?')
      .bind(ageGradeId, userId)
      .run();
    return result.meta.changes ?? 0;
  }

  async countLeads(ageGradeId: string): Promise<number> {
    const row = await this.db
      .prepare(
        `SELECT COUNT(*) AS total FROM "age_grade_admins"
         WHERE "age_grade_id" = ? AND "admin_role" = 'lead'`,
      )
      .bind(ageGradeId)
      .first<{ total: number }>();
    return Number(row?.total ?? 0);
  }

  // --- Posts ---------------------------------------------------------------

  async posts(
    ageGradeId: string,
    statuses: string[],
    options: { limit: number; offset: number },
  ): Promise<{ items: AgeGradePostRecord[]; total: number }> {
    if (statuses.length === 0) return { items: [], total: 0 };
    const placeholders = statuses.map(() => '?').join(', ');

    const [countRow, rows] = await this.db.batch<Record<string, unknown>>([
      this.db
        .prepare(
          `SELECT COUNT(*) AS total FROM "age_grade_posts"
           WHERE "age_grade_id" = ? AND "status" IN (${placeholders})`,
        )
        .bind(ageGradeId, ...statuses),
      this.db
        .prepare(
          `SELECT * FROM "age_grade_posts"
           WHERE "age_grade_id" = ? AND "status" IN (${placeholders})
           ORDER BY COALESCE("published_at", "created_at") DESC
           LIMIT ? OFFSET ?`,
        )
        .bind(ageGradeId, ...statuses, options.limit, options.offset),
    ]);

    return {
      items: (rows?.results ?? []) as unknown as AgeGradePostRecord[],
      total: Number((countRow?.results?.[0]?.['total'] as number | undefined) ?? 0),
    };
  }

  async findPost(id: string): Promise<AgeGradePostRecord | null> {
    const row = await this.db
      .prepare('SELECT * FROM "age_grade_posts" WHERE "id" = ? LIMIT 1')
      .bind(id)
      .first<AgeGradePostRecord>();
    return row ?? null;
  }

  async findPostBySlug(ageGradeId: string, slug: string): Promise<AgeGradePostRecord | null> {
    const row = await this.db
      .prepare('SELECT * FROM "age_grade_posts" WHERE "age_grade_id" = ? AND "slug" = ? LIMIT 1')
      .bind(ageGradeId, slug)
      .first<AgeGradePostRecord>();
    return row ?? null;
  }

  async postSlugExists(ageGradeId: string, slug: string): Promise<boolean> {
    return (await this.findPostBySlug(ageGradeId, slug)) !== null;
  }

  async createPost(values: {
    ageGradeId: string;
    slug: string;
    title: string;
    excerpt: string | null;
    body: string | null;
    postType: string;
    eventDate: string | null;
    coverMediaId: string | null;
    authorId: string | null;
    authorName: string | null;
    status: string;
  }): Promise<string> {
    const id = newId();
    const timestamp = nowIso();

    await this.db
      .prepare(
        `INSERT INTO "age_grade_posts"
           ("id", "age_grade_id", "slug", "title", "excerpt", "body", "post_type",
            "cover_media_id", "author_id", "author_name", "event_date", "published_at",
            "status", "created_at", "updated_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        id,
        values.ageGradeId,
        values.slug,
        values.title,
        values.excerpt,
        values.body,
        values.postType,
        values.coverMediaId,
        values.authorId,
        values.authorName,
        values.eventDate,
        values.status === CONTENT_STATUS.PUBLISHED ? timestamp : null,
        values.status,
        timestamp,
        timestamp,
      )
      .run();

    return id;
  }

  async updatePost(
    id: string,
    values: Partial<
      Pick<
        AgeGradePostRecord,
        'title' | 'excerpt' | 'body' | 'post_type' | 'event_date' | 'cover_media_id' | 'status' | 'published_at'
      >
    >,
  ): Promise<number> {
    const columns = Object.keys(values).filter(
      (column) => values[column as keyof typeof values] !== undefined,
    );
    if (columns.length === 0) return 0;

    const assignments = columns.map((column) => `"${assertSafeIdentifier(column)}" = ?`).join(', ');
    const result = await this.db
      .prepare(`UPDATE "age_grade_posts" SET ${assignments}, "updated_at" = ? WHERE "id" = ?`)
      .bind(...columns.map((column) => values[column as keyof typeof values] ?? null), nowIso(), id)
      .run();

    return result.meta.changes ?? 0;
  }

  async deletePost(id: string): Promise<number> {
    const result = await this.db.prepare('DELETE FROM "age_grade_posts" WHERE "id" = ?').bind(id).run();
    return result.meta.changes ?? 0;
  }

  /** The most recent posts across every published grade — the section index. */
  async recentPosts(limit: number): Promise<(AgeGradePostRecord & { grade_slug: string; grade_title: string })[]> {
    const result = await this.db
      .prepare(
        `SELECT p.*, g."slug" AS grade_slug, g."title" AS grade_title
         FROM "age_grade_posts" p
         INNER JOIN "age_grades" g ON g."id" = p."age_grade_id"
         WHERE p."status" = 'published' AND g."status" = 'published'
         ORDER BY COALESCE(p."published_at", p."created_at") DESC
         LIMIT ?`,
      )
      .bind(limit)
      .all<AgeGradePostRecord & { grade_slug: string; grade_title: string }>();
    return result.results ?? [];
  }

  // --- Members -------------------------------------------------------------

  async members(ageGradeId: string, statuses: string[]): Promise<AgeGradeMemberRecord[]> {
    if (statuses.length === 0) return [];
    const placeholders = statuses.map(() => '?').join(', ');

    const result = await this.db
      .prepare(
        `SELECT * FROM "age_grade_members"
         WHERE "age_grade_id" = ? AND "status" IN (${placeholders})
         ORDER BY "sort_order" ASC, "full_name" ASC`,
      )
      .bind(ageGradeId, ...statuses)
      .all<AgeGradeMemberRecord>();
    return result.results ?? [];
  }

  async findMember(id: string): Promise<AgeGradeMemberRecord | null> {
    const row = await this.db
      .prepare('SELECT * FROM "age_grade_members" WHERE "id" = ? LIMIT 1')
      .bind(id)
      .first<AgeGradeMemberRecord>();
    return row ?? null;
  }

  async addMember(values: {
    ageGradeId: string;
    fullName: string;
    office: string | null;
    joinedYear: number | null;
    notes: string | null;
    isDeceased: boolean;
    deceasedYear: number | null;
    status: string;
    addedBy: string | null;
  }): Promise<string> {
    const id = newId();
    const timestamp = nowIso();

    await this.db
      .prepare(
        `INSERT INTO "age_grade_members"
           ("id", "age_grade_id", "full_name", "office", "joined_year", "notes",
            "is_deceased", "deceased_year", "sort_order", "status", "added_by", "created_at", "updated_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        id,
        values.ageGradeId,
        values.fullName,
        values.office,
        values.joinedYear,
        values.notes,
        values.isDeceased ? 1 : 0,
        values.deceasedYear,
        0,
        values.status,
        values.addedBy,
        timestamp,
        timestamp,
      )
      .run();

    return id;
  }

  async updateMember(
    id: string,
    values: Partial<
      Pick<
        AgeGradeMemberRecord,
        'full_name' | 'office' | 'joined_year' | 'notes' | 'is_deceased' | 'deceased_year' | 'sort_order' | 'status'
      >
    >,
  ): Promise<number> {
    const columns = Object.keys(values).filter(
      (column) => values[column as keyof typeof values] !== undefined,
    );
    if (columns.length === 0) return 0;

    const assignments = columns.map((column) => `"${assertSafeIdentifier(column)}" = ?`).join(', ');
    const result = await this.db
      .prepare(`UPDATE "age_grade_members" SET ${assignments}, "updated_at" = ? WHERE "id" = ?`)
      .bind(...columns.map((column) => values[column as keyof typeof values] ?? null), nowIso(), id)
      .run();

    return result.meta.changes ?? 0;
  }

  async deleteMember(id: string): Promise<number> {
    const result = await this.db.prepare('DELETE FROM "age_grade_members" WHERE "id" = ?').bind(id).run();
    return result.meta.changes ?? 0;
  }
}
