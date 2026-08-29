import type { RequestContext } from '../types/api';
import { MembershipService } from '../services/membership.service';
import { MemberRepository } from '../repositories/member.repository';
import { NotificationRepository } from '../repositories/notification.repository';
import {
  CONNECTIONS,
  CONNECTION_LABELS,
  EKOLI_RELATIONSHIPS,
  EKOLI_RELATIONSHIP_LABELS,
  EDUCATION_LABELS,
  EDUCATION_LEVELS,
  EMPLOYMENT_LABELS,
  EMPLOYMENT_STATUSES,
  PROFICIENCIES,
  PROFILE_VISIBILITIES,
  WORK_GROUP_LABELS,
  workGroupFor,
  visibleProfile,
  type ViewerRelationship,
} from '../services/membership';
import { can } from '../services/permissions';
import { UnauthorizedError } from '../utils/errors';
import { readJsonBody, Validator } from '../utils/validation';
import { json, paginated, NO_STORE_HEADERS, publicCacheHeaders } from '../utils/responses';
import { parsePagination } from '../utils/pagination';

/**
 * THE OKOLI ACCOUNT
 *
 * One account for the whole platform. These routes are the account itself —
 * joining, the profile, skills, interests, privacy, notifications.
 *
 * Everything that returns a profile goes through `MembershipService`, which
 * applies the visibility rules. No handler here shapes a profile itself.
 */

function requireActor(context: RequestContext) {
  if (!context.user) throw new UnauthorizedError('Please sign in to continue.');
  return context.user;
}

/**
 * `GET /api/membership/options`
 *
 * Everything the joining form and the profile editor need to draw themselves:
 * professions, skills, interests, and the wording for every choice offered.
 *
 * Served from the database rather than hard-coded in the client, so the
 * community can add a profession or a skill without a deployment — and so the
 * labels on the employment question, which matter, live in one place.
 */
export async function membershipOptions(context: RequestContext): Promise<Response> {
  const repository = new MemberRepository(context.env.DB);

  const [professions, skills, interests] = await Promise.all([
    repository.professions(),
    repository.skills(),
    repository.interests(),
  ]);

  return json(
    {
      professions,
      skills,
      interests,
      // Offered in the order somebody is likely to recognise themselves in,
      // with working first — not with "unemployed" at the top of the list.
      employmentStatuses: EMPLOYMENT_STATUSES.map((value) => ({
        value,
        label: EMPLOYMENT_LABELS[value],
        group: workGroupFor(value),
      })),
      workGroups: Object.entries(WORK_GROUP_LABELS).map(([value, label]) => ({ value, label })),
      // The two axes, offered separately: what somebody IS to Ekoli-Yeden, and
      // the longer list of ways of saying it that profiles filled in before
      // 0033 still carry.
      relationships: EKOLI_RELATIONSHIPS.map((value) => ({
        value,
        label: EKOLI_RELATIONSHIP_LABELS[value],
      })),
      connections: CONNECTIONS.map((value) => ({ value, label: CONNECTION_LABELS[value] })),
      educationLevels: EDUCATION_LEVELS.map((value) => ({ value, label: EDUCATION_LABELS[value] })),
      proficiencies: PROFICIENCIES,
      visibilities: [
        {
          value: 'public',
          label: 'Public',
          description: 'Anybody can see your profile, including people who are not members.',
        },
        {
          value: 'members',
          label: 'Yakoli members only',
          description: 'Only signed-in members of the community can see your profile.',
        },
        {
          value: 'private',
          label: 'Private',
          description: 'Only you, and the administrators who keep the platform.',
        },
      ],
      privacyPromise: [
        'Your phone number and email are hidden unless you turn them on.',
        'Your work situation is never shown publicly by default.',
        'The platform does not label anybody unemployed, anywhere, to anyone.',
        'You are not in the directory unless you choose to be.',
        'Your birth year is never shown to anybody but you.',
      ],
    },
    { headers: publicCacheHeaders(600) },
  );
}

