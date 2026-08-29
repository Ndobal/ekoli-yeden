import type { Handler, RequestContext } from '../types/api';
import { ForumRepository } from '../repositories/forum.repository';
import { NotificationRepository } from '../repositories/notification.repository';
import { AuditRepository } from '../repositories/audit.repository';
import { can } from '../services/permissions';
import { ForbiddenError, NotFoundError, UnauthorizedError, ValidationError } from '../utils/errors';
import { json, NO_STORE_HEADERS } from '../utils/responses';
import { readJsonBody, Validator } from '../utils/validation';
import { publicMediaUrl } from '../utils/files';

/**
 * BELONGING TO A FORUM.
 *
 * ---------------------------------------------------------------------------
 * WHY A REFUSAL IS KEPT
 * ---------------------------------------------------------------------------
 *
 * Rejecting somebody sets their row to `rejected` rather than deleting it. An
 * admin looking at a request needs to know whether this person has been turned
 * away before, and deleting the row would make every reapplication look like a
 * first one — which is precisely the situation somebody being deliberately
 * persistent relies on.
 *
 * It also means the person can be told why, in the admin's own words, instead
 * of being met with silence and left to ask again.
 */

function actorOf(context: RequestContext) {
  if (!context.user) throw new UnauthorizedError('Please sign in to continue.');
  return context.user;
}

/** Whoever may decide membership here: the space's own admin, or a Super Admin. */
async function assertSpaceAdmin(context: RequestContext, spaceId: string) {
  const actor = actorOf(context);
  if (can(actor, 'users:update')) return actor;

  const repo = new ForumRepository(context.env.DB);
  if (await repo.isSpaceAdmin(spaceId, actor.id)) return actor;

  throw new ForbiddenError('Only this forum’s administrators can decide that.');
}

async function resolveSpace(context: RequestContext, identifier: string) {
  const space = await new ForumRepository(context.env.DB).findSpace(identifier);
  if (!space || space.status !== 'published') {
    throw new NotFoundError('That forum was not found.');
  }
  return space;
}

// ---------------------------------------------------------------------------
// A member's own view
// ---------------------------------------------------------------------------

/**
 * `GET /api/forums/mine`
 *
 * Every forum, and where this person stands in each: a member, waiting, turned
 * away, or not asked yet. One request, because "which forums am I in" and
 * "which could I join" are the same question asked from either end.
 */
export const myForums: Handler = async (context: RequestContext) => {
  const actor = actorOf(context);
  const rows = await new ForumRepository(context.env.DB).membershipsForUser(actor.id);

  return json(
    {
      items: rows.map((row) => ({
        id: row['id'],
        slug: row['slug'],
        name: row['name'],
        tagline: row['tagline'],
        icon: row['icon'],
        accent: row['accent'],
        visibility: row['visibility'],
        join_policy: row['join_policy'],
        is_default: Number(row['is_default'] ?? 0) === 1,
        topic_count: Number(row['topic_count'] ?? 0),
        state: row['state'] ?? null,
        role: row['role'] ?? null,
        decision_note: row['decision_note'],
        // The General Forum cannot be left, which is what makes it the place
        // the whole community can be reached in.
        can_leave: Number(row['is_default'] ?? 0) !== 1 && row['state'] === 'member',
        can_request:
          row['state'] == null && String(row['join_policy'] ?? 'request') === 'request',
      })),
    },
    { headers: NO_STORE_HEADERS },
  );
};

/**
 * `POST /api/forums/:space/join`
 *
 * Asks to join. The admin decides; nothing is granted here.
 */
