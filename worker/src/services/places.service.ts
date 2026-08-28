import { newId, nowIso } from '../utils/id';
import { slugify } from '../utils/slug';
import type { Env } from '../types/env';

export interface PlaceRecord {
  id: string;
  slug: string;
  name: string;
  parent_id: string | null;
  kind: string;
  path: string | null;
  depth: number;
  description: string | null;
  /// What is known about the place. Empty for most, and said to be empty
  /// rather than filled with something plausible.
  history: string | null;
  /// What the place is known for — the material a summary would draw on.
  known_for: string | null;
  member_count: number;
  is_canonical: number;
  status: string;
}

/**
 * THE PLACES OF EKORI
 *
 * Ekori is not one place. It is Ajere and Ntan and Epenti and Afrekpe; inside
 * Ajere is Edang, and inside Edang is Ukekeya.
 *
 * Somebody from Ukekeya is from Ukekeya, AND from Edang, AND from Ajere, AND
 * from Ekori. All four are true at once, which is why places nest rather than
 * sitting in fixed columns called `quarter` and `street`.
 *
 * ---------------------------------------------------------------------------
 * THE LIST GROWS FROM WHAT PEOPLE TYPE
 * ---------------------------------------------------------------------------
 *
 * No list an administrator writes will ever contain every compound in Ekori,
 * and a member whose home is missing from a dropdown picks the wrong thing or
 * gives up. So the field takes free text, everything typed is recorded, and a
 * name that TWO DIFFERENT PEOPLE give becomes a real place automatically.
 *
 * Two rather than one, and different people rather than repeat submissions:
 * one person typing something is a spelling; two people typing the same thing
 * is a place. That single rule is what lets the list grow without an
 * administrator approving every compound in a village of thousands, and without
 * one person's typo becoming a permanent entry.
 */
export class PlacesService {
  constructor(private readonly env: Env) {}

