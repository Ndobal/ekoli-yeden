import { newId, nowIso } from '../utils/id';
import { assertSafeIdentifier } from './base.repository';

export interface GalleryItemRecord {
  id: string;
  gallery_id: string;
  media_asset_id: string;
  caption: string | null;
  people_pictured: string | null;
  photographer: string | null;
  taken_at: string | null;
  location: string | null;
  sort_order: number;
  status: string;
  contributed_by: string | null;
  submission_upload_id: string | null;
  added_by: string | null;
  created_at: string;
  updated_at: string;
}

/** A gallery item joined to the media metadata the client needs to render it. */
export type GalleryItemWithMedia = GalleryItemRecord & {
  storage_key: string;
  mime_type: string;
  alt_text: string | null;
  media_status: string;
};

export interface GalleryRecord {
  id: string;
  slug: string;
  title: string;
  description: string | null;
  category: string | null;
  event_date: string | null;
  location: string | null;
  festival_id: string | null;
  is_festival_gallery: number;
  cover_media_id: string | null;
  sort_order: number;
  status: string;
  created_at: string;
  updated_at: string;
}

/**
 * Gallery membership.
 *
 * A gallery is an ordered set of media assets plus the descriptive labels that
 * turn a photograph into an archive record: who is pictured, where, when and
 * who took it. Those fields stay empty until somebody who knows supplies them.
 *
 * Every festival has one of these, created with it, which is what gives a
 * photograph a year to belong to. Because a festival gallery is an ordinary
 * gallery row, the same photographs reach the main Gallery section without
 * being filed a second time.
 */
export class GalleryRepository {
  constructor(private readonly db: D1Database) {}

  /** Items in a gallery, joined to the media metadata the client needs. */
  async itemsForGallery(galleryId: string, statuses: string[]): Promise<GalleryItemWithMedia[]> {
    return this.itemsForGalleries([galleryId], statuses);
  }

  /**
   * Items across several galleries at once.
   *
   * The festival page and the combined photograph stream both need this, and
   * doing it in one statement keeps a page of forty photographs to a single
   * D1 round trip rather than one per album.
   */
  async itemsForGalleries(
    galleryIds: string[],
    statuses: string[],
    options: { limit?: number; offset?: number } = {},
  ): Promise<GalleryItemWithMedia[]> {
    if (galleryIds.length === 0 || statuses.length === 0) return [];

    const galleryPlaceholders = galleryIds.map(() => '?').join(', ');
    const statusPlaceholders = statuses.map(() => '?').join(', ');
    const limit = options.limit ?? 500;
    const offset = options.offset ?? 0;

    const result = await this.db
      .prepare(
        `SELECT gi.*, ma."storage_key", ma."mime_type", ma."alt_text", ma."status" AS media_status
         FROM "gallery_items" gi
         INNER JOIN "media_assets" ma ON ma."id" = gi."media_asset_id"
         WHERE gi."gallery_id" IN (${galleryPlaceholders})
           AND gi."status" IN (${statusPlaceholders})
           AND ma."status" IN (${statusPlaceholders})
         ORDER BY gi."sort_order" ASC, gi."created_at" ASC
         LIMIT ? OFFSET ?`,
      )
      .bind(...galleryIds, ...statuses, ...statuses, limit, offset)
      .all<GalleryItemWithMedia>();

    return result.results ?? [];
  }

