import { newId, nowIso } from '../utils/id';
import { assertSafeIdentifier } from './base.repository';

export interface GroupRecord {
  id: string;
  slug: string;
  kind: string;
  title: string;
  subtitle: string | null;
  motto: string | null;
  excerpt: string | null;
  body: string | null;
  formed_year: number | null;
  birth_year_from: number | null;
  birth_year_to: number | null;
  birth_years: string | null;
  join_policy: string;
  dues_amount: number | null;
  dues_currency: string;
  dues_period: string;
  dues_notes: string | null;
  cover_media_id: string | null;
  gallery_id: string | null;
  contact_name: string | null;
  contact_phone: string | null;
  contact_email: string | null;
  member_count: number;
  created_by: string | null;
  verification_status: string;
  status: string;
  created_at: string;
  updated_at: string;
}

export interface GroupAdminRecord {
  id: string;
  group_id: string;
  user_id: string;
  admin_role: 'lead' | 'admin' | 'treasurer';
  office: string | null;
  created_at: string;
}

export interface GroupMemberRecord {
  id: string;
  group_id: string;
  user_id: string | null;
  full_name: string;
  membership_state: string;
  office: string | null;
  joined_year: number | null;
  birth_year: number | null;
  notes: string | null;
  request_note: string | null;
  is_deceased: number;
  deceased_year: number | null;
  status: string;
  created_at: string;
}

/**
 * COMMUNITY GROUPS
 *
 * Age grades, cultural groups and whatever the community forms next. One table
 * with a `kind`, so the membership, dues and moderation logic exists once
 * rather than once per sort of group.
 */
export class GroupRepository {
  constructor(private readonly db: D1Database) {}

  // -------------------------------------------------------------------------
  // Groups
  // -------------------------------------------------------------------------

  async findBySlugOrId(identifier: string, statuses: string[] | null): Promise<GroupRecord | null> {
    const conditions = ['("slug" = ? OR "id" = ?)'];
    const bindings: unknown[] = [identifier, identifier];

    if (statuses && statuses.length > 0) {
      conditions.push(`"status" IN (${statuses.map(() => '?').join(', ')})`);
      bindings.push(...statuses);
    }

    const row = await this.db
      .prepare(`SELECT * FROM "community_groups" WHERE ${conditions.join(' AND ')} LIMIT 1`)
      .bind(...bindings)
      .first<GroupRecord>();
    return row ?? null;
  }

  async slugExists(slug: string): Promise<boolean> {
    const row = await this.db
      .prepare('SELECT "id" FROM "community_groups" WHERE "slug" = ? LIMIT 1')
      .bind(slug)
      .first<{ id: string }>();
    return row !== null;
  }

  async list(options: {
    kind?: string | null;
    statuses: string[];
    search?: string | null;
    limit: number;
    offset: number;
  }): Promise<{ items: GroupRecord[]; total: number }> {
    const conditions: string[] = [];
    const bindings: unknown[] = [];

    if (options.statuses.length > 0) {
      conditions.push(`"status" IN (${options.statuses.map(() => '?').join(', ')})`);
      bindings.push(...options.statuses);
    }
    if (options.kind) {
      conditions.push('"kind" = ?');
      bindings.push(options.kind);
    }
    if (options.search) {
      const pattern = `%${options.search.replace(/[\\%_]/g, (char) => `\\${char}`)}%`;
      conditions.push(`("title" LIKE ? ESCAPE '\\' OR "subtitle" LIKE ? ESCAPE '\\')`);
      bindings.push(pattern, pattern);
    }

    const where = conditions.length > 0 ? ` WHERE ${conditions.join(' AND ')}` : '';

    const [countRow, rows] = await this.db.batch<Record<string, unknown>>([
      this.db.prepare(`SELECT COUNT(*) AS total FROM "community_groups"${where}`).bind(...bindings),
      this.db
        .prepare(
          `SELECT * FROM "community_groups"${where}
           ORDER BY "formed_year" IS NULL, "formed_year" ASC, "sort_order" ASC, "title" ASC
           LIMIT ? OFFSET ?`,
        )
        .bind(...bindings, options.limit, options.offset),
    ]);

    return {
      items: (rows?.results ?? []) as unknown as GroupRecord[],
      total: Number((countRow?.results?.[0]?.['total'] as number | undefined) ?? 0),
    };
  }

