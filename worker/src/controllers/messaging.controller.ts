import type { RequestContext } from '../types/api';
import { MessagingRepository } from '../repositories/messaging.repository';
import { MemberRepository } from '../repositories/member.repository';
import { NotificationRepository } from '../repositories/notification.repository';
import { AuditRepository } from '../repositories/audit.repository';
import { readJsonBody, Validator } from '../utils/validation';
import { json, paginated, NO_STORE_HEADERS } from '../utils/responses';
import { parsePagination } from '../utils/pagination';
import { publicMediaUrl } from '../utils/files';
import {
  BadRequestError,
  ForbiddenError,
  NotFoundError,
  UnauthorizedError,
} from '../utils/errors';

/**
 * MESSAGES BETWEEN MEMBERS.
 *
 * ---------------------------------------------------------------------------
 * THE ONE THING THIS MODULE EXISTS TO MAKE TRUE
 * ---------------------------------------------------------------------------
 *
 * You can reach somebody without being given their number.
 *
 * Every screen, every response shape and every check below follows from that.
 * A member is findable by name, can be written to, and can reply — and at no
 * point in any of it does either person's phone number or email address leave
 * the database. A search result carries a name, a handle and a headline. A
 * conversation carries names and messages. Nothing here carries a way to
 * contact somebody off the platform.
 *
 * If somebody wants the number, they ask for it, and the other person decides:
 * `requestContact` below, and the `contact_grants` row it produces, which
 * `visibleProfile` reads on every profile it shapes.
 *
 * ---------------------------------------------------------------------------
 * WHAT AUTHORISES A READ
 * ---------------------------------------------------------------------------
 *
 * Membership of the conversation, checked against
 * `conversation_participants` on every single call. Not the conversation id
 * being unguessable, and not the client having shown the thread already.
 */

/** `GET /api/messages` — my conversations, newest activity first. */
export async function listConversations(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const repository = new MessagingRepository(context.env.DB);
  const { page, perPage, offset } = parsePagination(context.query);

  const { items, total } = await repository.conversationsFor(actor.id, perPage, offset);

  return paginated(
    items.map((row) => shapeConversation(context, row)),
    page,
    perPage,
    total,
    NO_STORE_HEADERS,
  );
}

/** `GET /api/messages/unread` — the number for the badge, and nothing else. */
export async function unreadCount(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const repository = new MessagingRepository(context.env.DB);
  return json({ unread: await repository.unreadTotal(actor.id) }, { headers: NO_STORE_HEADERS });
}

/**
 * `GET /api/messages/people?q=`
 *
 * Members you could write to, by name.
 *
 * Deliberately thin. A name, a handle, a headline, where they are from — and
 * nothing that would let the searcher contact them anywhere else. The search
 * itself is the introduction; the message is how you reach them.
 */
export async function searchPeople(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const query = (context.query.get('q') ?? '').trim();

  if (query.length < 2) {
    return json({ items: [], total: 0 }, { headers: NO_STORE_HEADERS });
  }

  const repository = new MessagingRepository(context.env.DB);
  const rows = await repository.searchPeople(query, actor.id, 20);

  const items = rows.map((row) => ({
    user_id: row['user_id'],
    handle: row['handle'],
    name: row['full_name'] ?? 'A member',
    headline: row['headline'] ?? null,
    from: row['place_text'] ?? row['community_area'] ?? null,
    avatar_url: avatarUrl(context, row['avatar_key']),
    // Said in the result rather than discovered on send: somebody who has
    // closed their messages should show as unreachable before you write four
    // paragraphs to them.
    accepts_messages: row['messages_from'] !== 'nobody',
  }));

  return json({ items, total: items.length }, { headers: NO_STORE_HEADERS });
}

/**
 * `POST /api/messages/conversations`
 *
 * Opens the conversation with somebody, or finds the one that already exists.
 *
 * Idempotent by design — pressing "message" twice must not produce two threads,
 * and two people writing to each other at the same moment must not each end up
 * in their own copy. See `pairKey`.
 */
