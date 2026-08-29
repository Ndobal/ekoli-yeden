import type { RequestContext } from '../types/api';
import { ForumService } from '../services/forum.service';
import { NotificationRepository } from '../repositories/notification.repository';
import { AuditRepository } from '../repositories/audit.repository';
import { readJsonBody, Validator } from '../utils/validation';
import { json, paginated, NO_STORE_HEADERS } from '../utils/responses';
import { parsePagination } from '../utils/pagination';
import { BadRequestError, ForbiddenError, NotFoundError, UnauthorizedError } from '../utils/errors';
import { hashIp } from '../utils/crypto';
import { slugify } from '../utils/slug';
import { nowIso } from '../utils/id';

/**
 * THE YAKOLI FORUMS (Module 5)
 *
 * The community's own conversation, in three spaces. Every access decision goes
 * through `ForumService.access`, so the rules cannot drift between the list
 * view and the handler that writes a post.
 *
 * The reasoning behind those rules — particularly around the youth and student
 * spaces — is at the top of `forum.service.ts` and is worth reading before
 * changing anything here.
 */

const REPORT_REASONS = [
  'abuse', 'harassment', 'spam', 'misinformation', 'inappropriate',
  'off_topic', 'personal_information', 'child_safety', 'other',
] as const;

const REACTION_KINDS = ['appreciate', 'agree', 'helpful', 'celebrate'] as const;

// ---------------------------------------------------------------------------
// Reading
// ---------------------------------------------------------------------------

/**
 * `GET /api/forums`
 *
 * The spaces, and whether the caller may enter each.
 *
 * A space the caller cannot read is still listed, with `can_read: false` and
 * the reason — otherwise somebody who has an account but no membership sees
 * two spaces and has no idea a third exists or how to reach it.
 */
export async function listSpaces(context: RequestContext): Promise<Response> {
  const service = new ForumService(context.env);
  const spaces = await service.repo.spaces();

  const items = await Promise.all(
    spaces.map(async (space) => {
      const access = await service.access(space.id, context.user);
      return {
        id: space.id,
        slug: space.slug,
        name: space.name,
        tagline: space.tagline,
        description: space.description,
        kind: space.kind,
        icon: space.icon,
        accent: space.accent,
        topic_count: space.topic_count,
        is_youth_space: space.is_youth_space === 1,
        visibility: space.visibility,
        can_read: access.canRead,
        can_post: access.canPost,
        blocked_reason: access.blockedReason,
        // What the interface needs to draw the right control: Join, Asked,
        // Approved, or nothing at all.
        membership_state: access.membershipState,
        join_policy: access.joinPolicy,
        can_request_to_join: access.canRequestToJoin,
      };
    }),
  );

  return json({ items, total: items.length }, { headers: NO_STORE_HEADERS });
}

/** `GET /api/forums/:space` — one space with its categories and recent topics. */
export async function showSpace(context: RequestContext): Promise<Response> {
  const service = new ForumService(context.env);
  const access = await service.access(context.params['space'] ?? '', context.user);
  service.assertCanRead(access);

  const { page, perPage, offset } = parsePagination(context.query);
  const category = context.query.get('category');

  const categoryRow = category
    ? await service.repo.findCategory(access.space.id, category)
    : null;

  const { items, total } = await service.repo.topics({
    spaceId: access.space.id,
    categoryId: categoryRow ? String(categoryRow['id']) : null,
    statuses: service.visibleStatuses(access),
    search: context.query.get('q'),
    limit: perPage,
    offset,
  });

  return json(
    {
      space: {
        id: access.space.id,
        slug: access.space.slug,
        name: access.space.name,
        tagline: access.space.tagline,
        description: access.space.description,
        is_youth_space: access.space.is_youth_space === 1,
        // Never indexed where the flag says so. Passed to the client so the
        // page can set `noindex` as well — belt and braces on the one thing
        // this module most needs to get right.
        is_indexable: access.space.is_indexable === 1,
      },
      categories: await service.repo.categories(access.space.id),
      topics: items.map((topic) => shapeTopic(topic as unknown as Record<string, unknown>)),
      total,
      page,
      perPage,
      totalPages: Math.max(1, Math.ceil(total / perPage)),
      viewer: {
        can_post: access.canPost,
        is_moderator: access.isModerator,
        blocked_reason: access.blockedReason,
        // What the interface needs to draw the right control: Join, Asked,
        // Approved, or nothing at all.
        membership_state: access.membershipState,
        join_policy: access.joinPolicy,
        can_request_to_join: access.canRequestToJoin,
      },
    },
    { headers: NO_STORE_HEADERS },
  );
}

