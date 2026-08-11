import type { RoleRecord, SessionRecord, UserRecord } from '../types/models';
import { newId, nowIso } from '../utils/id';
import { findRecordBy, insertRecord, listRecords, updateRecord, type ListResult } from './base.repository';

/** Users, roles, role assignments and sessions. */
export class UserRepository {
  constructor(private readonly db: D1Database) {}

  async findByEmail(email: string): Promise<UserRecord | null> {
    return findRecordBy<UserRecord>(this.db, 'users', 'email', email.toLowerCase());
  }

  async findById(id: string): Promise<UserRecord | null> {
    return findRecordBy<UserRecord>(this.db, 'users', 'id', id);
  }

  async list(options: {
    search?: string | null;
    limit: number;
    offset: number;
  }): Promise<ListResult<UserRecord>> {
    return listRecords<UserRecord>(this.db, 'users', {
      search: options.search ?? null,
      searchColumns: ['email', 'display_name'],
      sortColumn: 'created_at',
      sortDirection: 'DESC',
      limit: options.limit,
      offset: options.offset,
      // password_hash / password_salt are never selected for a list view.
      columns: [
        'id', 'email', 'display_name', 'avatar_media_id', 'phone', 'bio',
        'preservation_team_position', 'status', 'email_verified_at',
        'last_login_at', 'created_at', 'updated_at',
      ],
    });
  }

  async create(values: {
    email: string;
    display_name: string;
    password_hash: string | null;
    password_salt: string | null;
    status: string;
    preservation_team_position?: string | null;
  }): Promise<string> {
    const id = newId();
    const timestamp = nowIso();
    await insertRecord(this.db, 'users', {
      ...values,
      id,
      email: values.email.toLowerCase(),
      preservation_team_position: values.preservation_team_position ?? null,
      created_at: timestamp,
      updated_at: timestamp,
    });
    return id;
  }

  async update(id: string, values: Record<string, unknown>): Promise<number> {
    return updateRecord(this.db, 'users', id, values);
  }

  async recordLogin(id: string): Promise<void> {
    await updateRecord(this.db, 'users', id, { last_login_at: nowIso() });
  }

  // --- Roles ---------------------------------------------------------------

  async listRoles(): Promise<RoleRecord[]> {
    const result = await this.db
      .prepare('SELECT * FROM "roles" ORDER BY "name" ASC')
      .all<RoleRecord>();
    return result.results ?? [];
  }

  async findRoleBySlug(slug: string): Promise<RoleRecord | null> {
    return findRecordBy<RoleRecord>(this.db, 'roles', 'slug', slug);
  }

  /** Role slugs held by a user, resolved through the `user_roles` join table. */
  async rolesForUser(userId: string): Promise<RoleRecord[]> {
    const result = await this.db
      .prepare(
        `SELECT r.* FROM "roles" r
         INNER JOIN "user_roles" ur ON ur."role_id" = r."id"
         WHERE ur."user_id" = ?
         ORDER BY r."name" ASC`,
      )
      .bind(userId)
      .all<RoleRecord>();
    return result.results ?? [];
  }

  async assignRole(userId: string, roleId: string, assignedBy: string | null): Promise<void> {
    await this.db
      .prepare(
        `INSERT OR IGNORE INTO "user_roles" ("id", "user_id", "role_id", "assigned_by", "created_at")
         VALUES (?, ?, ?, ?, ?)`,
      )
      .bind(newId(), userId, roleId, assignedBy, nowIso())
      .run();
  }

  async revokeRole(userId: string, roleId: string): Promise<number> {
    const result = await this.db
      .prepare('DELETE FROM "user_roles" WHERE "user_id" = ? AND "role_id" = ?')
      .bind(userId, roleId)
      .run();
    return result.meta.changes ?? 0;
  }

  // --- Sessions ------------------------------------------------------------

  async createSession(values: {
    id: string;
    userId: string;
    refreshTokenHash: string;
    userAgent: string | null;
    ipHash: string | null;
    expiresAt: string;
  }): Promise<void> {
    await insertRecord(this.db, 'sessions', {
      id: values.id,
      user_id: values.userId,
      refresh_token_hash: values.refreshTokenHash,
      user_agent: values.userAgent,
      ip_hash: values.ipHash,
      expires_at: values.expiresAt,
      revoked_at: null,
      created_at: nowIso(),
    });
  }

  async findSession(id: string): Promise<SessionRecord | null> {
    return findRecordBy<SessionRecord>(this.db, 'sessions', 'id', id);
  }

  async revokeSession(id: string): Promise<void> {
    // Written directly rather than through `updateRecord`: the sessions table
    // is append-and-revoke only and carries no `updated_at` column.
    await this.db
      .prepare('UPDATE "sessions" SET "revoked_at" = ? WHERE "id" = ? AND "revoked_at" IS NULL')
      .bind(nowIso(), id)
      .run();
  }

  async revokeAllSessionsForUser(userId: string): Promise<void> {
    await this.db
      .prepare('UPDATE "sessions" SET "revoked_at" = ? WHERE "user_id" = ? AND "revoked_at" IS NULL')
      .bind(nowIso(), userId)
      .run();
  }

  /** Housekeeping: drop sessions that expired more than a day ago. */
  async purgeExpiredSessions(): Promise<void> {
    await this.db.prepare('DELETE FROM "sessions" WHERE "expires_at" < ?').bind(nowIso()).run();
  }
}
