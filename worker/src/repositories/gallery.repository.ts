import { newId, nowIso } from '../utils/id';

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
  created_at: string;
  updated_at: string;
}

/**
 * Gallery membership.
 *
 * A gallery is an ordered set of media assets plus the descriptive labels that
 * turn a photograph into an archive record: who is pictured, where, when and
 * who took it. Those fields stay empty until somebody who knows supplies them.
 */
export class GalleryRepository {
  constructor(private readonly db: D1Database) {}

  /** Items in a gallery, joined to the media metadata the client needs. */
  async itemsForGallery(
    galleryId: string,
    statuses: string[],
  ): Promise<(GalleryItemRecord & { storage_key: string; mime_type: string; alt_text: string | null })[]> {
    const placeholders = statuses.map(() => '?').join(', ');
    const result = await this.db
      .prepare(
        `SELECT gi.*, ma."storage_key", ma."mime_type", ma."alt_text"
         FROM "gallery_items" gi
         INNER JOIN "media_assets" ma ON ma."id" = gi."media_asset_id"
         WHERE gi."gallery_id" = ?
           AND gi."status" IN (${placeholders})
           AND ma."status" IN (${placeholders})
         ORDER BY gi."sort_order" ASC, gi."created_at" ASC`,
      )
      .bind(galleryId, ...statuses, ...statuses)
      .all<GalleryItemRecord & { storage_key: string; mime_type: string; alt_text: string | null }>();
    return result.results ?? [];
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
  }): Promise<string> {
    const id = newId();
    const timestamp = nowIso();
    await this.db
      .prepare(
        `INSERT INTO "gallery_items"
           ("id", "gallery_id", "media_asset_id", "caption", "people_pictured",
            "photographer", "taken_at", "location", "sort_order", "status",
            "created_at", "updated_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
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
        timestamp,
        timestamp,
      )
      .run();
    return id;
  }

  async removeItem(id: string): Promise<number> {
    const result = await this.db.prepare('DELETE FROM "gallery_items" WHERE "id" = ?').bind(id).run();
    return result.meta.changes ?? 0;
  }
}
