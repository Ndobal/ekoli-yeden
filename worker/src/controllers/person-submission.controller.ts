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
 * CONTRIBUTING A PERSON
 *
 * The People section holds structured records. Contributing one used to go
 * through the generic form — a title, a description and a file — so everything
 * that makes a person's record useful arrived as one paragraph of prose that a
 * Heritage editor then took apart by hand. Most of it arrived not at all,
 * because nobody thinks to mention a birth year in a box labelled
 * "description".
 *
 * This is a profile builder instead: it asks for the fields the destination
 * actually has, and it takes a photograph and a short film.
 *
 * ---------------------------------------------------------------------------
 * THE CONSENT QUESTION IS NOT A FORMALITY
 * ---------------------------------------------------------------------------
 *
 * Most of this archive is about places, practices and things. This is about
 * named people, many of them alive. A community archive that publishes a
 * biography of a living person who never agreed to it has done something TO
 * them rather than FOR them — so the form asks on what basis it may publish,
 * and a reviewer sees that answer before they see anything else.
 */

const CONSENT_BASES = [
  'person_agreed',
  'family_agreed',
  'public_figure',
  'deceased_historical',
  'unspecified',
] as const;

const PERSON_CATEGORIES = [
  'elder', 'leader', 'educator', 'professional', 'artisan', 'artist',
  'religious', 'sports', 'medicine', 'business', 'public_service',
  'diaspora', 'youth', 'other',
] as const;

/** `GET /api/contribute/person/form` — what the builder offers. */
export async function personFormOptions(_context: RequestContext): Promise<Response> {
  return json({
    categories: [
      { value: 'elder', label: 'An elder of the community' },
      { value: 'leader', label: 'Traditional or community leader' },
      { value: 'educator', label: 'Teacher, lecturer or educator' },
      { value: 'professional', label: 'Professional' },
      { value: 'artisan', label: 'Artisan or craftsperson' },
      { value: 'artist', label: 'Artist, musician or performer' },
      { value: 'religious', label: 'Religious leader' },
      { value: 'sports', label: 'Sports' },
      { value: 'medicine', label: 'Medicine or health' },
      { value: 'business', label: 'Business' },
      { value: 'public_service', label: 'Public service' },
      { value: 'diaspora', label: 'Ekoli-Yeden abroad' },
      { value: 'youth', label: 'Young person' },
      { value: 'other', label: 'Something else' },
    ],
    consentBases: [
      {
        value: 'person_agreed',
        label: 'They know about this and are happy for it to be published',
      },
      {
        value: 'family_agreed',
        label: 'Their family agreed',
      },
      {
        value: 'public_figure',
        label: 'They hold public office, or this is already publicly known',
      },
      {
        value: 'deceased_historical',
        label: 'They have passed on — this is a historical record',
      },
      {
        value: 'unspecified',
        label: 'I am not sure — please check before publishing',
      },
    ],
    guidance: [
      'Fill in as much as you know. A partial record is worth far more than none, and other '
        + 'people can add to it later.',
      'A photograph makes a person findable in a way a name alone does not. A short film says '
        + 'more still.',
      'If the person is alive, please only send what they are happy to have published.',
    ],
  });
}

/**
 * `POST /api/contribute/person`
 *
 * Sends a profile for review. Nothing is published by this route.
 */