/** `GET /api/forums/:space/topics/:topic` */
export async function showTopic(context: RequestContext): Promise<Response> {
  const service = new ForumService(context.env);
  const access = await service.access(context.params['space'] ?? '', context.user);
  service.assertCanRead(access);

  const topic = await service.repo.findTopic(access.space.id, context.params['topic'] ?? '');
  if (!topic) throw new NotFoundError('That conversation was not found.');

  const statuses = service.visibleStatuses(access);
  if (!statuses.includes(topic.status)) {
    throw new NotFoundError('That conversation was not found.');
  }

  const posts = await service.repo.posts(topic.id, statuses);

  const reacted = context.user
    ? await service.repo.reactedTargets(
        context.user.id,
        [topic.id, ...posts.map((post) => String(post['id']))],
      )
    : new Set<string>();

  return json(
    {
      ...shapeTopic(topic as unknown as Record<string, unknown>),
      body: topic.body,
      author: service.shapeAuthor(access.space, topic as unknown as Record<string, unknown>),
      you_reacted: reacted.has(topic.id),
      is_following: context.user
        ? await service.repo.isFollowing(topic.id, context.user.id)
        : false,
      posts: posts.map((post) => ({
        id: post['id'],
        body: post['body'],
        parent_post_id: post['parent_post_id'],
        author: service.shapeAuthor(access.space, post),
        reaction_count: post['reaction_count'],
        you_reacted: reacted.has(String(post['id'])),
        is_answer: post['is_answer'] === 1,
        status: post['status'],
        edited_at: post['edited_at'],
        created_at: post['created_at'],
        is_mine: context.user !== null && post['author_id'] === context.user.id,
      })),
      viewer: {
        can_post: access.canPost,
        is_moderator: access.isModerator,
        blocked_reason: access.blockedReason,
        // What the interface needs to draw the right control: Join, Asked,
        // Approved, or nothing at all.
        membership_state: access.membershipState,
        join_policy: access.joinPolicy,
        can_request_to_join: access.canRequestToJoin,
        is_mine: context.user !== null && topic.author_id === context.user.id,
      },
    },
    { headers: NO_STORE_HEADERS },
  );
}

// ---------------------------------------------------------------------------
// Writing
// ---------------------------------------------------------------------------

