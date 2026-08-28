import { newId, nowIso } from '../utils/id';
import { assertSafeIdentifier } from './base.repository';

/**
 * NEWS.
 *
 * ---------------------------------------------------------------------------
 * ONE RULE ABOVE ALL OTHERS
 * ---------------------------------------------------------------------------
 *
 * `publishedOnly` is not a parameter with a default. Every read either goes
 * through `publicList`/`publicFind`, which hard-code `status = 'published'` and
 * a publication time that has passed, or through the editorial methods, which
 * are only reachable behind a permission.
 *
 * That split is deliberate. A single method with a boolean flag is one
 * forgotten argument away from serving a draft — or a scheduled story — to the
 * whole internet, and drafts of a community's news are exactly the thing that
 * must not leak early.
 */
export class NewsRepository {
  constructor(private readonly db: D1Database) {}

  // -------------------------------------------------------------------------
  // Public reads. Published, and only published.
  // -------------------------------------------------------------------------

  /**
   * The news portal's list.
   *
   * `published_at <= now` as well as `status = 'published'`, so a story whose
   * publication moment has not arrived cannot appear even if its status was
   * moved by hand.
   */
  async publicList(options: {
    limit: number;
    offset: number;
    categorySlug?: string | null;
    tagSlug?: string | null;
    search?: string | null;
    featuredOnly?: boolean;
    withVideoOnly?: boolean;
  }): Promise<{ items: Record<string, unknown>[]; total: number }> {
    const conditions = [`n."status" = 'published'`, `(n."published_at" IS NULL OR n."published_at" <= ?)`];
    const bindings: unknown[] = [nowIso()];

    if (options.categorySlug) {
      conditions.push('c."slug" = ?');
      bindings.push(options.categorySlug);
    }
    if (options.featuredOnly) {
      conditions.push('n."is_featured" = 1');
    }
    if (options.tagSlug) {
      conditions.push(
        `EXISTS (SELECT 1 FROM "news_tag_links" tl
                 INNER JOIN "news_tags" t ON t."id" = tl."tag_id"
                 WHERE tl."news_id" = n."id" AND t."slug" = ?)`,
      );
      bindings.push(options.tagSlug);
    }
    if (options.withVideoOnly) {
      conditions.push(
        `EXISTS (SELECT 1 FROM "news_media" m
                 WHERE m."news_id" = n."id" AND m."media_type" = 'youtube_video')`,
      );
    }
    if (options.search) {
      const pattern = `%${options.search.replace(/[\\%_]/g, (char) => `\\${char}`)}%`;
      conditions.push(
        `(n."title" LIKE ? ESCAPE '\\' OR n."excerpt" LIKE ? ESCAPE '\\'
          OR n."body" LIKE ? ESCAPE '\\' OR n."location" LIKE ? ESCAPE '\\')`,
      );
      bindings.push(pattern, pattern, pattern, pattern);
    }

    const where = conditions.join(' AND ');
    const from = `FROM "news" n LEFT JOIN "news_categories" c ON c."id" = n."category_id" WHERE ${where}`;

    const [countRow, rows] = await this.db.batch<Record<string, unknown>>([
      this.db.prepare(`SELECT COUNT(*) AS total ${from}`).bind(...bindings),
      this.db
        .prepare(
          `SELECT n."id", n."slug", n."title", n."excerpt", n."news_date", n."location",
                  n."published_at", n."is_featured", n."is_important", n."author_name",
                  n."contributor_name",
                  c."slug" AS category_slug, c."name" AS category_name, c."accent" AS category_accent,
                  ma."storage_key" AS cover_key, ma."alt_text" AS cover_alt,
                  (SELECT COUNT(*) FROM "news_media" m
                    WHERE m."news_id" = n."id" AND m."media_type" = 'image') AS photo_count,
                  (SELECT COUNT(*) FROM "news_media" m
                    WHERE m."news_id" = n."id" AND m."media_type" = 'youtube_video') AS video_count,
                  (SELECT m."youtube_id" FROM "news_media" m
                    WHERE m."news_id" = n."id" AND m."media_type" = 'youtube_video'
                    ORDER BY m."display_order" LIMIT 1) AS first_video_id
           ${from}
           ORDER BY n."published_at" IS NULL, n."published_at" DESC
           LIMIT ? OFFSET ?`,
        )
        .bind(...bindings, options.limit, options.offset),
    ]);

    return {
      items: rows?.results ?? [],
      total: Number((countRow?.results?.[0]?.['total'] as number | undefined) ?? 0),
    };
  }