export const requestToJoin: Handler = async (context: RequestContext) => {
  const actor = actorOf(context);
  const space = await resolveSpace(context, context.params['space'] ?? '');
  const repo = new ForumRepository(context.env.DB);

  if (String(space.join_policy) === 'automatic') {
    throw new ValidationError(
      { space: ['Everybody is already a member of this forum.'] },
      'You are already a member of this forum.',
    );
  }
  if (String(space.join_policy) === 'closed') {
    throw new ForbiddenError(
      'This forum is not open to requests. Its administrators add people themselves.',
    );
  }

  const existing = await repo.membershipFor(space.id, actor.id);
  if (existing?.state === 'member') {
    return json({ state: 'member', message: 'You are already a member.' }, { headers: NO_STORE_HEADERS });
  }
  if (existing?.state === 'pending') {
    return json(
      { state: 'pending', message: 'Your request is already waiting on the administrators.' },
      { headers: NO_STORE_HEADERS },
    );
  }
  if (existing?.state === 'rejected') {
    // Not silently re-queued. Somebody who was turned away and simply asks
    // again puts the admin back where they started; being told the decision
    // stands, and who to talk to, is the honest answer.
    throw new ForbiddenError(
      existing.decision_note
        ? `Your earlier request was not accepted: ${existing.decision_note}`
        : 'Your earlier request to join this forum was not accepted. Speak to its administrators.',
    );
  }

  const body = await readJsonBody(context.request).catch(() => ({}) as Record<string, unknown>);
  const validated = new Validator(body)
    .string('note', { max: 500, label: 'Why you would like to join' })
    .validated();

  await repo.setMembership({
    spaceId: space.id,
    userId: actor.id,
    state: 'pending',
    requestNote: (validated['note'] as string | null) ?? null,
  });

  // Tell the people who have to act on it.
  const admins = await repo.membersOf(space.id, ['member']);
  const notifications = new NotificationRepository(context.env.DB);
  for (const admin of admins) {
    if (admin['role'] !== 'admin' && admin['role'] !== 'moderator') continue;
    await notifications.notify({
      userId: String(admin['user_id']),
      kind: 'forum.join_requested',
      title: `${actor.displayName} asked to join ${space.name}`,
      body: (validated['note'] as string | null) ?? null,
      linkPath: `/community/forums/${space.slug}/members`,
      resourceType: 'forum_space',
      resourceId: space.id,
    });
  }

  return json(
    {
      state: 'pending',
      message: `Your request to join ${space.name} has been sent to its administrators.`,
    },
    { status: 201, headers: NO_STORE_HEADERS },
  );
};

/**
 * `POST /api/forums/:space/leave`
 *
 * Leaves a forum. Not the General Forum: that one is what makes it possible to
 * reach the whole community at once, and a room everybody can leave is not
 * that room.
 */
export const leaveForum: Handler = async (context: RequestContext) => {
  const actor = actorOf(context);
  const space = await resolveSpace(context, context.params['space'] ?? '');

  if (Number(space.is_default) === 1) {
    throw new ForbiddenError(
      'The General Forum is where the whole community can be reached, so nobody leaves it. '
      + 'You can turn its notifications off instead.',
    );
  }

  const repo = new ForumRepository(context.env.DB);
  const existing = await repo.membershipFor(space.id, actor.id);
  if (!existing || existing.state !== 'member') {
    throw new ValidationError({ space: ['You are not a member of this forum.'] });
  }

  await repo.setMembership({
    spaceId: space.id,
    userId: actor.id,
    state: 'removed',
    decisionNote: 'Left by their own choice.',
    decidedBy: actor.id,
  });

  return json({ state: 'removed', message: `You have left ${space.name}.` }, { headers: NO_STORE_HEADERS });
};

// ---------------------------------------------------------------------------
// The forum's own administration
// ---------------------------------------------------------------------------

