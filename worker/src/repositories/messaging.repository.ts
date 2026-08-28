import { newId, nowIso } from '../utils/id';
import { assertSafeIdentifier } from './base.repository';

export interface ConversationRecord {
  id: string;
  kind: string;
  title: string | null;
  pair_key: string | null;
  last_message_at: string | null;
  last_message_text: string | null;
  last_message_by: string | null;
  created_at: string;
}

/**
 * MESSAGES BETWEEN MEMBERS.
 *
 * ---------------------------------------------------------------------------
 * `pairKey` IS WHAT STOPS TWO PEOPLE HAVING TWO CONVERSATIONS
 * ---------------------------------------------------------------------------
 *
 * Two members who write to each other within the same second would otherwise
 * each create a thread, and each would sit in their own copy wondering why the
 * other never replied. The key is the two ids sorted and joined, held UNIQUE by
 * the database — so the second insert loses, and the loser reads the row the
 * winner made.
 *
 * Sorted, so that (A, B) and (B, A) produce the same key. That is the whole
 * trick and it is easy to break by "tidying" this into `${a}:${b}`.
 */
export class MessagingRepository {
  constructor(private readonly db: D1Database) {}

  static pairKey(a: string, b: string): string {
    return [a, b].sort().join(':');
  }

  /**
   * Finds the conversation between two people, or makes it.
   *
   * The insert is `OR IGNORE` against the unique key and is followed by a read,
   * rather than a check-then-insert: between the check and the insert is
   * exactly where the duplicate would be created.
   */
  async findOrCreateDirect(
    a: string,
    b: string,
  ): Promise<{ id: string; created: boolean }> {
    const key = MessagingRepository.pairKey(a, b);

    const existing = await this.db
      .prepare('SELECT "id" FROM "conversations" WHERE "pair_key" = ? LIMIT 1')
      .bind(key)
      .first<{ id: string }>();

    if (existing) return { id: existing.id, created: false };

    const id = newId();
    const timestamp = nowIso();

    await this.db
      .prepare(
        `INSERT OR IGNORE INTO "conversations"
           ("id", "kind", "pair_key", "created_by", "created_at", "updated_at")
         VALUES (?, 'direct', ?, ?, ?, ?)`,
      )
      .bind(id, key, a, timestamp, timestamp)
      .run();

    // Read back rather than trusting the insert: if the ignore fired, the row
    // that exists is somebody else's and this is the id to use.
    const row = await this.db
      .prepare('SELECT "id" FROM "conversations" WHERE "pair_key" = ? LIMIT 1')
      .bind(key)
      .first<{ id: string }>();

    const conversationId = row?.id ?? id;

    await this.db.batch([
      this.db
        .prepare(
          `INSERT OR IGNORE INTO "conversation_participants"
             ("id", "conversation_id", "user_id", "joined_at")
           VALUES (?, ?, ?, ?)`,
        )
        .bind(newId(), conversationId, a, timestamp),
      this.db
        .prepare(
          `INSERT OR IGNORE INTO "conversation_participants"
             ("id", "conversation_id", "user_id", "joined_at")
           VALUES (?, ?, ?, ?)`,
        )
        .bind(newId(), conversationId, b, timestamp),
    ]);

    return { id: conversationId, created: conversationId === id };
  }

