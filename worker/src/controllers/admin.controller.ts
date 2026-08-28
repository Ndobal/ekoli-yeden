import type { RequestContext } from '../types/api';
import type { UserRecord } from '../types/models';
import { CONTENT_RESOURCES } from '../services/content-registry';
import { UserRepository } from '../repositories/user.repository';
import { SubmissionRepository } from '../repositories/submission.repository';
import { AuditRepository, AUDIT_ACTIONS } from '../repositories/audit.repository';
import { countByStatus } from '../repositories/base.repository';
import { AuthService } from '../services/auth.service';
import { PRESERVATION_TEAM, isPreservationPosition } from '../services/preservation-team.service';
import { ROLES } from '../types/auth';
import { hashPassword } from '../utils/crypto';
import { nowIso } from '../utils/id';
import { assertUsablePassword } from '../utils/password-quality';
import { BadRequestError, ForbiddenError, NotFoundError, UnauthorizedError } from '../utils/errors';
import { readJsonBody, Validator } from '../utils/validation';
import { json, paginated, NO_STORE_HEADERS } from '../utils/responses';
import { parsePagination } from '../utils/pagination';

/** Admin dashboard, user administration and the audit log. */

/**
 * `GET /api/admin/dashboard`
 *
 * Counts per content type and status, plus the pending moderation queue. These
 * are all zero until the Preservation Team begins adding material — which is
 * the correct state for a newly created archive.
 */
export async function dashboard(context: RequestContext): Promise<Response> {
  const db = context.env.DB;

  const contentCounts = await Promise.all(
    Object.values(CONTENT_RESOURCES).map(async (resource) => ({
      resource: resource.key,
      label: resource.label,
      byStatus: await countByStatus(db, resource.table),
    })),
  );

  const [pendingSubmissions, mediaCounts, users] = await Promise.all([
    new SubmissionRepository(db).countPending(),
    countByStatus(db, 'media_assets'),
    db.prepare('SELECT COUNT(*) AS total FROM "users"').first<{ total: number }>(),
  ]);

  const totalPublished = contentCounts.reduce(
    (sum, entry) => sum + (entry.byStatus['published'] ?? 0),
    0,
  );
  const totalPendingReview = contentCounts.reduce(
    (sum, entry) => sum + (entry.byStatus['pending_review'] ?? 0),
    0,
  );

  return json(
    {
      environment: context.env.ENVIRONMENT,
      summary: {
        publishedRecords: totalPublished,
        awaitingReview: totalPendingReview + pendingSubmissions,
        pendingSubmissions,
        registeredUsers: Number(users?.total ?? 0),
      },
      content: contentCounts,
      media: mediaCounts,
    },
    { headers: NO_STORE_HEADERS },
  );
}

/** `GET /api/admin/users` */
export async function listUsers(context: RequestContext): Promise<Response> {
  const { page, perPage, offset } = parsePagination(context.query);
  const repository = new UserRepository(context.env.DB);

  const { items, total } = await repository.list({
    search: context.query.get('q'),
    limit: perPage,
    offset,
  });

  const withRoles = await Promise.all(
    items.map(async (user) => ({
      ...user,
      roles: (await repository.rolesForUser(user.id)).map((role) => role.slug),
    })),
  );

  return paginated(withRoles, page, perPage, total, NO_STORE_HEADERS);
}

/** `POST /api/admin/users` — creating an account for a team member. */
export async function createUser(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const body = await readJsonBody(context.request);

  const validated = new Validator(body)
    .email('email', { required: true })
    .string('display_name', { required: true, min: 2, max: 120, label: 'Name' })
    .string('password', { required: true, min: 6, max: 200, label: 'Password' })
    .stringArray('roles', { maxItems: 10 })
    .validated();

  assertUsablePassword(validated['password'] as string, {
    email: validated['email'] as string,
    displayName: validated['display_name'] as string,
  });

  const position = typeof body['preservation_team_position'] === 'string'
    ? body['preservation_team_position']
    : null;
  if (position !== null && !isPreservationPosition(position)) {
    throw new BadRequestError('That is not a recognised Preservation Team position.');
  }

  const repository = new UserRepository(context.env.DB);
  const email = validated['email'] as string;
  if (await repository.findByEmail(email)) {
    throw new BadRequestError('An account already exists with that email address.');
  }

  const { hash, salt } = await hashPassword(validated['password'] as string);
  const userId = await repository.create({
    email,
    display_name: validated['display_name'] as string,
    password_hash: hash,
    password_salt: salt,
    status: 'active',
    preservation_team_position: position,
  });

  const requestedRoles: string[] = JSON.parse((validated['roles'] as string | undefined) ?? '[]');
  const assigned: string[] = [];
  for (const slug of requestedRoles) {
    const role = await repository.findRoleBySlug(slug);
    if (!role) continue;
    await repository.assignRole(userId, role.id, actor.id);
    assigned.push(slug);
  }

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: AUDIT_ACTIONS.USER_CREATED,
    resourceType: 'user',
    resourceId: userId,
    changes: { email, roles: assigned, preservationTeamPosition: position },
    requestId: context.requestId,
  });

  return json({ id: userId, email, roles: assigned }, { status: 201, headers: NO_STORE_HEADERS });
}