/** `POST /api/membership/join` — turn this account into a membership. */
export async function joinCommunity(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const body = await readJsonBody(context.request).catch(() => ({}) as Record<string, unknown>);

  const validated = new Validator(body)
    .string('full_name', { max: 200, label: 'Your name' })
    .validated();

  const service = new MembershipService(context.env);
  const result = await service.join(
    actor,
    { fullName: (validated['full_name'] as string | null) ?? null },
    { requestId: context.requestId },
  );

  return json(
    {
      ...result,
      message:
        result.status === 'pending'
          ? 'Thank you for joining. Your membership is waiting to be confirmed — you can fill in '
            + 'your profile in the meantime.'
          : 'Welcome to the Yakoli community. Fill in your profile so people can find you — you '
            + 'decide what appears and what stays private.',
    },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

/** `GET /api/membership/me` — the member's own profile, in full. */
export async function myProfile(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const service = new MembershipService(context.env);
  await service.ensureMembership(actor, { requestId: context.requestId });
  return json(await service.readOwnProfile(actor), { headers: NO_STORE_HEADERS });
}

/** `GET /api/membership/dashboard` — the whole Okoli account in one request. */
export async function memberDashboard(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const service = new MembershipService(context.env);

  // Every registered person is a member. An account made before that was true —
  // or created by an administrator, which does not go through registration —
  // gets its profile here, on the first dashboard it opens, using the name it
  // already has. Cheap and idempotent when there is nothing to do.
  await service.ensureMembership(actor, { requestId: context.requestId });

  return json(await service.dashboard(actor), { headers: NO_STORE_HEADERS });
}

/**
 * `PATCH /api/membership/me`
 *
 * One stage of the profile at a time. Everything is optional — a member may
 * answer three questions today and three more next week.
 */
export async function updateMyProfile(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const body = await readJsonBody(context.request);

  const validator = new Validator(body)
    .string('full_name', { max: 200, label: 'Your name' })
    .string('headline', { max: 200, label: 'Headline' })
    .string('bio', { max: 4000, label: 'About you' })
    .string('avatar_media_id', { max: 64 })
    .string('phone', { max: 40, label: 'Phone number' })
    .string('whatsapp_number', { max: 40, label: 'WhatsApp number' })
    .string('country', { max: 100, label: 'Country' })
    .string('state_region', { max: 120, label: 'State' })
    .string('lga', { max: 120, label: 'Local government area' })
    .string('community_area', { max: 150, label: 'Community' })
    .string('city', { max: 120, label: 'City' })
    // Free text, not a dropdown. No list an administrator writes will contain
    // every compound in Ekori, and a member whose home is missing from a
    // picker either chooses the wrong thing or gives up. The service matches
    // what they typed against the places we know and keeps their words either
    // way — see `places.service.ts`.
    .string('place_text', { max: 120, label: 'Where in Ekori you are from' })
    .string('clan', { max: 120, label: 'Your clan' })
    .string('connection_note', { max: 500, label: 'Your connection' })
    .string('profession_id', { max: 64 })
    .string('profession_other', { max: 150, label: 'Profession' })
    .string('industry', { max: 120, label: 'Industry' })
    .string('employer', { max: 200, label: 'Employer' })
    .string('education_field', { max: 200, label: 'Field of study' })
    .string('institution', { max: 200, label: 'Institution' });

  if ('connection' in body && body['connection']) validator.oneOf('connection', CONNECTIONS);
  // WHAT THEY ARE TO EKOLI-YEDEN. Recorded, never consulted for permission —
  // see the note above `EKOLI_RELATIONSHIPS`.
  if ('relationship' in body && body['relationship']) {
    validator.oneOf('relationship', EKOLI_RELATIONSHIPS);
  }
  if ('education_level' in body && body['education_level']) {
    validator.oneOf('education_level', EDUCATION_LEVELS);
  }
  if ('employment_status' in body && body['employment_status']) {
    validator.oneOf('employment_status', EMPLOYMENT_STATUSES);
  }
  if ('years_experience' in body && body['years_experience'] !== null && body['years_experience'] !== '') {
    validator.integer('years_experience', { min: 0, max: 80, label: 'Years of experience' });
  }
  if ('birth_year' in body && body['birth_year'] !== null && body['birth_year'] !== '') {
    validator.integer('birth_year', { min: 1900, max: 2100, label: 'Year of birth' });
  }
  if ('open_to_opportunities' in body) validator.boolean('open_to_opportunities');

  // THE BIRTHDAY.
  //
  // `birth_date`, `birth_day`, `birth_month`, `show_birthday` and the wishes
  // switch have existed since the birthdays module was built, along with the
  // page that shows whose birthday it is. Nothing ever accepted a date, so
  // that page could only ever be empty.
  //
  // The year is part of the date and is never published — it feeds the
  // age-grade brackets. The day and month are derived on write by the service.
  if ('birth_date' in body && body['birth_date'] !== null && body['birth_date'] !== '') {
    validator.date('birth_date', { label: 'Date of birth' });
  }
  if ('show_birthday' in body) validator.boolean('show_birthday');
  if ('birthday_wishes_enabled' in body) validator.boolean('birthday_wishes_enabled');
  if ('show_age' in body) validator.boolean('show_age');

  // §14 of the proposal. Kept separate from `open_to_opportunities`: that one
  // says this person would like to hear about work, and this one says they are
  // willing to give their time to somebody younger. They are opposite
  // directions and a member may well set one and not the other.
  if ('open_to_mentoring' in body) validator.boolean('open_to_mentoring');
  if ('mentoring_note' in body) {
    validator.string('mentoring_note', { max: 400, label: 'What you can help with' });
  }

  const validated = validator.validated();

  const service = new MembershipService(context.env);
  const updated = await service.update(actor, validated, { requestId: context.requestId });

  return json(updated, { headers: NO_STORE_HEADERS });
}

/**
 * `PATCH /api/membership/me/privacy`
 *
 * Kept separate from the profile edit on purpose. Changing what the world can
 * see about you is a different act from correcting your job title, and it
 * should not be something that happens as a side effect of saving a form.
 */
export async function updateMyPrivacy(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const body = await readJsonBody(context.request);

  const validator = new Validator(body);
  if ('profile_visibility' in body) validator.oneOf('profile_visibility', PROFILE_VISIBILITIES);
  // Who may write to them. 'members' or 'nobody' — there is no 'everyone',
  // because writing to a named person is a thing members do.
  if ('messages_from' in body) validator.oneOf('messages_from', ['members', 'nobody']);
  for (const flag of [
    'show_contact',
    'show_employment',
    'show_location',
    'show_education',
    'listed_in_directory',
    // Kept apart from `listed_in_directory` on purpose: not wanting to be in
    // the published list is not the same as not wanting to be reachable.
    'findable_for_messages',
    'notify_opportunities',
    'notify_forum',
    'notify_community',
  ]) {
    if (flag in body) validator.boolean(flag);
  }

  const service = new MembershipService(context.env);
  const updated = await service.update(actor, validator.validated(), {
    requestId: context.requestId,
  });

  return json(updated, { headers: NO_STORE_HEADERS });
}

/**
 * `PUT /api/membership/me/skills`
 *
 * Replaces the list. A skill named but not in the vocabulary is added to it
 * rather than refused — the community knows its own trades better than a seed
 * list does.
 */
export async function updateMySkills(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const body = await readJsonBody(context.request);

  const raw = Array.isArray(body['skills']) ? body['skills'] : [];
  const entries = raw
    .filter((item): item is Record<string, unknown> => item !== null && typeof item === 'object')
    .map((item) => ({
      skillId: asText(item['skill_id'], 64),
      name: asText(item['name'], 100),
      proficiency: (PROFICIENCIES as readonly string[]).includes(String(item['proficiency']))
        ? String(item['proficiency'])
        : 'unspecified',
      years: typeof item['years'] === 'number' ? item['years'] : null,
    }));

  const service = new MembershipService(context.env);
  const skills = await service.setSkills(actor, entries);

  return json({ skills }, { headers: NO_STORE_HEADERS });
}

/** `PUT /api/membership/me/interests` */
export async function updateMyInterests(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const body = await readJsonBody(context.request);

  const ids = Array.isArray(body['interests'])
    ? body['interests'].filter((item): item is string => typeof item === 'string')
    : [];

  const service = new MembershipService(context.env);
  return json({ interests: await service.setInterests(actor, ids) }, { headers: NO_STORE_HEADERS });
}

/**
 * `GET /api/members/:handle`
 *
 * Somebody else's profile, shaped to what the caller may see. A profile the
 * caller may not see answers 404 rather than 403 — whether a private profile
 * exists is itself private.
 */
export async function showMember(context: RequestContext): Promise<Response> {
  const service = new MembershipService(context.env);
  const profile = await service.readProfile(context.params['handle'] ?? '', context.user);

  // Never cached at the edge: what this response contains depends on who asked.
  return json(profile, { headers: NO_STORE_HEADERS });
}

/**
 * `GET /api/membership/skills`
 *
 * The skill vocabulary, searchable, for the picker. Ordered by how many members
 * hold each — so the list a member sees is the community's actual skills
 * rather than the order somebody seeded them in.
 */
export async function searchSkills(context: RequestContext): Promise<Response> {
  const repository = new MemberRepository(context.env.DB);
  const skills = await repository.skills({
    search: context.query.get('q'),
    category: context.query.get('category'),
  });
  return json({ items: skills, total: skills.length }, { headers: publicCacheHeaders(300) });
}

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

/** `GET /api/notifications` */
export async function listNotifications(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const { page, perPage, offset } = parsePagination(context.query);

  const repository = new NotificationRepository(context.env.DB);
  const { items, total, unread } = await repository.list(actor.id, {
    unreadOnly: context.query.get('unread') === 'true',
    limit: perPage,
    offset,
  });

  return paginated(items, page, perPage, total, {
    ...NO_STORE_HEADERS,
    // Saves the client a second request purely to draw the badge.
    'x-unread-count': String(unread),
  });
}

/** `POST /api/notifications/:id/read` */
export async function markNotificationRead(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const repository = new NotificationRepository(context.env.DB);

  // Scoped to the owner, so quoting an id from somebody else's list does
  // nothing at all — not an error, simply no change.
  const changed = await repository.markRead(context.params['id'] ?? '', actor.id);
  return json(
    { read: changed > 0, unread: await repository.unreadCount(actor.id) },
    { headers: NO_STORE_HEADERS },
  );
}

/** `POST /api/notifications/read-all` */
export async function markAllNotificationsRead(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const repository = new NotificationRepository(context.env.DB);
  const changed = await repository.markAllRead(actor.id);
  return json({ read: changed, unread: 0 }, { headers: NO_STORE_HEADERS });
}

// ---------------------------------------------------------------------------
// Administration
// ---------------------------------------------------------------------------

/**
 * `GET /api/admin/membership/statistics`
 *
 * The community snapshot: how many members, how many working, how many seeking,
 * where they are and what they can do.
 *
 * Aggregates only. An administrator planning community development needs to
 * know that a hundred and eighty members are seeking work; they do not need,
 * and this does not give them, a list of who those people are.
 */
export async function membershipStatistics(context: RequestContext): Promise<Response> {
  const service = new MembershipService(context.env);
  return json(await service.statistics(), { headers: NO_STORE_HEADERS });
}

function asText(value: unknown, max: number): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed === '' ? null : trimmed.slice(0, max);
}


// ---------------------------------------------------------------------------
// THE YAKOLI DIRECTORY (Module 7)
// ---------------------------------------------------------------------------

/**
 * `GET /api/directory`
 *
 * Members who have chosen to be findable, searchable by profession, skill and
 * place.
 *
 * BEING IN THE DIRECTORY IS OPT-IN AND DEFAULTS TO OFF. That is enforced in the
 * query itself rather than in the shaping below, so no mistake in this file can
 * list somebody who asked not to be listed. Each entry is then shaped through
 * `visibleProfile`, because agreeing to be findable is not the same as
 * publishing a phone number.
 *
 * The directory requires a session — it is the community's list of itself, not
 * a public register. `visibleProfile` then shapes each entry: being signed in
 * says you may see the directory, not that you may see any given member's
 * phone number.
 */
export async function searchDirectory(context: RequestContext): Promise<Response> {
  const { page, perPage, offset } = parsePagination(context.query);
  const members = new MemberRepository(context.env.DB);

  const { items, total } = await members.searchDirectory({
    query: context.query.get('q'),
    professionId: context.query.get('profession'),
    skillId: context.query.get('skill'),
    country: context.query.get('country'),
    stateRegion: context.query.get('state'),
    employmentStatus: context.query.get('employment'),
    // ?mentoring=1 — the members who have offered to help somebody younger.
    mentoringOnly: context.query.get('mentoring') === '1',
    limit: perPage,
    offset,
  });

  const relationship: ViewerRelationship = context.user
    ? (can(context.user, 'users:update') ? 'administrator' : 'member')
    : 'stranger';

  const shaped = items
    .map((profile) => visibleProfile(profile as unknown as Record<string, unknown>, relationship))
    .filter((profile): profile is Record<string, unknown> => profile !== null);

  // Never cached at the edge. This is a signed-in view of real people, and one
  // member's page of results must not be served to the next caller.
  return paginated(shaped, page, perPage, total, NO_STORE_HEADERS);
}

/**
 * `GET /api/directory/facets`
 *
 * The professions and countries that actually have somebody behind them.
 *
 * Only occupied ones: a filter list offering thirty professions where
 * twenty-eight return nothing teaches people the directory is empty when it is
 * not.
 */
export async function directoryFacets(context: RequestContext): Promise<Response> {
  const facets = await new MemberRepository(context.env.DB).directoryFacets();
  return json(facets, { headers: publicCacheHeaders() });
}