  /**
   * Age grades whose bracket contains a given birth year.
   *
   * The query behind "which grades are mine?". A grade with no bracket
   * recorded is excluded rather than offered to everybody — suggesting a grade
   * to somebody who does not belong to it wastes an officer's time declining it.
   */
  async eligibleByBirthYear(birthYear: number, kind = 'age_grade'): Promise<GroupRecord[]> {
    const result = await this.db
      .prepare(
        `SELECT * FROM "community_groups"
         WHERE "kind" = ?
           AND "status" = 'published'
           AND "join_policy" IN ('by_age', 'by_request', 'open')
           AND "birth_year_from" IS NOT NULL
           AND "birth_year_to" IS NOT NULL
           AND ? BETWEEN "birth_year_from" AND "birth_year_to"
         ORDER BY "formed_year" ASC`,
      )
      .bind(kind, birthYear)
      .all<GroupRecord>();

    return result.results ?? [];
  }

  async create(values: Record<string, unknown>): Promise<string> {
    const id = newId();
    const timestamp = nowIso();

    const columns = Object.keys(values).filter((column) => values[column] !== undefined);
    const allColumns = ['id', ...columns, 'created_at', 'updated_at'];
    const allValues = [id, ...columns.map((column) => values[column] ?? null), timestamp, timestamp];

    await this.db
      .prepare(
        `INSERT INTO "community_groups" (${allColumns.map((c) => `"${assertSafeIdentifier(c)}"`).join(', ')})
         VALUES (${allColumns.map(() => '?').join(', ')})`,
      )
      .bind(...allValues)
      .run();

    return id;
  }

  /**
   * The fields a group's own officers may change.
   *
   * `status` and `verification_status` are absent deliberately: a group writes
   * its own page, but whether that page is published, and whether the archive
   * vouches for it, stay with the Preservation Team.
   */
  private static readonly OWN_FIELDS = new Set<string>([
    'title', 'subtitle', 'motto', 'excerpt', 'body', 'category',
    'formed_year', 'birth_year_from', 'birth_year_to', 'birth_years',
    'join_policy', 'dues_amount', 'dues_currency', 'dues_period', 'dues_notes',
    'dues_updated_at', 'cover_media_id', 'gallery_id',
    'contact_name', 'contact_phone', 'contact_email', 'member_count',
  ]);

  async updateOwnFields(id: string, values: Record<string, unknown>): Promise<number> {
    const columns = Object.keys(values).filter(
      (column) => GroupRepository.OWN_FIELDS.has(column) && values[column] !== undefined,
    );
    if (columns.length === 0) return 0;

    const assignments = columns.map((column) => `"${assertSafeIdentifier(column)}" = ?`).join(', ');
    const result = await this.db
      .prepare(`UPDATE "community_groups" SET ${assignments}, "updated_at" = ? WHERE "id" = ?`)
      .bind(...columns.map((column) => values[column] ?? null), nowIso(), id)
      .run();

    return result.meta.changes ?? 0;
  }

  async recountMembers(groupId: string): Promise<void> {
    await this.db
      .prepare(
        `UPDATE "community_groups" SET "member_count" =
           (SELECT COUNT(*) FROM "group_members"
            WHERE "group_id" = ? AND "membership_state" = 'active')
         WHERE "id" = ?`,
      )
      .bind(groupId, groupId)
      .run();
  }

  // -------------------------------------------------------------------------
  // Officers
  // -------------------------------------------------------------------------

  async adminFor(groupId: string, userId: string): Promise<GroupAdminRecord | null> {
    const row = await this.db
      .prepare('SELECT * FROM "group_admins" WHERE "group_id" = ? AND "user_id" = ? LIMIT 1')
      .bind(groupId, userId)
      .first<GroupAdminRecord>();
    return row ?? null;
  }