  /** One published story, by slug or id. */
  async publicFind(identifier: string): Promise<Record<string, unknown> | null> {
    const row = await this.db
      .prepare(
        `SELECT n.*, c."slug" AS category_slug, c."name" AS category_name,
                c."accent" AS category_accent,
                ma."storage_key" AS cover_key, ma."alt_text" AS cover_alt
         FROM "news" n
         LEFT JOIN "news_categories" c ON c."id" = n."category_id"
         LEFT JOIN "media_assets" ma ON ma."id" = n."cover_media_id"
         WHERE (n."slug" = ? OR n."id" = ?)
           AND n."status" = 'published'
           AND (n."published_at" IS NULL OR n."published_at" <= ?)
         LIMIT 1`,
      )
      .bind(identifier, identifier, nowIso())
      .first<Record<string, unknown>>();
    return row ?? null;
  }

  /**
   * The announcements sitting at the top of the section.
   *
   * An expiry that has passed takes the announcement out of this list without
   * touching the article, which stays published and findable. That is the
   * difference between an announcement and a story: one stops being urgent, and
   * neither stops being true.
   */
  async importantAnnouncements(): Promise<Record<string, unknown>[]> {
    const result = await this.db
      .prepare(
        `SELECT n."id", n."slug", n."title", n."excerpt", n."published_at",
                n."important_expires_at"
         FROM "news" n
         WHERE n."status" = 'published'
           AND n."is_important" = 1
           AND (n."published_at" IS NULL OR n."published_at" <= ?)
           AND (n."important_expires_at" IS NULL OR n."important_expires_at" > ?)
         ORDER BY n."published_at" DESC
         LIMIT 5`,
      )
      .bind(nowIso(), nowIso())
      .all<Record<string, unknown>>();
    return result.results ?? [];
  }

  /** Other stories in the same category, for the foot of an article. */
  async related(newsId: string, categoryId: string | null, limit: number): Promise<Record<string, unknown>[]> {
    const result = await this.db
      .prepare(
        `SELECT n."id", n."slug", n."title", n."excerpt", n."published_at",
                c."name" AS category_name,
                ma."storage_key" AS cover_key
         FROM "news" n
         LEFT JOIN "news_categories" c ON c."id" = n."category_id"
         LEFT JOIN "media_assets" ma ON ma."id" = n."cover_media_id"
         WHERE n."status" = 'published'
           AND n."id" <> ?
           AND (? IS NULL OR n."category_id" = ?)
           AND (n."published_at" IS NULL OR n."published_at" <= ?)
         ORDER BY n."published_at" DESC
         LIMIT ?`,
      )
      .bind(newsId, categoryId, categoryId, nowIso(), limit)
      .all<Record<string, unknown>>();
    return result.results ?? [];
  }

  // -------------------------------------------------------------------------
  // Editorial reads. Behind a permission, in the controller.
  // -------------------------------------------------------------------------

  async editorialList(options: {
    status?: string | null;
    limit: number;
    offset: number;
    search?: string | null;
  }): Promise<{ items: Record<string, unknown>[]; total: number }> {
    const conditions: string[] = [];
    const bindings: unknown[] = [];

    if (options.status && options.status !== 'all') {
      conditions.push('n."status" = ?');
      bindings.push(options.status);
    }
    if (options.search) {
      const pattern = `%${options.search.replace(/[\\%_]/g, (char) => `\\${char}`)}%`;
      conditions.push(`(n."title" LIKE ? ESCAPE '\\' OR n."excerpt" LIKE ? ESCAPE '\\')`);
      bindings.push(pattern, pattern);
    }

    const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
    const from = `FROM "news" n LEFT JOIN "news_categories" c ON c."id" = n."category_id" ${where}`;

    const [countRow, rows] = await this.db.batch<Record<string, unknown>>([
      this.db.prepare(`SELECT COUNT(*) AS total ${from}`).bind(...bindings),
      this.db
        .prepare(
          `SELECT n."id", n."slug", n."title", n."excerpt", n."status", n."news_date",
                  n."published_at", n."scheduled_publish_at", n."is_featured", n."is_important",
                  n."contributor_name", n."author_name", n."review_notes", n."updated_at",
                  c."name" AS category_name, c."slug" AS category_slug,
                  ma."storage_key" AS cover_key
           ${from}
           ORDER BY n."updated_at" DESC
           LIMIT ? OFFSET ?`,
        )
        .bind(...bindings, options.limit, options.offset),
    ]);

    return {
      items: rows?.results ?? [],
      total: Number((countRow?.results?.[0]?.['total'] as number | undefined) ?? 0),
    };
  }