/** `POST /api/forums/:space/topics` */
export async function createTopic(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const service = new ForumService(context.env);
  const access = await service.access(context.params['space'] ?? '', actor);
  service.assertCanPost(access);

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('title', { required: true, min: 4, max: 200, label: 'Title' })
    .string('body', { required: true, min: 2, max: 20000, label: 'Message' })
    .string('category_id', { required: true, max: 64, label: 'Category' })
    .validated();

  const category = await service.repo.findCategory(
    access.space.id,
    validated['category_id'] as string,
  );
  if (!category) throw new BadRequestError('Choose a category for this conversation.');

  // Announcement categories are readable by everybody and writable by few.
  if (category['post_permission'] === 'moderators' && !access.isModerator) {
    throw new ForbiddenError('Only moderators can start a conversation in this category.');
  }

  const title = validated['title'] as string;
  const status = access.space.requires_approval === 1 && !access.isModerator
    ? 'pending_review'
    : 'published';

  const id = await service.repo.createTopic({
    spaceId: access.space.id,
    categoryId: String(category['id']),
    slug: await uniqueTopicSlug(service, access.space.id, title),
    title,
    body: validated['body'] as string,
    authorId: actor.id,
    authorName: actor.displayName,
    status,
  });

  const topic = await service.repo.findTopicById(id);

  return json(
    {
      id,
      slug: topic?.slug,
      status,
      message: status === 'pending_review'
        ? 'Posted. A moderator looks at new conversations in this space before they appear.'
        : 'Posted.',
    },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

/** `POST /api/forums/:space/topics/:topic/replies` */
export async function reply(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const service = new ForumService(context.env);
  const access = await service.access(context.params['space'] ?? '', actor);
  service.assertCanPost(access);

  const topic = await service.repo.findTopic(access.space.id, context.params['topic'] ?? '');
  if (!topic) throw new NotFoundError('That conversation was not found.');

  if (topic.is_locked === 1 && !access.isModerator) {
    throw new ForbiddenError('This conversation has been closed to new replies.');
  }
  if (topic.status !== 'published' && !access.isModerator) {
    throw new NotFoundError('That conversation was not found.');
  }

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('body', { required: true, min: 2, max: 20000, label: 'Reply' })
    .string('parent_post_id', { max: 64 })
    .validated();

  const id = await service.repo.createPost({
    topicId: topic.id,
    parentPostId: (validated['parent_post_id'] as string | null) ?? null,
    body: validated['body'] as string,
    authorId: actor.id,
    authorName: actor.displayName,
    status: 'published',
  });

  // Everybody following the conversation is told, and so is its author — but
  // each person once, and never themselves.
  const followers = new Set(await service.repo.followerIds(topic.id, actor.id));
  if (topic.author_id && topic.author_id !== actor.id) followers.add(topic.author_id);

  if (followers.size > 0) {
    await new NotificationRepository(context.env.DB).notifyMany([...followers], {
      kind: 'general',
      title: `${actor.displayName} replied to "${topic.title}"`,
      body: (validated['body'] as string).slice(0, 140),
      linkPath: `/community/forums/${access.space.slug}/${topic.slug}`,
      resourceType: 'forum_topic',
      resourceId: topic.id,
    });
  }

  return json({ id, message: 'Posted.' }, { status: 201, headers: NO_STORE_HEADERS });
}

/**
 * `PATCH /api/forums/posts/:id`
 *
 * Editing your own reply. The edit is stamped rather than silent — a
 * conversation where posts change under the people who replied to them is a
 * conversation nobody can follow.
 */
export async function editPost(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const service = new ForumService(context.env);

  const post = await service.repo.findPost(context.params['id'] ?? '');
  if (!post) throw new NotFoundError('That reply was not found.');

  const topic = await service.repo.findTopicById(String(post['topic_id']));
  if (!topic) throw new NotFoundError('That reply was not found.');

  const access = await service.access(topic.space_id, actor);
  if (post['author_id'] !== actor.id && !access.isModerator) {
    throw new ForbiddenError('You can only edit your own replies.');
  }

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('body', { required: true, min: 2, max: 20000, label: 'Reply' })
    .validated();

  await service.repo.updatePost(String(post['id']), {
    body: validated['body'],
    edited_at: nowIso(),
  });

  return json({ message: 'Saved.' }, { headers: NO_STORE_HEADERS });
}

// ---------------------------------------------------------------------------
// Reacting and following
// ---------------------------------------------------------------------------

/** `POST /api/forums/:targetType/:id/react` */
export async function react(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const targetType = context.params['targetType'] === 'topic' ? 'topic' : 'post';

  const body = await readJsonBody(context.request).catch(() => ({}) as Record<string, unknown>);
  const kind = new Validator(body).oneOf('kind', REACTION_KINDS).validated()['kind'] as
    | string
    | null;

  const service = new ForumService(context.env);
  const standing = await service.repo.toggleReaction({
    targetType,
    targetId: context.params['id'] ?? '',
    userId: actor.id,
    kind: kind ?? 'appreciate',
  });

  return json({ reacted: standing }, { headers: NO_STORE_HEADERS });
}

/** `POST /api/forums/topics/:id/follow` */
export async function follow(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const service = new ForumService(context.env);
  const following = await service.repo.toggleFollow(context.params['id'] ?? '', actor.id);
  return json({ following }, { headers: NO_STORE_HEADERS });
}

// ---------------------------------------------------------------------------
// Reporting
// ---------------------------------------------------------------------------

/**
 * `POST /api/forums/:targetType/:id/report`
 *
 * One press, and the reporter never has to explain themselves at length. A
 * report queue only works if reporting is easy — somebody being harassed
 * should not have to write an essay about it first.
 */
export async function report(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const targetType = context.params['targetType'] === 'topic' ? 'topic' : 'post';

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .oneOf('reason', REPORT_REASONS, { required: true })
    .string('detail', { max: 2000, label: 'Detail' })
    .validated();

  const service = new ForumService(context.env);
  const targetId = context.params['id'] ?? '';

  const secret = context.env.JWT_SECRET;
  const ipHash = secret
    ? await hashIp(context.request.headers.get('cf-connecting-ip'), secret)
    : null;

  await service.repo.report({
    targetType,
    targetId,
    reporterId: actor.id,
    reason: validated['reason'] as string,
    detail: (validated['detail'] as string | null) ?? null,
    ipHash,
  });

  const reason = validated['reason'] as string;
  const count = await service.repo.openReportCount(targetType, targetId);

  // A child-safety report hides the content at once and does not wait for a
  // count. Everything else waits for a moderator, because hiding on a single
  // report would hand any one person a veto over anybody else's speech.
  const urgent = reason === 'child_safety';
  if (urgent) {
    if (targetType === 'topic') {
      await service.repo.updateTopic(targetId, { status: 'hidden' });
    } else {
      await service.repo.updatePost(targetId, { status: 'hidden' });
    }
  }

  await notifyModerators(
    context,
    urgent ? 'A child-safety report has been made' : 'Something has been reported',
    urgent
      ? 'The content has been hidden automatically and needs looking at now.'
      : `${count} open report${count === 1 ? '' : 's'} on this.`,
    targetId,
  );

  return json(
    {
      message: urgent
        ? 'Thank you. It has been hidden immediately and the moderators have been told.'
        : 'Thank you. The moderators have been told and will look at it.',
    },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

// ---------------------------------------------------------------------------
// Moderation
// ---------------------------------------------------------------------------

/** `GET /api/forums/admin/reports` */
export async function listReports(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const service = new ForumService(context.env);
  await assertModerator(service, actor);

  const { page, perPage, offset } = parsePagination(context.query);
  const { items, total } = await service.repo.reports(
    context.query.get('status') ?? 'open',
    perPage,
    offset,
  );

  // Shaped rather than passed through. The row carries `ip_hash`, which exists
  // so repeat reports from one place can be recognised — not so that every
  // moderator screen ships it to a browser.
  const shaped = items.map((row) => ({
    id: row['id'],
    target_type: row['target_type'],
    target_id: row['target_id'],
    reason: row['reason'],
    detail: row['detail'],
    status: row['status'],
    review_notes: row['review_notes'],
    reviewed_at: row['reviewed_at'],
    created_at: row['created_at'],
    // What was reported, so the queue can be read rather than looked up.
    target_title: row['target_title'],
    target_body: row['target_body'],
    target_status: row['target_status'],
    target_author_name: row['target_author_name'],
    target_author_id: row['target_author_id'],
    target_space_slug: row['target_space_slug'],
    target_topic_slug: row['target_topic_slug'],
  }));

  return paginated(shaped, page, perPage, total, NO_STORE_HEADERS);
}

/**
 * `POST /api/forums/admin/moderate`
 *
 * Hide, remove, restore, lock, pin. Every one writes an append-only record of
 * who did it and why — "who removed my post, and why?" has to have an answer
 * somebody else can check.
 */
export async function moderate(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const service = new ForumService(context.env);
  await assertModerator(service, actor);

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .oneOf('action', ['hide', 'remove', 'restore', 'lock', 'unlock', 'pin', 'unpin', 'approve'], {
      required: true,
    })
    .oneOf('target_type', ['topic', 'post'], { required: true })
    .string('target_id', { required: true, max: 64 })
    .string('reason', { max: 1000, label: 'Reason' })
    .validated();

  const action = validated['action'] as string;
  const targetType = validated['target_type'] as string;
  const targetId = validated['target_id'] as string;

  const change: Record<string, unknown> = {};
  switch (action) {
    case 'hide':
      change['status'] = 'hidden';
      break;
    case 'remove':
      change['status'] = 'removed';
      // Removed clears the text; hidden does not. Both keep the row, because a
      // moderation decision that leaves no trace is one nobody can review.
      change['body'] = '[This was removed by a moderator.]';
      break;
    case 'restore':
    case 'approve':
      change['status'] = 'published';
      break;
    case 'lock':
      change['is_locked'] = 1;
      break;
    case 'unlock':
      change['is_locked'] = 0;
      break;
    case 'pin':
      change['is_pinned'] = 1;
      break;
    case 'unpin':
      change['is_pinned'] = 0;
      break;
  }

  const changed = targetType === 'topic'
    ? await service.repo.updateTopic(targetId, change)
    : await service.repo.updatePost(targetId, change);

  if (changed === 0) throw new NotFoundError('That was not found, or nothing changed.');

  await service.repo.recordAction({
    moderatorId: actor.id,
    moderatorName: actor.displayName,
    action,
    targetType,
    targetId,
    reason: (validated['reason'] as string | null) ?? null,
    spaceId: null,
  });

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: `forum.${action}`,
    resourceType: `forum_${targetType}`,
    resourceId: targetId,
    changes: { reason: validated['reason'] ?? null },
    requestId: context.requestId,
  });

  return json({ message: 'Done.' }, { headers: NO_STORE_HEADERS });
}

/** `POST /api/forums/admin/reports/:id/settle` */
export async function settleReport(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const service = new ForumService(context.env);
  await assertModerator(service, actor);

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .oneOf('status', ['actioned', 'dismissed', 'reviewing'], { required: true })
    .string('notes', { max: 1000 })
    .validated();

  const changed = await service.repo.settleReport(context.params['id'] ?? '', {
    status: validated['status'] as string,
    reviewedBy: actor.id,
    notes: (validated['notes'] as string | null) ?? null,
  });
  if (changed === 0) throw new NotFoundError('That report was not found.');

  return json({ message: 'Settled.' }, { headers: NO_STORE_HEADERS });
}

/**
 * `POST /api/forums/admin/sanctions`
 *
 * A warning, a suspension or a ban.
 *
 * A warning does not silence anybody — it is a record that somebody was spoken
 * to. Only a suspension or a ban stops them posting, and the person is always
 * told which they have received and when it ends.
 */
export async function sanction(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const service = new ForumService(context.env);
  await assertModerator(service, actor);

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('user_id', { required: true, max: 64 })
    .oneOf('kind', ['warning', 'suspension', 'ban'], { required: true })
    .string('reason', { max: 2000, label: 'Reason' })
    .string('space_id', { max: 64 })
    .integer('days', { min: 1, max: 365, label: 'Days' })
    .validated();

  const kind = validated['kind'] as string;
  const days = validated['days'] as number | null;

  const expiresAt = kind === 'suspension' && days
    ? new Date(Date.now() + days * 86400000).toISOString()
    : null;

  const id = await service.repo.sanction({
    userId: validated['user_id'] as string,
    kind,
    spaceId: (validated['space_id'] as string | null) ?? null,
    reason: (validated['reason'] as string | null) ?? null,
    issuedBy: actor.id,
    expiresAt,
  });

  // Always told, and told what it means. Somebody who finds they cannot post
  // and does not know why will assume the worst and leave.
  await new NotificationRepository(context.env.DB).notify({
    userId: validated['user_id'] as string,
    kind: 'membership',
    title: kind === 'warning'
      ? 'A moderator has left you a warning'
      : kind === 'suspension'
        ? 'Your posting has been suspended'
        : 'You can no longer post in the forums',
    body: (validated['reason'] as string | null) ??
        'Contact the moderators if you would like to discuss this.',
    linkPath: '/community/forums',
    resourceType: 'forum_sanction',
    resourceId: id,
  });

  await service.repo.recordAction({
    moderatorId: actor.id,
    moderatorName: actor.displayName,
    action: kind === 'warning' ? 'warn' : kind === 'suspension' ? 'suspend' : 'ban',
    targetType: 'member',
    targetId: validated['user_id'] as string,
    reason: (validated['reason'] as string | null) ?? null,
    spaceId: (validated['space_id'] as string | null) ?? null,
  });

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: `forum.sanction.${kind}`,
    resourceType: 'user',
    resourceId: validated['user_id'] as string,
    changes: { kind, expiresAt, reason: validated['reason'] ?? null },
    requestId: context.requestId,
  });

  return json({ id, message: 'Recorded, and the member has been told.' }, {
    status: 201,
    headers: NO_STORE_HEADERS,
  });
}

