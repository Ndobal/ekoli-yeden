import type { RequestContext } from '../types/api';
import { OpportunityRepository, type MatchedOpportunity } from '../repositories/opportunity.repository';
import { MemberRepository } from '../repositories/member.repository';
import { NotificationRepository } from '../repositories/notification.repository';
import { AuditRepository } from '../repositories/audit.repository';
import { locationTier } from '../services/membership';
import { can } from '../services/permissions';
import { readJsonBody, Validator } from '../utils/validation';
import { json, paginated, NO_STORE_HEADERS } from '../utils/responses';
import { parsePagination } from '../utils/pagination';
import { BadRequestError, ForbiddenError, NotFoundError, UnauthorizedError } from '../utils/errors';
import { slugify } from '../utils/slug';
import { nowIso } from '../utils/id';

/**
 * YAKOLI OPPORTUNITIES (Module 6)
 *
 * Jobs, scholarships, training and grants, ordered for the member reading them.
 *
 * ---------------------------------------------------------------------------
 * MEMBERS ONLY, AND NOT FOR THE REASON YOU MIGHT EXPECT
 * ---------------------------------------------------------------------------
 *
 * The rest of this archive is open to anybody, and that is a principle rather
 * than an oversight. This board is not, for two specific reasons:
 *
 *   The whole feature is matching, and matching needs a profile. There is
 *   nothing to show a visitor except an unordered list, which is worse than
 *   what they can get anywhere else.
 *
 *   A public jobs board carrying a community's name is a standing invitation to
 *   whoever wants to defraud that community. Requiring membership to post means
 *   every listing has an accountable person behind it, and requiring it to read
 *   means a fraudulent listing cannot be scraped and spread beyond the people
 *   the archive can warn.
 */

const OPPORTUNITY_KINDS = [
  'job', 'internship', 'apprenticeship', 'scholarship',
  'grant', 'training', 'volunteer', 'tender', 'other',
] as const;

const LOCATION_TIERS = [
  'ekoli_yeden', 'yakurr', 'cross_river', 'nigeria', 'remote', 'international',
] as const;

const REPORT_REASONS = [
  'asks_for_money', 'not_genuine', 'expired', 'misleading', 'offensive', 'duplicate', 'other',
] as const;

/**
 * `GET /api/opportunities`
 *
 * The board, ordered for whoever is asking.
 */
export async function listOpportunities(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const { page, perPage, offset } = parsePagination(context.query);

  const repo = new OpportunityRepository(context.env.DB);
  const profile = await new MemberRepository(context.env.DB).findByUserId(actor.id);

  const { items, total } = await repo.listForMember({
    userId: actor.id,
    profileId: profile ? String(profile['id']) : null,
    // Where this member is, as a tier the sort can use. Derived from what
    // they filled in rather than asked for separately — nobody should have to
    // pick "cross_river" from a list to get sensible results.
    memberTier: profile
        ? locationTier({
            communityArea: profile['community_area'] as string | null,
            lga: profile['lga'] as string | null,
            stateRegion: profile['state_region'] as string | null,
            country: profile['country'] as string | null,
          })
        : null,
    kind: context.query.get('kind'),
    tier: context.query.get('tier'),
    search: context.query.get('q'),
    savedOnly: context.query.get('saved') === 'true',
    limit: perPage,
    offset,
  });

  return paginated(
    items.map((item) => shape(item, profile !== null)),
    page,
    perPage,
    total,
    NO_STORE_HEADERS,
  );
}

/**
 * `GET /api/opportunities/options`
 *
 * What may be posted and where, for the forms and the filter bar.
 */
