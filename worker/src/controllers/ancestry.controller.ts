import type { RequestContext } from '../types/api';
import { RemembranceRepository } from '../repositories/remembrance.repository';
import { readJsonBody, Validator } from '../utils/validation';
import { json, paginated, NO_STORE_HEADERS } from '../utils/responses';
import { parsePagination } from '../utils/pagination';
import { NotFoundError, UnauthorizedError } from '../utils/errors';
import { publicMediaUrl } from '../utils/files';

/**
 * ANCESTRY RECORDS — the people Ekoli-Yeden came from.
 *
 * ---------------------------------------------------------------------------
 * WHY THIS IS A PUBLIC SECTION AND NOT A MEMBERS-ONLY ONE
 * ---------------------------------------------------------------------------
 *
 * A memorial that only members can read is a memorial the family living abroad
 * cannot show their children. These records are published content like every
 * other section of the archive: readable by anybody, written only through
 * review.
 *
 * Two things a memorial must never do, which is why this file is short and the
 * writing paths are elsewhere:
 *
 *   Records are NOT created here. A memorial exists because a death was
 *   reported, confirmed by somebody who was already family, and then published
 *   by the Preservation Team — three separate acts in `remembrance.service.ts`,
 *   each with its own undo. An endpoint that let a caller create one directly
 *   would go around all of it.
 *
 *   Only `published` records are served, and the repository enforces it in
 *   SQL rather than here. A memorial published in error must disappear the
 *   moment it is archived, from every route at once.
 */

/** `GET /api/ancestry` — everybody the archive remembers. */
export async function listAncestry(context: RequestContext): Promise<Response> {
  const repository = new RemembranceRepository(context.env.DB);
  const { page, perPage, offset } = parsePagination(context.query);

  const { items, total } = await repository.listAncestry({
    limit: perPage,
    offset,
    search: context.query.get('q'),
    groupId: context.query.get('group'),
  });

  return paginated(
    items.map((row) => shapeRecord(context, row)),
    page,
    perPage,
    total,
  );
}

/**
 * `GET /api/ancestry/:identifier` — one memorial, with what people have left
 * on it.
 */
export async function showAncestry(context: RequestContext): Promise<Response> {
  const repository = new RemembranceRepository(context.env.DB);
  const record = await repository.findAncestryRecord(context.params['identifier'] ?? '');

  if (!record || record.status !== 'published') {
    throw new NotFoundError('That record was not found.');
  }

  const tributes = await repository.tributesFor(record.id);

  return json({
    ...shapeRecord(context, record as unknown as Record<string, unknown>),
    also_known_as: record.also_known_as ?? null,
    place_of_origin: record.place_of_origin ?? null,
    quarter: record.quarter ?? null,
    contribution: record.contribution ?? null,
    survived_by: record.survived_by ?? null,
    verification_status: record.verification_status,
    tributes: tributes.map((tribute) => ({
      id: tribute['id'],
      // The name as it was given. A tribute is signed by a person, not by an
      // account, so nothing here links to a profile.
      author_name: tribute['author_name'] ?? 'A member of the community',
      relationship: tribute['relationship'] ?? null,
      message: tribute['message'],
      created_at: tribute['created_at'],
    })),
  });
}

/**
 * `POST /api/ancestry/:identifier/tributes`
 *
 * What somebody wants to say about the person.
 *
 * Published immediately rather than held for review, deliberately. A condolence
 * that appears three days later, after the burial, has missed the moment it
 * existed for — and a tribute is signed, on a memorial, in front of the
 * family, which is a far stronger restraint than any queue. A moderator can
 * hide one afterwards.
 */
export async function addTribute(context: RequestContext): Promise<Response> {
  if (!context.user) throw new UnauthorizedError('Please sign in to leave a tribute.');

  const repository = new RemembranceRepository(context.env.DB);
  const record = await repository.findAncestryRecord(context.params['identifier'] ?? '');

  if (!record || record.status !== 'published') {
    throw new NotFoundError('That record was not found.');
  }

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('message', { required: true, min: 2, max: 4000, label: 'Your tribute' })
    .string('relationship', { max: 120, label: 'How you knew them' })
    .validated();

  const id = await repository.addTribute({
    recordId: record.id,
    authorId: context.user.id,
    authorName: context.user.displayName,
    relationship: (validated['relationship'] as string | null) ?? null,
    message: validated['message'] as string,
  });

  return json(
    { id, message: 'Thank you. It is on their page now.' },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

/**
 * `GET /api/members/:handle/memorial` is not a route, and this is why:
 *
 * a memorialised member is reached through their ancestry record, not through
 * their profile. Keeping the two apart means a page about somebody living and
 * a page about somebody who has died never render from the same shape by
 * accident.
 */

function shapeRecord(
  context: RequestContext,
  row: Record<string, unknown>,
): Record<string, unknown> {
  const portraitKey = row['portrait_key'];

  return {
    id: row['id'],
    slug: row['slug'],
    full_name: row['full_name'],
    birth_year: row['birth_year'] ?? null,
    birth_date: row['birth_date'] ?? null,
    death_year: row['death_year'] ?? null,
    death_date: row['death_date'] ?? null,
    biography: row['biography'] ?? null,
    group_title: row['group_title'] ?? null,
    group_slug: row['group_slug'] ?? null,
    portrait_url:
      typeof portraitKey === 'string' && portraitKey.length > 0
        ? publicMediaUrl(context.env.PUBLIC_MEDIA_BASE_URL, portraitKey)
        : null,
    created_at: row['created_at'],
  };
}
