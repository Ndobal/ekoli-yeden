import { newId, nowIso } from '../utils/id';
import { communityToday } from '../services/kinship';

export interface BirthdayPerson {
  user_id: string;
  handle: string;
  full_name: string | null;
  display_name: string;
  avatar_key: string | null;
  headline: string | null;
  birth_day: number;
  birth_month: number;
  birth_year: number | null;
  wishes_enabled: number;
}

export interface WishRecord {
  id: string;
  recipient_user_id: string;
  sender_user_id: string | null;
  sender_name: string | null;
  year: number;
  message: string;
  is_prayer: number;
  group_id: string | null;
  visibility: string;
  status: string;
  created_at: string;
}

/**
 * BIRTHDAYS
 *
 * Two questions, asked constantly, so both are one indexed read:
 *
 *   "whose birthday is today?"          — the prompt
 *   "what did people say to me in 2027?" — the chart
 *
 * The second is why wishes carry a `year` rather than being derived from their
 * timestamp: a wish sent just after midnight on the wrong side of a timezone
 * still belongs to the birthday it was sent for.
 */
export class BirthdayRepository {
  constructor(private readonly db: D1Database) {}

  /**
   * Everybody whose birthday falls today.
   *
   * The leap-day case is handled in SQL rather than by filtering afterwards:
   * somebody born on the 29th of February is wished well on the 28th in a
   * common year, which is the convention most of them use themselves.
   */
  async birthdaysToday(now: Date = new Date()): Promise<BirthdayPerson[]> {
    const today = communityToday(now);
    const isLeapYear =
      (today.year % 4 === 0 && today.year % 100 !== 0) || today.year % 400 === 0;
    const includeLeapDay = !isLeapYear && today.month === 2 && today.day === 28;

    const result = await this.db
      .prepare(
        `SELECT p."user_id", p."handle", p."full_name", p."headline",
                p."birth_day", p."birth_month", p."birth_year",
                p."birthday_wishes_enabled" AS wishes_enabled,
                u."display_name", ma."storage_key" AS avatar_key
         FROM "member_profiles" p
         INNER JOIN "users" u ON u."id" = p."user_id"
         LEFT JOIN "media_assets" ma ON ma."id" = p."avatar_media_id"
         WHERE p."show_birthday" = 1
           AND p."membership_status" = 'active'
           -- Nobody is wished a happy birthday after they have died.
           AND p."memorial_state" = 'living'
           AND u."status" = 'active'
           AND (
             (p."birth_month" = ? AND p."birth_day" = ?)
             OR (? = 1 AND p."birth_month" = 2 AND p."birth_day" = 29)
           )`,
      )
      .bind(today.month, today.day, includeLeapDay ? 1 : 0)
      .all<BirthdayPerson>();

    return result.results ?? [];
  }

  /**
   * Birthdays coming up, so a group page can show them before the day.
   *
   * Deliberately simple: the next `days` calendar days, matched on month and
   * day. Crossing a year boundary is handled by the caller passing both ranges.
   */
  async birthdaysBetween(
    from: { day: number; month: number },
    to: { day: number; month: number },
  ): Promise<BirthdayPerson[]> {
    const result = await this.db
      .prepare(
        `SELECT p."user_id", p."handle", p."full_name", p."headline",
                p."birth_day", p."birth_month", p."birth_year",
                p."birthday_wishes_enabled" AS wishes_enabled,
                u."display_name", ma."storage_key" AS avatar_key
         FROM "member_profiles" p
         INNER JOIN "users" u ON u."id" = p."user_id"
         LEFT JOIN "media_assets" ma ON ma."id" = p."avatar_media_id"
         WHERE p."show_birthday" = 1
           AND p."membership_status" = 'active'
           AND p."memorial_state" = 'living'
           AND u."status" = 'active'
           AND p."birth_month" IS NOT NULL
           AND (
             (p."birth_month" * 100 + p."birth_day") BETWEEN ? AND ?
           )
         ORDER BY p."birth_month", p."birth_day"`,
      )
      .bind(from.month * 100 + from.day, to.month * 100 + to.day)
      .all<BirthdayPerson>();

    return result.results ?? [];
  }

  // -------------------------------------------------------------------------
  // Wishes
  // -------------------------------------------------------------------------

