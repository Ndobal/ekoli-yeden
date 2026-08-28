import type { RequestContext } from '../types/api';
import { NotificationRepository } from '../repositories/notification.repository';
import { AuditRepository } from '../repositories/audit.repository';
import { can } from '../services/permissions';
import { readJsonBody, Validator } from '../utils/validation';
import { json, paginated, NO_STORE_HEADERS } from '../utils/responses';
import { parsePagination } from '../utils/pagination';
import { BadRequestError, ForbiddenError, NotFoundError, UnauthorizedError } from '../utils/errors';
import { newId, nowIso } from '../utils/id';
import { slugify } from '../utils/slug';

/**
 * NEWS ANYBODY MAY WRITE, ONLY ADMINISTRATORS MAY PUBLISH
 *
 * Publishing to News stays with the Content Administrators, and should. It is
 * the community's official channel: what appears there is taken as the
 * community speaking, and an open channel would make that meaningless.
 *
 * But "only administrators may publish" had quietly become "only administrators
 * may know". A member who hears that the borehole is finished, or that a
 * scholarship deadline has moved, had nowhere to put it except the generic
 * contribution form — where it arrived as an untitled file and sat in a media
 * queue.
 *
 * Writing and publishing are different permissions. This is the gap between
 * them.
 */

const NEWS_CATEGORIES = [
  'announcement', 'development', 'community', 'festival', 'education',
  'health', 'obituary', 'achievement', 'other',
] as const;

/** `GET /api/contribute/news/form` */
export async function newsFormOptions(_context: RequestContext): Promise<Response> {
  return json({
    categories: [
      { value: 'announcement', label: 'An announcement' },
      { value: 'development', label: 'Development or a project' },
      { value: 'community', label: 'Community life' },
      { value: 'festival', label: 'Festival' },
      { value: 'education', label: 'Education' },
      { value: 'health', label: 'Health' },
      { value: 'obituary', label: 'A passing' },
      { value: 'achievement', label: 'Somebody has achieved something' },
      { value: 'other', label: 'Something else' },
    ],
    guidance: [
      'News is published by the administrators — that is what makes this the community\'s '
        + 'official channel rather than a noticeboard. Anybody may write it, and they read '
        + 'everything that arrives.',
      'Say how you know. News from somebody who was there is a different thing from news read in '
        + 'a WhatsApp group, and it helps the administrators decide what to do with it.',
    ],
  });
}

