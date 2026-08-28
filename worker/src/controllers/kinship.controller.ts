import type { RequestContext } from '../types/api';
import { KinshipService } from '../services/kinship.service';
import { BirthdayService } from '../services/birthday.service';
import { RemembranceService } from '../services/remembrance.service';
import { RELATIONSHIP_GROUPS, RELATIONSHIP_LABELS, RELATIONSHIP_TYPES } from '../services/kinship';
import { MemberRepository } from '../repositories/member.repository';
import { can } from '../services/permissions';
import { readJsonBody, Validator } from '../utils/validation';
import { json, paginated, NO_STORE_HEADERS } from '../utils/responses';
import { parsePagination } from '../utils/pagination';
import { BadRequestError, ForbiddenError, NotFoundError, UnauthorizedError } from '../utils/errors';

/**
 * FAMILY, BIRTHDAYS AND REMEMBRANCE
 *
 * Three features that look separate and are not. Each rests on the same record:
 * an accepted relationship between two members.
 *
 *   Family      is that record.
 *   Birthdays   decide who to tell using it.
 *   Remembrance decides who may confirm a death using it.
 *
 * That last one is why the acceptance step is not a courtesy. If a claimed
 * relationship counted, two accounts made this morning could between them still
 * a living person's account this afternoon. Nothing in this file lets a
 * relationship exist because one side said so.
 */

// ---------------------------------------------------------------------------
// Family
// ---------------------------------------------------------------------------

/** `GET /api/membership/family` — my family, and what is waiting for me. */
export async function myFamily(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const service = new KinshipService(context.env);
  return json(await service.family(actor.id), { headers: NO_STORE_HEADERS });
}

/**
 * `GET /api/membership/family/options`
 *
 * The relationships the platform recognises, grouped for a picker.
 *
 * Served rather than hard-coded in the client so the two cannot disagree about
 * what counts as family — a client offering "step-father" to an API that has
 * never heard of it produces an error the member cannot act on.
 */
export async function relationshipOptions(_context: RequestContext): Promise<Response> {
  return json({
    groups: RELATIONSHIP_GROUPS.map((group) => ({
      label: group.label,
      options: group.types.map((type) => ({ value: type, label: RELATIONSHIP_LABELS[type] ?? type })),
    })),
    all: RELATIONSHIP_TYPES.map((type) => ({ value: type, label: RELATIONSHIP_LABELS[type] ?? type })),
  });
}

/**
 * `POST /api/membership/family/requests`
 *
 * Asks somebody to confirm a relationship, by member or by phone number.
 *
 * The phone form answers identically whether or not a member holds that number.
 * That is deliberate and must stay so: an endpoint that says "no such member"
 * is a way to test a list of numbers against the membership.
 */
