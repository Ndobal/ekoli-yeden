import { assertSafeIdentifier } from './base.repository';
import { newId, nowIso } from '../utils/id';

export interface ForumSpaceRecord {
  id: string;
  slug: string;
  name: string;
  tagline: string | null;
  description: string | null;
  kind: string;
  visibility: string;
  is_indexable: number;
  requires_approval: number;
  is_youth_space: number;
  icon: string | null;
  accent: string | null;
  topic_count: number;
  status: string;
}

export interface ForumTopicRecord {
  id: string;
  space_id: string;
  category_id: string;
  slug: string;
  title: string;
  body: string;
  author_id: string | null;
  author_name: string | null;
  is_pinned: number;
  is_locked: number;
  reply_count: number;
  reaction_count: number;
  last_reply_at: string | null;
  status: string;
  created_at: string;
  updated_at: string;
}

/**
 * THE YAKOLI FORUMS (Module 5)
 *
 * Three spaces — the general community, the youth, and the students — sharing
 * one set of tables and one set of rules.
 */
export class ForumRepository {
  constructor(private readonly db: D1Database) {}

  // -------------------------------------------------------------------------
  // Spaces and categories
  // -------------------------------------------------------------------------

  async spaces(): Promise<ForumSpaceRecord[]> {
    const result = await this.db
      .prepare(`SELECT * FROM "forum_spaces" WHERE "status" = 'published' ORDER BY "sort_order" ASC`)
      .all<ForumSpaceRecord>();
    return result.results ?? [];
  }

  async findSpace(identifier: string): Promise<ForumSpaceRecord | null> {
    const row = await this.db
      .prepare(`SELECT * FROM "forum_spaces" WHERE ("slug" = ? OR "id" = ?) LIMIT 1`)
      .bind(identifier, identifier)
      .first<ForumSpaceRecord>();
    return row ?? null;
  }

  async categories(spaceId: string): Promise<Record<string, unknown>[]> {
    const result = await this.db
      .prepare(
        `SELECT * FROM "forum_categories"
         WHERE "space_id" = ? AND "status" = 'published'
         ORDER BY "section" IS NULL, "section" ASC, "sort_order" ASC, "name" ASC`,
      )
      .bind(spaceId)
      .all<Record<string, unknown>>();
    return result.results ?? [];
  }

  async findCategory(spaceId: string, identifier: string): Promise<Record<string, unknown> | null> {
    const row = await this.db
      .prepare(
        `SELECT * FROM "forum_categories"
         WHERE "space_id" = ? AND ("slug" = ? OR "id" = ?) LIMIT 1`,
      )
      .bind(spaceId, identifier, identifier)
      .first<Record<string, unknown>>();
    return row ?? null;
  }

  // -------------------------------------------------------------------------
  // Topics
  // -------------------------------------------------------------------------