/** `PATCH /api/admin/users/:id` */
export async function updateUser(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const id = context.params['id'] ?? '';
  const body = await readJsonBody(context.request);

  const repository = new UserRepository(context.env.DB);
  const existing = await repository.findById(id);
  if (!existing) throw new NotFoundError('That user was not found.');

  const validated = new Validator(body)
    .string('display_name', { min: 2, max: 120, label: 'Name' })
    .string('phone', { max: 40, label: 'Phone number' })
    .string('bio', { max: 2000, label: 'Biography' })
    .oneOf('status', ['active', 'suspended', 'invited'])
    .validated();

  if ('preservation_team_position' in body) {
    const position = body['preservation_team_position'];
    if (position !== null && (typeof position !== 'string' || !isPreservationPosition(position))) {
      throw new BadRequestError('That is not a recognised Preservation Team position.');
    }
    validated['preservation_team_position'] = position;
  }

  // Suspending an account must end its sessions immediately, not at token expiry.
  if (validated['status'] === 'suspended') {
    await repository.revokeAllSessionsForUser(id);
  }

  await repository.update(id, validated);

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: AUDIT_ACTIONS.USER_UPDATED,
    resourceType: 'user',
    resourceId: id,
    changes: { fields: Object.keys(validated) },
    requestId: context.requestId,
  });

  const updated = await repository.findById(id);
  return json(serializeUserRecord(updated), { headers: NO_STORE_HEADERS });
}

/**
 * `POST /api/admin/users/:id/roles`
 *
 * Granting a role. One role is guarded beyond its permission: Super Admin.
 */
export async function assignRole(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const id = context.params['id'] ?? '';
  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('role', { required: true, max: 60, label: 'Role' })
    .validated();

  const repository = new UserRepository(context.env.DB);
  const role = await repository.findRoleBySlug(validated['role'] as string);
  if (!role) throw new NotFoundError('That role does not exist.');
  if (!(await repository.findById(id))) throw new NotFoundError('That user was not found.');

  // Only a Super Admin may create another Super Admin.
  //
  // A Deputy Administrator holds every other administrative permission,
  // including `users.assign_roles` — so without this check they could simply
  // promote themselves and erase the distinction. The guard is on the identity
  // of the caller, not on a permission, precisely so that no configuration of
  // the Deputy role can grant it.
  assertMayGovernSuperAdmin(actor, role.slug, 'appoint');

  await repository.assignRole(id, role.id, actor.id);

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: AUDIT_ACTIONS.ROLE_ASSIGNED,
    resourceType: 'user',
    resourceId: id,
    changes: { role: role.slug },
    requestId: context.requestId,
  });

  return json({ userId: id, role: role.slug, assigned: true }, { headers: NO_STORE_HEADERS });
}