export async function requestRelationship(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const body = await readJsonBody(context.request);

  const validated = new Validator(body)
    .oneOf('type', RELATIONSHIP_TYPES, { required: true })
    .string('note', { max: 500, label: 'Note' })
    .string('handle', { max: 60, label: 'Member' })
    .string('user_id', { max: 64, label: 'Member' })
    .string('phone', { max: 30, label: 'Phone number' })
    .validated();

  const service = new KinshipService(context.env);
  const type = validated['type'] as string;
  const note = (validated['note'] as string | null) ?? null;

  const phone = validated['phone'] as string | null;
  if (phone) {
    const result = await service.requestByPhone(actor, { phone, type, note }, { requestId: context.requestId });
    return json(
      {
        ...result,
        // Says nothing about whether the number is known here. See above.
        message:
          'If that number belongs to a member, we have asked them to confirm. They have to accept '
          + 'before anything is recorded.',
      },
      { status: 202, headers: NO_STORE_HEADERS },
    );
  }

  const toUserId = await resolveMember(context, validated);
  const result = await service.request(
    actor,
    { toUserId, type, note, via: 'profile' },
    { requestId: context.requestId },
  );

  return json(
    { ...result, message: 'Asked. Nothing is recorded until they confirm it.' },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

/** `POST /api/membership/family/:id/accept` */
export async function acceptRelationship(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const body = await readJsonBody(context.request).catch(() => ({}) as Record<string, unknown>);

  // The accepter says what they are to the other person. Only they can know
  // whether they are the son or the daughter, and the archive does not ask
  // anybody to record their sex so it can guess.
  const reverse = new Validator(body)
    .string('reverse_type', { max: 40, label: 'Relationship' })
    .validated()['reverse_type'] as string | null;

  const service = new KinshipService(context.env);
  await service.accept(actor, context.params['id'] ?? '', reverse ?? '', { requestId: context.requestId });

  return json({ message: 'Confirmed.' }, { headers: NO_STORE_HEADERS });
}

/** `POST /api/membership/family/:id/decline` */
export async function declineRelationship(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  await new KinshipService(context.env).decline(actor, context.params['id'] ?? '');
  return json({ message: 'Declined.' }, { headers: NO_STORE_HEADERS });
}

/** `DELETE /api/membership/family/:id` — either side may end it, alone. */
export async function removeRelationship(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  await new KinshipService(context.env).remove(actor, context.params['id'] ?? '', {
    requestId: context.requestId,
  });
  return json({ message: 'Ended.' }, { headers: NO_STORE_HEADERS });
}

// ---------------------------------------------------------------------------
// Birthdays
// ---------------------------------------------------------------------------

/**
 * `GET /api/membership/birthdays/today`
 *
 * The cards for a member's dashboard: whose birthday it is among the people
 * they know, and whether it is their own.
 */
export async function birthdaysToday(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const service = new BirthdayService(context.env);

  const [prompts, own] = await Promise.all([
    service.promptsFor(actor),
    service.ownBirthdayToday(actor),
  ]);

  return json({ prompts, own, total: prompts.length }, { headers: NO_STORE_HEADERS });
}

/** `POST /api/membership/birthdays/:userId/wish` */
export async function wishBirthday(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const body = await readJsonBody(context.request);

  const validated = new Validator(body)
    .string('message', { required: true, max: 2000, label: 'Message' })
    .boolean('is_prayer')
    .string('group_id', { max: 64, label: 'Group' })
    .validated();

  const result = await new BirthdayService(context.env).wish(actor, {
    recipientUserId: context.params['userId'] ?? '',
    message: validated['message'] as string,
    isPrayer: validated['is_prayer'] === 1 || validated['is_prayer'] === true,
    groupId: (validated['group_id'] as string | null) ?? null,
  });

  return json(
    { ...result, message: 'Sent. It is kept in their birthday chart for this year.' },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

/**
 * `POST /api/membership/birthdays/:userId/skip`
 *
 * "Not now" means not now. Recorded so the card does not come back on the next
 * page load — a prompt that reappears after being dismissed gets ignored
 * unread, which defeats the whole thing.
 */
export async function skipBirthday(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  await new BirthdayService(context.env).skip(actor, context.params['userId'] ?? '');
  return json({ message: 'Skipped.' }, { headers: NO_STORE_HEADERS });
}

/**
 * `GET /api/members/:handle/birthdays`
 *
 * One year of somebody's birthday chart, and the list of years that have any.
 *
 * A feed cannot answer "what did people say to me in 2027?", which is the
 * question a member actually asks years later. Each year is its own page.
 */
export async function birthdayChart(context: RequestContext): Promise<Response> {
  const handle = context.params['handle'] ?? '';
  const profile = await new MemberRepository(context.env.DB).findByHandle(handle);
  if (!profile) throw new NotFoundError('That member was not found.');

  const yearParam = context.query.get('year');
  const year = yearParam ? Number(yearParam) : null;
  if (yearParam && (!Number.isInteger(year) || year! < 1900 || year! > 2200)) {
    throw new BadRequestError('That is not a year.');
  }

  const chart = await new BirthdayService(context.env).chart(
    String(profile['user_id']),
    year,
    context.user,
  );

  return json(chart, { headers: NO_STORE_HEADERS });
}

/** `DELETE /api/membership/birthdays/wishes/:id` — hide one from my own chart. */
export async function hideBirthdayWish(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  await new BirthdayService(context.env).hideWish(actor, context.params['id'] ?? '');
  return json({ message: 'Hidden.' }, { headers: NO_STORE_HEADERS });
}

// ---------------------------------------------------------------------------
// Remembrance
// ---------------------------------------------------------------------------

/**
 * `POST /api/membership/remembrance/reports`
 *
 * Records that somebody has died. Changes nothing else — see the long note at
 * the top of `remembrance.service.ts` for why every step here is separate.
 */
export async function reportDeath(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const body = await readJsonBody(context.request);

  const validated = new Validator(body)
    .string('subject_name', { required: true, max: 200, label: 'Name' })
    .string('subject_user_id', { max: 64, label: 'Member' })
    .string('relationship', { max: 40, label: 'Your relationship' })
    .string('group_id', { max: 64, label: 'Group' })
    .string('place_of_death', { max: 300, label: 'Place' })
    .string('detail', { max: 4000, label: 'Detail' })
    .validated();

  if ('date_of_death' in body && body['date_of_death']) {
    Object.assign(
      validated,
      new Validator(body).date('date_of_death', { label: 'Date' }).validated(),
    );
  }

  const result = await new RemembranceService(context.env).report(
    actor,
    {
      subjectUserId: (validated['subject_user_id'] as string | null) ?? null,
      subjectName: validated['subject_name'] as string,
      relationship: (validated['relationship'] as string | null) ?? null,
      groupId: (validated['group_id'] as string | null) ?? null,
      dateOfDeath: (validated['date_of_death'] as string | null) ?? null,
      placeOfDeath: (validated['place_of_death'] as string | null) ?? null,
      detail: (validated['detail'] as string | null) ?? null,
    },
    { requestId: context.requestId },
  );

  return json(result, { status: 201, headers: NO_STORE_HEADERS });
}

/** `POST /api/membership/remembrance/reports/:id/confirm` */
export async function confirmDeath(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const body = await readJsonBody(context.request).catch(() => ({}) as Record<string, unknown>);
  const note = new Validator(body).string('note', { max: 2000 }).validated()['note'] as string | null;

  const result = await new RemembranceService(context.env).confirm(
    actor,
    context.params['id'] ?? '',
    note ?? null,
    { requestId: context.requestId },
  );

  return json(result, { headers: NO_STORE_HEADERS });
}

/**
 * `POST /api/membership/remembrance/contest`
 *
 * "I am not dead."
 *
 * No deadline is enforced against the account holder, and the account is
 * restored at once rather than after review. Wrongly restoring a genuinely
 * deceased account for a day costs nothing next to a living person being unable
 * to undo this.
 */
export async function contestMemorial(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const body = await readJsonBody(context.request).catch(() => ({}) as Record<string, unknown>);
  const note = new Validator(body).string('note', { max: 2000 }).validated()['note'] as string | null;

  const result = await new RemembranceService(context.env).contest(actor, note ?? null, {
    requestId: context.requestId,
  });

  return json(result, { headers: NO_STORE_HEADERS });
}

/**
 * `GET /api/membership/remembrance/notice`
 *
 * What a reported or memorialised account is told when its holder signs in.
 * Null for everybody else, which is almost everybody.
 */
export async function memorialNotice(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const notice = await new RemembranceService(context.env).noticeFor(actor.id);
  return json({ notice }, { headers: NO_STORE_HEADERS });
}

/** `POST /api/admin/remembrance/:id/publish` — the Preservation Team's decision. */
export async function publishMemorial(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const body = await readJsonBody(context.request).catch(() => ({}) as Record<string, unknown>);

  const validated = new Validator(body)
    .string('biography', { max: 20000, label: 'Life' })
    .string('group_id', { max: 64, label: 'Group' })
    .integer('birth_year', { min: 1800, max: 2200, label: 'Year of birth' })
    .validated();

  const result = await new RemembranceService(context.env).publishMemorial(
    actor,
    context.params['id'] ?? '',
    {
      biography: (validated['biography'] as string | null) ?? null,
      birthYear: (validated['birth_year'] as number | null) ?? null,
      groupId: (validated['group_id'] as string | null) ?? null,
    },
    { requestId: context.requestId },
  );

  return json(result, { status: 201, headers: NO_STORE_HEADERS });
}

/** `POST /api/admin/remembrance/:id/reject` — the undo, available at any stage. */
export async function rejectDeathReport(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const body = await readJsonBody(context.request).catch(() => ({}) as Record<string, unknown>);
  const reason = new Validator(body).string('reason', { max: 2000 }).validated()['reason'] as string | null;

  await new RemembranceService(context.env).reject(actor, context.params['id'] ?? '', reason ?? null, {
    requestId: context.requestId,
  });

  return json({ message: 'Rejected, and the account restored.' }, { headers: NO_STORE_HEADERS });
}

/** `GET /api/admin/remembrance` — reports awaiting the Preservation Team. */
export async function listDeathReports(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  if (!can(actor, 'users:update')) {
    throw new ForbiddenError('Only the Preservation Team can review these.');
  }

  const { page, perPage, offset } = parsePagination(context.query);
  const service = new RemembranceService(context.env);
  const { items, total } = await service.repo.listReports(
    context.query.get('state') ?? 'reported',
    perPage,
    offset,
  );

  return paginated(items, page, perPage, total, NO_STORE_HEADERS);
}

// ---------------------------------------------------------------------------

function requireUser(context: RequestContext) {
  if (!context.user) throw new UnauthorizedError('Please sign in to continue.');
  return context.user;
}

/** Resolves whichever way the caller named the other member. */
async function resolveMember(
  context: RequestContext,
  validated: Record<string, unknown>,
): Promise<string> {
  const userId = validated['user_id'] as string | null;
  if (userId) return userId;

  const handle = validated['handle'] as string | null;
  if (!handle) {
    throw new BadRequestError('Say who you mean — a member, or a phone number.');
  }

  const profile = await new MemberRepository(context.env.DB).findByHandle(handle);
  if (!profile) throw new NotFoundError('That member was not found.');
  return String(profile['user_id']);
}