  /**
   * Somebody's conversations, newest activity first, with the other person and
   * the unread count already attached.
   *
   * One query. The list of threads is the screen people open most, and it must
   * not be N+1 over participants.
   */
  async conversationsFor(userId: string, limit: number, offset: number): Promise<{
    items: Record<string, unknown>[];
    total: number;
  }> {
    const [countRow, rows] = await this.db.batch<Record<string, unknown>>([
      this.db
        .prepare(
          `SELECT COUNT(*) AS total FROM "conversation_participants"
           WHERE "user_id" = ? AND "is_archived" = 0`,
        )
        .bind(userId),
      this.db
        .prepare(
          `SELECT c."id", c."kind", c."title", c."last_message_at", c."last_message_text",
                  c."last_message_by", c."created_at",
                  me."last_read_at", me."is_muted", me."is_blocked",
                  other."user_id"      AS other_user_id,
                  op."handle"          AS other_handle,
                  op."full_name"       AS other_name,
                  op."headline"        AS other_headline,
                  ou."display_name"    AS other_display_name,
                  ma."storage_key"     AS other_avatar_key,
                  (SELECT COUNT(*) FROM "direct_messages" m
                    WHERE m."conversation_id" = c."id"
                      AND m."sender_id" <> ?
                      AND m."status" = 'sent'
                      AND (me."last_read_at" IS NULL OR m."created_at" > me."last_read_at")
                  ) AS unread_count
           FROM "conversation_participants" me
           INNER JOIN "conversations" c ON c."id" = me."conversation_id"
           LEFT JOIN "conversation_participants" other
                  ON other."conversation_id" = c."id" AND other."user_id" <> me."user_id"
           LEFT JOIN "member_profiles" op ON op."user_id" = other."user_id"
           LEFT JOIN "users" ou ON ou."id" = other."user_id"
           LEFT JOIN "media_assets" ma ON ma."id" = op."avatar_media_id"
           WHERE me."user_id" = ? AND me."is_archived" = 0
           ORDER BY c."last_message_at" IS NULL, c."last_message_at" DESC
           LIMIT ? OFFSET ?`,
        )
        .bind(userId, userId, limit, offset),
    ]);

    return {
      items: rows?.results ?? [],
      total: Number((countRow?.results?.[0]?.['total'] as number | undefined) ?? 0),
    };
  }

  /** The participant row, which is also the authorisation check. */
  async participant(
    conversationId: string,
    userId: string,
  ): Promise<Record<string, unknown> | null> {
    const row = await this.db
      .prepare(
        `SELECT * FROM "conversation_participants"
         WHERE "conversation_id" = ? AND "user_id" = ? LIMIT 1`,
      )
      .bind(conversationId, userId)
      .first<Record<string, unknown>>();
    return row ?? null;
  }

  /** Everybody else in a conversation. */
  async otherParticipants(conversationId: string, userId: string): Promise<string[]> {
    const result = await this.db
      .prepare(
        `SELECT "user_id" FROM "conversation_participants"
         WHERE "conversation_id" = ? AND "user_id" <> ?`,
      )
      .bind(conversationId, userId)
      .all<{ user_id: string }>();
    return (result.results ?? []).map((row) => row.user_id);
  }

  async findConversation(id: string): Promise<ConversationRecord | null> {
    const row = await this.db
      .prepare('SELECT * FROM "conversations" WHERE "id" = ? LIMIT 1')
      .bind(id)
      .first<ConversationRecord>();
    return row ?? null;
  }

  /**
   * A page of messages, oldest last.
   *
   * Returned newest-first from SQL because that is what the index serves and
   * what pagination needs; the caller reverses for display.
   */
  async messages(conversationId: string, limit: number, offset: number): Promise<{
    items: Record<string, unknown>[];
    total: number;
  }> {
    const [countRow, rows] = await this.db.batch<Record<string, unknown>>([
      this.db
        .prepare('SELECT COUNT(*) AS total FROM "direct_messages" WHERE "conversation_id" = ?')
        .bind(conversationId),
      this.db
        .prepare(
          `SELECT m.*, ma."storage_key" AS media_key, ma."original_filename" AS media_name,
                  ma."mime_type" AS media_type
           FROM "direct_messages" m
           LEFT JOIN "media_assets" ma ON ma."id" = m."media_id"
           WHERE m."conversation_id" = ?
           ORDER BY m."created_at" DESC
           LIMIT ? OFFSET ?`,
        )
        .bind(conversationId, limit, offset),
    ]);

    return {
      items: rows?.results ?? [],
      total: Number((countRow?.results?.[0]?.['total'] as number | undefined) ?? 0),
    };
  }