export async function openConversation(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const body = await readJsonBody(context.request);

  const validated = new Validator(body)
    .string('handle', { max: 120, label: 'Member' })
    .string('user_id', { max: 64 })
    .validated();

  const members = new MemberRepository(context.env.DB);
  const repository = new MessagingRepository(context.env.DB);

  const otherId = await resolveMember(members, validated);
  if (otherId === actor.id) {
    throw new BadRequestError('You cannot start a conversation with yourself.');
  }

  await assertCanWriteTo(context, members, actor.id, otherId);

  const { id } = await repository.findOrCreateDirect(actor.id, otherId);
  const rows = await repository.conversationsFor(actor.id, 50, 0);
  const shaped = rows.items.find((row) => row['id'] === id);

  return json(
    shaped ? shapeConversation(context, shaped) : { id },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

/** `GET /api/messages/:id` — one conversation and its messages. */
export async function showConversation(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const repository = new MessagingRepository(context.env.DB);
  const conversationId = context.params['id'] ?? '';

  const participant = await repository.participant(conversationId, actor.id);
  if (!participant) throw new NotFoundError('That conversation was not found.');

  const { page, perPage, offset } = parsePagination(context.query);
  const { items, total } = await repository.messages(conversationId, perPage, offset);

  // The other person, for the header. Read through the member repository so a
  // closed account still renders as a name rather than as an empty card.
  const others = await repository.otherParticipants(conversationId, actor.id);
  const otherProfile = others[0]
    ? await new MemberRepository(context.env.DB).findByUserId(others[0])
    : null;

  await repository.markRead(conversationId, actor.id);

  return json(
    {
      id: conversationId,
      with: otherProfile
        ? {
            user_id: otherProfile['user_id'],
            handle: otherProfile['handle'],
            name: otherProfile['full_name'] ?? 'A member',
            headline: otherProfile['headline'] ?? null,
            // No phone, no email. Whether this reader may see those is a
            // question about a profile, answered by the profile route.
          }
        : null,
      is_muted: participant['is_muted'] === 1,
      is_blocked: participant['is_blocked'] === 1,
      // Oldest last, which is the order a conversation is read in.
      messages: items
        .slice()
        .reverse()
        .map((row) => shapeMessage(context, row, actor.id)),
      total,
      page,
      perPage,
      totalPages: Math.max(1, Math.ceil(total / perPage)),
    },
    { headers: NO_STORE_HEADERS },
  );
}

/** `POST /api/messages/:id` — say something. */
export async function sendMessage(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const repository = new MessagingRepository(context.env.DB);
  const conversationId = context.params['id'] ?? '';

  const participant = await repository.participant(conversationId, actor.id);
  if (!participant) throw new NotFoundError('That conversation was not found.');

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('body', { required: true, min: 1, max: 8000, label: 'Message' })
    .string('media_id', { max: 64 })
    .validated();

  // Checked on every send, not only when the thread is opened. Somebody may
  // block a conversation while the other person is typing into it.
  const others = await repository.otherParticipants(conversationId, actor.id);
  for (const otherId of others) {
    const theirs = await repository.participant(conversationId, otherId);
    if (theirs?.['is_blocked'] === 1) {
      throw new ForbiddenError('This person is no longer receiving messages in this conversation.');
    }
  }

  const id = await repository.createMessage({
    conversationId,
    senderId: actor.id,
    senderName: actor.displayName,
    body: validated['body'] as string,
    mediaId: (validated['media_id'] as string | null) ?? null,
  });

  // Told once, and only where they have not muted the thread. A notification
  // per message would make the bell useless within a day.
  const notifications = new NotificationRepository(context.env.DB);
  for (const otherId of others) {
    const theirs = await repository.participant(conversationId, otherId);
    if (theirs?.['is_muted'] === 1) continue;

    await notifications.notify({
      userId: otherId,
      kind: 'general',
      title: `${actor.displayName} sent you a message`,
      body: (validated['body'] as string).slice(0, 140),
      linkPath: `/messages/${conversationId}`,
      resourceType: 'conversation',
      resourceId: conversationId,
    });
  }

  return json({ id, message: 'Sent.' }, { status: 201, headers: NO_STORE_HEADERS });
}

/** `POST /api/messages/:id/read` — I have seen this. */
export async function markConversationRead(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const repository = new MessagingRepository(context.env.DB);
  const conversationId = context.params['id'] ?? '';

  const participant = await repository.participant(conversationId, actor.id);
  if (!participant) throw new NotFoundError('That conversation was not found.');

  await repository.markRead(conversationId, actor.id);
  return json({ unread: await repository.unreadTotal(actor.id) }, { headers: NO_STORE_HEADERS });
}

/**
 * `PATCH /api/messages/:id`
 *
 * Archive, mute or block — each on the caller's own side only. One person
 * putting a thread away does not remove the other person's record of it.
 */
export async function updateConversation(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const repository = new MessagingRepository(context.env.DB);
  const conversationId = context.params['id'] ?? '';

  const participant = await repository.participant(conversationId, actor.id);
  if (!participant) throw new NotFoundError('That conversation was not found.');

  const body = await readJsonBody(context.request);
  const validator = new Validator(body);
  for (const flag of ['is_archived', 'is_muted', 'is_blocked']) {
    if (flag in body) validator.boolean(flag);
  }

  const changed = await repository.updateParticipant(
    conversationId,
    actor.id,
    validator.validated(),
  );
  if (changed === 0) throw new BadRequestError('Nothing was changed.');

  return json({ message: 'Saved.' }, { headers: NO_STORE_HEADERS });
}

// ---------------------------------------------------------------------------
// Asking for somebody's contact details
// ---------------------------------------------------------------------------

/**
 * `POST /api/messages/contact-requests`
 *
 * "May I have your number?"
 *
 * The reason travels with the request and is shown to the person deciding,
 * because "I am your cousin in Calabar and there is a funeral" and "hi" are
 * different asks and only one of them should be granted on the spot.
 *
 * Being declined is final until the subject changes their mind. There is no
 * asking again, which is what makes "no" mean something.
 */
export async function requestContact(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const body = await readJsonBody(context.request);

  const validated = new Validator(body)
    .string('handle', { max: 120, label: 'Member' })
    .string('user_id', { max: 64 })
    .string('reason', { max: 1000, label: 'Why you are asking' })
    .boolean('wants_phone')
    .boolean('wants_email')
    .validated();

  const members = new MemberRepository(context.env.DB);
  const repository = new MessagingRepository(context.env.DB);

  const subjectId = await resolveMember(members, validated);
  if (subjectId === actor.id) {
    throw new BadRequestError('You already have your own details.');
  }

  const existing = await repository.findRequest(actor.id, subjectId);
  if (existing?.['state'] === 'declined') {
    throw new ForbiddenError(
      'You have already asked this person and they said no. Please respect that.',
    );
  }
  if (existing?.['state'] === 'approved') {
    throw new BadRequestError('They have already shared their details with you.');
  }

  const wantsPhone = validated['wants_phone'] !== 0 && validated['wants_phone'] !== false;
  const wantsEmail = validated['wants_email'] === 1 || validated['wants_email'] === true;

  const id = await repository.upsertRequest({
    requesterId: actor.id,
    subjectId,
    wantsPhone,
    wantsEmail,
    reason: (validated['reason'] as string | null) ?? null,
  });

  await new NotificationRepository(context.env.DB).notify({
    userId: subjectId,
    kind: 'membership',
    title: `${actor.displayName} has asked for your ${describeAsk(wantsPhone, wantsEmail)}`,
    body:
      (validated['reason'] as string | null) ??
      'They have not said why. You decide, and you can change your mind later.',
    linkPath: '/account/requests',
    resourceType: 'contact_request',
    resourceId: id,
  });

  return json(
    {
      id,
      message:
        'Asked. They decide — nothing of theirs is shared with you unless they say yes.',
    },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

/** `GET /api/messages/contact-requests` — waiting on me, and what I have asked. */
export async function listContactRequests(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const repository = new MessagingRepository(context.env.DB);

  const { incoming, outgoing } = await repository.requestsFor(actor.id);
  const granted = await repository.grantsBy(actor.id);

  return json(
    {
      incoming: incoming.map(shapeRequest),
      outgoing: outgoing.map(shapeRequest),
      // Everybody currently holding my details, so taking them back is one
      // press and does not require remembering who was ever given them.
      granted: granted.map((row) => ({
        viewer_id: row['viewer_id'],
        handle: row['handle'],
        name: row['full_name'] ?? 'A member',
        can_see_phone: row['can_see_phone'] === 1,
        can_see_email: row['can_see_email'] === 1,
        granted_at: row['granted_at'],
      })),
    },
    { headers: NO_STORE_HEADERS },
  );
}

/** `POST /api/messages/contact-requests/:id/decide` — yes, or no. */
export async function decideContactRequest(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const repository = new MessagingRepository(context.env.DB);

  const request = await repository.findRequestById(context.params['id'] ?? '');
  if (!request) throw new NotFoundError('That request was not found.');

  // Only the person being asked may answer. Not the requester, and not an
  // administrator: this is consent, and it is not delegable.
  if (request['subject_id'] !== actor.id) {
    throw new ForbiddenError('That request is not yours to answer.');
  }
  if (request['state'] !== 'pending') {
    throw new BadRequestError('That request has already been answered.');
  }

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .oneOf('decision', ['approve', 'decline'], { required: true })
    .string('note', { max: 500 })
    .boolean('share_phone')
    .boolean('share_email')
    .validated();

  const approved = validated['decision'] === 'approve';
  const requesterId = String(request['requester_id']);

  if (approved) {
    // What they asked for, narrowed by what the subject actually agreed to.
    // Somebody may hand over a phone number and keep their email.
    const askedPhone = request['wants_phone'] === 1;
    const askedEmail = request['wants_email'] === 1;
    const sharePhone =
      'share_phone' in body
        ? validated['share_phone'] === 1 || validated['share_phone'] === true
        : askedPhone;
    const shareEmail =
      'share_email' in body
        ? validated['share_email'] === 1 || validated['share_email'] === true
        : askedEmail;

    await repository.grant({
      viewerId: requesterId,
      subjectId: actor.id,
      phone: sharePhone && askedPhone,
      email: shareEmail && askedEmail,
      requestId: String(request['id']),
    });
  }

  await repository.setRequestState(
    String(request['id']),
    approved ? 'approved' : 'declined',
    (validated['note'] as string | null) ?? null,
  );

  await new NotificationRepository(context.env.DB).notify({
    userId: requesterId,
    kind: 'membership',
    title: approved
      ? `${actor.displayName} has shared their details with you`
      : `${actor.displayName} would rather not share their details`,
    body: approved
      ? 'You can see them on their profile now.'
      : 'You can still write to them here. Please do not ask again.',
    linkPath: '/messages',
    resourceType: 'contact_request',
    resourceId: String(request['id']),
  });

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: approved ? 'contact.granted' : 'contact.declined',
    resourceType: 'contact_request',
    resourceId: String(request['id']),
    changes: { requester: requesterId },
    requestId: context.requestId,
  });

  return json(
    {
      message: approved
        ? 'Shared. You can take this back at any time from Account → Privacy.'
        : 'Declined. They have been told, and they cannot ask again.',
    },
    { headers: NO_STORE_HEADERS },
  );
}

/**
 * `DELETE /api/messages/contact-grants/:viewerId`
 *
 * Taking it back.
 *
 * Effective on the next request, because the grant is read on every profile
 * shaping rather than cached anywhere. Changing your mind must not depend on
 * some other system noticing.
 */
export async function revokeContactGrant(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const repository = new MessagingRepository(context.env.DB);
  const viewerId = context.params['viewerId'] ?? '';

  await repository.revokeGrant(viewerId, actor.id);

  const existing = await repository.findRequest(viewerId, actor.id);
  if (existing) {
    await repository.setRequestState(String(existing['id']), 'revoked', null);
  }

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: 'contact.revoked',
    resourceType: 'user',
    resourceId: viewerId,
    changes: {},
    requestId: context.requestId,
  });

  return json(
    { message: 'Taken back. They can no longer see your details.' },
    { headers: NO_STORE_HEADERS },
  );
}