/** `POST /api/contribute/news` */
export async function submitNews(context: RequestContext): Promise<Response> {
  const actor = context.user;
  const body = await readJsonBody(context.request);

  const validated = new Validator(body)
    .string('title', { required: true, min: 4, max: 200, label: 'Headline' })
    .string('body', { required: true, min: 20, max: 20000, label: 'The story' })
    .string('excerpt', { max: 500, label: 'Summary' })
    .oneOf('category', NEWS_CATEGORIES)
    .string('location', { max: 200, label: 'Where' })
    .string('source_note', { max: 1000, label: 'How you know' })
    .string('contributor_name', { max: 200, label: 'Your name' })
    .email('contributor_email')
    .string('contributor_phone', { max: 40, label: 'Your phone number' })
    .string('cover_upload_id', { max: 64 })
    .validated();

  if ('happened_on' in body && body['happened_on']) {
    Object.assign(
      validated,
      new Validator(body).date('happened_on', { label: 'When it happened' }).validated(),
    );
  }

  const id = newId();
  const reference = referenceCode();
  const timestamp = nowIso();

  await context.env.DB.prepare(
    `INSERT INTO "news_submissions"
       ("id", "reference_code", "title", "excerpt", "body", "category",
        "happened_on", "location", "cover_upload_id",
        "contributor_name", "contributor_email", "contributor_phone", "source_note",
        "submitted_by", "status", "created_at", "updated_at")
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending_review', ?, ?)`,
  )
    .bind(
      id,
      reference,
      validated['title'],
      validated['excerpt'] ?? null,
      validated['body'],
      validated['category'] ?? null,
      validated['happened_on'] ?? null,
      validated['location'] ?? null,
      validated['cover_upload_id'] ?? null,
      validated['contributor_name'] ?? actor?.displayName ?? null,
      validated['contributor_email'] ?? actor?.email ?? null,
      validated['contributor_phone'] ?? null,
      validated['source_note'] ?? null,
      actor?.id ?? null,
      timestamp,
      timestamp,
    )
    .run();

  await new AuditRepository(context.env.DB).record({
    actorId: actor?.id ?? null,
    actorEmail: actor?.email ?? null,
    action: 'news.submitted',
    resourceType: 'news_submission',
    resourceId: id,
    changes: { title: validated['title'], reference },
    requestId: context.requestId,
  });

  await notifyEditors(
    context,
    'Somebody has sent in news',
    `${String(validated['title'])} — from ${actor?.displayName ?? 'a visitor'}.`,
    id,
  );

  return json(
    {
      id,
      reference,
      message:
        'Thank you. Keep this reference — you can use it to check what happened. An administrator '
        + 'reads everything that arrives, and decides what is published.',
    },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

/** `GET /api/contribute/news/:reference` */
export async function newsSubmissionStatus(context: RequestContext): Promise<Response> {
  const row = await context.env.DB.prepare(
    `SELECT "reference_code", "title", "status", "review_notes", "news_id", "created_at"
     FROM "news_submissions" WHERE "reference_code" = ? LIMIT 1`,
  )
    .bind(context.params['reference'] ?? '')
    .first<Record<string, unknown>>();

  if (!row) throw new NotFoundError('No submission with that reference.');

  return json(
    { ...row, explanation: explain(String(row['status'])) },
    { headers: NO_STORE_HEADERS },
  );
}

/** `GET /api/admin/news-submissions` */
export async function listNewsSubmissions(context: RequestContext): Promise<Response> {
  requireEditor(context);

  const { page, perPage, offset } = parsePagination(context.query);
  const status = context.query.get('status') ?? 'pending_review';

  const [countRow, rows] = await context.env.DB.batch<Record<string, unknown>>([
    context.env.DB
      .prepare('SELECT COUNT(*) AS total FROM "news_submissions" WHERE "status" = ?')
      .bind(status),
    context.env.DB
      .prepare(
        `SELECT * FROM "news_submissions" WHERE "status" = ?
         ORDER BY "created_at" DESC LIMIT ? OFFSET ?`,
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
 * `POST /api/admin/news-submissions/:id/promote`
 *
 * Publishes a submission as a news item.
 *
 * The administrator may rewrite the headline and the body first — this is the
 * community's official channel, and what goes out under its name is theirs to
 * word. What they cannot do is lose who sent it: `submitted_by` and
 * `source_note` travel onto the published item.
 */
export async function promoteNewsSubmission(context: RequestContext): Promise<Response> {
  const actor = requireEditor(context);

  const submission = await context.env.DB.prepare(
    'SELECT * FROM "news_submissions" WHERE "id" = ? LIMIT 1',
  )
    .bind(context.params['id'] ?? '')
    .first<Record<string, unknown>>();

  if (!submission) throw new NotFoundError('That submission was not found.');
  if (submission['status'] === 'promoted') {
    throw new BadRequestError('That has already been published.');
  }

  const body = await readJsonBody(context.request).catch(() => ({}) as Record<string, unknown>);
  const edits = new Validator(body)
    .string('title', { max: 200, label: 'Headline' })
    .string('excerpt', { max: 500, label: 'Summary' })
    .string('body', { max: 20000, label: 'The story' })
    .string('category', { max: 60 })
    .validated();

  const title = (edits['title'] as string | null) ?? String(submission['title']);
  const newsId = newId();
  const timestamp = nowIso();
  const slug = await uniqueSlug(context, title);

  await context.env.DB.prepare(
    `INSERT INTO "news"
       ("id", "slug", "title", "excerpt", "body", "category", "author_name",
        "published_at", "submitted_by", "source_note", "status", "created_at", "updated_at")
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'published', ?, ?)`,
  )
    .bind(
      newsId,
      slug,
      title,
      (edits['excerpt'] as string | null) ?? submission['excerpt'],
      (edits['body'] as string | null) ?? submission['body'],
      (edits['category'] as string | null) ?? submission['category'],
      submission['contributor_name'],
      timestamp,
      submission['submitted_by'],
      submission['source_note'],
      timestamp,
      timestamp,
    )
    .run();

  await context.env.DB.prepare(
    `UPDATE "news_submissions"
     SET "status" = 'promoted', "news_id" = ?, "reviewed_by" = ?, "reviewed_at" = ?, "updated_at" = ?
     WHERE "id" = ?`,
  )
    .bind(newsId, actor.id, timestamp, timestamp, submission['id'])
    .run();

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: 'news.promoted',
    resourceType: 'news',
    resourceId: newsId,
    changes: { from: submission['id'], title },
    requestId: context.requestId,
  });

  if (submission['submitted_by']) {
    await new NotificationRepository(context.env.DB).notify({
      userId: String(submission['submitted_by']),
      kind: 'contribution',
      title: 'Your news has been published',
      body: title,
      linkPath: `/news/${slug}`,
      resourceType: 'news',
      resourceId: newsId,
    });
  }

  return json({ newsId, slug, message: 'Published.' }, {
    status: 201,
    headers: NO_STORE_HEADERS,
  });
}

/** `POST /api/admin/news-submissions/:id/review` */
export async function reviewNewsSubmission(context: RequestContext): Promise<Response> {
  const actor = requireEditor(context);

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .oneOf('status', ['in_review', 'needs_more', 'rejected'], { required: true })
    .string('review_notes', { max: 2000, label: 'Notes' })
    .validated();

  const result = await context.env.DB.prepare(
    `UPDATE "news_submissions"
     SET "status" = ?, "review_notes" = ?, "reviewed_by" = ?, "reviewed_at" = ?, "updated_at" = ?
     WHERE "id" = ?`,
  )
    .bind(
      validated['status'],
      validated['review_notes'] ?? null,
      actor.id,
      nowIso(),
      nowIso(),
      context.params['id'] ?? '',
    )
    .run();

  if ((result.meta.changes ?? 0) === 0) {
    throw new NotFoundError('That submission was not found.');
  }

  return json({ message: 'Saved.' }, { headers: NO_STORE_HEADERS });
}

// ---------------------------------------------------------------------------

function requireEditor(context: RequestContext) {
  if (!context.user) throw new UnauthorizedError('Please sign in to continue.');
  if (!can(context.user, 'news:publish') && !can(context.user, 'news:update')) {
    throw new ForbiddenError('Only the administrators publish news.');
  }
  return context.user;
}

function explain(status: string): string {
  switch (status) {
    case 'pending_review':
      return 'Received. An administrator will read it.';
    case 'in_review':
      return 'Somebody is reading it now.';
    case 'needs_more':
      return 'The administrators would like a little more before publishing it.';
    case 'promoted':
      return 'Published. Thank you.';
    case 'rejected':
      return 'It was not published. The notes explain why.';
    default:
      return 'Received.';
  }
}

function referenceCode(): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = new Uint8Array(6);
  crypto.getRandomValues(bytes);
  return `EY-${Array.from(bytes, (b) => alphabet[b % alphabet.length]).join('')}`;
}

async function uniqueSlug(context: RequestContext, title: string): Promise<string> {
  const root = slugify(title).slice(0, 80) || 'news';

  for (let suffix = 0; suffix < 60; suffix += 1) {
    const candidate = suffix === 0 ? root : `${root}-${suffix + 1}`;
    const clash = await context.env.DB
      .prepare('SELECT "id" FROM "news" WHERE "slug" = ? LIMIT 1')
      .bind(candidate)
      .first<{ id: string }>();
    if (!clash) return candidate;
  }
  return `${root}-${Date.now()}`;
}

async function notifyEditors(
  context: RequestContext,
  title: string,
  body: string,
  resourceId: string,
): Promise<void> {
  const result = await context.env.DB.prepare(
    `SELECT DISTINCT ur."user_id" FROM "user_roles" ur
     INNER JOIN "roles" r ON r."id" = ur."role_id"
     WHERE r."slug" IN ('super_admin', 'deputy_super_admin', 'content_administrator')`,
  ).all<{ user_id: string }>();

  const editors = (result.results ?? []).map((row) => row.user_id);
  if (editors.length === 0) return;

  await new NotificationRepository(context.env.DB).notifyMany(editors, {
    kind: 'contribution',
    title,
    body,
    linkPath: '/admin/news-submissions',
    resourceType: 'news_submission',
    resourceId,
  });
}