  /**
   * Every published photograph in the archive, newest first.
   *
   * This is what makes "it also appears in the main gallery" true rather than
   * a promise: a photograph uploaded to Leboku 2026 is in this stream the
   * moment it is published, without anybody copying it anywhere.
   *
   * Ordered by when the photograph was taken where that is known, falling back
   * to when it was added — an undated scan from 1974 should not sort as if it
   * were taken today.
   */
  /**
   * Every published album with how many published items it holds.
   *
   * This exists to drive the filter bar on the gallery page, where the count is
   * most of what makes a filter worth pressing — "Leboku 2026 (48)" tells a
   * visitor where the pictures are, and a bare list of album names does not.
   *
   * One grouped query rather than a count per album: the alternative is a round
   * trip for every album on a page that has to be fast to be useful, and albums
   * only accumulate.
   *
   * A LEFT JOIN, so an album that has been created but not yet filled still
   * appears — with a zero the interface can act on, rather than vanishing and
   * leaving the Media Team wondering where it went.
   */
  async publishedAlbumsWithCounts(): Promise<
    {
      id: string;
      slug: string;
      title: string;
      description: string | null;
      category: string | null;
      event_date: string | null;
      location: string | null;
      festival_id: string | null;
      is_festival_gallery: number;
      item_count: number;
      video_count: number;
    }[]
  > {
    const result = await this.db
      .prepare(
        `SELECT g."id", g."slug", g."title", g."description", g."category",
                g."event_date", g."location", g."festival_id", g."is_festival_gallery",
                g."year", f."name" AS festival_name, f."slug" AS festival_slug,
                COUNT(gi."id") AS item_count,
                SUM(CASE WHEN ma."mime_type" LIKE 'video/%' THEN 1 ELSE 0 END) AS video_count
         FROM "galleries" g
         LEFT JOIN "gallery_items" gi
                ON gi."gallery_id" = g."id" AND gi."status" = 'published'
         LEFT JOIN "media_assets" ma
                ON ma."id" = gi."media_asset_id" AND ma."status" = 'published'
         LEFT JOIN "festivals" f
                ON f."id" = g."festival_id" AND f."status" = 'published'
         WHERE g."status" = 'published'
         GROUP BY g."id"
         ORDER BY g."is_festival_gallery" DESC,
                  g."year" IS NULL, g."year" DESC,
                  g."event_date" IS NULL, g."event_date" DESC,
                  g."sort_order" ASC, g."title" ASC`,
      )
      .all<Record<string, unknown>>();

    return (result.results ?? []).map((row) => ({
      id: String(row['id']),
      slug: String(row['slug']),
      title: String(row['title']),
      description: (row['description'] as string | null) ?? null,
      category: (row['category'] as string | null) ?? null,
      event_date: (row['event_date'] as string | null) ?? null,
      location: (row['location'] as string | null) ?? null,
      festival_id: (row['festival_id'] as string | null) ?? null,
      // The festival's own name and slug, so the Gallery can offer "Leboku" as
      // a filter without a second request — and so an album reads as
      // "Leboku · 2026" rather than relying on whatever it was titled.
      festival_name: (row['festival_name'] as string | null) ?? null,
      festival_slug: (row['festival_slug'] as string | null) ?? null,
      year: row['year'] == null ? null : Number(row['year']),
      is_festival_gallery: Number(row['is_festival_gallery'] ?? 0),
      item_count: Number(row['item_count'] ?? 0),
      video_count: Number(row['video_count'] ?? 0),
    }));
  }

  async allPublishedItems(options: {
    limit: number;
    offset: number;
    galleryId?: string | null;
    festivalId?: string | null;
  }): Promise<{ items: (GalleryItemWithMedia & { gallery_slug: string; gallery_title: string })[]; total: number }> {
    const conditions = [
      `gi."status" = 'published'`,
      `ma."status" = 'published'`,
      `g."status" = 'published'`,
    ];
    const bindings: unknown[] = [];

    if (options.galleryId) {
      conditions.push('gi."gallery_id" = ?');
      bindings.push(options.galleryId);
    }
    if (options.festivalId) {
      conditions.push('g."festival_id" = ?');
      bindings.push(options.festivalId);
    }

    const where = conditions.join(' AND ');
    const from =
      `FROM "gallery_items" gi
       INNER JOIN "media_assets" ma ON ma."id" = gi."media_asset_id"
       INNER JOIN "galleries" g ON g."id" = gi."gallery_id"
       WHERE ${where}`;

    const [countResult, rowsResult] = await this.db.batch<Record<string, unknown>>([
      this.db.prepare(`SELECT COUNT(*) AS total ${from}`).bind(...bindings),
      this.db
        .prepare(
          `SELECT gi.*, ma."storage_key", ma."mime_type", ma."alt_text",
                  ma."status" AS media_status, g."slug" AS gallery_slug, g."title" AS gallery_title
           ${from}
           ORDER BY COALESCE(gi."taken_at", gi."created_at") DESC, gi."id" ASC
           LIMIT ? OFFSET ?`,
        )
        .bind(...bindings, options.limit, options.offset),
    ]);

    return {
      items: (rowsResult?.results ?? []) as unknown as (GalleryItemWithMedia & {
        gallery_slug: string;
        gallery_title: string;
      })[],
      total: Number((countResult?.results?.[0]?.['total'] as number | undefined) ?? 0),
    };
  }

  async findById(id: string): Promise<GalleryRecord | null> {
    const row = await this.db
      .prepare('SELECT * FROM "galleries" WHERE "id" = ? LIMIT 1')
      .bind(id)
      .first<GalleryRecord>();
    return row ?? null;
  }

  async findBySlugOrId(identifier: string): Promise<GalleryRecord | null> {
    const row = await this.db
      .prepare('SELECT * FROM "galleries" WHERE "slug" = ? OR "id" = ? LIMIT 1')
      .bind(identifier, identifier)
      .first<GalleryRecord>();
    return row ?? null;
  }