  /** Any story whatever its status. Editorial only. */
  async find(identifier: string): Promise<Record<string, unknown> | null> {
    const row = await this.db
      .prepare(
        `SELECT n.*, c."slug" AS category_slug, c."name" AS category_name,
                ma."storage_key" AS cover_key
         FROM "news" n
         LEFT JOIN "news_categories" c ON c."id" = n."category_id"
         LEFT JOIN "media_assets" ma ON ma."id" = n."cover_media_id"
         WHERE n."slug" = ? OR n."id" = ? LIMIT 1`,
      )
      .bind(identifier, identifier)
      .first<Record<string, unknown>>();
    return row ?? null;
  }

  async slugExists(slug: string): Promise<boolean> {
    const row = await this.db
      .prepare('SELECT "id" FROM "news" WHERE "slug" = ? LIMIT 1')
      .bind(slug)
      .first<{ id: string }>();
    return row !== null;
  }

  /** Counts per status, for the tabs above the editorial list. */
  async statusCounts(): Promise<Record<string, number>> {
    const result = await this.db
      .prepare('SELECT "status", COUNT(*) AS total FROM "news" GROUP BY "status"')
      .all<{ status: string; total: number }>();

    const counts: Record<string, number> = {};
    for (const row of result.results ?? []) counts[row.status] = Number(row.total);
    return counts;
  }

  // -------------------------------------------------------------------------
  // Writing
  // -------------------------------------------------------------------------

  private static readonly WRITABLE = new Set<string>([
    'slug',
    'title',
    'excerpt',
    'body',
    'category_id',
    'author_name',
    'news_date',
    'location',
    'published_at',
    'is_featured',
    'is_important',
    'important_expires_at',
    'scheduled_publish_at',
    'source',
    'source_url',
    'cover_media_id',
    'seo_title',
    'seo_description',
    'seo_image_media_id',
    'review_notes',
    'status',
    'updated_by',
    'published_by',
    'archived_at',
    // Written once, when a submission becomes an article, and never by an edit
    // — see the note in the controller.
    'submitted_by',
    'contributor_name',
    'source_note',
  ]);

  async create(values: Record<string, unknown>): Promise<string> {
    const id = newId();
    const timestamp = nowIso();

    const columns = ['id', 'created_at', 'updated_at'];
    const bindings: unknown[] = [id, timestamp, timestamp];

    for (const [column, value] of Object.entries(values)) {
      if (!NewsRepository.WRITABLE.has(column) || value === undefined) continue;
      columns.push(assertSafeIdentifier(column));
      bindings.push(value);
    }

    await this.db
      .prepare(
        `INSERT INTO "news" (${columns.map((c) => `"${c}"`).join(', ')})
         VALUES (${columns.map(() => '?').join(', ')})`,
      )
      .bind(...bindings)
      .run();

    return id;
  }

  async update(id: string, values: Record<string, unknown>): Promise<number> {
    const columns = Object.keys(values).filter(
      (column) => NewsRepository.WRITABLE.has(column) && values[column] !== undefined,
    );
    if (columns.length === 0) return 0;

    const assignments = columns.map((column) => `"${assertSafeIdentifier(column)}" = ?`).join(', ');

    const result = await this.db
      .prepare(`UPDATE "news" SET ${assignments}, "updated_at" = ? WHERE "id" = ?`)
      .bind(...columns.map((column) => values[column] ?? null), nowIso(), id)
      .run();

    return result.meta.changes ?? 0;
  }