/** `DELETE /api/admin/users/:id/roles/:role` */
export async function revokeRole(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const id = context.params['id'] ?? '';
  const slug = context.params['role'] ?? '';

  const repository = new UserRepository(context.env.DB);
  const role = await repository.findRoleBySlug(slug);
  if (!role) throw new NotFoundError('That role does not exist.');

  // Only a Super Admin may remove a Super Admin — the counterpart of the
  // appointment guard, and the reason a Deputy cannot quietly take the archive.
  assertMayGovernSuperAdmin(actor, role.slug, 'remove');

  // Removing the last Super Admin would lock the community out of its own
  // archive, so the platform refuses.
  if (role.slug === 'super_admin') {
    const remaining = await context.env.DB.prepare(
      'SELECT COUNT(*) AS total FROM "user_roles" WHERE "role_id" = ?',
    )
      .bind(role.id)
      .first<{ total: number }>();
    if (Number(remaining?.total ?? 0) <= 1) {
      throw new BadRequestError('The last Super Admin cannot be removed.');
    }
  }

  const changed = await repository.revokeRole(id, role.id);
  if (changed === 0) throw new NotFoundError('That user does not hold that role.');

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: AUDIT_ACTIONS.ROLE_REVOKED,
    resourceType: 'user',
    resourceId: id,
    changes: { role: role.slug },
    requestId: context.requestId,
  });

  return json({ userId: id, role: role.slug, revoked: true }, { headers: NO_STORE_HEADERS });
}

/** `GET /api/admin/roles` — the roles and what each may do. */
export async function listRoles(context: RequestContext): Promise<Response> {
  const repository = new UserRepository(context.env.DB);
  const roles = await repository.listRoles();

  return json(
    {
      roles: roles.map((role) => ({
        id: role.id,
        slug: role.slug,
        name: role.name,
        description: role.description,
        permissions: safeParsePermissions(role.permissions),
        isSystem: role.is_system === 1,
      })),
      preservationTeam: PRESERVATION_TEAM,
    },
    { headers: NO_STORE_HEADERS },
  );
}

/** `POST /api/admin/users/:id/password` — an administrator resetting a password. */
export async function resetPassword(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const id = context.params['id'] ?? '';
  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('password', { required: true, min: 6, max: 200, label: 'Password' })
    .validated();

  const repository = new UserRepository(context.env.DB);
  const target = await repository.findById(id);
  if (!target) throw new NotFoundError('That user was not found.');

  assertUsablePassword(validated['password'] as string, {
    email: target.email,
    displayName: target.display_name,
  });

  const { hash, salt } = await hashPassword(validated['password'] as string);
  await repository.update(id, { password_hash: hash, password_salt: salt });
  // A password change invalidates every existing session for that account.
  await repository.revokeAllSessionsForUser(id);

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: AUDIT_ACTIONS.USER_UPDATED,
    resourceType: 'user',
    resourceId: id,
    changes: { passwordReset: true },
    requestId: context.requestId,
  });

  return json({ id, passwordReset: true }, { headers: NO_STORE_HEADERS });
}

/**
 * `POST /api/admin/users/:id/close`
 *
 * Closing somebody's account.
 *
 * ---------------------------------------------------------------------------
 * WHY THIS IS NOT A DELETE
 * ---------------------------------------------------------------------------
 *
 * Deleting the row would take with it, or orphan, things that are not the
 * account's to remove: the audit entries recording what was done and by whom,
 * the attribution on every photograph and story they contributed, the
 * authorship of history the community now relies on. An archive whose record of
 * who supplied what can be erased by an administrator pressing a button is not
 * an archive.
 *
 * So closing does everything a removal is actually wanted for, and keeps the
 * record:
 *
 *   - the account can no longer sign in;
 *   - every session it holds ends immediately;
 *   - the profile leaves the directory and stops being findable in messages;
 *   - the membership is marked as left.
 *
 * If somebody wants their personal data erased rather than their account
 * closed, that is a privacy request under the policy — it is handled by a
 * person, in the contact inbox, because it needs judgement about what belongs
 * to them and what belongs to the community's history.
 */