  /** The album a festival's photographs default into. */
  /**
   * Every year of a festival, newest first, with what each album holds.
   *
   * This is the festival archive: 2026, 2025, 2024. Each row is an ordinary
   * gallery — the same record the Gallery section lists — so a photograph
   * added in either place appears in both and the two cannot disagree.
   *
   * Counts are split by kind because "12 photographs and 3 films" is what
   * somebody deciding whether to open a year actually wants to know.
   */
  async albumsForFestival(
    festivalId: string,
    statuses: string[] = ['published'],
  ): Promise<Record<string, unknown>[]> {
    const placeholders = statuses.map(() => '?').join(', ');
    const result = await this.db
      .prepare(
        `SELECT g."id", g."slug", g."title", g."description", g."year",
                g."event_date", g."location", g."programme", g."people_featured",
                g."status", m."storage_key" AS cover_key,
                (SELECT COUNT(*) FROM "gallery_items" gi
                  INNER JOIN "media_assets" ma ON ma."id" = gi."media_asset_id"
                  WHERE gi."gallery_id" = g."id" AND gi."status" = 'published'
                    AND ma."mime_type" LIKE 'image/%') AS photo_count,
                (SELECT COUNT(*) FROM "gallery_items" gi
                  INNER JOIN "media_assets" ma ON ma."id" = gi."media_asset_id"
                  WHERE gi."gallery_id" = g."id" AND gi."status" = 'published'
                    AND ma."mime_type" LIKE 'video/%') AS video_count,
                (SELECT COUNT(*) FROM "videos" v
                  WHERE v."related_festival_id" = g."festival_id"
                    AND v."status" = 'published') AS linked_video_count
         FROM "galleries" g
         LEFT JOIN "media_assets" m ON m."id" = g."cover_media_id"
         WHERE g."festival_id" = ? AND g."status" IN (${placeholders})
         ORDER BY g."year" IS NULL, g."year" DESC, g."created_at" DESC`,
      )
      .bind(festivalId, ...statuses)
      .all<Record<string, unknown>>();
    return result.results ?? [];
  }

  async findPrimaryForFestival(festivalId: string): Promise<GalleryRecord | null> {
    const row = await this.db
      .prepare(
        `SELECT * FROM "galleries"
         WHERE "festival_id" = ?
         ORDER BY "is_festival_gallery" DESC, "created_at" ASC
         LIMIT 1`,
      )
      .bind(festivalId)
      .first<GalleryRecord>();
    return row ?? null;
  }

  /** Every gallery attached to a festival, primary first. */
  async listForFestival(festivalId: string): Promise<GalleryRecord[]> {
    const result = await this.db
      .prepare(
        `SELECT * FROM "galleries" WHERE "festival_id" = ?
         ORDER BY "is_festival_gallery" DESC, "created_at" ASC`,
      )
      .bind(festivalId)
      .all<GalleryRecord>();
    return result.results ?? [];
  }

  /// A slug nobody else is using, by suffixing until it is free.
  ///
  /// "leboku-2026" is taken by the album seeded before the restructuring, so a
  /// second attempt becomes "leboku-2026-2" rather than failing on the UNIQUE
  /// constraint and losing whatever the person had typed.
  async uniqueSlug(base: string): Promise<string> {
    const root = base.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
    for (let attempt = 0; attempt < 50; attempt++) {
      const candidate = attempt === 0 ? root : `${root}-${attempt + 1}`;
      const clash = await this.db
        .prepare('SELECT 1 FROM "galleries" WHERE "slug" = ? LIMIT 1')
        .bind(candidate)
        .first();
      if (!clash) return candidate;
    }
    return `${root}-${Date.now()}`;
  }