  /**
   * Records a wish, or replaces the one this sender already left this year.
   *
   * `INSERT OR REPLACE` on the (recipient, sender, year) key: somebody who
   * writes again is correcting themselves, not adding a second message, and a
   * birthday page full of the same person twice reads badly.
   */
  async wish(values: {
    recipientUserId: string;
    senderUserId: string;
    senderName: string;
    year: number;
    message: string;
    isPrayer: boolean;
    groupId: string | null;
    visibility: string;
  }): Promise<string> {
    const existing = await this.db
      .prepare(
        `SELECT "id" FROM "birthday_wishes"
         WHERE "recipient_user_id" = ? AND "sender_user_id" = ? AND "year" = ? LIMIT 1`,
      )
      .bind(values.recipientUserId, values.senderUserId, values.year)
      .first<{ id: string }>();

    if (existing) {
      await this.db
        .prepare('UPDATE "birthday_wishes" SET "message" = ?, "is_prayer" = ? WHERE "id" = ?')
        .bind(values.message, values.isPrayer ? 1 : 0, existing.id)
        .run();
      return existing.id;
    }

    const id = newId();
    await this.db
      .prepare(
        `INSERT INTO "birthday_wishes"
           ("id", "recipient_user_id", "sender_user_id", "sender_name", "year",
            "message", "is_prayer", "group_id", "visibility", "status", "created_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'published', ?)`,
      )
      .bind(
        id,
        values.recipientUserId,
        values.senderUserId,
        values.senderName,
        values.year,
        values.message,
        values.isPrayer ? 1 : 0,
        values.groupId,
        values.visibility,
        nowIso(),
      )
      .run();

    return id;
  }

  /** One year of somebody's birthday chart. */
  async wishesFor(
    recipientUserId: string,
    year: number,
  ): Promise<(WishRecord & { sender_handle: string | null; sender_avatar_key: string | null })[]> {
    const result = await this.db
      .prepare(
        `SELECT w.*, p."handle" AS sender_handle, ma."storage_key" AS sender_avatar_key
         FROM "birthday_wishes" w
         LEFT JOIN "member_profiles" p ON p."user_id" = w."sender_user_id"
         LEFT JOIN "media_assets" ma ON ma."id" = p."avatar_media_id"
         WHERE w."recipient_user_id" = ? AND w."year" = ? AND w."status" = 'published'
         ORDER BY w."created_at" ASC`,
      )
      .bind(recipientUserId, year)
      .all<WishRecord & { sender_handle: string | null; sender_avatar_key: string | null }>();

    return result.results ?? [];
  }

  /**
   * The years somebody has wishes for, newest first, with a count each.
   *
   * This is the chart's index — the list of years a member can click through.
   */
  async wishYears(recipientUserId: string): Promise<{ year: number; total: number }[]> {
    const result = await this.db
      .prepare(
        `SELECT "year", COUNT(*) AS total FROM "birthday_wishes"
         WHERE "recipient_user_id" = ? AND "status" = 'published'
         GROUP BY "year" ORDER BY "year" DESC`,
      )
      .bind(recipientUserId)
      .all<{ year: number; total: number }>();

    return result.results ?? [];
  }

  async findWish(id: string): Promise<WishRecord | null> {
    const row = await this.db
      .prepare('SELECT * FROM "birthday_wishes" WHERE "id" = ? LIMIT 1')
      .bind(id)
      .first<WishRecord>();
    return row ?? null;
  }

  async hideWish(id: string): Promise<number> {
    const result = await this.db
      .prepare(`UPDATE "birthday_wishes" SET "status" = 'hidden' WHERE "id" = ?`)
      .bind(id)
      .run();
    return result.meta.changes ?? 0;
  }

  // -------------------------------------------------------------------------
  // Prompts
  // -------------------------------------------------------------------------

  /**
   * What this member has already been asked about this year.
   *
   * Exists so that "Not now" means not now. Without it the same card would
   * reappear on every page load, which turns a kindness into a nuisance and
   * teaches people to dismiss notifications without reading them.
   */
  async answeredThisYear(userId: string, year: number): Promise<Set<string>> {
    const result = await this.db
      .prepare(
        `SELECT "recipient_user_id" FROM "birthday_prompts"
         WHERE "user_id" = ? AND "year" = ? AND "action" IN ('wished', 'skipped')`,
      )
      .bind(userId, year)
      .all<{ recipient_user_id: string }>();

    return new Set((result.results ?? []).map((row) => row.recipient_user_id));
  }

  async recordPrompt(
    userId: string,
    recipientUserId: string,
    year: number,
    action: 'shown' | 'wished' | 'skipped',
  ): Promise<void> {
    await this.db
      .prepare(
        `INSERT INTO "birthday_prompts" ("id", "user_id", "recipient_user_id", "year", "action", "created_at")
         VALUES (?, ?, ?, ?, ?, ?)
         ON CONFLICT ("user_id", "recipient_user_id", "year")
         DO UPDATE SET "action" = excluded."action"`,
      )
      .bind(newId(), userId, recipientUserId, year, action, nowIso())
      .run();
  }
}