  /**
   * Topics in a space, newest conversation first.
   *
   * ORDERED BY WHEN SOMEBODY LAST SPOKE, never by reactions. Sorting a
   * community's conversation by what gets the most reactions is how the
   * loudest thing wins and the quiet question goes unanswered. Pinned topics
   * come first because a moderator put them there deliberately; everything else
   * is chronological.
   */
  async topics(options: {
    spaceId: string;
    categoryId?: string | null;
    statuses: string[];
    search?: string | null;
    authorId?: string | null;
    limit: number;
    offset: number;
  }): Promise<{ items: ForumTopicRecord[]; total: number }> {
    const conditions = ['t."space_id" = ?'];
    const bindings: unknown[] = [options.spaceId];

    if (options.statuses.length > 0) {
      conditions.push(`t."status" IN (${options.statuses.map(() => '?').join(', ')})`);
      bindings.push(...options.statuses);
    }
    if (options.categoryId) {
      conditions.push('t."category_id" = ?');
      bindings.push(options.categoryId);
    }
    if (options.authorId) {
      conditions.push('t."author_id" = ?');
      bindings.push(options.authorId);
    }
    if (options.search) {
      const pattern = `%${options.search.replace(/[\\%_]/g, (char) => `\\${char}`)}%`;
      conditions.push(`(t."title" LIKE ? ESCAPE '\\' OR t."body" LIKE ? ESCAPE '\\')`);
      bindings.push(pattern, pattern);
    }

    const from = `FROM "forum_topics" t WHERE ${conditions.join(' AND ')}`;

    const [countRow, rows] = await this.db.batch<Record<string, unknown>>([
      this.db.prepare(`SELECT COUNT(*) AS total ${from}`).bind(...bindings),
      this.db
        .prepare(
          `SELECT t.*, c."name" AS category_name, c."slug" AS category_slug
           FROM "forum_topics" t
           LEFT JOIN "forum_categories" c ON c."id" = t."category_id"
           WHERE ${conditions.join(' AND ')}
           ORDER BY t."is_pinned" DESC,
                    COALESCE(t."last_reply_at", t."created_at") DESC
           LIMIT ? OFFSET ?`,
        )
        .bind(...bindings, options.limit, options.offset),
    ]);

    return {
      items: (rows?.results ?? []) as unknown as ForumTopicRecord[],
      total: Number((countRow?.results?.[0]?.['total'] as number | undefined) ?? 0),
    };
  }

  async findTopic(spaceId: string, identifier: string): Promise<ForumTopicRecord | null> {
    const row = await this.db
      .prepare(
        `SELECT * FROM "forum_topics" WHERE "space_id" = ? AND ("slug" = ? OR "id" = ?) LIMIT 1`,
      )
      .bind(spaceId, identifier, identifier)
      .first<ForumTopicRecord>();
    return row ?? null;
  }

  async findTopicById(id: string): Promise<ForumTopicRecord | null> {
    const row = await this.db
      .prepare('SELECT * FROM "forum_topics" WHERE "id" = ? LIMIT 1')
      .bind(id)
      .first<ForumTopicRecord>();
    return row ?? null;
  }

  async topicSlugExists(spaceId: string, slug: string): Promise<boolean> {
    const row = await this.db
      .prepare('SELECT "id" FROM "forum_topics" WHERE "space_id" = ? AND "slug" = ? LIMIT 1')
      .bind(spaceId, slug)
      .first<{ id: string }>();
    return row !== null;
  }