  /**
   * Normalises a typed place name for matching.
   *
   * Lowercase, punctuation and spacing collapsed. "Ajere Beach", "ajere-beach"
   * and "AJERE  BEACH" are the same answer, and treating them as three places
   * is how a dropdown becomes useless.
   */
  static normalise(value: string): string {
    return value
      .toLowerCase()
      .normalize('NFKD')
      .replace(/[^a-z0-9\s]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  /** Every published place, as a tree ordered for a picker. */
  async list(): Promise<PlaceRecord[]> {
    const result = await this.env.DB.prepare(
      `SELECT * FROM "places" WHERE "status" = 'published'
       ORDER BY "depth" ASC, "sort_order" ASC, "name" ASC`,
    ).all<PlaceRecord>();
    return result.results ?? [];
  }

  async find(identifier: string): Promise<PlaceRecord | null> {
    const row = await this.env.DB
      .prepare('SELECT * FROM "places" WHERE ("slug" = ? OR "id" = ?) LIMIT 1')
      .bind(identifier, identifier)
      .first<PlaceRecord>();
    return row ?? null;
  }

  /**
   * Everything at or below a place.
   *
   * A recursive walk down the tree, so "who is from Ajere" reaches Edang and
   * Ukekeya too. Depth is capped: the data cannot legitimately nest that far,
   * and a cycle introduced by a bad `parent_id` would otherwise loop forever.
   */
  async descendantIds(placeId: string): Promise<string[]> {
    const ids: string[] = [placeId];
    let frontier: string[] = [placeId];

    for (let level = 0; level < 8 && frontier.length > 0; level += 1) {
      const result = await this.env.DB
        .prepare(
          `SELECT "id" FROM "places"
           WHERE "parent_id" IN (${frontier.map(() => '?').join(', ')})`,
        )
        .bind(...frontier)
        .all<{ id: string }>();

      frontier = (result.results ?? [])
        .map((row) => row.id)
        .filter((id) => !ids.includes(id));

      ids.push(...frontier);
    }

    return ids;
  }

  /**
   * Matches what somebody typed against the places we know.
   *
   * Checks the canonical names first, then the aliases — so "Ekoli-Yeden" finds
   * Ekori rather than creating a second village beside it.
   */
  async match(typed: string): Promise<PlaceRecord | null> {
    const normalised = PlacesService.normalise(typed);
    if (normalised === '') return null;

    const direct = await this.env.DB
      .prepare(
        `SELECT * FROM "places"
         WHERE "status" = 'published'
           AND LOWER(REPLACE(REPLACE("name", '-', ' '), '  ', ' ')) = ?
         LIMIT 1`,
      )
      .bind(normalised)
      .first<PlaceRecord>();
    if (direct) return direct;

    const alias = await this.env.DB
      .prepare(
        `SELECT p.* FROM "place_aliases" a
         INNER JOIN "places" p ON p."id" = a."place_id"
         WHERE a."normalised" = ? LIMIT 1`,
      )
      .bind(normalised)
      .first<PlaceRecord>();

    return alias ?? null;
  }

  /**
   * Records what somebody typed, and promotes it once enough people agree.
   *
   * Returns the place it resolved to, which may be one that has just been
   * created. Where it resolves to nothing, the answer is still kept — the
   * member's own words are never discarded just because the archive did not
   * recognise them.
   *
   * `seen_by` holds user ids rather than a bare counter, so the threshold
   * counts PEOPLE. One member editing their profile six times must not conjure
   * a village.
   */
  async recordAnswer(
    typed: string,
    userId: string,
    parentId: string | null,
  ): Promise<PlaceRecord | null> {
    const trimmed = typed.trim();
    if (trimmed.length < 2 || trimmed.length > 120) return null;

    const existing = await this.match(trimmed);
    if (existing) return existing;

    const normalised = PlacesService.normalise(trimmed);
    if (normalised === '') return null;

    const candidate = await this.env.DB
      .prepare('SELECT * FROM "place_candidates" WHERE "normalised" = ? LIMIT 1')
      .bind(normalised)
      .first<Record<string, unknown>>();

    if (!candidate) {
      await this.env.DB
        .prepare(
          `INSERT INTO "place_candidates"
             ("id", "raw_name", "normalised", "parent_id", "times_seen", "seen_by",
              "state", "first_seen_at", "last_seen_at")
           VALUES (?, ?, ?, ?, 1, ?, 'open', ?, ?)`,
        )
        .bind(newId(), trimmed, normalised, parentId, JSON.stringify([userId]), nowIso(), nowIso())
        .run();
      return null;
    }

    if (candidate['state'] === 'promoted' && candidate['promoted_place_id']) {
      return this.find(String(candidate['promoted_place_id']));
    }

    const seenBy: string[] = safeJsonArray(candidate['seen_by']);
    if (seenBy.includes(userId)) {
      // Already counted this person. Touch the timestamp and stop.
      await this.env.DB
        .prepare('UPDATE "place_candidates" SET "last_seen_at" = ? WHERE "id" = ?')
        .bind(nowIso(), String(candidate['id']))
        .run();
      return null;
    }

    seenBy.push(userId);

    await this.env.DB
      .prepare(
        `UPDATE "place_candidates"
         SET "times_seen" = ?, "seen_by" = ?, "last_seen_at" = ?,
             "parent_id" = COALESCE("parent_id", ?)
         WHERE "id" = ?`,
      )
      .bind(seenBy.length, JSON.stringify(seenBy), nowIso(), parentId, String(candidate['id']))
      .run();

    const threshold = await this.threshold();
    if (seenBy.length < threshold) return null;

    return this.promote(String(candidate['id']), trimmed, parentId ?? (candidate['parent_id'] as string | null));
  }

  /**
   * Turns a candidate into a real place.
   *
   * Marked `created_from_candidate` so a reviewer can find the automatically
   * created ones and tidy their spelling or their parent later, without having
   * to hunt through everything.
   */
  async promote(
    candidateId: string,
    name: string,
    parentId: string | null,
  ): Promise<PlaceRecord | null> {
    // Default to sitting directly under Ekori. Wrong sometimes, and far better
    // than orphaned — a reviewer can move it, and in the meantime it is at
    // least reachable.
    const parent = parentId
      ? await this.find(parentId)
      : await this.find('place_ekori');

    const id = newId();
    const slug = await this.uniqueSlug(name);
    const depth = parent ? parent.depth + 1 : 1;
    const path = parent ? `${parent.path ?? parent.name} / ${name}` : name;

    await this.env.DB
      .prepare(
        `INSERT INTO "places"
           ("id", "slug", "name", "parent_id", "kind", "path", "depth",
            "is_canonical", "created_from_candidate", "status", "created_at", "updated_at")
         VALUES (?, ?, ?, ?, 'compound', ?, ?, 0, 1, 'published', ?, ?)`,
      )
      .bind(id, slug, name, parent?.id ?? null, path, depth, nowIso(), nowIso())
      .run();

    await this.env.DB
      .prepare(
        `UPDATE "place_candidates" SET "state" = 'promoted', "promoted_place_id" = ? WHERE "id" = ?`,
      )
      .bind(id, candidateId)
      .run();

    return this.find(id);
  }

  /** Recomputes how many members give each place as where they are from. */
  async recountMembers(placeId: string): Promise<void> {
    await this.env.DB
      .prepare(
        `UPDATE "places" SET "member_count" =
           (SELECT COUNT(*) FROM "member_profiles" WHERE "place_id" = ?)
         WHERE "id" = ?`,
      )
      .bind(placeId, placeId)
      .run();
  }

  private async threshold(): Promise<number> {
    const row = await this.env.DB
      .prepare(`SELECT "value" FROM "site_settings" WHERE "key" = 'place_promotion_threshold'`)
      .first<{ value: string | null }>()
      .catch(() => null);

    const parsed = Number(row?.value);
    return Number.isFinite(parsed) && parsed >= 1 ? parsed : 2;
  }

  private async uniqueSlug(name: string): Promise<string> {
    const root = slugify(name).slice(0, 60) || 'place';

    for (let suffix = 0; suffix < 60; suffix += 1) {
      const candidate = suffix === 0 ? root : `${root}-${suffix + 1}`;
      const clash = await this.env.DB
        .prepare('SELECT "id" FROM "places" WHERE "slug" = ? LIMIT 1')
        .bind(candidate)
        .first<{ id: string }>();
      if (!clash) return candidate;
    }
    return `${root}-${Date.now()}`;
  }
}

function safeJsonArray(value: unknown): string[] {
  if (typeof value !== 'string' || value === '') return [];
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed.map(String) : [];
  } catch {
    return [];
  }
}