  async createMessage(values: {
    conversationId: string;
    senderId: string;
    senderName: string;
    body: string;
    mediaId: string | null;
  }): Promise<string> {
    const id = newId();
    const timestamp = nowIso();

    await this.db.batch([
      this.db
        .prepare(
          `INSERT INTO "direct_messages"
             ("id", "conversation_id", "sender_id", "sender_name", "body", "media_id",
              "status", "created_at")
           VALUES (?, ?, ?, ?, ?, ?, 'sent', ?)`,
        )
        .bind(
          id,
          values.conversationId,
          values.senderId,
          values.senderName,
          values.body,
          values.mediaId,
          timestamp,
        ),
      // Denormalised onto the conversation so the list of threads needs no
      // join to show the last line of each.
      this.db
        .prepare(
          `UPDATE "conversations"
           SET "last_message_at" = ?, "last_message_text" = ?, "last_message_by" = ?,
               "updated_at" = ?
           WHERE "id" = ?`,
        )
        .bind(timestamp, values.body.slice(0, 200), values.senderId, timestamp, values.conversationId),
      // Sending is reading: a thread you just wrote in is not unread to you.
      this.db
        .prepare(
          `UPDATE "conversation_participants" SET "last_read_at" = ?
           WHERE "conversation_id" = ? AND "user_id" = ?`,
        )
        .bind(timestamp, values.conversationId, values.senderId),
      // A thread somebody archived comes back when they are written to. Putting
      // it away is not the same as refusing to hear from them again — that is
      // what blocking is for, and blocking is checked before this runs.
      this.db
        .prepare(
          `UPDATE "conversation_participants" SET "is_archived" = 0
           WHERE "conversation_id" = ? AND "user_id" <> ?`,
        )
        .bind(values.conversationId, values.senderId),
    ]);

    return id;
  }

  async markRead(conversationId: string, userId: string): Promise<void> {
    await this.db
      .prepare(
        `UPDATE "conversation_participants" SET "last_read_at" = ?
         WHERE "conversation_id" = ? AND "user_id" = ?`,
      )
      .bind(nowIso(), conversationId, userId)
      .run();
  }

  /** Total unread across every conversation, for the badge. */
  async unreadTotal(userId: string): Promise<number> {
    const row = await this.db
      .prepare(
        `SELECT COUNT(*) AS total
         FROM "direct_messages" m
         INNER JOIN "conversation_participants" p
                 ON p."conversation_id" = m."conversation_id" AND p."user_id" = ?
         WHERE m."sender_id" <> ?
           AND m."status" = 'sent'
           AND p."is_archived" = 0
           AND (p."last_read_at" IS NULL OR m."created_at" > p."last_read_at")`,
      )
      .bind(userId, userId)
      .first<{ total: number }>();
    return Number(row?.total ?? 0);
  }

  private static readonly PARTICIPANT_WRITABLE = new Set<string>([
    'is_archived',
    'is_muted',
    'is_blocked',
  ]);

  async updateParticipant(
    conversationId: string,
    userId: string,
    values: Record<string, unknown>,
  ): Promise<number> {
    const columns = Object.keys(values).filter(
      (column) =>
        MessagingRepository.PARTICIPANT_WRITABLE.has(column) && values[column] !== undefined,
    );
    if (columns.length === 0) return 0;

    const assignments = columns
      .map((column) => `"${assertSafeIdentifier(column)}" = ?`)
      .join(', ');

    const result = await this.db
      .prepare(
        `UPDATE "conversation_participants" SET ${assignments}
         WHERE "conversation_id" = ? AND "user_id" = ?`,
      )
      .bind(...columns.map((column) => values[column]), conversationId, userId)
      .run();

    return result.meta.changes ?? 0;
  }