export async function opportunityOptions(_context: RequestContext): Promise<Response> {
  return json({
    kinds: [
      { value: 'job', label: 'Job' },
      { value: 'internship', label: 'Internship' },
      { value: 'apprenticeship', label: 'Apprenticeship' },
      { value: 'scholarship', label: 'Scholarship' },
      { value: 'grant', label: 'Grant' },
      { value: 'training', label: 'Training' },
      { value: 'volunteer', label: 'Volunteering' },
      { value: 'tender', label: 'Tender' },
      { value: 'other', label: 'Something else' },
    ],
    tiers: [
      { value: 'ekoli_yeden', label: 'In Ekoli-Yeden' },
      { value: 'yakurr', label: 'In Yakurr' },
      { value: 'cross_river', label: 'In Cross River' },
      { value: 'nigeria', label: 'Elsewhere in Nigeria' },
      { value: 'remote', label: 'Remote' },
      { value: 'international', label: 'Outside Nigeria' },
    ],
    employmentTypes: [
      { value: 'full_time', label: 'Full time' },
      { value: 'part_time', label: 'Part time' },
      { value: 'contract', label: 'Contract' },
      { value: 'temporary', label: 'Temporary' },
      { value: 'casual', label: 'Casual' },
      { value: 'self_employed', label: 'Self-employed' },
    ],
    payPeriods: [
      { value: 'month', label: 'a month' },
      { value: 'year', label: 'a year' },
      { value: 'week', label: 'a week' },
      { value: 'day', label: 'a day' },
      { value: 'hour', label: 'an hour' },
      { value: 'once', label: 'in total' },
    ],
    reportReasons: [
      { value: 'asks_for_money', label: 'It asks for money' },
      { value: 'not_genuine', label: 'I do not think it is genuine' },
      { value: 'misleading', label: 'It is misleading' },
      { value: 'expired', label: 'It has already closed' },
      { value: 'offensive', label: 'It is offensive' },
      { value: 'duplicate', label: 'It is a duplicate' },
      { value: 'other', label: 'Something else' },
    ],
  });
}

/** `GET /api/opportunities/:identifier` */
export async function showOpportunity(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const repo = new OpportunityRepository(context.env.DB);

  const reviewer = can(actor, 'opportunities:update');
  const listing = await repo.findBySlugOrId(
    context.params['identifier'] ?? '',
    reviewer ? null : ['published'],
  );
  if (!listing) throw new NotFoundError('That opportunity was not found.');

  const profile = await new MemberRepository(context.env.DB).findByUserId(actor.id);
  const skills = await repo.skillsFor(listing.id);
  const mine = profile ? await repo.memberSkillIds(String(profile['id'])) : new Set<string>();

  await repo.recordView(listing.id);

  return json(
    {
      ...listing,
      // Each skill says whether this member has it. A gap is shown rather than
      // hidden: "this wants bookkeeping, which you have not listed" tells
      // somebody what to learn, where silence tells them nothing.
      skills: skills.map((skill) => ({
        id: skill.id,
        name: skill.name,
        is_required: skill.is_required === 1,
        you_have_it: mine.has(skill.id),
      })),
      matched_skills: skills.filter((skill) => mine.has(skill.id)).length,
      report_count: await repo.openReportCount(listing.id),
      is_owner: listing.posted_by === actor.id,
      can_review: reviewer,
    },
    { headers: NO_STORE_HEADERS },
  );
}

/**
 * `POST /api/opportunities`
 *
 * Any member may post one. It goes to review before anybody sees it — the same
 * rule as every other kind of contribution, and more important here than
 * anywhere, because a fraudulent listing costs somebody money rather than
 * accuracy.
 */
