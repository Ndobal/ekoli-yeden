import type { RequestContext } from '../types/api';
import { NotificationRepository } from '../repositories/notification.repository';
import { AuditRepository } from '../repositories/audit.repository';
import { can } from '../services/permissions';
import { readJsonBody, Validator } from '../utils/validation';
import { json, paginated, NO_STORE_HEADERS } from '../utils/responses';
import { parsePagination } from '../utils/pagination';
import { hashIp } from '../utils/crypto';
import { newId, nowIso } from '../utils/id';
import { ForbiddenError, NotFoundError, UnauthorizedError } from '../utils/errors';

/**
 * MESSAGES FROM THE PUBLIC.
 *
 * ---------------------------------------------------------------------------
 * WHY THIS IS NOT A MAILTO LINK
 * ---------------------------------------------------------------------------
 *
 * A contact page that offers an email address works for somebody with an email
 * client set up who remembers to say what they are writing about. Most people
 * reaching this archive are on a phone, arriving from a WhatsApp link, and a
 * `mailto:` is where their message stops.
 *
 * A message recorded here reaches every administrator instead of one inbox,
 * keeps its own state, and gives the sender a reference they can quote.
 *
 * ---------------------------------------------------------------------------
 * THE TWO TOPICS THAT ARE NOT LIKE THE OTHERS
 * ---------------------------------------------------------------------------
 *
 * `privacy` and `takedown` — "what do you hold about me", "take my photograph
 * down". Both carry obligations in law and both are marked urgent to the
 * administrators, ahead of a general greeting. Neither requires an account:
 * somebody asking for their own material to be removed must not first have to
 * create a record of themselves to do it.
 */

const TOPICS = [
  'general', 'correction', 'contribution', 'privacy', 'takedown',
  'membership', 'technical', 'press', 'complaint', 'other',
] as const;

const REPLY_CHANNELS = ['email', 'phone', 'whatsapp', 'none'] as const;

/** The topics an administrator should see before the others. */
const URGENT_TOPICS = new Set<string>(['privacy', 'takedown', 'complaint']);

/** `GET /api/contact/topics` — what the form offers, and what each one means. */
export async function contactTopics(_context: RequestContext): Promise<Response> {
  return json({
    topics: [
      { value: 'general', label: 'Just saying hello' },
      {
        value: 'correction',
        label: 'Something on the site is wrong',
        help: 'A date, a name, a claim about the community. Say which page.',
      },
      {
        value: 'contribution',
        label: 'I have something to add',
        help: 'Photographs, a story, a recording, a document.',
      },
      {
        value: 'membership',
        label: 'About my account or membership',
        help: 'Signing in, your profile, your privacy settings.',
      },
      {
        value: 'privacy',
        label: 'What do you hold about me?',
        help: 'We answer this, and we do not need you to have an account to ask.',
      },
      {
        value: 'takedown',
        label: 'Please remove something about me',
        help: 'A photograph, a name, anything about you or somebody in your care.',
      },
      { value: 'technical', label: 'Something is broken' },
      { value: 'press', label: 'Press or research enquiry' },
      { value: 'complaint', label: 'A complaint' },
      { value: 'other', label: 'Something else' },
    ],
    replyChannels: [
      { value: 'whatsapp', label: 'WhatsApp' },
      { value: 'phone', label: 'A phone call' },
      { value: 'email', label: 'Email' },
      { value: 'none', label: 'No reply needed' },
    ],
  });
}

/**
 * `POST /api/contact`
 *
 * Open to anybody, signed in or not, and rate limited in the route table.
 */