export async function submitPerson(context: RequestContext): Promise<Response> {
  const actor = context.user;
  const body = await readJsonBody(context.request);

  const validated = new Validator(body)
    .string('name', { required: true, min: 2, max: 200, label: 'Their name' })
    .string('also_known_as', { max: 200, label: 'Also known as' })
    .string('headline', { max: 200, label: 'One line about them' })
    .string('profession', { max: 200, label: 'What they do' })
    .oneOf('category', PERSON_CATEGORIES)
    .string('biography', { max: 20000, label: 'About them' })
    .string('city', { max: 120, label: 'City' })
    .string('country', { max: 120, label: 'Country' })
    .string('community_area', { max: 150, label: 'Where in Ekoli-Yeden' })
    .url('website_url')
    .string('connection_to_ekoli', { max: 2000, label: 'Their connection to Ekoli-Yeden' })
    .string('why_notable', { max: 2000, label: 'Why they are worth recording' })
    .integer('birth_year', { min: 1800, max: 2200, label: 'Year of birth' })
    .integer('death_year', { min: 1800, max: 2200, label: 'Year they passed' })
    .boolean('is_living')
    .oneOf('consent_basis', CONSENT_BASES, { required: true })
    .string('consent_note', { max: 2000, label: 'About consent' })
    .string('consent_contact', { max: 200, label: 'Who to check with' })
    .string('contributor_name', { max: 200, label: 'Your name' })
    .email('contributor_email')
    .string('contributor_phone', { max: 40, label: 'Your phone number' })
    .string('contributor_relationship', { max: 300, label: 'How you know them' })
    .string('photo_upload_id', { max: 64 })
    .string('video_upload_id', { max: 64 })
    .validated();

  const birthYear = validated['birth_year'] as number | null;
  const deathYear = validated['death_year'] as number | null;
  if (birthYear && deathYear && deathYear < birthYear) {
    throw new BadRequestError('The year they passed cannot come before the year they were born.');
  }

  // Somebody recorded as living with a year of death is a contradiction a
  // reviewer would have to resolve by guessing. Caught here, where the person
  // filling it in can simply correct it.
  const isLiving = validated['is_living'];
  if (deathYear && (isLiving === 1 || isLiving === true)) {
    throw new BadRequestError(
      'You have given a year they passed, but also marked them as living. Please correct one.',
    );
  }

  const achievements = Array.isArray(body['achievements'])
    ? (body['achievements'] as unknown[])
        .map((entry) => String(entry).trim())
        .filter((entry) => entry.length > 0 && entry.length <= 500)
        .slice(0, 30)
    : [];

  const extraUploads = Array.isArray(body['extra_upload_ids'])
    ? (body['extra_upload_ids'] as unknown[]).map(String).slice(0, 20)
    : [];

  const id = newId();
  const reference = referenceCode();
  const timestamp = nowIso();

  await context.env.DB.prepare(
    `INSERT INTO "person_submissions"
       ("id", "reference_code", "name", "also_known_as", "headline", "profession", "category",
        "biography", "achievements", "birth_year", "death_year", "is_living",
        "city", "country", "community_area", "website_url",
        "connection_to_ekoli", "why_notable",
        "photo_upload_id", "video_upload_id", "extra_upload_ids",
        "consent_basis", "consent_note", "consent_contact",
        "contributor_name", "contributor_email", "contributor_phone",
        "contributor_relationship", "submitted_by",
        "status", "created_at", "updated_at")
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
             'pending_review', ?, ?)`,
  )
    .bind(
      id,
      reference,
      validated['name'],
      validated['also_known_as'] ?? null,
      validated['headline'] ?? null,
      validated['profession'] ?? null,
      validated['category'] ?? null,
      validated['biography'] ?? null,
      achievements.length > 0 ? JSON.stringify(achievements) : null,
      birthYear,
      deathYear,
      isLiving === undefined ? null : (isLiving === 1 || isLiving === true ? 1 : 0),
      validated['city'] ?? null,
      validated['country'] ?? null,
      validated['community_area'] ?? null,
      validated['website_url'] ?? null,
      validated['connection_to_ekoli'] ?? null,
      validated['why_notable'] ?? null,
      validated['photo_upload_id'] ?? null,
      validated['video_upload_id'] ?? null,
      extraUploads.length > 0 ? JSON.stringify(extraUploads) : null,
      validated['consent_basis'],
      validated['consent_note'] ?? null,
      validated['consent_contact'] ?? null,
      validated['contributor_name'] ?? actor?.displayName ?? null,
      validated['contributor_email'] ?? actor?.email ?? null,
      validated['contributor_phone'] ?? null,
      validated['contributor_relationship'] ?? null,
      actor?.id ?? null,
      timestamp,
      timestamp,
    )
    .run();

  await new AuditRepository(context.env.DB).record({
    actorId: actor?.id ?? null,
    actorEmail: actor?.email ?? null,
    action: 'person.submitted',
    resourceType: 'person_submission',
    resourceId: id,
    changes: { name: validated['name'], reference, consent: validated['consent_basis'] },
    requestId: context.requestId,
  });

  await notifyReviewers(
    context,
    'Somebody has been submitted for the People section',
    `${String(validated['name'])} — consent basis: ${String(validated['consent_basis'])}.`,
    id,
  );

  return json(
    {
      id,
      reference,
      message:
        'Thank you. Keep this reference — you can use it to check what happened. The Heritage '
        + 'Team reads every profile before it is published, and they look at the consent question '
        + 'first.',
    },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

/** `GET /api/contribute/person/:reference` — what happened to my submission. */
export async function personSubmissionStatus(context: RequestContext): Promise<Response> {
  const reference = context.params['reference'] ?? '';

  const row = await context.env.DB.prepare(
    `SELECT "reference_code", "name", "status", "review_notes", "person_id", "created_at"
     FROM "person_submissions" WHERE "reference_code" = ? LIMIT 1`,
  )
    .bind(reference)
    .first<Record<string, unknown>>();

  if (!row) throw new NotFoundError('No submission with that reference.');

  return json(
    {
      ...row,
      // Said in words rather than as a status token. Somebody checking on a
      // profile they sent in wants to know what is happening, not to decode
      // "needs_more".
      explanation: explain(String(row['status'])),
    },
    { headers: NO_STORE_HEADERS },
  );
}

/** `GET /api/admin/person-submissions` */
export async function listPersonSubmissions(context: RequestContext): Promise<Response> {
  const actor = requireReviewer(context);
  void actor;

  const { page, perPage, offset } = parsePagination(context.query);
  const status = context.query.get('status') ?? 'pending_review';

  const [countRow, rows] = await context.env.DB.batch<Record<string, unknown>>([
    context.env.DB
      .prepare('SELECT COUNT(*) AS total FROM "person_submissions" WHERE "status" = ?')
      .bind(status),
    context.env.DB
      .prepare(
        `SELECT * FROM "person_submissions" WHERE "status" = ?
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
 * `POST /api/admin/person-submissions/:id/promote`
 *
 * Turns a submission into a published person.
 *
 * The copy is field for field, because the submission was built to match the
 * destination — which is the whole point of having a profile builder rather
 * than a description box.
 */
export async function promotePersonSubmission(context: RequestContext): Promise<Response> {
  const actor = requireReviewer(context);

  const submission = await context.env.DB.prepare(
    'SELECT * FROM "person_submissions" WHERE "id" = ? LIMIT 1',
  )
    .bind(context.params['id'] ?? '')
    .first<Record<string, unknown>>();

  if (!submission) throw new NotFoundError('That submission was not found.');
  if (submission['status'] === 'promoted') {
    throw new BadRequestError('That has already been published.');
  }

  // A living person published on an unspecified consent basis is exactly the
  // outcome the consent column exists to prevent. The reviewer has to settle it
  // first — they can record the basis and then publish.
  if (
    submission['consent_basis'] === 'unspecified' &&
    submission['is_living'] !== 0
  ) {
    throw new BadRequestError(
      'The consent basis is unspecified and this person may be living. Settle that before '
        + 'publishing — record how we may publish, or ask the contributor.',
    );
  }

  const personId = newId();
  const timestamp = nowIso();
  const slug = await uniqueSlug(context, String(submission['name']));

  await context.env.DB.prepare(
    `INSERT INTO "people"
       ("id", "slug", "name", "also_known_as", "headline", "profession", "category",
        "biography", "achievements", "birth_year", "death_year", "is_living",
        "city", "country", "community_area", "website_url", "connection_to_ekoli",
        "consent_basis", "consent_reference", "verification_status", "status",
        "created_at", "updated_at")
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'unverified', 'published',
             ?, ?)`,
  )
    .bind(
      personId,
      slug,
      submission['name'],
      submission['also_known_as'],
      submission['headline'],
      submission['profession'],
      submission['category'],
      submission['biography'],
      submission['achievements'],
      submission['birth_year'],
      submission['death_year'],
      submission['is_living'],
      submission['city'],
      submission['country'],
      submission['community_area'],
      submission['website_url'],
      submission['connection_to_ekoli'],
      submission['consent_basis'],
      submission['consent_note'],
      timestamp,
      timestamp,
    )
    .run();

  await context.env.DB.prepare(
    `UPDATE "person_submissions"
     SET "status" = 'promoted', "person_id" = ?, "reviewed_by" = ?, "reviewed_at" = ?,
         "updated_at" = ?
     WHERE "id" = ?`,
  )
    .bind(personId, actor.id, timestamp, timestamp, submission['id'])
    .run();

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: 'person.promoted',
    resourceType: 'person',
    resourceId: personId,
    changes: { from: submission['id'], name: submission['name'] },
    requestId: context.requestId,
  });

  if (submission['submitted_by']) {
    await new NotificationRepository(context.env.DB).notify({
      userId: String(submission['submitted_by']),
      kind: 'general',
      title: `${String(submission['name'])} is now in the archive`,
      body: 'The profile you sent in has been published. Thank you.',
      linkPath: `/people/${slug}`,
      resourceType: 'person',
      resourceId: personId,
    });
  }

  return json(
    { personId, slug, message: 'Published.' },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

/** `POST /api/admin/person-submissions/:id/review` — reject, or ask for more. */
export async function reviewPersonSubmission(context: RequestContext): Promise<Response> {
  const actor = requireReviewer(context);

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .oneOf('status', ['in_review', 'needs_more', 'rejected', 'duplicate'], { required: true })
    .string('review_notes', { max: 2000, label: 'Notes' })
    .validated();

  const result = await context.env.DB.prepare(
    `UPDATE "person_submissions"
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

function requireReviewer(context: RequestContext) {
  if (!context.user) throw new UnauthorizedError('Please sign in to continue.');
  if (!can(context.user, 'people:update')) {
    throw new ForbiddenError('You do not review submissions for the People section.');
  }
  return context.user;
}

function explain(status: string): string {
  return switchStatus(status);
}

function switchStatus(status: string): string {
  switch (status) {
    case 'pending_review':
      return 'Received. It is waiting for the Heritage Team to read it.';
    case 'in_review':
      return 'Somebody is reading it now.';
    case 'needs_more':
      return 'The Heritage Team would like a little more before publishing it.';
    case 'promoted':
      return 'Published. Thank you — it is part of the archive now.';
    case 'duplicate':
      return 'This person is already in the archive.';
    case 'rejected':
      return 'It was not published. The notes explain why.';
    default:
      return 'Received.';
  }
}

/** `EY-XXXXXX`, the same shape used everywhere else a contributor gets a code. */
function referenceCode(): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = new Uint8Array(6);
  crypto.getRandomValues(bytes);
  const body = Array.from(bytes, (byte) => alphabet[byte % alphabet.length]).join('');
  return `EY-${body}`;
}

async function uniqueSlug(context: RequestContext, name: string): Promise<string> {
  const root = slugify(name).slice(0, 80) || 'person';

  for (let suffix = 0; suffix < 60; suffix += 1) {
    const candidate = suffix === 0 ? root : `${root}-${suffix + 1}`;
    const clash = await context.env.DB
      .prepare('SELECT "id" FROM "people" WHERE "slug" = ? LIMIT 1')
      .bind(candidate)
      .first<{ id: string }>();
    if (!clash) return candidate;
  }
  return `${root}-${Date.now()}`;
}

async function notifyReviewers(
  context: RequestContext,
  title: string,
  body: string,
  resourceId: string,
): Promise<void> {
  const result = await context.env.DB.prepare(
    `SELECT DISTINCT ur."user_id" FROM "user_roles" ur
     INNER JOIN "roles" r ON r."id" = ur."role_id"
     WHERE r."slug" IN ('super_admin', 'deputy_super_admin', 'heritage_editor', 'moderator')`,
  ).all<{ user_id: string }>();

  const reviewers = (result.results ?? []).map((row) => row.user_id);
  if (reviewers.length === 0) return;

  await new NotificationRepository(context.env.DB).notifyMany(reviewers, {
    // Must be one of the kinds the notifications table allows.
    kind: 'contribution',
    title,
    body,
    linkPath: '/admin/person-submissions',
    resourceType: 'person_submission',
    resourceId,
  });
}