/** `GET /api/forums/admin/actions` — the moderation log, for anybody who moderates. */
export async function moderationLog(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const service = new ForumService(context.env);
  await assertModerator(service, actor);

  const items = await service.repo.actions(200);
  return json({ items, total: items.length }, { headers: NO_STORE_HEADERS });
}

// ---------------------------------------------------------------------------

function requireUser(context: RequestContext) {
  if (!context.user) throw new UnauthorizedError('Please sign in to continue.');
  return context.user;
}

/** Moderator of any space, or the Preservation Team. */
async function assertModerator(
  service: ForumService,
  actor: { id: string; permissions: Set<string> },
): Promise<void> {
  if (actor.permissions.has('*') || actor.permissions.has('forums:moderate')) return;
  if (await service.repo.isModerator(actor.id, null)) return;
  throw new ForbiddenError('You do not moderate the forums.');
}

function shapeTopic(topic: Record<string, unknown>): Record<string, unknown> {
  return {
    id: topic['id'],
    slug: topic['slug'],
    title: topic['title'],
    // A preview rather than the whole body. A list of forty topics should not
    // ship forty full posts to a phone.
    excerpt: String(topic['body'] ?? '').slice(0, 220),
    author_name: topic['author_name'],
    category_name: topic['category_name'] ?? null,
    category_slug: topic['category_slug'] ?? null,
    is_pinned: topic['is_pinned'] === 1,
    is_locked: topic['is_locked'] === 1,
    reply_count: topic['reply_count'],
    reaction_count: topic['reaction_count'],
    last_reply_at: topic['last_reply_at'],
    status: topic['status'],
    created_at: topic['created_at'],
  };
}