/** `GET /api/forums/:space/members` — the roster and the queue. */
export const listMembers: Handler = async (context: RequestContext) => {
  const space = await resolveSpace(context, context.params['space'] ?? '');
  await assertSpaceAdmin(context, space.id);

  const repo = new ForumRepository(context.env.DB);
  const [members, pending] = await Promise.all([
    repo.membersOf(space.id, ['member', 'suspended']),
    repo.pendingRequests(space.id),
  ]);

  const shape = (row: Record<string, unknown>) => ({
    id: row['id'],
    user_id: row['user_id'],
    name: row['full_name'] ?? row['display_name'],
    handle: row['handle'],
    state: row['state'],
    role: row['role'],
    suspended_until: row['suspended_until'],
    request_note: row['request_note'],
    requested_at: row['requested_at'],
    avatar_url: row['avatar_key']
      ? publicMediaUrl(context.env.PUBLIC_MEDIA_BASE_URL, String(row['avatar_key']))
      : null,
  });

  return json(
    {
      space: { id: space.id, slug: space.slug, name: space.name },
      members: members.map(shape),
      pending: pending.map(shape),
    },
    { headers: NO_STORE_HEADERS },
  );
};

/**
 * `POST /api/forums/:space/members/:userId/decide`
 *
 * Approve, reject, remove, suspend, restore, or change somebody's role — one
 * endpoint, because they are all the same act with a different outcome and
 * splitting them into six invites five of them to drift.
 */
export const decideMembership: Handler = async (context: RequestContext) => {
  const space = await resolveSpace(context, context.params['space'] ?? '');
  const actor = await assertSpaceAdmin(context, space.id);
  const userId = context.params['userId'] ?? '';

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .oneOf('action', ['approve', 'reject', 'remove', 'suspend', 'restore', 'set_role'])
    .string('note', { max: 500, label: 'Note' })
    .string('until', { max: 40, label: 'Suspended until' })
    .oneOf('role', ['member', 'moderator', 'admin'])
    .validated();

  const action = String(validated['action']);
  const note = (validated['note'] as string | null) ?? null;
  const repo = new ForumRepository(context.env.DB);

  const existing = await repo.membershipFor(space.id, userId);
  if (!existing && action !== 'approve') {
    throw new NotFoundError('That person has no standing in this forum.');
  }

  // Nobody is removed from the General Forum. It is the room the whole
  // community is reachable in; suspending somebody from posting is the
  // instrument for a problem there, not eviction.
  if (Number(space.is_default) === 1 && (action === 'remove' || action === 'reject')) {
    throw new ForbiddenError(
      'Nobody is removed from the General Forum. Suspend them from posting instead.',
    );
  }

  const outcome: Record<string, { state: string; message: string }> = {
    approve: { state: 'member', message: `You have been approved to join ${space.name}.` },
    reject: { state: 'rejected', message: `Your request to join ${space.name} was not accepted.` },
    remove: { state: 'removed', message: `You are no longer a member of ${space.name}.` },
    suspend: { state: 'suspended', message: `You have been suspended from ${space.name}.` },
    restore: { state: 'member', message: `Your membership of ${space.name} has been restored.` },
    set_role: { state: existing?.state ?? 'member', message: `Your role in ${space.name} changed.` },
  };

  await repo.setMembership({
    spaceId: space.id,
    userId,
    state: outcome[action]!.state,
    role: action === 'set_role' ? String(validated['role'] ?? 'member') : existing?.role,
    decisionNote: note,
    suspendedUntil: action === 'suspend' ? ((validated['until'] as string | null) ?? null) : null,
    decidedBy: actor.id,
  });

  // The person is told, whichever way it went. A decision nobody hears about
  // is a decision that gets asked about again.
  await new NotificationRepository(context.env.DB).notify({
    userId,
    kind: `forum.${action}`,
    title: outcome[action]!.message,
    body: note,
    linkPath: `/community/forums/${space.slug}`,
    resourceType: 'forum_space',
    resourceId: space.id,
  });

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: `forum.membership.${action}`,
    resourceType: 'forum_space',
    resourceId: space.id,
    changes: { userId, action, note },
    requestId: context.requestId,
  });

  return json(
    { state: outcome[action]!.state, message: outcome[action]!.message },
    { headers: NO_STORE_HEADERS },
  );
};