  async createGallery(values: {
    id?: string;
    slug: string;
    title: string;
    description: string | null;
    category: string | null;
    eventDate: string | null;
    location: string | null;
    festivalId: string | null;
    isFestivalGallery: boolean;
    /// Which year's celebration this album is. See migration 0036.
    year?: number | null;
    sortOrder?: number;
    status: string;
  }): Promise<string> {
    const id = values.id ?? newId();
    const timestamp = nowIso();

    await this.db
      .prepare(
        `INSERT INTO "galleries"
           ("id", "slug", "title", "description", "category", "event_date", "location",
            "festival_id", "is_festival_gallery", "year", "sort_order", "status",
            "created_at", "updated_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        id,
        values.slug,
        values.title,
        values.description,
        values.category,
        values.eventDate,
        values.location,
        values.festivalId,
        values.isFestivalGallery ? 1 : 0,
        values.year ?? null,
        values.sortOrder ?? 0,
        values.status,
        timestamp,
        timestamp,
      )
      .run();

    return id;
  }

  /** Keeps a festival gallery's status in step with the festival itself. */
  async setStatus(galleryId: string, status: string): Promise<void> {
    await this.db
      .prepare('UPDATE "galleries" SET "status" = ?, "updated_at" = ? WHERE "id" = ?')
      .bind(status, nowIso(), galleryId)
      .run();
  }

  async slugExists(slug: string): Promise<boolean> {
    const row = await this.db
      .prepare('SELECT "id" FROM "galleries" WHERE "slug" = ? LIMIT 1')
      .bind(slug)
      .first<{ id: string }>();
    return row !== null;
  }

  /** Where a newly added photograph goes: the end of the album. */
  /**
   * The album entry for a given file, if it already has one.
   *
   * `gallery_items` is UNIQUE on (gallery_id, media_asset_id), so filing the
   * same photograph into the same album twice is a constraint violation. A
   * reviewer pressing a button a second time should get the existing entry
   * back, not an error about a unique index.
   */
  async findItemByMedia(galleryId: string, mediaAssetId: string): Promise<{ id: string; status: string } | null> {
    const row = await this.db
      .prepare('SELECT "id", "status" FROM "gallery_items" WHERE "gallery_id" = ? AND "media_asset_id" = ? LIMIT 1')
      .bind(galleryId, mediaAssetId)
      .first<{ id: string; status: string }>();
    return row ?? null;
  }

  async nextSortOrder(galleryId: string): Promise<number> {
    const row = await this.db
      .prepare('SELECT MAX("sort_order") AS highest FROM "gallery_items" WHERE "gallery_id" = ?')
      .bind(galleryId)
      .first<{ highest: number | null }>();
    return Number(row?.highest ?? -1) + 1;
  }

  async addItem(values: {
    galleryId: string;
    mediaAssetId: string;
    caption: string | null;
    photographer: string | null;
    peoplePictured: string | null;
    takenAt: string | null;
    location: string | null;
    sortOrder: number;
    status: string;
    contributedBy?: string | null;
    submissionUploadId?: string | null;
    addedBy?: string | null;
  }): Promise<string> {
    const id = newId();
    const timestamp = nowIso();
    await this.db
      .prepare(
        `INSERT INTO "gallery_items"
           ("id", "gallery_id", "media_asset_id", "caption", "people_pictured",
            "photographer", "taken_at", "location", "sort_order", "status",
            "contributed_by", "submission_upload_id", "added_by", "created_at", "updated_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        id,
        values.galleryId,
        values.mediaAssetId,
        values.caption,
        values.peoplePictured,
        values.photographer,
        values.takenAt,
        values.location,
        values.sortOrder,
        values.status,
        values.contributedBy ?? null,
        values.submissionUploadId ?? null,
        values.addedBy ?? null,
        timestamp,
        timestamp,
      )
      .run();
    return id;
  }

  async findItem(id: string): Promise<GalleryItemRecord | null> {
    const row = await this.db
      .prepare('SELECT * FROM "gallery_items" WHERE "id" = ? LIMIT 1')
      .bind(id)
      .first<GalleryItemRecord>();
    return row ?? null;
  }

  /**
   * Updates the labels on one photograph.
   *
   * Only the columns named here can be written. Cataloguing is the step that
   * turns a picture into an archive record, and it is done long after the
   * upload — often by a different person, often from an elder's answer to
   * "who is that?".
   */
  async updateItem(
    id: string,
    values: Partial<
      Pick<
        GalleryItemRecord,
        'caption' | 'people_pictured' | 'photographer' | 'taken_at' | 'location' | 'sort_order' | 'status'
      >
    >,
  ): Promise<number> {
    const columns = Object.keys(values).filter((column) => values[column as keyof typeof values] !== undefined);
    if (columns.length === 0) return 0;

    // The keys reaching here today come only from a validator's output, so they
    // are already a fixed set. The guard is here so that stays true if somebody
    // later hands this a request body directly — a column name is the one thing
    // in these statements that is not a bound parameter.
    const assignments = columns.map((column) => `"${assertSafeIdentifier(column)}" = ?`).join(', ');
    const result = await this.db
      .prepare(`UPDATE "gallery_items" SET ${assignments}, "updated_at" = ? WHERE "id" = ?`)
      .bind(...columns.map((column) => values[column as keyof typeof values] ?? null), nowIso(), id)
      .run();

    return result.meta.changes ?? 0;
  }

  async removeItem(id: string): Promise<number> {
    const result = await this.db.prepare('DELETE FROM "gallery_items" WHERE "id" = ?').bind(id).run();
    return result.meta.changes ?? 0;
  }

  /** Counts per status, for the workspace screen that manages an album. */
  async countsForGallery(galleryId: string): Promise<Record<string, number>> {
    const result = await this.db
      .prepare(
        'SELECT "status", COUNT(*) AS total FROM "gallery_items" WHERE "gallery_id" = ? GROUP BY "status"',
      )
      .bind(galleryId)
      .all<{ status: string; total: number }>();

    const counts: Record<string, number> = {};
    for (const row of result.results ?? []) counts[row.status] = Number(row.total);
    return counts;
  }
}
