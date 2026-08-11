import type { AuditLogRecord } from '../types/models';
import { newId, nowIso } from '../utils/id';
import { insertRecord, listRecords, type ListResult } from './base.repository';

/**
 * The audit trail.
 *
 * Because this platform is meant to be an authoritative record for the
 * community, every change to content, every moderation decision and every role
 * change is written here. The log is append-only — there is deliberately no
 * update or delete method.
 */
export class AuditRepository {
  constructor(private readonly db: D1Database) {}

  async record(entry: {
    actorId: string | null;
    actorEmail: string | null;
    action: string;
    resourceType: string | null;
    resourceId: string | null;
    changes?: unknown;
    ipHash?: string | null;
    userAgent?: string | null;
    requestId?: string | null;
  }): Promise<void> {
    await insertRecord(this.db, 'audit_logs', {
      id: newId(),
      actor_id: entry.actorId,
      actor_email: entry.actorEmail,
      action: entry.action,
      resource_type: entry.resourceType,
      resource_id: entry.resourceId,
      changes: entry.changes === undefined ? null : JSON.stringify(entry.changes),
      ip_hash: entry.ipHash ?? null,
      user_agent: entry.userAgent ?? null,
      request_id: entry.requestId ?? null,
      created_at: nowIso(),
    });
  }

  async list(options: {
    actorId?: string | null;
    resourceType?: string | null;
    search?: string | null;
    limit: number;
    offset: number;
  }): Promise<ListResult<AuditLogRecord>> {
    const filters: Record<string, string | number | null> = {};
    if (options.actorId) filters['actor_id'] = options.actorId;
    if (options.resourceType) filters['resource_type'] = options.resourceType;

    return listRecords<AuditLogRecord>(this.db, 'audit_logs', {
      search: options.search ?? null,
      searchColumns: ['action', 'actor_email', 'resource_id'],
      filters,
      sortColumn: 'created_at',
      sortDirection: 'DESC',
      limit: options.limit,
      offset: options.offset,
    });
  }
}

/** Canonical action names, so the log stays greppable. */
export const AUDIT_ACTIONS = {
  LOGIN_SUCCEEDED: 'auth.login.succeeded',
  LOGIN_FAILED: 'auth.login.failed',
  LOGOUT: 'auth.logout',
  TOKEN_REFRESHED: 'auth.token.refreshed',
  CONTENT_CREATED: 'content.created',
  CONTENT_UPDATED: 'content.updated',
  CONTENT_DELETED: 'content.deleted',
  CONTENT_STATUS_CHANGED: 'content.status.changed',
  MEDIA_UPLOADED: 'media.uploaded',
  MEDIA_DELETED: 'media.deleted',
  SUBMISSION_RECEIVED: 'submission.received',
  SUBMISSION_REVIEWED: 'submission.reviewed',
  USER_CREATED: 'user.created',
  USER_UPDATED: 'user.updated',
  ROLE_ASSIGNED: 'user.role.assigned',
  ROLE_REVOKED: 'user.role.revoked',
  SETTING_UPDATED: 'settings.updated',
} as const;