  async admins(groupId: string): Promise<(GroupAdminRecord & { display_name: string; email: string })[]> {
    const result = await this.db
      .prepare(
        `SELECT a.*, u."display_name", u."email"
         FROM "group_admins" a
         INNER JOIN "users" u ON u."id" = a."user_id"
         WHERE a."group_id" = ?
         ORDER BY CASE a."admin_role" WHEN 'lead' THEN 0 WHEN 'treasurer' THEN 1 ELSE 2 END,
                  a."created_at" ASC`,
      )
      .bind(groupId)
      .all<GroupAdminRecord & { display_name: string; email: string }>();
    return result.results ?? [];
  }

  async addAdmin(values: {
    groupId: string;
    userId: string;
    adminRole: string;
    office: string | null;
    appointedBy: string | null;
  }): Promise<string> {
    const id = newId();
    await this.db
      .prepare(
        `INSERT OR REPLACE INTO "group_admins"
           ("id", "group_id", "user_id", "admin_role", "office", "appointed_by", "created_at")
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(id, values.groupId, values.userId, values.adminRole, values.office, values.appointedBy, nowIso())
      .run();
    return id;
  }

  async removeAdmin(groupId: string, userId: string): Promise<number> {
    const result = await this.db
      .prepare('DELETE FROM "group_admins" WHERE "group_id" = ? AND "user_id" = ?')
      .bind(groupId, userId)
      .run();
    return result.meta.changes ?? 0;
  }

  async countLeads(groupId: string): Promise<number> {
    const row = await this.db
      .prepare(`SELECT COUNT(*) AS total FROM "group_admins" WHERE "group_id" = ? AND "admin_role" = 'lead'`)
      .bind(groupId)
      .first<{ total: number }>();
    return Number(row?.total ?? 0);
  }

  async groupsAdministeredBy(userId: string): Promise<(GroupRecord & { admin_role: string })[]> {
    const result = await this.db
      .prepare(
        `SELECT g.*, a."admin_role"
         FROM "group_admins" a
         INNER JOIN "community_groups" g ON g."id" = a."group_id"
         WHERE a."user_id" = ?
         ORDER BY g."title" ASC`,
      )
      .bind(userId)
      .all<GroupRecord & { admin_role: string }>();
    return result.results ?? [];
  }

  // -------------------------------------------------------------------------
  // Members
  // -------------------------------------------------------------------------

  async members(groupId: string, states: string[], statuses: string[]): Promise<GroupMemberRecord[]> {
    if (states.length === 0 || statuses.length === 0) return [];

    const result = await this.db
      .prepare(
        `SELECT * FROM "group_members"
         WHERE "group_id" = ?
           AND "membership_state" IN (${states.map(() => '?').join(', ')})
           AND "status" IN (${statuses.map(() => '?').join(', ')})
         ORDER BY "sort_order" ASC, "full_name" ASC`,
      )
      .bind(groupId, ...states, ...statuses)
      .all<GroupMemberRecord>();
    return result.results ?? [];
  }

  async memberFor(groupId: string, userId: string): Promise<GroupMemberRecord | null> {
    const row = await this.db
      .prepare('SELECT * FROM "group_members" WHERE "group_id" = ? AND "user_id" = ? LIMIT 1')
      .bind(groupId, userId)
      .first<GroupMemberRecord>();
    return row ?? null;
  }

  async findMember(id: string): Promise<GroupMemberRecord | null> {
    const row = await this.db
      .prepare('SELECT * FROM "group_members" WHERE "id" = ? LIMIT 1')
      .bind(id)
      .first<GroupMemberRecord>();
    return row ?? null;
  }

  async addMember(values: {
    groupId: string;
    userId: string | null;
    fullName: string;
    membershipState: string;
    office: string | null;
    joinedYear: number | null;
    birthYear: number | null;
    notes: string | null;
    requestNote: string | null;
    status: string;
    addedBy: string | null;
  }): Promise<string> {
    const id = newId();
    const timestamp = nowIso();

    await this.db
      .prepare(
        `INSERT INTO "group_members"
           ("id", "group_id", "user_id", "full_name", "membership_state", "office",
            "joined_year", "birth_year", "notes", "request_note", "status", "added_by",
            "created_at", "updated_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        id, values.groupId, values.userId, values.fullName, values.membershipState,
        values.office, values.joinedYear, values.birthYear, values.notes,
        values.requestNote, values.status, values.addedBy, timestamp, timestamp,
      )
      .run();

    return id;
  }

  private static readonly MEMBER_FIELDS = new Set<string>([
    'full_name', 'membership_state', 'office', 'joined_year', 'birth_year',
    'notes', 'is_deceased', 'deceased_year', 'sort_order', 'status',
    'decided_by', 'decided_at',
  ]);

  async updateMember(id: string, values: Record<string, unknown>): Promise<number> {
    const columns = Object.keys(values).filter(
      (column) => GroupRepository.MEMBER_FIELDS.has(column) && values[column] !== undefined,
    );
    if (columns.length === 0) return 0;

    const assignments = columns.map((column) => `"${assertSafeIdentifier(column)}" = ?`).join(', ');
    const result = await this.db
      .prepare(`UPDATE "group_members" SET ${assignments}, "updated_at" = ? WHERE "id" = ?`)
      .bind(...columns.map((column) => values[column] ?? null), nowIso(), id)
      .run();

    return result.meta.changes ?? 0;
  }

  async removeMember(id: string): Promise<number> {
    const result = await this.db.prepare('DELETE FROM "group_members" WHERE "id" = ?').bind(id).run();
    return result.meta.changes ?? 0;
  }

  /** The groups this person actually belongs to, as a confirmed member. */
  async groupsForUser(userId: string): Promise<(GroupRecord & { membership_state: string })[]> {
    const result = await this.db
      .prepare(
        `SELECT g.*, m."membership_state"
         FROM "group_members" m
         INNER JOIN "community_groups" g ON g."id" = m."group_id"
         WHERE m."user_id" = ? AND m."membership_state" IN ('active', 'requested')
         ORDER BY g."title" ASC`,
      )
      .bind(userId)
      .all<GroupRecord & { membership_state: string }>();
    return result.results ?? [];
  }

  /**
   * Everybody who shares a group with this person.
   *
   * What makes a birthday notice reach "every group the person belongs to":
   * the people in their age grade, their family group and their cultural group
   * are exactly the ones who should be told.
   *
   * One query rather than one per group — a member of five groups should not
   * cost five round trips every time a dashboard loads.
   */
  async fellowMemberIds(userId: string): Promise<string[]> {
    const result = await this.db
      .prepare(
        `SELECT DISTINCT other."user_id" AS other_id
         FROM "group_members" mine
         INNER JOIN "group_members" other ON other."group_id" = mine."group_id"
         WHERE mine."user_id" = ?1
           AND mine."membership_state" = 'active'
           AND other."membership_state" = 'active'
           AND other."user_id" IS NOT NULL
           AND other."user_id" <> ?1`,
      )
      .bind(userId)
      .all<{ other_id: string }>();

    return (result.results ?? []).map((row) => row.other_id);
  }

  /** Members of a group who hold accounts — for notifying a whole group. */
  async memberUserIds(groupId: string): Promise<string[]> {
    const result = await this.db
      .prepare(
        `SELECT "user_id" FROM "group_members"
         WHERE "group_id" = ? AND "membership_state" = 'active' AND "user_id" IS NOT NULL`,
      )
      .bind(groupId)
      .all<{ user_id: string }>();
    return (result.results ?? []).map((row) => row.user_id);
  }

  // -------------------------------------------------------------------------
  // Posts
  // -------------------------------------------------------------------------

  async posts(groupId: string, statuses: string[]): Promise<Record<string, unknown>[]> {
    if (statuses.length === 0) return [];
    const result = await this.db
      .prepare(
        `SELECT * FROM "group_posts"
         WHERE "group_id" = ? AND "status" IN (${statuses.map(() => '?').join(', ')})
         ORDER BY "published_at" IS NULL, "published_at" DESC, "created_at" DESC`,
      )
      .bind(groupId, ...statuses)
      .all<Record<string, unknown>>();
    return result.results ?? [];
  }

  async addPost(values: {
    groupId: string;
    title: string;
    body: string;
    excerpt: string | null;
    authorId: string | null;
    authorName: string | null;
    coverMediaId: string | null;
    status: string;
  }): Promise<string> {
    const id = newId();
    const timestamp = nowIso();

    await this.db
      .prepare(
        `INSERT INTO "group_posts"
           ("id", "group_id", "title", "body", "excerpt", "author_id", "author_name",
            "cover_media_id", "status", "published_at", "created_at", "updated_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        id, values.groupId, values.title, values.body, values.excerpt,
        values.authorId, values.authorName, values.coverMediaId, values.status,
        values.status === 'published' ? timestamp : null, timestamp, timestamp,
      )
      .run();

    return id;
  }

  // -------------------------------------------------------------------------
  // Where the money is sent
  // -------------------------------------------------------------------------

  /**
   * A group's bank details.
   *
   * Never returned on a public route. A community's account number on an
   * indexable page is an invitation, and the `visibility` column exists so a
   * group can keep them to its officers even from its own members.
   */
  async paymentAccounts(groupId: string, includeInactive = false): Promise<Record<string, unknown>[]> {
    const result = await this.db
      .prepare(
        `SELECT * FROM "group_payment_accounts"
         WHERE "group_id" = ?${includeInactive ? '' : ' AND "is_active" = 1'}
         ORDER BY "is_primary" DESC, "created_at" ASC`,
      )
      .bind(groupId)
      .all<Record<string, unknown>>();
    return result.results ?? [];
  }

  async findAccount(id: string): Promise<Record<string, unknown> | null> {
    const row = await this.db
      .prepare('SELECT * FROM "group_payment_accounts" WHERE "id" = ? LIMIT 1')
      .bind(id)
      .first<Record<string, unknown>>();
    return row ?? null;
  }

  async addAccount(values: {
    groupId: string;
    label: string | null;
    bankName: string;
    accountName: string;
    accountNumber: string;
    swiftCode: string | null;
    sortCode: string | null;
    instructions: string | null;
    visibility: string;
    isPrimary: boolean;
    addedBy: string | null;
  }): Promise<string> {
    const id = newId();
    const timestamp = nowIso();

    // One primary at a time, or a member reading the page cannot tell which
    // account the group actually wants the money in.
    if (values.isPrimary) {
      await this.db
        .prepare('UPDATE "group_payment_accounts" SET "is_primary" = 0 WHERE "group_id" = ?')
        .bind(values.groupId)
        .run();
    }

    await this.db
      .prepare(
        `INSERT INTO "group_payment_accounts"
           ("id", "group_id", "label", "bank_name", "account_name", "account_number",
            "swift_code", "sort_code", "instructions", "visibility", "is_primary",
            "added_by", "last_changed_by", "created_at", "updated_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        id, values.groupId, values.label, values.bankName, values.accountName,
        values.accountNumber, values.swiftCode, values.sortCode, values.instructions,
        values.visibility, values.isPrimary ? 1 : 0, values.addedBy, values.addedBy,
        timestamp, timestamp,
      )
      .run();

    return id;
  }

  private static readonly ACCOUNT_FIELDS = new Set<string>([
    'label', 'bank_name', 'account_name', 'account_number',
    'swift_code', 'sort_code', 'instructions', 'visibility', 'is_primary', 'is_active',
  ]);

  /**
   * Changes an account, and writes down what it used to be.
   *
   * The old value is recorded on every field that changes. If somebody alters
   * an account number, the group can see exactly what it was and when it
   * changed without having to take anybody's word for it — which is the single
   * most useful thing this table does, because redirecting a community's dues
   * is the obvious way to steal from one.
   */
  async updateAccount(
    id: string,
    values: Record<string, unknown>,
    actor: { id: string; name: string },
  ): Promise<number> {
    const existing = await this.findAccount(id);
    if (!existing) return 0;

    const columns = Object.keys(values).filter(
      (column) => GroupRepository.ACCOUNT_FIELDS.has(column) && values[column] !== undefined,
    );
    if (columns.length === 0) return 0;

    const changes = columns.filter(
      (column) => String(existing[column] ?? '') !== String(values[column] ?? ''),
    );

    const assignments = columns.map((column) => `"${assertSafeIdentifier(column)}" = ?`).join(', ');
    const result = await this.db
      .prepare(
        `UPDATE "group_payment_accounts"
         SET ${assignments}, "last_changed_by" = ?, "updated_at" = ?
         WHERE "id" = ?`,
      )
      .bind(...columns.map((column) => values[column] ?? null), actor.id, nowIso(), id)
      .run();

    for (const field of changes) {
      await this.db
        .prepare(
          `INSERT INTO "group_account_changes"
             ("id", "account_id", "group_id", "changed_by", "changed_by_name",
              "field", "old_value", "new_value", "created_at")
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        )
        .bind(
          newId(), id, String(existing['group_id']), actor.id, actor.name,
          field, existing[field] ?? null, values[field] ?? null, nowIso(),
        )
        .run();
    }

    return result.meta.changes ?? 0;
  }

  async accountChanges(groupId: string, limit = 50): Promise<Record<string, unknown>[]> {
    const result = await this.db
      .prepare(
        `SELECT * FROM "group_account_changes"
         WHERE "group_id" = ? ORDER BY "created_at" DESC LIMIT ?`,
      )
      .bind(groupId, limit)
      .all<Record<string, unknown>>();
    return result.results ?? [];
  }

  // -------------------------------------------------------------------------
  // Dues
  // -------------------------------------------------------------------------

  /**
   * Records that a member says they have paid.
   *
   * DECLARED, NOT TAKEN. The platform never touches the money — the member
   * sends it to the group's account by whatever means they already use, and
   * records it here so both sides have the same list. A treasurer then
   * confirms it against the bank.
   *
   * That is deliberate. Processing payments would mean holding a community's
   * money, complying with what that entails, and being blamed when a transfer
   * fails. A shared ledger solves the actual problem, which is that nobody can
   * agree on who has paid.
   */
  async declarePayment(values: {
    groupId: string;
    memberId: string | null;
    userId: string | null;
    payerName: string | null;
    amount: number;
    currency: string;
    periodLabel: string | null;
    paidOn: string | null;
    method: string;
    reference: string | null;
    note: string | null;
    proofMediaId: string | null;
  }): Promise<string> {
    const id = newId();
    const timestamp = nowIso();

    await this.db
      .prepare(
        `INSERT INTO "group_dues_payments"
           ("id", "group_id", "member_id", "user_id", "payer_name", "amount", "currency",
            "period_label", "paid_on", "method", "reference", "note", "proof_media_id",
            "state", "created_at", "updated_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'declared', ?, ?)`,
      )
      .bind(
        id, values.groupId, values.memberId, values.userId, values.payerName,
        values.amount, values.currency, values.periodLabel, values.paidOn,
        values.method, values.reference, values.note, values.proofMediaId,
        timestamp, timestamp,
      )
      .run();

    return id;
  }

  async payments(options: {
    groupId: string;
    userId?: string | null;
    state?: string | null;
    limit: number;
    offset: number;
  }): Promise<{ items: Record<string, unknown>[]; total: number }> {
    const conditions = ['"group_id" = ?'];
    const bindings: unknown[] = [options.groupId];

    if (options.userId) {
      conditions.push('"user_id" = ?');
      bindings.push(options.userId);
    }
    if (options.state) {
      conditions.push('"state" = ?');
      bindings.push(options.state);
    }

    const where = conditions.join(' AND ');
    const [countRow, rows] = await this.db.batch<Record<string, unknown>>([
      this.db.prepare(`SELECT COUNT(*) AS total FROM "group_dues_payments" WHERE ${where}`).bind(...bindings),
      this.db
        .prepare(
          `SELECT * FROM "group_dues_payments" WHERE ${where}
           ORDER BY "paid_on" IS NULL, "paid_on" DESC, "created_at" DESC
           LIMIT ? OFFSET ?`,
        )
        .bind(...bindings, options.limit, options.offset),
    ]);

    return {
      items: rows?.results ?? [],
      total: Number((countRow?.results?.[0]?.['total'] as number | undefined) ?? 0),
    };
  }

  async findPayment(id: string): Promise<Record<string, unknown> | null> {
    const row = await this.db
      .prepare('SELECT * FROM "group_dues_payments" WHERE "id" = ? LIMIT 1')
      .bind(id)
      .first<Record<string, unknown>>();
    return row ?? null;
  }

  async settlePayment(
    id: string,
    state: string,
    officer: { id: string; note: string | null },
  ): Promise<number> {
    const result = await this.db
      .prepare(
        `UPDATE "group_dues_payments"
         SET "state" = ?, "confirmed_by" = ?, "confirmed_at" = ?, "officer_note" = ?, "updated_at" = ?
         WHERE "id" = ?`,
      )
      .bind(state, officer.id, nowIso(), officer.note, nowIso(), id)
      .run();
    return result.meta.changes ?? 0;
  }

  /** What a group has actually been paid, for the officers' own page. */
  async duesSummary(groupId: string): Promise<{ state: string; count: number; total: number }[]> {
    const result = await this.db
      .prepare(
        `SELECT "state", COUNT(*) AS count, COALESCE(SUM("amount"), 0) AS total
         FROM "group_dues_payments" WHERE "group_id" = ? GROUP BY "state"`,
      )
      .bind(groupId)
      .all<{ state: string; count: number; total: number }>();
    return result.results ?? [];
  }

  // -------------------------------------------------------------------------
  // Issues
  // -------------------------------------------------------------------------

  async raiseIssue(values: {
    groupId: string;
    raisedBy: string | null;
    raisedByName: string | null;
    kind: string;
    subject: string;
    detail: string | null;
    isPrivate: boolean;
  }): Promise<string> {
    const id = newId();
    const timestamp = nowIso();

    await this.db
      .prepare(
        `INSERT INTO "group_issues"
           ("id", "group_id", "raised_by", "raised_by_name", "kind", "subject", "detail",
            "is_private", "state", "created_at", "updated_at")
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'open', ?, ?)`,
      )
      .bind(
        id, values.groupId, values.raisedBy, values.raisedByName, values.kind,
        values.subject, values.detail, values.isPrivate ? 1 : 0, timestamp, timestamp,
      )
      .run();

    return id;
  }

  /**
   * A group's issues.
   *
   * `raisedBy` narrows it to one person's own — which is what a member sees.
   * Officers see everything, including the private ones, because a private
   * issue is private from the rest of the group rather than from the people it
   * is addressed to.
   */
  async issues(groupId: string, options: { raisedBy?: string | null; state?: string | null } = {}): Promise<Record<string, unknown>[]> {
    const conditions = ['"group_id" = ?'];
    const bindings: unknown[] = [groupId];

    if (options.raisedBy) {
      conditions.push('"raised_by" = ?');
      bindings.push(options.raisedBy);
    }
    if (options.state) {
      conditions.push('"state" = ?');
      bindings.push(options.state);
    }

    const result = await this.db
      .prepare(
        `SELECT * FROM "group_issues" WHERE ${conditions.join(' AND ')}
         ORDER BY CASE "state" WHEN 'open' THEN 0 WHEN 'acknowledged' THEN 1 ELSE 2 END,
                  "created_at" DESC`,
      )
      .bind(...bindings)
      .all<Record<string, unknown>>();

    return result.results ?? [];
  }

  async findIssue(id: string): Promise<Record<string, unknown> | null> {
    const row = await this.db
      .prepare('SELECT * FROM "group_issues" WHERE "id" = ? LIMIT 1')
      .bind(id)
      .first<Record<string, unknown>>();
    return row ?? null;
  }

  async settleIssue(
    id: string,
    values: { state: string; resolution: string | null; handledBy: string },
  ): Promise<number> {
    const result = await this.db
      .prepare(
        `UPDATE "group_issues"
         SET "state" = ?, "resolution" = ?, "handled_by" = ?, "handled_at" = ?, "updated_at" = ?
         WHERE "id" = ?`,
      )
      .bind(values.state, values.resolution, values.handledBy, nowIso(), nowIso(), id)
      .run();
    return result.meta.changes ?? 0;
  }
}
