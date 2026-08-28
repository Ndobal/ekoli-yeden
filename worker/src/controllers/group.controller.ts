import type { RequestContext } from '../types/api';
import { GroupService, GROUP_KINDS, GROUP_KIND_LABELS } from '../services/group.service';
import { GroupRepository } from '../repositories/group.repository';
import { MemberRepository } from '../repositories/member.repository';
import { AuditRepository } from '../repositories/audit.repository';
import { NotificationRepository } from '../repositories/notification.repository';
import { can } from '../services/permissions';
import { readJsonBody, Validator } from '../utils/validation';
import { json, paginated, NO_STORE_HEADERS, publicCacheHeaders } from '../utils/responses';
import { parsePagination } from '../utils/pagination';
import { BadRequestError, NotFoundError, UnauthorizedError } from '../utils/errors';

/**
 * COMMUNITY GROUPS
 *
 * Age grades, cultural groups, associations. The reasoning lives in
 * `services/group.service.ts`; this file is the surface.
 *
 * WHAT IS PUBLIC AND WHAT IS NOT, in one place so it cannot drift:
 *
 *   public   the group's page, its officers, its published roster entries
 *   members  notices, dues owed, how to pay, the payment accounts
 *   officers requests to join, declared payments, issues, account history
 *
 * Bank details are never public. A community's account number on an indexable
 * page is an invitation, and the group can restrict them further — to officers
 * only — if it would rather.
 */

const JOIN_POLICIES = ['open', 'by_age', 'by_request', 'invite', 'closed'] as const;

// ---------------------------------------------------------------------------
// Reading
// ---------------------------------------------------------------------------

/** `GET /api/groups` — the groups of Ekoli-Yeden, newest formed first. */
export async function listGroups(context: RequestContext): Promise<Response> {
  const { page, perPage, offset } = parsePagination(context.query);
  const repo = new GroupRepository(context.env.DB);

  const kind = context.query.get('kind');
  if (kind && !(GROUP_KINDS as readonly string[]).includes(kind)) {
    throw new BadRequestError('That is not a kind of group the archive recognises.');
  }

  const { items, total } = await repo.list({
    kind,
    statuses: ['published'],
    search: context.query.get('q'),
    limit: perPage,
    offset,
  });

  return paginated(items.map(shapeGroup), page, perPage, total, publicCacheHeaders());
}

/** `GET /api/groups/kinds` — what a group may be, for a picker. */
export async function groupKinds(_context: RequestContext): Promise<Response> {
  return json({
    kinds: GROUP_KINDS.map((kind) => ({ value: kind, label: GROUP_KIND_LABELS[kind] ?? kind })),
    joinPolicies: [
      { value: 'by_age', label: 'Anyone born in the right years may join', forKind: 'age_grade' },
      { value: 'open', label: 'Anyone may join' },
      { value: 'by_request', label: 'People ask, and the officers decide' },
      { value: 'invite', label: 'By invitation only' },
      { value: 'closed', label: 'Not taking anybody at the moment' },
    ],
  });
}

/**
 * `GET /api/groups/:identifier`
 *
 * One group with everything a visitor may see, plus everything the viewer's own
 * standing in it entitles them to. One request rather than five, because a
 * group page is useless in pieces.
 */
export async function showGroup(context: RequestContext): Promise<Response> {
  const service = new GroupService(context.env);
  const group = await service.find(context.params['identifier'] ?? '', context.user);
  const repo = service.repo;

  const viewer = context.user;
  const officer = viewer ? await repo.adminFor(group.id, viewer.id) : null;
  const membership = viewer ? await repo.memberFor(group.id, viewer.id) : null;
  const isMember = membership?.membership_state === 'active';
  const isOfficer = officer !== null || (viewer !== null && can(viewer, 'users:update'));

  const [officers, roster, posts] = await Promise.all([
    repo.admins(group.id),
    // Only roster entries the member agreed to publish are shown to the
    // public. Being in a grade is not consent to be listed on the internet.
    repo.members(group.id, ['active'], isOfficer ? ['draft', 'published'] : ['published']),
    repo.posts(group.id, isMember || isOfficer ? ['draft', 'published'] : ['published']),
  ]);

  return json(
    {
      ...shapeGroup(group),
      body: group.body,
      officers: officers.map((row) => ({
        user_id: row.user_id,
        name: row.display_name,
        role: row.admin_role,
        office: row.office,
      })),
      roster: roster.map((row) => ({
        id: row.id,
        name: row.full_name,
        office: row.office,
        joined_year: row.joined_year,
        is_deceased: row.is_deceased === 1,
      })),
      posts,
      // Where the viewer stands, so the client never has to guess which
      // controls to draw.
      viewer: {
        is_member: isMember,
        is_officer: isOfficer,
        officer_role: officer?.admin_role ?? null,
        membership_state: membership?.membership_state ?? null,
        can_request_to_join:
          viewer !== null && !membership && ['open', 'by_age', 'by_request'].includes(group.join_policy),
      },
      // Bank details travel only to people entitled to them.
      payment_accounts: isMember || isOfficer
        ? (await repo.paymentAccounts(group.id))
            .filter((account) => account['visibility'] !== 'admins' || isOfficer)
        : [],
    },
    { headers: NO_STORE_HEADERS },
  );
}