  /**
   * Members somebody can write to, by name.
   *
   * `findable_for_messages` is checked in the query rather than filtered after
   * it, so no mistake in a controller can surface somebody who asked not to be
   * findable. Nothing contactable is selected at all — a name, a handle, a
   * headline and a place. The whole point of this feature is that you can reach
   * somebody without being given their number, and a search result carrying a
   * phone number would give the game away on the first screen.
   */
  async searchPeople(query: string, viewerId: string, limit: number): Promise<Record<string, unknown>[]> {
    const pattern = `%${query.replace(/[\\%_]/g, (char) => `\\${char}`)}%`;

    const result = await this.db
      .prepare(
        `SELECT p."user_id", p."handle", p."full_name", p."headline", p."place_text",
                p."community_area", p."messages_from",
                ma."storage_key" AS avatar_key
         FROM "member_profiles" p
         LEFT JOIN "media_assets" ma ON ma."id" = p."avatar_media_id"
         WHERE p."membership_status" = 'active'
           AND p."findable_for_messages" = 1
           AND p."user_id" <> ?
           AND (p."full_name" LIKE ? ESCAPE '\\' OR p."handle" LIKE ? ESCAPE '\\')
         ORDER BY
           CASE WHEN p."full_name" LIKE ? ESCAPE '\\' THEN 0 ELSE 1 END,
           p."full_name" ASC
         LIMIT ?`,
      )
      .bind(viewerId, pattern, pattern, `${query}%`, limit)
      .all<Record<string, unknown>>();

    return result.results ?? [];
  }

  // -------------------------------------------------------------------------
  // Contact requests and what they grant
  // -------------------------------------------------------------------------

  async findRequest(requesterId: string, subjectId: string): Promise<Record<string, unknown> | null> {
    const row = await this.db
      .prepare(
        `SELECT * FROM "contact_requests"
         WHERE "requester_id" = ? AND "subject_id" = ? LIMIT 1`,
      )
      .bind(requesterId, subjectId)
      .first<Record<string, unknown>>();
    return row ?? null;
  }

  async findRequestById(id: string): Promise<Record<string, unknown> | null> {
    const row = await this.db
      .prepare('SELECT * FROM "contact_requests" WHERE "id" = ? LIMIT 1')
      .bind(id)
      .first<Record<string, unknown>>();
    return row ?? null;
  }

  /**
   * Records the ask, or revives one that was withdrawn.
   *
   * A declined request is NOT revived here — the caller decides whether asking
   * again is allowed, because "no" should mean something.
   */
  async upsertRequest(values: {
    requesterId: string;
    subjectId: string;
    wantsPhone: boolean;
    wantsEmail: boolean;
    reason: string | null;
  }): Promise<string> {
    const existing = await this.findRequest(values.requesterId, values.subjectId);
    const timestamp = nowIso();

    if (existing) {
      await this.db
        .prepare(
          `UPDATE "contact_requests"
           SET "wants_phone" = ?, "wants_email" = ?, "reason" = ?, "state" = 'pending',
               "decided_at" = NULL, "decided_note" = NULL, "updated_at" = ?
           WHERE "id" = ?`,
        )
        .bind(
          values.wantsPhone ? 1 : 0,
          values.wantsEmail ? 1 : 0,
          values.reason,
          timestamp,
          String(existing['id']),
        )
        .run();
      return String(existing['id']);
    }

    const id = newId();
    await this.db
      .prepare(
        `INSERT INTO "contact_requests"
           ("id", "requester_id", "subject_id", "wants_phone", "wants_email", "reason",
            "state", "created_at", "updated_at")
         VALUES (?, ?, ?, ?, ?, ?, 'pending', ?, ?)`,
      )
      .bind(
        id,
        values.requesterId,
        values.subjectId,
        values.wantsPhone ? 1 : 0,
        values.wantsEmail ? 1 : 0,
        values.reason,
        timestamp,
        timestamp,
      )
      .run();

    return id;
  }

  async setRequestState(
    id: string,
    state: string,
    note: string | null,
  ): Promise<number> {
    const result = await this.db
      .prepare(
        `UPDATE "contact_requests"
         SET "state" = ?, "decided_at" = ?, "decided_note" = ?, "updated_at" = ?
         WHERE "id" = ?`,
      )
      .bind(state, nowIso(), note, nowIso(), id)
      .run();
    return result.meta.changes ?? 0;
  }