  /**
   * Stories whose moment has come.
   *
   * Read by the scheduled handler. Ordered oldest first so a backlog after an
   * outage publishes in the order it was meant to.
   */
  async dueForPublication(now: string, limit: number): Promise<Record<string, unknown>[]> {
    const result = await this.db
      .prepare(
        `SELECT "id", "slug", "title" FROM "news"
         WHERE "status" = 'scheduled'
           AND "scheduled_publish_at" IS NOT NULL
           AND "scheduled_publish_at" <= ?
         ORDER BY "scheduled_publish_at" ASC
         LIMIT ?`,
      )
      .bind(now, limit)
      .all<Record<string, unknown>>();
    return result.results ?? [];
  }

  // -------------------------------------------------------------------------
  // Media, sources, tags, reviews, revisions
  // -------------------------------------------------------------------------

  async media(newsId: string): Promise<Record<string, unknown>[]> {
    const result = await this.db
      .prepare(
        `SELECT m.*, ma."storage_key" AS storage_key, ma."mime_type" AS mime_type,
                ma."original_filename" AS filename
         FROM "news_media" m
         LEFT JOIN "media_assets" ma ON ma."id" = m."media_id"
         WHERE m."news_id" = ?
         ORDER BY m."display_order" ASC, m."created_at" ASC`,
      )
      .bind(newsId)
      .all<Record<string, unknown>>();
    return result.results ?? [];
  }