export async function createOpportunity(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const body = await readJsonBody(context.request);

  const validated = new Validator(body)
    .oneOf('kind', OPPORTUNITY_KINDS, { required: true })
    .string('title', { required: true, max: 200, label: 'Title' })
    .string('organisation', { required: true, max: 200, label: 'Organisation' })
    .string('summary', { max: 500, label: 'Summary' })
    .string('description', { max: 20000, label: 'Description' })
    .string('requirements', { max: 8000, label: 'Requirements' })
    .string('benefits', { max: 4000, label: 'Benefits' })
    .oneOf('location_tier', LOCATION_TIERS)
    .string('location_text', { max: 200, label: 'Where' })
    .boolean('is_remote')
    .string('employment_type', { max: 30 })
    .string('pay_currency', { max: 8 })
    .string('pay_period', { max: 10 })
    .string('pay_note', { max: 300, label: 'About the pay' })
    .url('application_url')
    .email('application_email')
    .string('application_phone', { max: 40, label: 'Phone' })
    .string('application_note', { max: 1000, label: 'How to apply' })
    .url('source_url')
    .string('poster_relationship', { max: 200, label: 'Your connection to this' })
    .validated();

  if ('closes_at' in body && body['closes_at']) {
    Object.assign(validated, new Validator(body).date('closes_at', { label: 'Closing date' }).validated());
  }

  const repo = new OpportunityRepository(context.env.DB);
  const id = await repo.create({
    slug: await uniqueSlug(repo, `${validated['title']}-${validated['organisation']}`),
    kind: validated['kind'],
    title: validated['title'],
    organisation: validated['organisation'],
    summary: validated['summary'] ?? null,
    description: validated['description'] ?? null,
    requirements: validated['requirements'] ?? null,
    benefits: validated['benefits'] ?? null,
    location_tier: validated['location_tier'] ?? 'nigeria',
    location_text: validated['location_text'] ?? null,
    is_remote: validated['is_remote'] === 1 || validated['is_remote'] === true ? 1 : 0,
    employment_type: validated['employment_type'] ?? null,
    pay_min: numberOrNull(body['pay_min']),
    pay_max: numberOrNull(body['pay_max']),
    pay_currency: validated['pay_currency'] ?? 'NGN',
    pay_period: validated['pay_period'] ?? null,
    pay_note: validated['pay_note'] ?? null,
    application_url: validated['application_url'] ?? null,
    application_email: validated['application_email'] ?? null,
    application_phone: validated['application_phone'] ?? null,
    application_note: validated['application_note'] ?? null,
    closes_at: validated['closes_at'] ?? null,
    source_url: validated['source_url'] ?? null,
    posted_by: actor.id,
    poster_name: actor.displayName,
    poster_relationship: validated['poster_relationship'] ?? null,
    status: 'pending_review',
  });

  const skillIds = Array.isArray(body['skill_ids']) ? (body['skill_ids'] as unknown[]) : [];
  if (skillIds.length > 0) {
    await repo.setSkills(
      id,
      skillIds.slice(0, 20).map((skillId) => ({ skillId: String(skillId), required: true })),
    );
  }

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: 'opportunity.submitted',
    resourceType: 'opportunity',
    resourceId: id,
    changes: { title: validated['title'], organisation: validated['organisation'] },
    requestId: context.requestId,
  });

  await notifyReviewers(
    context,
    'An opportunity has been submitted',
    `${String(validated['title'])} at ${String(validated['organisation'])}, by ${actor.displayName}.`,
    id,
  );

  return json(
    {
      id,
      message:
        'Thank you. It goes to the Preservation Team before anybody sees it — which is what keeps '
        + 'fraudulent listings off this board.',
    },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

/** `POST /api/opportunities/:id/save` and `DELETE` to undo it. */
export async function saveOpportunity(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const repo = new OpportunityRepository(context.env.DB);
  const listing = await repo.findBySlugOrId(context.params['id'] ?? '', ['published']);
  if (!listing) throw new NotFoundError('That opportunity was not found.');

  if (context.request.method === 'DELETE') {
    await repo.unsave(listing.id, actor.id);
    return json({ saved: false }, { headers: NO_STORE_HEADERS });
  }

  const body = await readJsonBody(context.request).catch(() => ({}) as Record<string, unknown>);
  const note = new Validator(body).string('note', { max: 500 }).validated()['note'] as string | null;

  await repo.save(listing.id, actor.id, note ?? null);
  return json({ saved: true }, { status: 201, headers: NO_STORE_HEADERS });
}

/**
 * `POST /api/opportunities/:id/report`
 *
 * "This is a scam." One press from the listing.
 *
 * A listing gathering several independent reports is taken down automatically
 * pending review, rather than waiting for a reviewer to be awake. A wrongly
 * hidden listing costs somebody a few hours; a fraudulent one left up costs
 * somebody their money.
 */
export async function reportOpportunity(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  const body = await readJsonBody(context.request);

  const validated = new Validator(body)
    .oneOf('reason', REPORT_REASONS, { required: true })
    .string('detail', { max: 2000, label: 'Detail' })
    .validated();

  const repo = new OpportunityRepository(context.env.DB);
  const listing = await repo.findBySlugOrId(context.params['id'] ?? '', null);
  if (!listing) throw new NotFoundError('That opportunity was not found.');

  await repo.report({
    opportunityId: listing.id,
    reportedBy: actor.id,
    reporterName: actor.displayName,
    reason: validated['reason'] as string,
    detail: (validated['detail'] as string | null) ?? null,
  });

  const reports = await repo.openReportCount(listing.id);

  // Two independent reports is enough to hide it. The threshold is low on
  // purpose: this is the one part of the archive where being slow is more
  // expensive than being wrong.
  const hidden = reports >= 2 && listing.is_flagged === 0;
  if (hidden) {
    await repo.update(listing.id, {
      is_flagged: 1,
      flag_reason: `Hidden automatically after ${reports} reports from members.`,
      status: 'pending_review',
    });
  }

  await notifyReviewers(
    context,
    hidden ? 'An opportunity has been hidden after reports' : 'An opportunity has been reported',
    `${listing.title} at ${listing.organisation} — ${reports} report${reports === 1 ? '' : 's'}.`,
    listing.id,
  );

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: 'opportunity.reported',
    resourceType: 'opportunity',
    resourceId: listing.id,
    changes: { reason: validated['reason'], reports, autoHidden: hidden },
    requestId: context.requestId,
  });

  return json(
    {
      message: hidden
        ? 'Thank you. Enough people have reported this that it has been taken down while the '
          + 'Preservation Team looks at it.'
        : 'Thank you. The Preservation Team has been told, and will look at it.',
    },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

// ---------------------------------------------------------------------------
// The Opportunities Editor
// ---------------------------------------------------------------------------

/** `GET /api/admin/opportunities` — what is waiting to be reviewed. */
export async function listForReview(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  if (!can(actor, 'opportunities:update')) {
    throw new ForbiddenError('You do not review opportunities.');
  }

  const { page, perPage, offset } = parsePagination(context.query);
  const repo = new OpportunityRepository(context.env.DB);
  const { items, total } = await repo.listForReview(
    context.query.get('status') ?? 'pending_review',
    perPage,
    offset,
  );

  return paginated(items, page, perPage, total, NO_STORE_HEADERS);
}

/** `PATCH /api/admin/opportunities/:id` — publish, reject, verify, unflag. */
export async function reviewOpportunity(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  if (!can(actor, 'opportunities:update')) {
    throw new ForbiddenError('You do not review opportunities.');
  }

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .oneOf('status', ['draft', 'pending_review', 'approved', 'published', 'archived', 'rejected'])
    .oneOf('verification_status', ['unverified', 'in_review', 'verified', 'disputed'])
    .boolean('is_flagged')
    .string('flag_reason', { max: 500 })
    .validated();

  const repo = new OpportunityRepository(context.env.DB);
  const listing = await repo.findBySlugOrId(context.params['id'] ?? '', null);
  if (!listing) throw new NotFoundError('That opportunity was not found.');

  const values: Record<string, unknown> = { ...validated };
  if (validated['verification_status'] === 'verified') {
    values['verified_by'] = actor.id;
    values['verified_at'] = nowIso();
  }
  if ('is_flagged' in validated) {
    values['is_flagged'] = validated['is_flagged'] === 1 || validated['is_flagged'] === true ? 1 : 0;
  }

  const changed = await repo.update(listing.id, values);
  if (changed === 0) throw new BadRequestError('Nothing was changed.');

  // The person who posted it is told either way. Somebody who submitted a
  // genuine listing and heard nothing assumes the archive ignored them.
  if (listing.posted_by && validated['status']) {
    const published = validated['status'] === 'published';
    await new NotificationRepository(context.env.DB).notify({
      userId: listing.posted_by,
      kind: 'general',
      title: published
        ? `Your listing is live: ${listing.title}`
        : `Your listing was not published: ${listing.title}`,
      body: published
        ? 'Members can see it now, and it is being matched to the people it suits.'
        : 'The Preservation Team did not publish it. Contact them if you think that is wrong.',
      linkPath: `/opportunities/${listing.slug}`,
      resourceType: 'opportunity',
      resourceId: listing.id,
    });
  }

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: 'opportunity.reviewed',
    resourceType: 'opportunity',
    resourceId: listing.id,
    changes: values,
    requestId: context.requestId,
  });

  return json({ message: 'Saved.' }, { headers: NO_STORE_HEADERS });
}

