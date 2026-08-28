import { newId, nowIso } from '../utils/id';
import { canConfirmDeath, normalisePhone } from '../services/kinship';

export interface RelationshipRecord {
  id: string;
  from_user_id: string;
  to_user_id: string;
  type: string;
  reverse_type: string | null;
  state: string;
  requested_by: string;
  note: string | null;
  via: string;
  decided_at: string | null;
  created_at: string;
}

/** A relationship as one side of it sees it. */
export interface RelationshipView extends RelationshipRecord {
  /** The other person, from the point of view of whoever asked. */
  other_user_id: string;
  other_name: string;
  other_handle: string | null;
  other_avatar_key: string | null;
  /** What the other person is to the viewer. */
  as_seen: string;
  /** True where the viewer is the one being asked. */
  awaiting_me: boolean;
}

/**
 * KINSHIP
 *
 * Who is related to whom, and — the part that matters most — who has actually
 * agreed to it. A pending row is a claim; only an accepted row is a
 * relationship, and the death-confirmation safeguard depends on that
 * distinction holding absolutely.
 */
export class KinshipRepository {
  constructor(private readonly db: D1Database) {}

  // -------------------------------------------------------------------------
  // Reading
  // -------------------------------------------------------------------------

  /**
   * One relationship between two people, whichever direction it was recorded.
   *
   * Checked before creating a new one, so that A→B and B→A can never both
   * exist — two rows describing one relationship would eventually disagree.
   */
  async between(userA: string, userB: string): Promise<RelationshipRecord | null> {
    const row = await this.db
      .prepare(
        `SELECT * FROM "member_relationships"
         WHERE ("from_user_id" = ? AND "to_user_id" = ?)
            OR ("from_user_id" = ? AND "to_user_id" = ?)
         LIMIT 1`,
      )
      .bind(userA, userB, userB, userA)
      .first<RelationshipRecord>();
    return row ?? null;
  }

  /**
   * Everybody this person is connected to, in whichever direction.
   *
   * The union is what makes a relationship symmetrical to read: it does not
   * matter who sent the request, and neither side should have to know.
   */
  async forUser(userId: string, states: string[] = ['accepted']): Promise<RelationshipView[]> {
    if (states.length === 0) return [];
    const placeholders = states.map(() => '?').join(', ');

    const result = await this.db
      .prepare(
        `SELECT r.*,
                CASE WHEN r."from_user_id" = ?1 THEN r."to_user_id" ELSE r."from_user_id" END AS other_user_id,
                CASE WHEN r."from_user_id" = ?1 THEN r."type" ELSE r."reverse_type" END AS as_seen,
                u."display_name" AS other_name,
                p."handle" AS other_handle,
                p."full_name" AS other_full_name,
                ma."storage_key" AS other_avatar_key
         FROM "member_relationships" r
         INNER JOIN "users" u
           ON u."id" = CASE WHEN r."from_user_id" = ?1 THEN r."to_user_id" ELSE r."from_user_id" END
         LEFT JOIN "member_profiles" p ON p."user_id" = u."id"
         LEFT JOIN "media_assets" ma ON ma."id" = p."avatar_media_id"
         WHERE (r."from_user_id" = ?1 OR r."to_user_id" = ?1)
           AND r."state" IN (${placeholders})
         ORDER BY r."created_at" DESC`,
      )
      .bind(userId, ...states)
      .all<Record<string, unknown>>();

    return (result.results ?? []).map((row) => ({
      ...(row as unknown as RelationshipRecord),
      other_user_id: String(row['other_user_id']),
      other_name: String(row['other_full_name'] ?? row['other_name'] ?? 'A member'),
      other_handle: (row['other_handle'] as string | null) ?? null,
      other_avatar_key: (row['other_avatar_key'] as string | null) ?? null,
      // A pending request has no reverse yet, so the far side reads as the
      // mirror of what was asked until it is accepted.
      as_seen: String(row['as_seen'] ?? row['type'] ?? 'kin'),
      awaiting_me: row['state'] === 'pending' && row['requested_by'] !== userId,
    }));
  }

  /** Requests waiting on this person to answer. */
  async pendingFor(userId: string): Promise<RelationshipView[]> {
    const all = await this.forUser(userId, ['pending']);
    return all.filter((row) => row.awaiting_me);
  }

  /** The user ids this person is connected to — for birthdays and notices. */
  async connectedUserIds(userId: string): Promise<string[]> {
    const result = await this.db
      .prepare(
        `SELECT CASE WHEN "from_user_id" = ?1 THEN "to_user_id" ELSE "from_user_id" END AS other
         FROM "member_relationships"
         WHERE ("from_user_id" = ?1 OR "to_user_id" = ?1) AND "state" = 'accepted'`,
      )
      .bind(userId)
      .all<{ other: string }>();
    return (result.results ?? []).map((row) => row.other);
  }

  async findById(id: string): Promise<RelationshipRecord | null> {
    const row = await this.db
      .prepare('SELECT * FROM "member_relationships" WHERE "id" = ? LIMIT 1')
      .bind(id)
      .first<RelationshipRecord>();
    return row ?? null;
  }

  // -------------------------------------------------------------------------
  // Writing
  // -------------------------------------------------------------------------