/**
 * `GET /api/membership/groups/suggestions`
 *
 * "Which age grade is mine?" — answered on the member's own dashboard.
 */
export async function groupSuggestions(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const service = new GroupService(context.env);

  const [suggestions, mine] = await Promise.all([
    service.suggestionsFor(actor.id),
    service.repo.groupsForUser(actor.id),
  ]);

  return json(
    {
      ...suggestions,
      mine: mine.map((group) => ({ ...shapeGroup(group), membership_state: group.membership_state })),
      // The dashboard needs to say WHY it cannot suggest anything, rather than
      // showing an empty box.
      prompt: suggestions.needsBirthDate
        ? 'Add your date of birth and we can tell you which age grade is yours.'
        : null,
    },
    { headers: NO_STORE_HEADERS },
  );
}

// ---------------------------------------------------------------------------
// Registering and running one
// ---------------------------------------------------------------------------

/** `POST /api/groups` */
export async function createGroup(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const body = await readJsonBody(context.request);

  const validated = new Validator(body)
    .oneOf('kind', GROUP_KINDS, { required: true })
    .string('title', { required: true, max: 200, label: 'Name' })
    .string('subtitle', { max: 300, label: 'Subtitle' })
    .string('motto', { max: 300, label: 'Motto' })
    .string('excerpt', { max: 1000, label: 'Summary' })
    .string('body', { max: 40000, label: 'About' })
    .integer('formed_year', { min: 1800, max: 2200, label: 'Year formed' })
    .integer('birth_year_from', { min: 1900, max: 2200, label: 'Born from' })
    .integer('birth_year_to', { min: 1900, max: 2200, label: 'Born until' })
    .oneOf('join_policy', JOIN_POLICIES)
    .string('contact_name', { max: 200, label: 'Contact' })
    .string('contact_phone', { max: 30, label: 'Phone' })
    .email('contact_email')
    .validated();

  const result = await new GroupService(context.env).create(
    actor,
    {
      kind: validated['kind'] as string,
      title: validated['title'] as string,
      subtitle: (validated['subtitle'] as string | null) ?? null,
      motto: (validated['motto'] as string | null) ?? null,
      excerpt: (validated['excerpt'] as string | null) ?? null,
      body: (validated['body'] as string | null) ?? null,
      formedYear: (validated['formed_year'] as number | null) ?? null,
      birthYearFrom: (validated['birth_year_from'] as number | null) ?? null,
      birthYearTo: (validated['birth_year_to'] as number | null) ?? null,
      joinPolicy: (validated['join_policy'] as string | null) ?? 'by_request',
      contactName: (validated['contact_name'] as string | null) ?? null,
      contactPhone: (validated['contact_phone'] as string | null) ?? null,
      contactEmail: (validated['contact_email'] as string | null) ?? null,
    },
    { requestId: context.requestId },
  );

  return json(result, { status: 201, headers: NO_STORE_HEADERS });
}