  /** Requests waiting on this person, and the ones they have made. */
  async requestsFor(userId: string): Promise<{
    incoming: Record<string, unknown>[];
    outgoing: Record<string, unknown>[];
  }> {
    const [incoming, outgoing] = await this.db.batch<Record<string, unknown>>([
      this.db
        .prepare(
          `SELECT r.*, p."handle" AS other_handle, p."full_name" AS other_name,
                  p."headline" AS other_headline
           FROM "contact_requests" r
           LEFT JOIN "member_profiles" p ON p."user_id" = r."requester_id"
           WHERE r."subject_id" = ? AND r."state" = 'pending'
           ORDER BY r."created_at" DESC`,
        )
        .bind(userId),
      this.db
        .prepare(
          `SELECT r.*, p."handle" AS other_handle, p."full_name" AS other_name,
                  p."headline" AS other_headline
           FROM "contact_requests" r
           LEFT JOIN "member_profiles" p ON p."user_id" = r."subject_id"
           WHERE r."requester_id" = ? AND r."state" IN ('pending', 'approved', 'declined')
           ORDER BY r."updated_at" DESC`,
        )
        .bind(userId),
    ]);

    return {
      incoming: incoming?.results ?? [],
      outgoing: outgoing?.results ?? [],
    };
  }

  /** The permission itself. Deleting it is how somebody changes their mind. */
  async grant(values: {
    viewerId: string;
    subjectId: string;
    phone: boolean;
    email: boolean;
    requestId: string | null;
  }): Promise<void> {
    await this.db
      .prepare(
        `INSERT INTO "contact_grants"
           ("id", "viewer_id", "subject_id", "can_see_phone", "can_see_email",
            "request_id", "granted_at")
         VALUES (?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT ("viewer_id", "subject_id") DO UPDATE SET
           "can_see_phone" = excluded."can_see_phone",
           "can_see_email" = excluded."can_see_email",
           "request_id" = excluded."request_id",
           "granted_at" = excluded."granted_at"`,
      )
      .bind(
        newId(),
        values.viewerId,
        values.subjectId,
        values.phone ? 1 : 0,
        values.email ? 1 : 0,
        values.requestId,
        nowIso(),
      )
      .run();
  }

  async revokeGrant(viewerId: string, subjectId: string): Promise<void> {
    await this.db
      .prepare('DELETE FROM "contact_grants" WHERE "viewer_id" = ? AND "subject_id" = ?')
      .bind(viewerId, subjectId)
      .run();
  }

  /**
   * What this viewer has been allowed to see of this person.
   *
   * Consulted by `visibleProfile` on every read. Returns nulls rather than
   * throwing when there is no grant, because "no grant" is the ordinary case
   * and is not an error.
   */
  async grantFor(
    viewerId: string,
    subjectId: string,
  ): Promise<{ phone: boolean; email: boolean }> {
    const row = await this.db
      .prepare(
        `SELECT "can_see_phone", "can_see_email" FROM "contact_grants"
         WHERE "viewer_id" = ? AND "subject_id" = ? LIMIT 1`,
      )
      .bind(viewerId, subjectId)
      .first<{ can_see_phone: number; can_see_email: number }>();

    return {
      phone: row?.can_see_phone === 1,
      email: row?.can_see_email === 1,
    };
  }

  /** Everybody this person has given their details to, so they can take them back. */
  async grantsBy(subjectId: string): Promise<Record<string, unknown>[]> {
    const result = await this.db
      .prepare(
        `SELECT g.*, p."handle", p."full_name", p."headline"
         FROM "contact_grants" g
         LEFT JOIN "member_profiles" p ON p."user_id" = g."viewer_id"
         WHERE g."subject_id" = ?
         ORDER BY g."granted_at" DESC`,
      )
      .bind(subjectId)
      .all<Record<string, unknown>>();
    return result.results ?? [];
  }
}