  async request(values: {
    fromUserId: string;
    toUserId: string;
    type: string;
    note: string | null;
    via: string;
  }): Promise<string> {
    const id = newId();
    const timestamp = nowIso();

    await this.db
      .prepare(
        `INSERT INTO "member_relationships"
           ("id", "from_user_id", "to_user_id", "type", "state", "requested_by",
            "note", "via", "created_at", "updated_at")
         VALUES (?, ?, ?, ?, 'pending', ?, ?, ?, ?, ?)`,
      )
      .bind(
        id,
        values.fromUserId,
        values.toUserId,
        values.type,
        values.fromUserId,
        values.note,
        values.via,
        timestamp,
        timestamp,
      )
      .run();

    return id;
  }

  async accept(id: string, reverseType: string): Promise<number> {
    const timestamp = nowIso();
    const result = await this.db
      .prepare(
        `UPDATE "member_relationships"
         SET "state" = 'accepted', "reverse_type" = ?, "decided_at" = ?, "updated_at" = ?
         WHERE "id" = ? AND "state" = 'pending'`,
      )
      .bind(reverseType, timestamp, timestamp, id)
      .run();
    return result.meta.changes ?? 0;
  }

  async decline(id: string): Promise<number> {
    const timestamp = nowIso();
    const result = await this.db
      .prepare(
        `UPDATE "member_relationships"
         SET "state" = 'declined', "decided_at" = ?, "updated_at" = ?
         WHERE "id" = ? AND "state" = 'pending'`,
      )
      .bind(timestamp, timestamp, id)
      .run();
    return result.meta.changes ?? 0;
  }

  /**
   * Ends a relationship.
   *
   * Either side may do it, and it takes only one: a relationship the other
   * person denies is not a relationship, and requiring both to agree to end it
   * would be a way to hold somebody in a claim they have rejected.
   */
  async remove(id: string, byUserId: string): Promise<number> {
    const timestamp = nowIso();
    const result = await this.db
      .prepare(
        `UPDATE "member_relationships"
         SET "state" = 'removed', "removed_by" = ?, "removed_at" = ?, "updated_at" = ?
         WHERE "id" = ? AND "state" IN ('accepted', 'pending')`,
      )
      .bind(byUserId, timestamp, timestamp, id)
      .run();
    return result.meta.changes ?? 0;
  }

  /** How many requests this person has sent since a given moment. */
  async requestsSince(userId: string, sinceIso: string): Promise<number> {
    const row = await this.db
      .prepare(
        `SELECT COUNT(*) AS total FROM "member_relationships"
         WHERE "requested_by" = ? AND "created_at" >= ?`,
      )
      .bind(userId, sinceIso)
      .first<{ total: number }>();
    return Number(row?.total ?? 0);
  }

  // -------------------------------------------------------------------------
  // Finding somebody
  // -------------------------------------------------------------------------

  /**
   * The account behind a phone number.
   *
   * THE CALLER MUST NOT REVEAL WHETHER THIS FOUND ANYTHING. The connection
   * endpoint answers identically either way — "if there is an account for that
   * number, they have been asked" — for the same reason the password reset
   * flow does. Otherwise this becomes a way to test which of a list of numbers
   * belongs to a member of this community.
   *
   * Returns the first match. Two members may share a household phone; the
   * request goes to whoever registered it, and the other can be reached from
   * their profile.
   */
  async findByPhone(rawPhone: string): Promise<{ user_id: string; handle: string } | null> {
    const normalised = normalisePhone(rawPhone);
    if (!normalised) return null;

    const row = await this.db
      .prepare(
        `SELECT "user_id", "handle" FROM "member_profiles"
         WHERE "phone_normalised" = ? AND "membership_status" = 'active'
         ORDER BY "created_at" ASC LIMIT 1`,
      )
      .bind(normalised)
      .first<{ user_id: string; handle: string }>();

    return row ?? null;
  }

  // -------------------------------------------------------------------------
  // The death-confirmation safeguard
  // -------------------------------------------------------------------------

  /**
   * Whether this person was already close family of that one, BEFORE a given
   * moment.
   *
   * Three conditions, and all three matter:
   *
   *   accepted     a pending claim is not a relationship
   *   close        `canConfirmDeath` excludes distant kin, so a cousin cannot
   *                still somebody's account on their own
   *   pre-dating   the relationship must have been accepted before the report
   *                was filed, or two accounts could connect this morning and
   *                bury somebody this afternoon
   */
  async wasCloseFamilyBefore(
    userId: string,
    subjectId: string,
    beforeIso: string,
  ): Promise<RelationshipRecord | null> {
    const row = await this.db
      .prepare(
        `SELECT * FROM "member_relationships"
         WHERE (("from_user_id" = ?1 AND "to_user_id" = ?2)
             OR ("from_user_id" = ?2 AND "to_user_id" = ?1))
           AND "state" = 'accepted'
           AND "decided_at" IS NOT NULL
           AND "decided_at" < ?3
         LIMIT 1`,
      )
      .bind(userId, subjectId, beforeIso)
      .first<RelationshipRecord>();

    if (!row) return null;

    // Which label applies depends on which way round the row was recorded.
    const asSeen = row.from_user_id === userId ? row.type : (row.reverse_type ?? row.type);
    return canConfirmDeath(asSeen) ? row : null;
  }
}