/** `PATCH /api/groups/:id` — the group's own page, edited by its officers. */
export async function updateGroup(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const service = new GroupService(context.env);
  const group = await service.find(context.params['id'] ?? '', actor);
  await service.assertOfficer(actor, group.id);

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('title', { max: 200, label: 'Name' })
    .string('subtitle', { max: 300, label: 'Subtitle' })
    .string('motto', { max: 300, label: 'Motto' })
    .string('excerpt', { max: 1000, label: 'Summary' })
    .string('body', { max: 40000, label: 'About' })
    .integer('formed_year', { min: 1800, max: 2200, label: 'Year formed' })
    .integer('birth_year_from', { min: 1900, max: 2200, label: 'Born from' })
    .integer('birth_year_to', { min: 1900, max: 2200, label: 'Born until' })
    .oneOf('join_policy', JOIN_POLICIES)
    .string('dues_notes', { max: 4000, label: 'About the dues' })
    .string('dues_period', { max: 40, label: 'How often' })
    .string('contact_name', { max: 200, label: 'Contact' })
    .string('contact_phone', { max: 30, label: 'Phone' })
    .email('contact_email')
    .validated();

  if ('dues_amount' in body && body['dues_amount'] !== null && body['dues_amount'] !== '') {
    const amount = Number(body['dues_amount']);
    if (!Number.isFinite(amount) || amount < 0) throw new BadRequestError('That is not an amount.');
    validated['dues_amount'] = amount;
    validated['dues_updated_at'] = new Date().toISOString();
  }

  const changed = await service.repo.updateOwnFields(group.id, validated);
  if (changed === 0) throw new BadRequestError('Nothing was changed.');

  return json({ message: 'Saved.' }, { headers: NO_STORE_HEADERS });
}

/** `POST /api/groups/:id/join` */
export async function joinGroup(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const body = await readJsonBody(context.request).catch(() => ({}) as Record<string, unknown>);
  const note = new Validator(body).string('note', { max: 1000 }).validated()['note'] as string | null;

  const result = await new GroupService(context.env).join(
    actor,
    context.params['id'] ?? '',
    note ?? null,
  );

  return json(result, { status: 201, headers: NO_STORE_HEADERS });
}

/** `GET /api/groups/:id/requests` — who is waiting, for the officers. */
export async function listJoinRequests(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const service = new GroupService(context.env);
  const group = await service.find(context.params['id'] ?? '', actor);
  await service.assertOfficer(actor, group.id);

  const items = await service.repo.members(group.id, ['requested'], ['draft', 'published']);
  return json({ items, total: items.length }, { headers: NO_STORE_HEADERS });
}

/** `POST /api/groups/members/:memberId/decide` */
export async function decideJoinRequest(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const body = await readJsonBody(context.request);
  const accept = new Validator(body).boolean('accept', { required: true }).validated()['accept'];

  await new GroupService(context.env).decideMembership(
    actor,
    context.params['memberId'] ?? '',
    accept === 1 || accept === true,
  );

  return json({ message: 'Answered.' }, { headers: NO_STORE_HEADERS });
}

/** `POST /api/groups/:id/officers` — the lead officer appoints the others. */
export async function addOfficer(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const service = new GroupService(context.env);
  const group = await service.find(context.params['id'] ?? '', actor);
  await service.assertOfficer(actor, group.id, 'lead');

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('handle', { max: 60, label: 'Member' })
    .string('user_id', { max: 64, label: 'Member' })
    .oneOf('admin_role', ['lead', 'admin', 'treasurer'], { required: true })
    .string('office', { max: 120, label: 'Office' })
    .validated();

  let userId = validated['user_id'] as string | null;
  if (!userId) {
    const handle = validated['handle'] as string | null;
    if (!handle) throw new BadRequestError('Say which member.');
    const profile = await new MemberRepository(context.env.DB).findByHandle(handle);
    if (!profile) throw new NotFoundError('That member was not found.');
    userId = String(profile['user_id']);
  }

  await service.repo.addAdmin({
    groupId: group.id,
    userId,
    adminRole: validated['admin_role'] as string,
    office: (validated['office'] as string | null) ?? null,
    appointedBy: actor.id,
  });

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: 'group.officer.appointed',
    resourceType: 'community_group',
    resourceId: group.id,
    changes: { userId, role: validated['admin_role'] },
    requestId: context.requestId,
  });

  return json({ message: 'Appointed.' }, { status: 201, headers: NO_STORE_HEADERS });
}

/** `DELETE /api/groups/:id/officers/:userId` */
export async function removeOfficer(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const service = new GroupService(context.env);
  const group = await service.find(context.params['id'] ?? '', actor);
  await service.assertOfficer(actor, group.id, 'lead');

  const userId = context.params['userId'] ?? '';
  const officer = await service.repo.adminFor(group.id, userId);

  // A group with no lead officer has nobody who can appoint one, which is a
  // state it cannot get itself out of.
  if (officer?.admin_role === 'lead' && (await service.repo.countLeads(group.id)) <= 1) {
    throw new BadRequestError(
      'This is the only lead officer. Appoint another before standing this one down.',
    );
  }

  await service.repo.removeAdmin(group.id, userId);
  return json({ message: 'Stood down.' }, { headers: NO_STORE_HEADERS });
}