// ---------------------------------------------------------------------------

function requireActor(context: RequestContext) {
  if (!context.user) throw new UnauthorizedError('Please sign in to continue.');
  return context.user;
}

/** Resolves whichever way the caller named the other member. */
async function resolveMember(
  members: MemberRepository,
  validated: Record<string, unknown>,
): Promise<string> {
  const userId = validated['user_id'] as string | null;
  if (userId) return userId;

  const handle = validated['handle'] as string | null;
  if (!handle) throw new BadRequestError('Say who you mean.');

  const profile = await members.findByHandle(handle);
  if (!profile) throw new NotFoundError('That member was not found.');
  return String(profile['user_id']);
}

/**
 * Whether this person may be written to at all.
 *
 * Checked when a conversation is opened rather than on every message, because
 * it is a statement about strangers reaching them — once a conversation is
 * running, closing it is what blocking is for.
 */
async function assertCanWriteTo(
  context: RequestContext,
  members: MemberRepository,
  actorId: string,
  otherId: string,
): Promise<void> {
  const profile = await members.findByUserId(otherId);
  if (!profile) throw new NotFoundError('That member was not found.');

  if (profile['membership_status'] !== 'active') {
    throw new ForbiddenError('That member is not receiving messages.');
  }
  if (profile['messages_from'] === 'nobody') {
    throw new ForbiddenError(
      'This member has turned off messages. You could ask somebody who knows them.',
    );
  }

  // The sender has to be a member too. Reading the archive is open to
  // everybody; writing to a named person is not.
  const mine = await members.findByUserId(actorId);
  if (!mine || mine['membership_status'] !== 'active') {
    throw new ForbiddenError('Complete your membership to write to other members.');
  }

  void context;
}