async function uniqueTopicSlug(
  service: ForumService,
  spaceId: string,
  title: string,
): Promise<string> {
  const root = slugify(title).slice(0, 80) || 'conversation';
  if (!(await service.repo.topicSlugExists(spaceId, root))) return root;

  for (let suffix = 2; suffix < 60; suffix += 1) {
    const candidate = `${root}-${suffix}`;
    if (!(await service.repo.topicSlugExists(spaceId, candidate))) return candidate;
  }
  return `${root}-${Date.now()}`;
}

async function notifyModerators(
  context: RequestContext,
  title: string,
  body: string,
  resourceId: string,
): Promise<void> {
  const result = await context.env.DB.prepare(
    `SELECT DISTINCT ur."user_id" FROM "user_roles" ur
     INNER JOIN "roles" r ON r."id" = ur."role_id"
     WHERE r."slug" IN ('super_admin', 'deputy_super_admin', 'community_moderator', 'moderator')
     UNION
     SELECT DISTINCT "user_id" FROM "forum_moderators"`,
  ).all<{ user_id: string }>();

  const moderators = (result.results ?? []).map((row) => row.user_id);
  if (moderators.length === 0) return;

  await new NotificationRepository(context.env.DB).notifyMany(moderators, {
    kind: 'membership',
    title,
    body,
    linkPath: '/community/forums/moderation',
    resourceType: 'forum_report',
    resourceId,
  });
}