export async function submitContactMessage(context: RequestContext): Promise<Response> {
  const actor = context.user;
  const body = await readJsonBody(context.request);

  const validated = new Validator(body)
    .string('name', { required: true, min: 2, max: 200, label: 'Your name' })
    .string('message', { required: true, min: 10, max: 8000, label: 'Your message' })
    .string('subject', { max: 200, label: 'Subject' })
    .string('phone', { max: 40, label: 'Phone number' })
    .oneOf('topic', TOPICS)
    .oneOf('preferred_reply', REPLY_CHANNELS)
    .validated();

  if ('email' in body && body['email']) {
    Object.assign(validated, new Validator(body).email('email').validated());
  }

  const topic = (validated['topic'] as string | null) ?? 'general';
  const preferredReply = (validated['preferred_reply'] as string | null) ?? 'email';
  const email = (validated['email'] as string | null) ?? actor?.email ?? null;
  const phone = (validated['phone'] as string | null) ?? null;

  // Asked for rather than assumed. Somebody who wants an answer and has given
  // us no way to send one should be told now, not left waiting for a reply
  // that can never arrive.
  if (preferredReply !== 'none' && email === null && phone === null) {
    return json(
      {
        success: false,
        error: {
          message:
            'Please leave an email address or a phone number, or say that no reply is needed.',
          fields: { email: ['Give us one way to reach you.'] },
        },
      },
      { status: 400, headers: NO_STORE_HEADERS },
    );
  }

  const id = newId();
  const reference = referenceCode();
  const timestamp = nowIso();
  const secret = context.env.JWT_SECRET;

  await context.env.DB.prepare(
    `INSERT INTO "contact_messages"
       ("id", "reference_code", "name", "email", "phone", "preferred_reply", "topic",
        "subject", "message", "submitted_by", "status", "ip_hash", "created_at", "updated_at")
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'new', ?, ?, ?)`,
  )
    .bind(
      id,
      reference,
      validated['name'],
      email,
      phone,
      preferredReply,
      topic,
      validated['subject'] ?? null,
      validated['message'],
      actor?.id ?? null,
      secret ? await hashIp(context.request.headers.get('cf-connecting-ip'), secret) : null,
      timestamp,
      timestamp,
    )
    .run();

  await notifyAdministrators(context, {
    name: String(validated['name']),
    topic,
    subject: (validated['subject'] as string | null) ?? null,
    message: String(validated['message']),
    id,
  });

  await new AuditRepository(context.env.DB).record({
    actorId: actor?.id ?? null,
    actorEmail: actor?.email ?? email,
    action: 'contact.received',
    resourceType: 'contact_message',
    resourceId: id,
    changes: { topic, reference },
    requestId: context.requestId,
  });

  return json(
    {
      reference,
      message:
        preferredReply === 'none'
          ? 'Thank you. Your message has reached the Preservation Team.'
          : 'Thank you. Your message has reached the Preservation Team, and somebody will come '
            + 'back to you. Keep the reference below if you need to follow it up.',
    },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

/**
 * `GET /api/contact/:reference`
 *
 * What happened to a message, for somebody who has the reference.
 *
 * Deliberately thin: the status and nothing else. The reference is a shareable
 * string, and anybody holding it should not thereby be able to read what was
 * written or who wrote it.
 */
export async function contactMessageStatus(context: RequestContext): Promise<Response> {
  const row = await context.env.DB
    .prepare(
      `SELECT "status", "topic", "created_at", "answered_at"
       FROM "contact_messages" WHERE "reference_code" = ? LIMIT 1`,
    )
    .bind(context.params['reference'] ?? '')
    .first<Record<string, unknown>>();

  if (!row) throw new NotFoundError('We have no message with that reference.');

  const status = String(row['status']);

  return json(
    {
      status,
      created_at: row['created_at'],
      answered_at: row['answered_at'],
      explanation: explain(status),
    },
    { headers: NO_STORE_HEADERS },
  );
}

/** `GET /api/admin/contact` — the inbox. */
export async function listContactMessages(context: RequestContext): Promise<Response> {
  requireReader(context);

  const { page, perPage, offset } = parsePagination(context.query);
  const status = context.query.get('status') ?? 'new';

  const [countRow, rows] = await context.env.DB.batch<Record<string, unknown>>([
    context.env.DB
      .prepare('SELECT COUNT(*) AS total FROM "contact_messages" WHERE "status" = ?')
      .bind(status),
    context.env.DB
      .prepare(
        // Privacy requests, takedowns and complaints first. Everything else by
        // when it arrived — the one exception is the one the law cares about.
        `SELECT "id", "reference_code", "name", "email", "phone", "preferred_reply",
                "topic", "subject", "message", "status", "handling_notes",
                "answered_at", "created_at"
         FROM "contact_messages"
         WHERE "status" = ?
         ORDER BY
           CASE WHEN "topic" IN ('privacy', 'takedown', 'complaint') THEN 0 ELSE 1 END,
           "created_at" DESC
         LIMIT ? OFFSET ?`,
      )
      .bind(status, perPage, offset),
  ]);

  return paginated(
    rows?.results ?? [],
    page,
    perPage,
    Number((countRow?.results?.[0]?.['total'] as number | undefined) ?? 0),
    NO_STORE_HEADERS,
  );
}

/**
 * `POST /api/admin/contact/:id/status`
 *
 * Picking one up, answering it, closing it, or marking it spam.
 *
 * The note is for whoever reads the queue next — "answered by phone, she is
 * happy" is the difference between a queue that gets worked through and one
 * where the same message is answered three times.
 */
export async function updateContactMessage(context: RequestContext): Promise<Response> {
  const actor = requireReader(context);

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .oneOf('status', ['new', 'reading', 'answered', 'closed', 'spam'], { required: true })
    .string('handling_notes', { max: 2000, label: 'Notes' })
    .validated();

  const status = validated['status'] as string;
  const answered = status === 'answered' || status === 'closed';

  const result = await context.env.DB
    .prepare(
      `UPDATE "contact_messages"
       SET "status" = ?,
           "handling_notes" = COALESCE(?, "handling_notes"),
           "assigned_to" = ?,
           "answered_by" = CASE WHEN ? THEN ? ELSE "answered_by" END,
           "answered_at" = CASE WHEN ? THEN ? ELSE "answered_at" END,
           "updated_at" = ?
       WHERE "id" = ?`,
    )
    .bind(
      status,
      (validated['handling_notes'] as string | null) ?? null,
      actor.id,
      answered ? 1 : 0,
      actor.id,
      answered ? 1 : 0,
      nowIso(),
      nowIso(),
      context.params['id'] ?? '',
    )
    .run();

  if ((result.meta.changes ?? 0) === 0) {
    throw new NotFoundError('That message was not found.');
  }

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: `contact.${status}`,
    resourceType: 'contact_message',
    resourceId: context.params['id'] ?? null,
    changes: { status },
    requestId: context.requestId,
  });

  return json({ message: 'Saved.' }, { headers: NO_STORE_HEADERS });
}

