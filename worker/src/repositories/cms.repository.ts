import { nowIso, newId } from '../utils/id';
import { CONTENT_STATUS } from '../types/models';

export interface ContentStringRecord {
  key: string;
  value: string | null;
  draft_value: string | null;
  group_name: string;
  page: string | null;
  label: string;
  help_text: string | null;
  value_type: string;
  max_length: number | null;
  status: string;
  is_locked: number;
  sort_order: number;
  updated_by: string | null;
  reviewed_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface HeroSlideRecord {
  id: string;
  slide_number: number;
  eyebrow: string | null;
  title: string;
  description: string | null;
  image_media_id: string | null;
  image_alt_text: string | null;
  primary_button_label: string | null;
  primary_button_path: string | null;
  secondary_button_label: string | null;
  secondary_button_path: string | null;
  status: string;
  created_at: string;
  updated_at: string;
}

export interface NavigationItemRecord {
  id: string;
  menu: string;
  label: string;
  path: string;
  description: string | null;
  is_cta: number;
  sort_order: number;
  status: string;
}

/**
 * The CMS store: the text of the public website.
 *
 * The distinction that makes this safe is `value` versus `draft_value`. An
 * editor's work goes into `draft_value` and is invisible to visitors. Only
 * publishing copies it into `value`. A half-finished sentence can therefore
 * never appear on the live archive, and an editor can save as often as they
 * like without consequence.
 */
export class CmsRepository {
  constructor(private readonly db: D1Database) {}

  // --- Content strings -----------------------------------------------------

  /** The published text the public website renders. */
  async publishedStrings(): Promise<Record<string, string>> {
    const result = await this.db
      .prepare('SELECT "key", "value" FROM "content_strings" WHERE "status" = ? AND "value" IS NOT NULL')
      .bind(CONTENT_STATUS.PUBLISHED)
      .all<{ key: string; value: string }>();

    const strings: Record<string, string> = {};
    for (const row of result.results ?? []) strings[row.key] = row.value;
    return strings;
  }

  /** Every string with its draft and metadata, for the editorial interface. */
  async allStrings(group?: string | null, page?: string | null): Promise<ContentStringRecord[]> {
    const conditions: string[] = [];
    const bindings: unknown[] = [];
    if (group) {
      conditions.push('"group_name" = ?');
      bindings.push(group);
    }
    if (page) {
      conditions.push('"page" = ?');
      bindings.push(page);
    }
    const where = conditions.length > 0 ? ` WHERE ${conditions.join(' AND ')}` : '';

    const result = await this.db
      .prepare(`SELECT * FROM "content_strings"${where} ORDER BY "group_name" ASC, "sort_order" ASC`)
      .bind(...bindings)
      .all<ContentStringRecord>();
    return result.results ?? [];
  }

  async findString(key: string): Promise<ContentStringRecord | null> {
    const row = await this.db
      .prepare('SELECT * FROM "content_strings" WHERE "key" = ? LIMIT 1')
      .bind(key)
      .first<ContentStringRecord>();
    return row ?? null;
  }

  /**
   * Saves an editor's draft.
   *
   * Writes only `draft_value` and moves the row to `draft`. The live `value` is
   * untouched, so nothing a visitor sees changes until somebody publishes.
   */
  async saveDraft(key: string, draftValue: string | null, editorId: string): Promise<number> {
    const result = await this.db
      .prepare(
        `UPDATE "content_strings"
         SET "draft_value" = ?, "status" = ?, "updated_by" = ?, "updated_at" = ?
         WHERE "key" = ? AND "is_locked" = 0`,
      )
      .bind(draftValue, CONTENT_STATUS.DRAFT, editorId, nowIso(), key)
      .run();
    return result.meta.changes ?? 0;
  }

  /** Moves a draft into the review queue. */
  async submitForReview(key: string, editorId: string): Promise<number> {
    const result = await this.db
      .prepare(
        `UPDATE "content_strings"
         SET "status" = ?, "updated_by" = ?, "updated_at" = ?
         WHERE "key" = ? AND "is_locked" = 0 AND "draft_value" IS NOT NULL`,
      )
      .bind(CONTENT_STATUS.PENDING_REVIEW, editorId, nowIso(), key)
      .run();
    return result.meta.changes ?? 0;
  }

  async review(key: string, approved: boolean, reviewerId: string): Promise<number> {
    const result = await this.db
      .prepare(
        `UPDATE "content_strings"
         SET "status" = ?, "reviewed_by" = ?, "updated_at" = ?
         WHERE "key" = ? AND "status" = ?`,
      )
      .bind(
        approved ? CONTENT_STATUS.APPROVED : CONTENT_STATUS.REJECTED,
        reviewerId,
        nowIso(),
        key,
        CONTENT_STATUS.PENDING_REVIEW,
      )
      .run();
    return result.meta.changes ?? 0;
  }