/** `GET /api/admin/opportunities/reports` */
export async function listOpportunityReports(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  if (!can(actor, 'opportunities:update')) {
    throw new ForbiddenError('You do not review opportunities.');
  }

  const repo = new OpportunityRepository(context.env.DB);
  const items = await repo.listReports(context.query.get('state') ?? 'open');
  return json({ items, total: items.length }, { headers: NO_STORE_HEADERS });
}

/** `POST /api/admin/opportunities/reports/:id/settle` */
export async function settleOpportunityReport(context: RequestContext): Promise<Response> {
  const actor = requireUser(context);
  if (!can(actor, 'opportunities:update')) {
    throw new ForbiddenError('You do not review opportunities.');
  }

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .oneOf('state', ['upheld', 'dismissed'], { required: true })
    .string('note', { max: 1000 })
    .validated();

  const repo = new OpportunityRepository(context.env.DB);
  const changed = await repo.settleReport(context.params['id'] ?? '', {
    state: validated['state'] as string,
    reviewedBy: actor.id,
    note: (validated['note'] as string | null) ?? null,
  });
  if (changed === 0) throw new NotFoundError('That report was not found.');

  return json({ message: 'Settled.' }, { headers: NO_STORE_HEADERS });
}

// ---------------------------------------------------------------------------