export async function closeUserAccount(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const id = context.params['id'] ?? '';

  const repository = new UserRepository(context.env.DB);
  const target = await repository.findById(id);
  if (!target) throw new NotFoundError('That user was not found.');

  // Nobody closes their own account from the administration screen. It would
  // sign them out mid-action and leave the community one administrator short
  // by accident.
  if (target.id === actor.id) {
    throw new BadRequestError(
      'You cannot close your own account here. Ask another administrator.',
    );
  }

  // A Super Admin's account is not closable by a Deputy, for the same reason a
  // Deputy cannot appoint one: the distinction has to hold in both directions.
  const theirRoles = await repository.rolesForUser(target.id);
  assertMayGovernSuperAdmin(
    actor,
    theirRoles.some((role) => role.slug === 'super_admin') ? 'super_admin' : 'other',
    'remove',
  );

  const body = await readJsonBody(context.request).catch(() => ({}) as Record<string, unknown>);
  const reason = new Validator(body).string('reason', { max: 1000 }).validated()['reason'] as
    | string
    | null;

  await repository.update(id, { status: 'suspended' });
  await repository.revokeAllSessionsForUser(id);

  // Out of the directory and out of the messaging search. Somebody whose
  // account is closed should not keep appearing to members as findable.
  await context.env.DB
    .prepare(
      `UPDATE "member_profiles"
       SET "membership_status" = 'left', "listed_in_directory" = 0,
           "findable_for_messages" = 0, "messages_from" = 'nobody', "updated_at" = ?
       WHERE "user_id" = ?`,
    )
    .bind(nowIso(), id)
    .run();

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: 'user.closed',
    resourceType: 'user',
    resourceId: id,
    changes: { email: target.email, reason: reason ?? null, sessionsRevoked: true },
    requestId: context.requestId,
  });

  return json(
    {
      id,
      message:
        'The account is closed. They can no longer sign in, and they are out of the directory '
        + 'and the messaging search. What they contributed to the archive is unchanged, and '
        + 'their attribution stands.',
    },
    { headers: NO_STORE_HEADERS },
  );
}

/** `POST /api/admin/account/password` — a signed-in user changing their own. */
export async function changeOwnPassword(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('currentPassword', { required: true, min: 1, max: 200, label: 'Current password' })
    .string('newPassword', { required: true, min: 6, max: 200, label: 'New password' })
    .validated();

  const auth = new AuthService(context.env);
  // Verifying the current password throws `UnauthorizedError` on a mismatch,
  // which is exactly the behaviour we want here.
  await auth.authenticate(actor.email, validated['currentPassword'] as string);

  assertUsablePassword(validated['newPassword'] as string, {
    email: actor.email,
    displayName: actor.displayName,
  });

  const repository = new UserRepository(context.env.DB);
  const { hash, salt } = await hashPassword(validated['newPassword'] as string);
  await repository.update(actor.id, { password_hash: hash, password_salt: salt });
  await repository.revokeAllSessionsForUser(actor.id);

  return json(
    { changed: true, message: 'Your password has been changed. Please sign in again.' },
    { headers: NO_STORE_HEADERS },
  );
}

/** `GET /api/admin/audit-logs` */
export async function auditLogs(context: RequestContext): Promise<Response> {
  const { page, perPage, offset } = parsePagination(context.query);
  const repository = new AuditRepository(context.env.DB);

  const { items, total } = await repository.list({
    actorId: context.query.get('actor_id'),
    resourceType: context.query.get('resource_type'),
    search: context.query.get('q'),
    limit: perPage,
    offset,
  });

  return paginated(items, page, perPage, total, NO_STORE_HEADERS);
}

function requireActor(context: RequestContext) {
  if (!context.user) throw new UnauthorizedError('Please sign in to continue.');
  return context.user;
}

/**
 * Guards the Super Admin role itself.
 *
 * The Deputy Administrator exists so the community can have a second person
 * with full operational authority without handing out the one power that can
 * take the archive away: making and unmaking Super Admins.
 *
 * The check is on who the caller *is*, not on what permission they hold. That
 * is deliberate — a Deputy holds `users.assign_roles`, so a permission-based
 * check would let them promote themselves and dissolve the distinction. No
 * arrangement of the Deputy's permission array can get past this.
 */
function assertMayGovernSuperAdmin(
  actor: { roles: string[] },
  targetRole: string,
  action: 'appoint' | 'remove',
): void {
  if (targetRole !== ROLES.SUPER_ADMIN) return;
  if (actor.roles.includes(ROLES.SUPER_ADMIN)) return;

  throw new ForbiddenError(
    action === 'appoint'
      ? 'Only a Super Admin can appoint another Super Admin.'
      : 'Only a Super Admin can remove a Super Admin.',
  );
}

function safeParsePermissions(value: string): string[] {
  try {
    const parsed: unknown = JSON.parse(value);
    return Array.isArray(parsed) ? parsed.filter((item): item is string => typeof item === 'string') : [];
  } catch {
    return [];
  }
}

/** Strips the credential columns before a user record leaves the API. */
function serializeUserRecord(record: UserRecord | null): Record<string, unknown> | null {
  if (!record) return null;
  const { password_hash: _hash, password_salt: _salt, ...safe } = record;
  return safe;
}