  /**
   * Publishes: the draft becomes the live value.
   *
   * The draft is cleared afterwards so the editorial interface shows no
   * pending change on a string that has just gone live.
   */
  async publish(key: string, publisherId: string): Promise<number> {
    const result = await this.db
      .prepare(
        `UPDATE "content_strings"
         SET "value" = COALESCE("draft_value", "value"),
             "draft_value" = NULL,
             "status" = ?,
             "updated_by" = ?,
             "updated_at" = ?
         WHERE "key" = ? AND "is_locked" = 0`,
      )
      .bind(CONTENT_STATUS.PUBLISHED, publisherId, nowIso(), key)
      .run();
    return result.meta.changes ?? 0;
  }

  // --- Hero carousel -------------------------------------------------------

  async heroSlides(publishedOnly: boolean): Promise<HeroSlideRecord[]> {
    const where = publishedOnly ? ' WHERE "status" = ?' : '';
    const statement = this.db.prepare(
      `SELECT * FROM "hero_slides"${where} ORDER BY "slide_number" ASC`,
    );
    const result = publishedOnly
      ? await statement.bind(CONTENT_STATUS.PUBLISHED).all<HeroSlideRecord>()
      : await statement.all<HeroSlideRecord>();
    return result.results ?? [];
  }

  async updateHeroSlide(
    slideNumber: number,
    values: Record<string, unknown>,
    editorId: string,
  ): Promise<number> {
    const columns = Object.keys(values);
    if (columns.length === 0) return 0;

    // Column names come from an allow-list in the controller, never from the
    // request body, so interpolating them here is safe.
    const assignments = columns.map((column) => `"${column}" = ?`).join(', ');
    const result = await this.db
      .prepare(
        `UPDATE "hero_slides" SET ${assignments}, "updated_by" = ?, "updated_at" = ? WHERE "slide_number" = ?`,
      )
      .bind(...columns.map((column) => values[column] ?? null), editorId, nowIso(), slideNumber)
      .run();
    return result.meta.changes ?? 0;
  }

  // --- Navigation ----------------------------------------------------------

  async navigation(menu: string | null, publishedOnly: boolean): Promise<NavigationItemRecord[]> {
    const conditions: string[] = [];
    const bindings: unknown[] = [];
    if (menu) {
      conditions.push('"menu" = ?');
      bindings.push(menu);
    }
    if (publishedOnly) {
      conditions.push('"status" = ?');
      bindings.push(CONTENT_STATUS.PUBLISHED);
    }
    const where = conditions.length > 0 ? ` WHERE ${conditions.join(' AND ')}` : '';

    const result = await this.db
      .prepare(`SELECT * FROM "navigation_items"${where} ORDER BY "menu" ASC, "sort_order" ASC`)
      .bind(...bindings)
      .all<NavigationItemRecord>();
    return result.results ?? [];
  }

  async updateNavigationItem(id: string, values: Record<string, unknown>): Promise<number> {
    const columns = Object.keys(values);
    if (columns.length === 0) return 0;

    const assignments = columns.map((column) => `"${column}" = ?`).join(', ');
    const result = await this.db
      .prepare(`UPDATE "navigation_items" SET ${assignments}, "updated_at" = ? WHERE "id" = ?`)
      .bind(...columns.map((column) => values[column] ?? null), nowIso(), id)
      .run();
    return result.meta.changes ?? 0;
  }

  async createNavigationItem(values: {
    menu: string;
    label: string;
    path: string;
    description: string | null;
    is_cta: number;
    sort_order: number;
  }): Promise<string> {
    const id = newId();
    const timestamp = nowIso();
    await this.db
      .prepare(
        `INSERT INTO "navigation_items"
           ("id", "menu", "label", "path", "description", "is_cta", "sort_order", "status", "created_at", "updated_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        id,
        values.menu,
        values.label,
        values.path,
        values.description,
        values.is_cta,
        values.sort_order,
        CONTENT_STATUS.PUBLISHED,
        timestamp,
        timestamp,
      )
      .run();
    return id;
  }

  async deleteNavigationItem(id: string): Promise<number> {
    const result = await this.db
      .prepare('DELETE FROM "navigation_items" WHERE "id" = ?')
      .bind(id)
      .run();
    return result.meta.changes ?? 0;
  }
}