function requireUser(context: RequestContext) {
  if (!context.user) {
    throw new UnauthorizedError(
      'Please sign in to see opportunities. They are matched to your skills and where you are, so '
        + 'there is nothing useful to show without a profile.',
    );
  }
  return context.user;
}

/** What travels to the client for one listing in a list. */
function shape(item: MatchedOpportunity, hasProfile: boolean): Record<string, unknown> {
  return {
    id: item.id,
    slug: item.slug,
    kind: item.kind,
    title: item.title,
    organisation: item.organisation,
    summary: item.summary,
    location_tier: item.location_tier,
    location_text: item.location_text,
    is_remote: item.is_remote === 1,
    employment_type: item.employment_type,
    pay_min: item.pay_min,
    pay_max: item.pay_max,
    pay_currency: item.pay_currency,
    pay_period: item.pay_period,
    closes_at: item.closes_at,
    verification_status: item.verification_status,
    poster_name: item.poster_name,
    // How well it fits, and whether that number means anything yet. A member
    // with no skills recorded is shown 0 matched everywhere, and being told
    // why is the difference between a useless page and an actionable one.
    matched_skills: item.matched_skills,
    required_skills: item.required_skills,
    total_skills: item.total_skills,
    matching_active: hasProfile,
    is_saved: item.is_saved > 0,
    report_count: item.report_count,
  };
}

function numberOrNull(value: unknown): number | null {
  if (value === null || value === undefined || value === '') return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : null;
}

async function uniqueSlug(repo: OpportunityRepository, base: string): Promise<string> {
  const root = slugify(base).slice(0, 80) || 'opportunity';
  if (!(await repo.slugExists(root))) return root;

  for (let suffix = 2; suffix < 60; suffix += 1) {
    const candidate = `${root}-${suffix}`;
    if (!(await repo.slugExists(candidate))) return candidate;
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
     WHERE r."slug" IN ('super_admin', 'deputy_super_admin', 'opportunities_editor', 'moderator')`,
  ).all<{ user_id: string }>();

  const reviewers = (result.results ?? []).map((row) => row.user_id);
  if (reviewers.length === 0) return;

  await new NotificationRepository(context.env.DB).notifyMany(reviewers, {
    // Must be one of the kinds the notifications table allows.
    kind: 'opportunity_match',
    title,
    body,
    linkPath: '/admin/opportunities',
    resourceType: 'opportunity',
    resourceId,
  });
}
