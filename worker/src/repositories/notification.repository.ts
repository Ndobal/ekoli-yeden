import { newId, nowIso } from '../utils/id';

export interface NotificationRecord {
  id: string;
  user_id: string;
  kind: string;
  title: string;
  body: string | null;
  link_path: string | null;
  resource_type: string | null;
  resource_id: string | null;
  read_at: string | null;
  created_at: string;
}

/**
 * NOTIFICATIONS
 *
 * Deliberately generic: a notification is a line of text, a link and a kind.
 * Not a foreign key into whichever feature raised it — that would mean altering
 * this table every time a feature is added, and Modules 5, 6 and 7 all write
 * here.
 *
 * `link_path` is a path on this site and never a full URL. A notification is
 * not a delivery mechanism for somebody else's link, and an employer who can
 * post an opportunity should not thereby be able to send every matching member
 * a clickable address of their choosing.
 */
export class NotificationRepository {
  constructor(private readonly db: D1Database) {}

  /**
   * Raises a notification, unless the same one is already sitting unread.
   *
   * The de-duplication matters more than it looks: a forum thread with twenty
   * replies should not produce twenty unread rows for the person following it,
   * and an opportunity that matches on re-save should not notify twice.
   */
  async notify(values: {
    userId: string;
    kind: string;
    title: string;
    body?: string | null;
    linkPath?: string | null;
    resourceType?: string | null;
    resourceId?: string | null;
  }): Promise<string | null> {
    if (values.resourceType && values.resourceId) {
      const existing = await this.db
        .prepare(
          `SELECT "id" FROM "notifications"
           WHERE "user_id" = ? AND "kind" = ? AND "resource_type" = ? AND "resource_id" = ?
             AND "read_at" IS NULL
           LIMIT 1`,
        )
        .bind(values.userId, values.kind, values.resourceType, values.resourceId)
        .first<{ id: string }>();
      if (existing) return existing.id;
    }

    const id = newId();
    await this.db
      .prepare(
        `INSERT INTO "notifications"
           ("id", "user_id", "kind", "title", "body", "link_path",
            "resource_type", "resource_id", "created_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        id,
        values.userId,
        values.kind,
        values.title.slice(0, 300),
        values.body ?? null,
        // Enforced rather than trusted: anything that is not a site-relative
        // path is dropped.
        sitePathOrNull(values.linkPath),
        values.resourceType ?? null,
        values.resourceId ?? null,
        nowIso(),
      )
      .run();

    return id;
  }

  /** Raises the same notification for many people, in one batch. */
  async notifyMany(
    userIds: string[],
    values: Omit<Parameters<NotificationRepository['notify']>[0], 'userId'>,
  ): Promise<number> {
    const recipients = [...new Set(userIds)].filter((id) => id !== '');
    if (recipients.length === 0) return 0;

    const timestamp = nowIso();
    const statements = recipients.map((userId) =>
      this.db
        .prepare(
          `INSERT INTO "notifications"
             ("id", "user_id", "kind", "title", "body", "link_path",
              "resource_type", "resource_id", "created_at")
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        )
        .bind(
          newId(),
          userId,
          values.kind,
          values.title.slice(0, 300),
          values.body ?? null,
          sitePathOrNull(values.linkPath),
          values.resourceType ?? null,
          values.resourceId ?? null,
          timestamp,
        ),
    );

    await this.db.batch(statements);
    return recipients.length;
  }

  async list(
    userId: string,
    options: { unreadOnly: boolean; limit: number; offset: number },
  ): Promise<{ items: NotificationRecord[]; total: number; unread: number }> {
    const where = options.unreadOnly
      ? '"user_id" = ? AND "read_at" IS NULL'
      : '"user_id" = ?';

    const [countRow, unreadRow, rows] = await this.db.batch<Record<string, unknown>>([
      this.db.prepare(`SELECT COUNT(*) AS total FROM "notifications" WHERE ${where}`).bind(userId),
      this.db
        .prepare('SELECT COUNT(*) AS total FROM "notifications" WHERE "user_id" = ? AND "read_at" IS NULL')
        .bind(userId),
      this.db
        .prepare(
          `SELECT * FROM "notifications" WHERE ${where}
           ORDER BY "created_at" DESC LIMIT ? OFFSET ?`,
        )
        .bind(userId, options.limit, options.offset),
    ]);

    return {
      items: (rows?.results ?? []) as unknown as NotificationRecord[],
      total: Number((countRow?.results?.[0]?.['total'] as number | undefined) ?? 0),
      unread: Number((unreadRow?.results?.[0]?.['total'] as number | undefined) ?? 0),
    };
  }

  async unreadCount(userId: string): Promise<number> {
    const row = await this.db
      .prepare('SELECT COUNT(*) AS total FROM "notifications" WHERE "user_id" = ? AND "read_at" IS NULL')
      .bind(userId)
      .first<{ total: number }>();
    return Number(row?.total ?? 0);
  }

  /** Scoped to the owner, so an id from somebody else's list does nothing. */
  async markRead(id: string, userId: string): Promise<number> {
    const result = await this.db
      .prepare(
        'UPDATE "notifications" SET "read_at" = ? WHERE "id" = ? AND "user_id" = ? AND "read_at" IS NULL',
      )
      .bind(nowIso(), id, userId)
      .run();
    return result.meta.changes ?? 0;
  }

  async markAllRead(userId: string): Promise<number> {
    const result = await this.db
      .prepare('UPDATE "notifications" SET "read_at" = ? WHERE "user_id" = ? AND "read_at" IS NULL')
      .bind(nowIso(), userId)
      .run();
    return result.meta.changes ?? 0;
  }

  /** Clears notifications pointing at something that no longer exists. */
  async removeForResource(resourceType: string, resourceId: string): Promise<void> {
    await this.db
      .prepare('DELETE FROM "notifications" WHERE "resource_type" = ? AND "resource_id" = ?')
      .bind(resourceType, resourceId)
      .run();
  }
}

/** A site-relative path, or nothing. Never an external URL. */
function sitePathOrNull(value: string | null | undefined): string | null {
  if (!value) return null;
  const trimmed = value.trim();
  // `//evil.example` is protocol-relative and would leave the site.
  if (!trimmed.startsWith('/') || trimmed.startsWith('//')) return null;
  return trimmed.slice(0, 500);
}