  async createTopic(values: {
    spaceId: string;
    categoryId: string;
    slug: string;
    title: string;
    body: string;
    authorId: string;
    authorName: string;
    status: string;
  }): Promise<string> {
    const id = newId();
    const timestamp = nowIso();

    await this.db
      .prepare(
        `INSERT INTO "forum_topics"
           ("id", "space_id", "category_id", "slug", "title", "body",
            "author_id", "author_name", "status", "created_at", "updated_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        id, values.spaceId, values.categoryId, values.slug, values.title, values.body,
        values.authorId, values.authorName, values.status, timestamp, timestamp,
      )
      .run();

    if (values.status === 'published') {
      await this.db
        .batch([
          this.db
            .prepare('UPDATE "forum_categories" SET "topic_count" = "topic_count" + 1 WHERE "id" = ?')
            .bind(values.categoryId),
          this.db
            .prepare('UPDATE "forum_spaces" SET "topic_count" = "topic_count" + 1 WHERE "id" = ?')
            .bind(values.spaceId),
        ]);
    }

    return id;
  }

  private static readonly TOPIC_WRITABLE = new Set<string>([
    'title', 'body', 'is_pinned', 'is_locked', 'status', 'category_id',
  ]);

  async updateTopic(id: string, values: Record<string, unknown>): Promise<number> {
    const columns = Object.keys(values).filter(
      (column) => ForumRepository.TOPIC_WRITABLE.has(column) && values[column] !== undefined,
    );
    if (columns.length === 0) return 0;

    const assignments = columns.map((column) => `"${assertSafeIdentifier(column)}" = ?`).join(', ');
    const result = await this.db
      .prepare(`UPDATE "forum_topics" SET ${assignments}, "updated_at" = ? WHERE "id" = ?`)
      .bind(...columns.map((column) => values[column] ?? null), nowIso(), id)
      .run();

    return result.meta.changes ?? 0;
  }

  // -------------------------------------------------------------------------
  // Posts
  // -------------------------------------------------------------------------

  async posts(topicId: string, statuses: string[]): Promise<Record<string, unknown>[]> {
    if (statuses.length === 0) return [];

    const result = await this.db
      .prepare(
        `SELECT p.*, m."handle" AS author_handle, m."avatar_media_id" AS author_avatar
         FROM "forum_posts" p
         LEFT JOIN "member_profiles" m ON m."user_id" = p."author_id"
         WHERE p."topic_id" = ? AND p."status" IN (${statuses.map(() => '?').join(', ')})
         ORDER BY p."created_at" ASC`,
      )
      .bind(topicId, ...statuses)
      .all<Record<string, unknown>>();
    return result.results ?? [];
  }

  async findPost(id: string): Promise<Record<string, unknown> | null> {
    const row = await this.db
      .prepare('SELECT * FROM "forum_posts" WHERE "id" = ? LIMIT 1')
      .bind(id)
      .first<Record<string, unknown>>();
    return row ?? null;
  }

  async createPost(values: {
    topicId: string;
    parentPostId: string | null;
    body: string;
    authorId: string;
    authorName: string;
    status: string;
  }): Promise<string> {
    const id = newId();
    const timestamp = nowIso();

    await this.db
      .prepare(
        `INSERT INTO "forum_posts"
           ("id", "topic_id", "parent_post_id", "body", "author_id", "author_name",
            "status", "created_at", "updated_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        id, values.topicId, values.parentPostId, values.body,
        values.authorId, values.authorName, values.status, timestamp, timestamp,
      )
      .run();

    if (values.status === 'published') {
      await this.db
        .prepare(
          `UPDATE "forum_topics"
           SET "reply_count" = "reply_count" + 1, "last_reply_at" = ?, "last_reply_by" = ?,
               "updated_at" = ?
           WHERE "id" = ?`,
        )
        .bind(timestamp, values.authorName, timestamp, values.topicId)
        .run();
    }

    return id;
  }

  async updatePost(id: string, values: Record<string, unknown>): Promise<number> {
    const allowed = new Set(['body', 'status', 'is_answer', 'edited_at']);
    const columns = Object.keys(values).filter(
      (column) => allowed.has(column) && values[column] !== undefined,
    );
    if (columns.length === 0) return 0;

    const assignments = columns.map((column) => `"${assertSafeIdentifier(column)}" = ?`).join(', ');
    const result = await this.db
      .prepare(`UPDATE "forum_posts" SET ${assignments}, "updated_at" = ? WHERE "id" = ?`)
      .bind(...columns.map((column) => values[column] ?? null), nowIso(), id)
      .run();

    return result.meta.changes ?? 0;
  }

  // -------------------------------------------------------------------------
  // Reactions and follows
  // -------------------------------------------------------------------------

  /**
   * Adds or removes a reaction. Returns whether one now stands.
   *
   * The count is displayed and orders nothing — see the note on the table.
   */
  async toggleReaction(values: {
    targetType: 'topic' | 'post';
    targetId: string;
    userId: string;
    kind: string;
  }): Promise<boolean> {
    const existing = await this.db
      .prepare(
        `SELECT "id" FROM "forum_reactions"
         WHERE "target_type" = ? AND "target_id" = ? AND "user_id" = ? LIMIT 1`,
      )
      .bind(values.targetType, values.targetId, values.userId)
      .first<{ id: string }>();

    const table = values.targetType === 'topic' ? 'forum_topics' : 'forum_posts';

    if (existing) {
      await this.db.prepare('DELETE FROM "forum_reactions" WHERE "id" = ?').bind(existing.id).run();
      await this.db
        .prepare(
          `UPDATE "${table}" SET "reaction_count" = MAX(0, "reaction_count" - 1) WHERE "id" = ?`,
        )
        .bind(values.targetId)
        .run();
      return false;
    }

    await this.db
      .prepare(
        `INSERT INTO "forum_reactions" ("id", "target_type", "target_id", "user_id", "kind", "created_at")
         VALUES (?, ?, ?, ?, ?, ?)`,
      )
      .bind(newId(), values.targetType, values.targetId, values.userId, values.kind, nowIso())
      .run();

    await this.db
      .prepare(`UPDATE "${table}" SET "reaction_count" = "reaction_count" + 1 WHERE "id" = ?`)
      .bind(values.targetId)
      .run();

    return true;
  }

  async reactedTargets(userId: string, targetIds: string[]): Promise<Set<string>> {
    if (targetIds.length === 0) return new Set();

    const result = await this.db
      .prepare(
        `SELECT "target_id" FROM "forum_reactions"
         WHERE "user_id" = ? AND "target_id" IN (${targetIds.map(() => '?').join(', ')})`,
      )
      .bind(userId, ...targetIds)
      .all<{ target_id: string }>();

    return new Set((result.results ?? []).map((row) => row.target_id));
  }

  async toggleFollow(topicId: string, userId: string): Promise<boolean> {
    const existing = await this.db
      .prepare('SELECT "id" FROM "forum_follows" WHERE "topic_id" = ? AND "user_id" = ? LIMIT 1')
      .bind(topicId, userId)
      .first<{ id: string }>();

    if (existing) {
      await this.db.prepare('DELETE FROM "forum_follows" WHERE "id" = ?').bind(existing.id).run();
      return false;
    }

    await this.db
      .prepare(
        'INSERT INTO "forum_follows" ("id", "topic_id", "user_id", "created_at") VALUES (?, ?, ?, ?)',
      )
      .bind(newId(), topicId, userId, nowIso())
      .run();
    return true;
  }

  async followerIds(topicId: string, except: string): Promise<string[]> {
    const result = await this.db
      .prepare('SELECT "user_id" FROM "forum_follows" WHERE "topic_id" = ? AND "user_id" <> ?')
      .bind(topicId, except)
      .all<{ user_id: string }>();
    return (result.results ?? []).map((row) => row.user_id);
  }

  async isFollowing(topicId: string, userId: string): Promise<boolean> {
    const row = await this.db
      .prepare('SELECT "id" FROM "forum_follows" WHERE "topic_id" = ? AND "user_id" = ? LIMIT 1')
      .bind(topicId, userId)
      .first<{ id: string }>();
    return row !== null;
  }

  // -------------------------------------------------------------------------
  // Reporting and moderation
  // -------------------------------------------------------------------------

  async report(values: {
    targetType: 'topic' | 'post';
    targetId: string;
    reporterId: string | null;
    reason: string;
    detail: string | null;
    ipHash: string | null;
  }): Promise<string> {
    const id = newId();
    const timestamp = nowIso();

    await this.db
      .prepare(
        `INSERT INTO "forum_reports"
           ("id", "target_type", "target_id", "reporter_id", "reason", "detail",
            "status", "ip_hash", "created_at", "updated_at")
         VALUES (?, ?, ?, ?, ?, ?, 'open', ?, ?, ?)`,
      )
      .bind(
        id, values.targetType, values.targetId, values.reporterId,
        values.reason, values.detail, values.ipHash, timestamp, timestamp,
      )
      .run();

    return id;
  }

  async openReportCount(targetType: string, targetId: string): Promise<number> {
    const row = await this.db
      .prepare(
        `SELECT COUNT(*) AS total FROM "forum_reports"
         WHERE "target_type" = ? AND "target_id" = ? AND "status" = 'open'`,
      )
      .bind(targetType, targetId)
      .first<{ total: number }>();
    return Number(row?.total ?? 0);
  }

  async reports(status: string, limit: number, offset: number): Promise<{
    items: Record<string, unknown>[];
    total: number;
  }> {
    const [countRow, rows] = await this.db.batch<Record<string, unknown>>([
      this.db.prepare('SELECT COUNT(*) AS total FROM "forum_reports" WHERE "status" = ?').bind(status),
      this.db
        .prepare(
          // The reported thing travels with the report.
          //
          // A queue of ids is a queue a moderator has to go and look things up
          // from, in another tab, one at a time — and a moderator who cannot
          // read what was reported either acts blind or does not act. Both are
          // worse than one join.
          `SELECT r.*,
                  COALESCE(t."title", pt."title")           AS target_title,
                  COALESCE(t."body", p."body")              AS target_body,
                  COALESCE(t."status", p."status")          AS target_status,
                  COALESCE(t."author_name", p."author_name") AS target_author_name,
                  COALESCE(t."author_id", p."author_id")    AS target_author_id,
                  COALESCE(ts."slug", pts."slug")           AS target_space_slug,
                  COALESCE(t."slug", pt."slug")             AS target_topic_slug
           FROM "forum_reports" r
           LEFT JOIN "forum_topics" t
                  ON r."target_type" = 'topic' AND t."id" = r."target_id"
           LEFT JOIN "forum_posts" p
                  ON r."target_type" = 'post' AND p."id" = r."target_id"
           -- The topic a reported reply sits in, so the moderator can open the
           -- conversation around it rather than judging a sentence alone.
           LEFT JOIN "forum_topics" pt ON pt."id" = p."topic_id"
           LEFT JOIN "forum_spaces" ts ON ts."id" = t."space_id"
           LEFT JOIN "forum_spaces" pts ON pts."id" = pt."space_id"
           WHERE r."status" = ?
           ORDER BY
             -- Child-safety reports jump the queue. Nothing else in this
             -- module reorders anything, and this is the exception that
             -- earns it.
             CASE WHEN r."reason" = 'child_safety' THEN 0 ELSE 1 END,
             r."created_at" DESC
           LIMIT ? OFFSET ?`,
        )
        .bind(status, limit, offset),
    ]);

    return {
      items: rows?.results ?? [],
      total: Number((countRow?.results?.[0]?.['total'] as number | undefined) ?? 0),
    };
  }

  async findReport(id: string): Promise<Record<string, unknown> | null> {
    const row = await this.db
      .prepare('SELECT * FROM "forum_reports" WHERE "id" = ? LIMIT 1')
      .bind(id)
      .first<Record<string, unknown>>();
    return row ?? null;
  }

  async settleReport(
    id: string,
    values: { status: string; reviewedBy: string; notes: string | null },
  ): Promise<number> {
    const result = await this.db
      .prepare(
        `UPDATE "forum_reports"
         SET "status" = ?, "reviewed_by" = ?, "reviewed_at" = ?, "review_notes" = ?, "updated_at" = ?
         WHERE "id" = ?`,
      )
      .bind(values.status, values.reviewedBy, nowIso(), values.notes, nowIso(), id)
      .run();
    return result.meta.changes ?? 0;
  }

  /**
   * Writes a moderation action. Append-only — there is no update or delete.
   *
   * "Who removed my post, and why?" has to have an answer, and the answer has
   * to be one somebody else can check.
   */
  async recordAction(values: {
    moderatorId: string;
    moderatorName: string;
    action: string;
    targetType: string;
    targetId: string;
    reason: string | null;
    spaceId: string | null;
  }): Promise<void> {
    await this.db
      .prepare(
        `INSERT INTO "forum_moderation_actions"
           ("id", "moderator_id", "moderator_name", "action", "target_type", "target_id",
            "reason", "space_id", "created_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        newId(), values.moderatorId, values.moderatorName, values.action,
        values.targetType, values.targetId, values.reason, values.spaceId, nowIso(),
      )
      .run();
  }

  async actions(limit: number): Promise<Record<string, unknown>[]> {
    const result = await this.db
      .prepare(
        `SELECT * FROM "forum_moderation_actions" ORDER BY "created_at" DESC LIMIT ?`,
      )
      .bind(limit)
      .all<Record<string, unknown>>();
    return result.results ?? [];
  }

  // -------------------------------------------------------------------------
  // Who may moderate, and who is silenced
  // -------------------------------------------------------------------------

  async isModerator(userId: string, spaceId: string | null): Promise<boolean> {
    const row = await this.db
      .prepare(
        `SELECT "id" FROM "forum_moderators"
         WHERE "user_id" = ? AND ("space_id" IS NULL OR "space_id" = ?) LIMIT 1`,
      )
      .bind(userId, spaceId)
      .first<{ id: string }>();
    return row !== null;
  }

  /**
   * The sanction currently stopping this member posting, if any.
   *
   * A warning is not one — it is a record that somebody was spoken to, and it
   * does not silence them. Only a live suspension or an unlifted ban does.
   */
  async activeSanction(userId: string, spaceId: string): Promise<Record<string, unknown> | null> {
    const row = await this.db
      .prepare(
        `SELECT * FROM "forum_sanctions"
         WHERE "user_id" = ?
           AND "kind" IN ('suspension', 'ban')
           AND "lifted_at" IS NULL
           AND ("space_id" IS NULL OR "space_id" = ?)
           AND ("expires_at" IS NULL OR datetime("expires_at") > datetime('now'))
         ORDER BY CASE "kind" WHEN 'ban' THEN 0 ELSE 1 END
         LIMIT 1`,
      )
      .bind(userId, spaceId)
      .first<Record<string, unknown>>();
    return row ?? null;
  }

  async sanction(values: {
    userId: string;
    kind: string;
    spaceId: string | null;
    reason: string | null;
    issuedBy: string;
    expiresAt: string | null;
  }): Promise<string> {
    const id = newId();
    await this.db
      .prepare(
        `INSERT INTO "forum_sanctions"
           ("id", "user_id", "kind", "space_id", "reason", "issued_by", "expires_at", "created_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        id, values.userId, values.kind, values.spaceId,
        values.reason, values.issuedBy, values.expiresAt, nowIso(),
      )
      .run();
    return id;
  }

  async liftSanction(id: string, liftedBy: string): Promise<number> {
    const result = await this.db
      .prepare(
        'UPDATE "forum_sanctions" SET "lifted_at" = ?, "lifted_by" = ? WHERE "id" = ? AND "lifted_at" IS NULL',
      )
      .bind(nowIso(), liftedBy, id)
      .run();
    return result.meta.changes ?? 0;
  }

  /** Recent activity for a member's dashboard. */
  async recentTopics(spaceIds: string[], limit: number): Promise<Record<string, unknown>[]> {
    if (spaceIds.length === 0) return [];

    const result = await this.db
      .prepare(
        `SELECT t."id", t."slug", t."title", t."reply_count", t."last_reply_at", t."created_at",
                t."author_name", s."slug" AS space_slug, s."name" AS space_name
         FROM "forum_topics" t
         INNER JOIN "forum_spaces" s ON s."id" = t."space_id"
         WHERE t."status" = 'published'
           AND t."space_id" IN (${spaceIds.map(() => '?').join(', ')})
         ORDER BY COALESCE(t."last_reply_at", t."created_at") DESC
         LIMIT ?`,
      )
      .bind(...spaceIds, limit)
      .all<Record<string, unknown>>();

    return result.results ?? [];
  }
}