// ---------------------------------------------------------------------------

function requireReader(context: RequestContext) {
  if (!context.user) throw new UnauthorizedError('Please sign in to continue.');
  if (!can(context.user, 'users:read') && !can(context.user, 'settings:manage')) {
    throw new ForbiddenError('You do not read the messages sent to the Preservation Team.');
  }
  return context.user;
}

/**
 * Tells the administrators, and says which ones cannot wait.
 *
 * Everybody who can act on a message gets it, rather than one nominated
 * person — an inbox with one reader is an inbox that goes quiet the week that
 * reader is travelling.
 */
async function notifyAdministrators(
  context: RequestContext,
  message: { name: string; topic: string; subject: string | null; message: string; id: string },
): Promise<void> {
  const result = await context.env.DB.prepare(
    `SELECT DISTINCT ur."user_id" FROM "user_roles" ur
     INNER JOIN "roles" r ON r."id" = ur."role_id"
     WHERE r."slug" IN ('super_admin', 'deputy_super_admin', 'content_admin')`,
  ).all<{ user_id: string }>();

  const administrators = (result.results ?? []).map((row) => row.user_id);
  if (administrators.length === 0) return;

  const urgent = URGENT_TOPICS.has(message.topic);

  await new NotificationRepository(context.env.DB).notifyMany(administrators, {
    kind: 'general',
    title: urgent
      ? `${message.name} has sent a ${message.topic} request`
      : `${message.name} has written to the Preservation Team`,
    body: (message.subject ?? message.message).slice(0, 160),
    linkPath: '/admin/messages',
    resourceType: 'contact_message',
    resourceId: message.id,
  });
}

function explain(status: string): string {
  switch (status) {
    case 'new':
      return 'Received. It is waiting to be read.';
    case 'reading':
      return 'Somebody is looking at it now.';
    case 'answered':
      return 'It has been answered. Check the way you asked us to reply.';
    case 'closed':
      return 'It has been dealt with and closed.';
    case 'spam':
      return 'This was set aside.';
    default:
      return 'Received.';
  }
}

/**
 * The reference a sender keeps.
 *
 * Readable over a phone line: no characters that sound alike, and short enough
 * to write on the back of a receipt.
 */
function referenceCode(): string {
  const alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  const bytes = new Uint8Array(6);
  crypto.getRandomValues(bytes);
  let code = '';
  for (const byte of bytes) code += alphabet[byte % alphabet.length];
  return `EY-${code}`;
}