  async addMedia(values: {
    newsId: string;
    mediaType: string;
    mediaId: string | null;
    youtubeId: string | null;
    youtubeUrl: string | null;
    videoTitle: string | null;
    videoDescription: string | null;
    caption: string | null;
    altText: string | null;
    photographer: string | null;
    contributorId: string | null;
    copyright: string | null;
    takenAt: string | null;
  }): Promise<string> {
    const id = newId();

    // Appended at the end. Order is a property of the gallery, not of when a
    // file happened to finish uploading.
    const positionRow = await this.db
      .prepare('SELECT COALESCE(MAX("display_order"), -1) AS last FROM "news_media" WHERE "news_id" = ?')
      .bind(values.newsId)
      .first<{ last: number }>();

    await this.db
      .prepare(
        `INSERT INTO "news_media"
           ("id", "news_id", "media_type", "media_id", "youtube_id", "youtube_url",
            "video_title", "video_description", "display_order", "caption", "alt_text",
            "photographer", "contributor_id", "copyright", "taken_at", "created_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        id,
        values.newsId,
        values.mediaType,
        values.mediaId,
        values.youtubeId,
        values.youtubeUrl,
        values.videoTitle,
        values.videoDescription,
        Number(positionRow?.last ?? -1) + 1,
        values.caption,
        values.altText,
        values.photographer,
        values.contributorId,
        values.copyright,
        values.takenAt,
        nowIso(),
      )
      .run();

    return id;
  }

  private static readonly MEDIA_WRITABLE = new Set<string>([
    'caption',
    'alt_text',
    'photographer',
    'copyright',
    'taken_at',
    'display_order',
    'video_title',
    'video_description',
  ]);

  async updateMedia(id: string, newsId: string, values: Record<string, unknown>): Promise<number> {
    const columns = Object.keys(values).filter(
      (column) => NewsRepository.MEDIA_WRITABLE.has(column) && values[column] !== undefined,
    );
    if (columns.length === 0) return 0;

    const assignments = columns.map((column) => `"${assertSafeIdentifier(column)}" = ?`).join(', ');

    const result = await this.db
      .prepare(`UPDATE "news_media" SET ${assignments} WHERE "id" = ? AND "news_id" = ?`)
      .bind(...columns.map((column) => values[column] ?? null), id, newsId)
      .run();

    return result.meta.changes ?? 0;
  }

  async removeMedia(id: string, newsId: string): Promise<number> {
    const result = await this.db
      .prepare('DELETE FROM "news_media" WHERE "id" = ? AND "news_id" = ?')
      .bind(id, newsId)
      .run();
    return result.meta.changes ?? 0;
  }

  /** Reorders a whole gallery in one statement per item. */
  async reorderMedia(newsId: string, orderedIds: string[]): Promise<void> {
    if (orderedIds.length === 0) return;

    await this.db.batch(
      orderedIds.map((id, index) =>
        this.db
          .prepare('UPDATE "news_media" SET "display_order" = ? WHERE "id" = ? AND "news_id" = ?')
          .bind(index, id, newsId),
      ),
    );
  }

  async sources(newsId: string): Promise<Record<string, unknown>[]> {
    const result = await this.db
      .prepare('SELECT * FROM "news_sources" WHERE "news_id" = ? ORDER BY "created_at" ASC')
      .bind(newsId)
      .all<Record<string, unknown>>();
    return result.results ?? [];
  }

  async addSource(values: {
    newsId: string;
    sourceType: string;
    title: string | null;
    author: string | null;
    publisher: string | null;
    url: string | null;
    publishedOn: string | null;
    notes: string | null;
  }): Promise<string> {
    const id = newId();
    await this.db
      .prepare(
        `INSERT INTO "news_sources"
           ("id", "news_id", "source_type", "title", "author", "publisher", "url",
            "published_on", "notes", "created_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        id,
        values.newsId,
        values.sourceType,
        values.title,
        values.author,
        values.publisher,
        values.url,
        values.publishedOn,
        values.notes,
        nowIso(),
      )
      .run();
    return id;
  }

  async removeSource(id: string, newsId: string): Promise<number> {
    const result = await this.db
      .prepare('DELETE FROM "news_sources" WHERE "id" = ? AND "news_id" = ?')
      .bind(id, newsId)
      .run();
    return result.meta.changes ?? 0;
  }

  async categories(includeInactive: boolean): Promise<Record<string, unknown>[]> {
    const result = await this.db
      .prepare(
        `SELECT c.*,
                (SELECT COUNT(*) FROM "news" n
                  WHERE n."category_id" = c."id" AND n."status" = 'published') AS story_count
         FROM "news_categories" c
         ${includeInactive ? '' : 'WHERE c."is_active" = 1'}
         ORDER BY c."sort_order" ASC, c."name" ASC`,
      )
      .all<Record<string, unknown>>();
    return result.results ?? [];
  }

  async findCategory(identifier: string): Promise<Record<string, unknown> | null> {
    const row = await this.db
      .prepare('SELECT * FROM "news_categories" WHERE "slug" = ? OR "id" = ? LIMIT 1')
      .bind(identifier, identifier)
      .first<Record<string, unknown>>();
    return row ?? null;
  }

  async upsertCategory(values: {
    id?: string | null;
    slug: string;
    name: string;
    description: string | null;
    accent: string | null;
    sortOrder: number;
    isActive: boolean;
  }): Promise<string> {
    const timestamp = nowIso();

    if (values.id) {
      await this.db
        .prepare(
          `UPDATE "news_categories"
           SET "slug" = ?, "name" = ?, "description" = ?, "accent" = ?, "sort_order" = ?,
               "is_active" = ?, "updated_at" = ?
           WHERE "id" = ?`,
        )
        .bind(
          values.slug,
          values.name,
          values.description,
          values.accent,
          values.sortOrder,
          values.isActive ? 1 : 0,
          timestamp,
          values.id,
        )
        .run();
      return values.id;
    }

    const id = newId();
    await this.db
      .prepare(
        `INSERT INTO "news_categories"
           ("id", "slug", "name", "description", "accent", "sort_order", "is_active",
            "created_at", "updated_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        id,
        values.slug,
        values.name,
        values.description,
        values.accent,
        values.sortOrder,
        values.isActive ? 1 : 0,
        timestamp,
        timestamp,
      )
      .run();
    return id;
  }

  async tagsFor(newsId: string): Promise<Record<string, unknown>[]> {
    const result = await this.db
      .prepare(
        `SELECT t."id", t."slug", t."name"
         FROM "news_tag_links" l
         INNER JOIN "news_tags" t ON t."id" = l."tag_id"
         WHERE l."news_id" = ?
         ORDER BY t."name" ASC`,
      )
      .bind(newsId)
      .all<Record<string, unknown>>();
    return result.results ?? [];
  }

  async allTags(limit: number): Promise<Record<string, unknown>[]> {
    const result = await this.db
      .prepare(
        `SELECT "id", "slug", "name", "usage_count" FROM "news_tags"
         ORDER BY "usage_count" DESC, "name" ASC LIMIT ?`,
      )
      .bind(limit)
      .all<Record<string, unknown>>();
    return result.results ?? [];
  }

  /**
   * Replaces a story's tags, creating any that are new.
   *
   * A tag the vocabulary does not have is added rather than refused: turning an
   * editor away because "borehole" is not on a list is how tagging stops
   * happening.
   */
  async setTags(newsId: string, names: string[]): Promise<void> {
    await this.db.prepare('DELETE FROM "news_tag_links" WHERE "news_id" = ?').bind(newsId).run();

    for (const raw of names.slice(0, 20)) {
      const name = raw.trim();
      if (name.length === 0) continue;

      const slug = name
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+|-+$/g, '')
        .slice(0, 60);
      if (slug.length === 0) continue;

      const existing = await this.db
        .prepare('SELECT "id" FROM "news_tags" WHERE "slug" = ? LIMIT 1')
        .bind(slug)
        .first<{ id: string }>();

      const tagId = existing?.id ?? newId();
      if (!existing) {
        await this.db
          .prepare(
            `INSERT OR IGNORE INTO "news_tags" ("id", "slug", "name", "usage_count", "created_at")
             VALUES (?, ?, ?, 0, ?)`,
          )
          .bind(tagId, slug, name.slice(0, 80), nowIso())
          .run();
      }

      await this.db
        .prepare(
          `INSERT OR IGNORE INTO "news_tag_links" ("id", "news_id", "tag_id") VALUES (?, ?, ?)`,
        )
        .bind(newId(), newsId, tagId)
        .run();
    }

    await this.db
      .prepare(
        `UPDATE "news_tags" SET "usage_count" =
           (SELECT COUNT(*) FROM "news_tag_links" l WHERE l."tag_id" = "news_tags"."id")`,
      )
      .run();
  }

  async recordReview(values: {
    newsId: string | null;
    submissionId: string | null;
    decision: string;
    comment: string | null;
    reviewerId: string | null;
    reviewerName: string | null;
  }): Promise<void> {
    await this.db
      .prepare(
        `INSERT INTO "news_reviews"
           ("id", "news_id", "submission_id", "decision", "comment", "reviewer_id",
            "reviewer_name", "created_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        newId(),
        values.newsId,
        values.submissionId,
        values.decision,
        values.comment,
        values.reviewerId,
        values.reviewerName,
        nowIso(),
      )
      .run();
  }

  async reviews(newsId: string): Promise<Record<string, unknown>[]> {
    const result = await this.db
      .prepare('SELECT * FROM "news_reviews" WHERE "news_id" = ? ORDER BY "created_at" DESC')
      .bind(newsId)
      .all<Record<string, unknown>>();
    return result.results ?? [];
  }

  /** Snapshots the story as it stands, before an edit overwrites it. */
  async snapshot(values: {
    newsId: string;
    title: string | null;
    summary: string | null;
    content: string | null;
    changeSummary: string | null;
    editorId: string | null;
    editorName: string | null;
  }): Promise<void> {
    await this.db
      .prepare(
        `INSERT INTO "news_revisions"
           ("id", "news_id", "title", "summary", "content", "change_summary",
            "editor_id", "editor_name", "created_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        newId(),
        values.newsId,
        values.title,
        values.summary,
        values.content,
        values.changeSummary,
        values.editorId,
        values.editorName,
        nowIso(),
      )
      .run();
  }

  async revisions(newsId: string): Promise<Record<string, unknown>[]> {
    const result = await this.db
      .prepare(
        `SELECT "id", "title", "summary", "change_summary", "editor_name", "created_at"
         FROM "news_revisions" WHERE "news_id" = ? ORDER BY "created_at" DESC LIMIT 50`,
      )
      .bind(newsId)
      .all<Record<string, unknown>>();
    return result.results ?? [];
  }

  async revision(id: string, newsId: string): Promise<Record<string, unknown> | null> {
    const row = await this.db
      .prepare('SELECT * FROM "news_revisions" WHERE "id" = ? AND "news_id" = ? LIMIT 1')
      .bind(id, newsId)
      .first<Record<string, unknown>>();
    return row ?? null;
  }
}