// ---------------------------------------------------------------------------
// Money
// ---------------------------------------------------------------------------

/** `POST /api/groups/:id/accounts` — where members should send the dues. */
export async function addPaymentAccount(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const service = new GroupService(context.env);
  const group = await service.find(context.params['id'] ?? '', actor);
  await service.assertOfficer(actor, group.id, 'treasurer');

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('bank_name', { required: true, max: 200, label: 'Bank' })
    .string('account_name', { required: true, max: 200, label: 'Account name' })
    .string('account_number', { required: true, max: 40, label: 'Account number' })
    .string('label', { max: 120, label: 'Label' })
    .string('swift_code', { max: 20, label: 'SWIFT' })
    .string('sort_code', { max: 20, label: 'Sort code' })
    .string('instructions', { max: 2000, label: 'Instructions' })
    .oneOf('visibility', ['members', 'admins'])
    .boolean('is_primary')
    .validated();

  const id = await service.repo.addAccount({
    groupId: group.id,
    label: (validated['label'] as string | null) ?? null,
    bankName: validated['bank_name'] as string,
    accountName: validated['account_name'] as string,
    accountNumber: validated['account_number'] as string,
    swiftCode: (validated['swift_code'] as string | null) ?? null,
    sortCode: (validated['sort_code'] as string | null) ?? null,
    instructions: (validated['instructions'] as string | null) ?? null,
    visibility: (validated['visibility'] as string | null) ?? 'members',
    isPrimary: validated['is_primary'] !== 0 && validated['is_primary'] !== false,
    addedBy: actor.id,
  });

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: 'group.account.added',
    resourceType: 'community_group',
    resourceId: group.id,
    changes: { accountId: id, bank: validated['bank_name'] },
    requestId: context.requestId,
  });

  return json(
    {
      id,
      message: 'Saved. Members can see these details on the group page; the public cannot.',
    },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

/**
 * `PATCH /api/groups/:id/accounts/:accountId`
 *
 * Every change records what the value used to be. Redirecting a community's
 * dues is the obvious way to steal from one, and the group should never have to
 * take anybody's word for what an account number was last month.
 */
export async function updatePaymentAccount(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const service = new GroupService(context.env);
  const group = await service.find(context.params['id'] ?? '', actor);
  await service.assertOfficer(actor, group.id, 'treasurer');

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('bank_name', { max: 200, label: 'Bank' })
    .string('account_name', { max: 200, label: 'Account name' })
    .string('account_number', { max: 40, label: 'Account number' })
    .string('label', { max: 120, label: 'Label' })
    .string('instructions', { max: 2000, label: 'Instructions' })
    .oneOf('visibility', ['members', 'admins'])
    .boolean('is_active')
    .boolean('is_primary')
    .validated();

  const changed = await service.repo.updateAccount(context.params['accountId'] ?? '', validated, {
    id: actor.id,
    name: actor.displayName,
  });
  if (changed === 0) throw new BadRequestError('That account was not found, or nothing changed.');

  return json(
    { message: 'Changed. The previous details are kept in the group\'s record of changes.' },
    { headers: NO_STORE_HEADERS },
  );
}

/** `GET /api/groups/:id/accounts/history` — who changed what, and from what. */
export async function accountHistory(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const service = new GroupService(context.env);
  const group = await service.find(context.params['id'] ?? '', actor);
  await service.assertOfficer(actor, group.id);

  const items = await service.repo.accountChanges(group.id);
  return json({ items, total: items.length }, { headers: NO_STORE_HEADERS });
}

/**
 * `POST /api/groups/:id/dues`
 *
 * A member recording that they have paid.
 *
 * The platform never receives the money. The member sends it to the group's
 * account the way they already would, and records it here so both sides are
 * looking at the same list. A treasurer confirms it against the bank.
 */
export async function declareDues(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const service = new GroupService(context.env);
  const group = await service.find(context.params['id'] ?? '', actor);
  await service.assertMember(actor, group.id);

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('period_label', { max: 60, label: 'What it is for' })
    .oneOf('method', ['bank_transfer', 'cash', 'mobile_money', 'cheque', 'other'])
    .string('reference', { max: 120, label: 'Reference' })
    .string('note', { max: 1000, label: 'Note' })
    .string('proof_media_id', { max: 64 })
    .validated();

  if ('paid_on' in body && body['paid_on']) {
    Object.assign(validated, new Validator(body).date('paid_on', { label: 'Date paid' }).validated());
  }

  const amount = Number(body['amount']);
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new BadRequestError('Please give the amount you paid.');
  }

  const membership = await service.repo.memberFor(group.id, actor.id);

  const id = await service.repo.declarePayment({
    groupId: group.id,
    memberId: membership?.id ?? null,
    userId: actor.id,
    payerName: actor.displayName,
    amount,
    currency: group.dues_currency || 'NGN',
    periodLabel: (validated['period_label'] as string | null) ?? null,
    paidOn: (validated['paid_on'] as string | null) ?? null,
    method: (validated['method'] as string | null) ?? 'bank_transfer',
    reference: (validated['reference'] as string | null) ?? null,
    note: (validated['note'] as string | null) ?? null,
    proofMediaId: (validated['proof_media_id'] as string | null) ?? null,
  });

  return json(
    {
      id,
      state: 'declared',
      message:
        'Recorded. The treasurer will confirm it against the account. This is a record of what '
        + 'you say you have paid — no money passes through this website.',
    },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

/** `GET /api/groups/:id/dues` — mine, or everybody's if I am an officer. */
export async function listDues(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const service = new GroupService(context.env);
  const group = await service.find(context.params['id'] ?? '', actor);
  await service.assertMember(actor, group.id);

  const officer = await service.repo.adminFor(group.id, actor.id);
  const isOfficer = officer !== null || can(actor, 'users:update');

  const { page, perPage, offset } = parsePagination(context.query);
  const { items, total } = await service.repo.payments({
    groupId: group.id,
    // A member sees their own payments and nobody else's. What the group has
    // collected in total is the officers' business to publish, not a number
    // every member can derive from a list of names.
    userId: isOfficer ? context.query.get('user_id') : actor.id,
    state: context.query.get('state'),
    limit: perPage,
    offset,
  });

  const summary = isOfficer ? await service.repo.duesSummary(group.id) : null;

  return json(
    {
      items,
      total,
      page,
      perPage,
      totalPages: Math.max(1, Math.ceil(total / perPage)),
      summary,
      dues: {
        amount: group.dues_amount,
        currency: group.dues_currency,
        period: group.dues_period,
        notes: group.dues_notes,
      },
    },
    { headers: NO_STORE_HEADERS },
  );
}

/** `POST /api/groups/dues/:paymentId/settle` — the treasurer's confirmation. */
export async function settleDues(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const service = new GroupService(context.env);

  const payment = await service.repo.findPayment(context.params['paymentId'] ?? '');
  if (!payment) throw new NotFoundError('That payment was not found.');

  await service.assertOfficer(actor, String(payment['group_id']), 'treasurer');

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .oneOf('state', ['confirmed', 'disputed', 'cancelled'], { required: true })
    .string('officer_note', { max: 1000, label: 'Note' })
    .validated();

  await service.repo.settlePayment(String(payment['id']), validated['state'] as string, {
    id: actor.id,
    note: (validated['officer_note'] as string | null) ?? null,
  });

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: 'group.dues.settled',
    resourceType: 'group_dues_payment',
    resourceId: String(payment['id']),
    changes: { state: validated['state'], amount: payment['amount'] },
    requestId: context.requestId,
  });

  return json({ message: 'Recorded.' }, { headers: NO_STORE_HEADERS });
}