function shapeConversation(
  context: RequestContext,
  row: Record<string, unknown>,
): Record<string, unknown> {
  return {
    id: row['id'],
    kind: row['kind'],
    // A direct conversation is named by whoever you are talking to, which is
    // why the title is computed per reader rather than stored.
    title: row['title'] ?? row['other_name'] ?? row['other_display_name'] ?? 'A member',
    other: {
      user_id: row['other_user_id'],
      handle: row['other_handle'],
      name: row['other_name'] ?? row['other_display_name'] ?? 'A member',
      headline: row['other_headline'] ?? null,
      avatar_url: avatarUrl(context, row['other_avatar_key']),
    },
    last_message_text: row['last_message_text'],
    last_message_at: row['last_message_at'],
    last_message_is_mine: row['last_message_by'] === context.user?.id,
    unread_count: Number(row['unread_count'] ?? 0),
    is_muted: row['is_muted'] === 1,
    is_blocked: row['is_blocked'] === 1,
  };
}

function shapeMessage(
  context: RequestContext,
  row: Record<string, unknown>,
  actorId: string,
): Record<string, unknown> {
  const removed = row['status'] !== 'sent';

  return {
    id: row['id'],
    body: removed ? '' : row['body'],
    status: row['status'],
    sender_id: row['sender_id'],
    sender_name: row['sender_name'] ?? 'A member',
    is_mine: row['sender_id'] === actorId,
    media_url: avatarUrl(context, row['media_key']),
    media_name: row['media_name'] ?? null,
    media_type: row['media_type'] ?? null,
    edited_at: row['edited_at'],
    created_at: row['created_at'],
  };
}

function shapeRequest(row: Record<string, unknown>): Record<string, unknown> {
  return {
    id: row['id'],
    requester_id: row['requester_id'],
    subject_id: row['subject_id'],
    handle: row['other_handle'],
    name: row['other_name'] ?? 'A member',
    headline: row['other_headline'] ?? null,
    wants_phone: row['wants_phone'] === 1,
    wants_email: row['wants_email'] === 1,
    reason: row['reason'],
    state: row['state'],
    created_at: row['created_at'],
  };
}

function avatarUrl(context: RequestContext, key: unknown): string | null {
  return typeof key === 'string' && key.length > 0
    ? publicMediaUrl(context.env.PUBLIC_MEDIA_BASE_URL, key)
    : null;
}

function describeAsk(phone: boolean, email: boolean): string {
  if (phone && email) return 'phone number and email address';
  if (email) return 'email address';
  return 'phone number';
}