// ---------------------------------------------------------------------------
// Issues
// ---------------------------------------------------------------------------

/** `POST /api/groups/:id/issues` — a member raising something with the officers. */
export async function raiseIssue(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const service = new GroupService(context.env);
  const group = await service.find(context.params['id'] ?? '', actor);
  await service.assertMember(actor, group.id);

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .oneOf('kind', ['dues', 'membership', 'conduct', 'correction', 'finance', 'leadership', 'other'], {
      required: true,
    })
    .string('subject', { required: true, max: 200, label: 'Subject' })
    .string('detail', { max: 8000, label: 'Detail' })
    .boolean('is_private')
    .validated();

  const id = await service.repo.raiseIssue({
    groupId: group.id,
    raisedBy: actor.id,
    raisedByName: actor.displayName,
    kind: validated['kind'] as string,
    subject: validated['subject'] as string,
    detail: (validated['detail'] as string | null) ?? null,
    // Private by default. Somebody raising a concern about money should not
    // have to know to tick a box for it not to be read by the person they are
    // raising it about.
    isPrivate: validated['is_private'] !== 0 && validated['is_private'] !== false,
  });

  const officers = await service.repo.admins(group.id);
  await new NotificationRepository(context.env.DB).notifyMany(
    officers.map((officer) => officer.user_id),
    {
      kind: 'membership',
      title: `${actor.displayName} raised something with ${group.title}`,
      body: validated['subject'] as string,
      linkPath: `/groups/${group.slug}/manage`,
      resourceType: 'group_issue',
      resourceId: id,
    },
  );

  return json(
    { id, message: 'Raised. The officers of this group have been told.' },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

/** `GET /api/groups/:id/issues` */
export async function listIssues(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const service = new GroupService(context.env);
  const group = await service.find(context.params['id'] ?? '', actor);
  await service.assertMember(actor, group.id);

  const officer = await service.repo.adminFor(group.id, actor.id);
  const isOfficer = officer !== null || can(actor, 'users:update');

  const items = await service.repo.issues(group.id, {
    // A member sees what they themselves raised. An officer sees everything,
    // because a private issue is private from the rest of the group, not from
    // the people it was addressed to.
    raisedBy: isOfficer ? null : actor.id,
    state: context.query.get('state'),
  });

  return json({ items, total: items.length, is_officer: isOfficer }, { headers: NO_STORE_HEADERS });
}

/** `POST /api/groups/issues/:issueId/settle` */
export async function settleIssue(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const service = new GroupService(context.env);

  const issue = await service.repo.findIssue(context.params['issueId'] ?? '');
  if (!issue) throw new NotFoundError('That was not found.');

  await service.assertOfficer(actor, String(issue['group_id']));

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .oneOf('state', ['acknowledged', 'resolved', 'closed'], { required: true })
    .string('resolution', { max: 4000, label: 'What was done' })
    .validated();

  await service.repo.settleIssue(String(issue['id']), {
    state: validated['state'] as string,
    resolution: (validated['resolution'] as string | null) ?? null,
    handledBy: actor.id,
  });

  if (issue['raised_by']) {
    await new NotificationRepository(context.env.DB).notify({
      userId: String(issue['raised_by']),
      kind: 'membership',
      title: `Your group has answered: ${String(issue['subject'])}`,
      body: (validated['resolution'] as string | null) ?? 'The officers have looked at it.',
      linkPath: '/account',
      resourceType: 'group_issue',
      resourceId: String(issue['id']),
    });
  }

  return json({ message: 'Answered.' }, { headers: NO_STORE_HEADERS });
}

// ---------------------------------------------------------------------------

function requireUser(context: RequestContext) {
  if (!context.user) throw new UnauthorizedError('Please sign in to continue.');
  return context.user;
}

/**
 * The fields of a group that are safe on any route.
 *
 * Takes the record loosely rather than as a `GroupRecord`, so the same shaping
 * serves a bare group, a group joined to a membership row, and anything else a
 * query hands back. The allow-list below is what makes that safe: a column
 * added to the table later does not start appearing on public responses because
 * a query happened to select it.
 */
function shapeGroup(group: Record<string, unknown> | object): Record<string, unknown> {
  const row = group as Record<string, unknown>;
  return shapeRow(row);
}

function shapeRow(group: Record<string, unknown>): Record<string, unknown> {
  return {
    id: group['id'],
    slug: group['slug'],
    kind: group['kind'],
    kind_label: GROUP_KIND_LABELS[String(group['kind'])] ?? 'Group',
    title: group['title'],
    subtitle: group['subtitle'],
    motto: group['motto'],
    excerpt: group['excerpt'],
    formed_year: group['formed_year'],
    birth_year_from: group['birth_year_from'],
    birth_year_to: group['birth_year_to'],
    join_policy: group['join_policy'],
    member_count: group['member_count'],
    dues_amount: group['dues_amount'],
    dues_currency: group['dues_currency'],
    dues_period: group['dues_period'],
    dues_notes: group['dues_notes'],
    cover_media_id: group['cover_media_id'],
    verification_status: group['verification_status'],
    status: group['status'],
  };
}
