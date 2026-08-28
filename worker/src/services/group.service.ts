import { GroupRepository, type GroupRecord } from '../repositories/group.repository';
import { MemberRepository } from '../repositories/member.repository';
import { NotificationRepository } from '../repositories/notification.repository';
import { AuditRepository } from '../repositories/audit.repository';
import { can } from './permissions';
import type { Env } from '../types/env';
import type { AuthenticatedUser } from '../types/auth';
import { BadRequestError, ConflictError, ForbiddenError, NotFoundError } from '../utils/errors';
import { nowIso } from '../utils/id';
import { slugify } from '../utils/slug';

/** The kinds of group the community forms. */
export const GROUP_KINDS = [
  'age_grade',
  'cultural_group',
  'association',
  'union',
  'society',
  'other',
] as const;

export const GROUP_KIND_LABELS: Record<string, string> = {
  age_grade: 'Age grade',
  cultural_group: 'Cultural group',
  association: 'Association',
  union: 'Union',
  society: 'Society',
  other: 'Group',
};

/**
 * COMMUNITY GROUPS
 *
 * Age grades, cultural groups, unions and whatever the community forms next.
 * One table with a `kind`, because the things they all need — a roster, a way
 * to join, officers, dues, somewhere to raise a problem — are the same things,
 * and building them once per sort of group is how they drift apart.
 *
 * TWO IDEAS RUN THROUGH THIS FILE.
 *
 * AUTHORITY IS SCOPED TO ONE GROUP. Being an officer of the Ijom age grade
 * grants nothing anywhere else in the archive — not in another group, not in
 * the editorial workspace. It is a row in `group_admins`, and nothing outside a
 * group's own routes consults it.
 *
 * THE PLATFORM NEVER HOLDS THE MONEY. Dues are declared and confirmed, not
 * taken. See `declarePayment` in the repository for why.
 */
export class GroupService {
  private readonly groups: GroupRepository;
  private readonly members: MemberRepository;

  constructor(private readonly env: Env) {
    this.groups = new GroupRepository(env.DB);
    this.members = new MemberRepository(env.DB);
  }

  get repo(): GroupRepository {
    return this.groups;
  }

  // -------------------------------------------------------------------------
  // Finding a group
  // -------------------------------------------------------------------------

  async find(identifier: string, viewer: AuthenticatedUser | null): Promise<GroupRecord> {
    const statuses = viewer ? null : ['published'];
    const group = await this.groups.findBySlugOrId(identifier, statuses);
    if (!group) throw new NotFoundError('That group was not found.');

    // A signed-in stranger sees no more than an anonymous one. Only the
    // group's own people and the Preservation Team see it before it is
    // published.
    if (group.status !== 'published' && viewer) {
      const officer = await this.groups.adminFor(group.id, viewer.id);
      const member = await this.groups.memberFor(group.id, viewer.id);
      if (!officer && !member && !can(viewer, 'users:update')) {
        throw new NotFoundError('That group was not found.');
      }
    }

    return group;
  }

  // -------------------------------------------------------------------------
  // Creating one
  // -------------------------------------------------------------------------

  /**
   * Registers a group. The person who registers it becomes its lead officer.
   *
   * It arrives as a draft. A community group asserting itself on the archive's
   * public pages is a claim about the community, and the Preservation Team
   * settles those — but the group can fill in its roster, its page and its
   * dues while it waits, so the wait costs nothing.
   */
  async create(
    actor: AuthenticatedUser,
    values: {
      kind: string;
      title: string;
      subtitle: string | null;
      motto: string | null;
      excerpt: string | null;
      body: string | null;
      formedYear: number | null;
      birthYearFrom: number | null;
      birthYearTo: number | null;
      joinPolicy: string;
      contactName: string | null;
      contactPhone: string | null;
      contactEmail: string | null;
    },
    context: { requestId: string },
  ): Promise<{ id: string; slug: string; message: string }> {
    if (!(GROUP_KINDS as readonly string[]).includes(values.kind)) {
      throw new BadRequestError('That is not a kind of group the archive recognises.');
    }

    this.assertBracket(values.kind, values.birthYearFrom, values.birthYearTo);

    const slug = await this.uniqueSlug(values.title);
    const id = await this.groups.create({
      slug,
      kind: values.kind,
      title: values.title,
      subtitle: values.subtitle,
      motto: values.motto,
      excerpt: values.excerpt,
      body: values.body,
      formed_year: values.formedYear,
      birth_year_from: values.birthYearFrom,
      birth_year_to: values.birthYearTo,
      join_policy: values.joinPolicy,
      contact_name: values.contactName,
      contact_phone: values.contactPhone,
      contact_email: values.contactEmail,
      created_by: actor.id,
      status: 'draft',
      verification_status: 'unverified',
    });

    await this.groups.addAdmin({
      groupId: id,
      userId: actor.id,
      adminRole: 'lead',
      office: null,
      appointedBy: actor.id,
    });

    // The person who registered it is a member of it too. Being its officer and
    // not being on its roster is a state nobody expects.
    await this.groups.addMember({
      groupId: id,
      userId: actor.id,
      fullName: actor.displayName,
      membershipState: 'active',
      office: null,
      joinedYear: new Date().getUTCFullYear(),
      birthYear: null,
      notes: null,
      requestNote: null,
      status: 'published',
      addedBy: actor.id,
    });
    await this.groups.recountMembers(id);

    await new AuditRepository(this.env.DB).record({
      actorId: actor.id,
      actorEmail: actor.email,
      action: 'group.registered',
      resourceType: 'community_group',
      resourceId: id,
      changes: { kind: values.kind, title: values.title },
      requestId: context.requestId,
    });

    await this.notifyReviewers(
      'A community group has been registered',
      `${values.title} (${GROUP_KIND_LABELS[values.kind] ?? values.kind}), by ${actor.displayName}.`,
      `/admin/groups/${slug}`,
      id,
    );

    return {
      id,
      slug,
      message:
        'Registered. You are its lead officer: add its members, its page and its dues now. The '
        + 'Preservation Team publishes it once they have looked at it.',
    };
  }

  /**
   * An age grade without a bracket cannot do the one thing an age grade does.
   *
   * The whole point is that a member can be told which grade is theirs, and
   * that question has no answer without years. Requiring it at creation is
   * kinder than letting somebody build a grade nobody can be matched to.
   */
  private assertBracket(kind: string, from: number | null, to: number | null): void {
    if (kind !== 'age_grade') return;

    if (from === null || to === null) {
      throw new BadRequestError(
        'An age grade needs the years of birth it covers, so members can be told which grade is '
          + 'theirs.',
      );
    }
    if (from > to) {
      throw new BadRequestError('The first year of birth must come before the last.');
    }
    if (to - from > 30) {
      throw new BadRequestError('That bracket spans more than thirty years. Please check it.');
    }
  }

  // -------------------------------------------------------------------------
  // Which grades are mine?
  // -------------------------------------------------------------------------

  /**
   * The groups a member should be told about on their dashboard.
   *
   * Age grades whose bracket contains their year of birth, minus the ones they
   * already belong to or have already asked to join.
   *
   * Returns a reason as well as a list, because "we cannot work out your age
   * grade because we do not know when you were born" is a far more useful thing
   * to show somebody than an empty section.
   */
  async suggestionsFor(userId: string): Promise<{
    groups: Record<string, unknown>[];
    needsBirthDate: boolean;
  }> {
    const profile = await this.members.findByUserId(userId);
    if (!profile) return { groups: [], needsBirthDate: false };

    const birthYear = profile['birth_year'] as number | null;
    if (!birthYear) return { groups: [], needsBirthDate: true };

    const eligible = await this.groups.eligibleByBirthYear(Number(birthYear));
    if (eligible.length === 0) return { groups: [], needsBirthDate: false };

    const mine = await this.groups.groupsForUser(userId);
    const already = new Set(mine.map((group) => group.id));

    return {
      groups: eligible
        .filter((group) => !already.has(group.id))
        .map((group) => ({
          id: group.id,
          slug: group.slug,
          kind: group.kind,
          title: group.title,
          subtitle: group.subtitle,
          formed_year: group.formed_year,
          birth_year_from: group.birth_year_from,
          birth_year_to: group.birth_year_to,
          member_count: group.member_count,
          join_policy: group.join_policy,
          // Why this grade is being suggested, said plainly. A suggestion
          // without a reason reads as an advertisement.
          reason: `You were born in ${birthYear}, and this grade is for people born between `
            + `${group.birth_year_from} and ${group.birth_year_to}.`,
        })),
      needsBirthDate: false,
    };
  }

  // -------------------------------------------------------------------------
  // Joining
  // -------------------------------------------------------------------------

  async join(
    actor: AuthenticatedUser,
    identifier: string,
    note: string | null,
  ): Promise<{ state: string; message: string }> {
    const group = await this.find(identifier, actor);

    const existing = await this.groups.memberFor(group.id, actor.id);
    if (existing) {
      if (existing.membership_state === 'active') {
        throw new ConflictError('You are already a member of this group.');
      }
      if (existing.membership_state === 'requested') {
        throw new ConflictError('You have already asked to join. The officers have not answered yet.');
      }
    }

    if (group.join_policy === 'closed' || group.join_policy === 'invite') {
      throw new ForbiddenError(
        'This group is not taking requests. Speak to one of its officers.',
      );
    }

    const profile = await this.members.findByUserId(actor.id);
    const birthYear = (profile?.['birth_year'] as number | null) ?? null;

    // An age grade is defined by its years. Somebody outside the bracket
    // asking to join is almost always a mistake, and it is better caught here
    // than by an officer wondering why.
    if (group.kind === 'age_grade' && group.birth_year_from && group.birth_year_to) {
      if (!birthYear) {
        throw new BadRequestError(
          'Please add your date of birth to your profile first — an age grade is decided by the '
            + 'year you were born.',
        );
      }
      if (birthYear < group.birth_year_from || birthYear > group.birth_year_to) {
        throw new BadRequestError(
          `This grade is for people born between ${group.birth_year_from} and `
            + `${group.birth_year_to}. Yours is ${birthYear}.`,
        );
      }
    }

    // `by_age` means the bracket is the test, and it has just been passed.
    const immediate = group.join_policy === 'open' || group.join_policy === 'by_age';
    const state = immediate ? 'active' : 'requested';

    if (existing) {
      await this.groups.updateMember(existing.id, {
        membership_state: state,
        decided_at: immediate ? nowIso() : null,
      });
    } else {
      await this.groups.addMember({
        groupId: group.id,
        userId: actor.id,
        fullName: profile?.['full_name'] ? String(profile['full_name']) : actor.displayName,
        membershipState: state,
        office: null,
        joinedYear: new Date().getUTCFullYear(),
        birthYear,
        notes: null,
        requestNote: note,
        // The roster entry follows the group's own status: a draft group does
        // not publish names.
        status: group.status === 'published' ? 'published' : 'draft',
        addedBy: actor.id,
      });
    }

    if (immediate) await this.groups.recountMembers(group.id);

    if (!immediate) {
      const officers = await this.groups.admins(group.id);
      await new NotificationRepository(this.env.DB).notifyMany(
        officers.map((officer) => officer.user_id),
        {
          kind: 'membership',
          title: `${actor.displayName} asked to join ${group.title}`,
          body: note ?? 'No note was left.',
          linkPath: `/groups/${group.slug}/manage`,
          resourceType: 'community_group',
          resourceId: group.id,
        },
      );
    }

    return {
      state,
      message: immediate
        ? `You are now a member of ${group.title}.`
        : 'Asked. The officers of this group will answer.',
    };
  }

  /** An officer answering a request to join. */
  async decideMembership(
    actor: AuthenticatedUser,
    memberRowId: string,
    accept: boolean,
  ): Promise<void> {
    const member = await this.groups.findMember(memberRowId);
    if (!member) throw new NotFoundError('That request was not found.');

    await this.assertOfficer(actor, member.group_id);

    await this.groups.updateMember(memberRowId, {
      membership_state: accept ? 'active' : 'declined',
      decided_by: actor.id,
      decided_at: nowIso(),
    });
    await this.groups.recountMembers(member.group_id);

    if (member.user_id) {
      const group = await this.groups.findBySlugOrId(member.group_id, null);
      await new NotificationRepository(this.env.DB).notify({
        userId: member.user_id,
        kind: 'membership',
        title: accept
          ? `You are now a member of ${group?.title ?? 'the group'}`
          : `Your request to join ${group?.title ?? 'the group'} was declined`,
        body: accept
          ? 'You can see its page, its notices and how its dues are paid.'
          : 'Speak to one of its officers if you think this is a mistake.',
        linkPath: group ? `/groups/${group.slug}` : '/account',
        resourceType: 'community_group',
        resourceId: member.group_id,
      });
    }
  }

  // -------------------------------------------------------------------------
  // Authority
  // -------------------------------------------------------------------------

  /**
   * Throws unless this person may act as an officer of this group.
   *
   * The only two ways in: a row in `group_admins` for THIS group, or the
   * Preservation Team's own authority. There is no third.
   */
  async assertOfficer(
    actor: AuthenticatedUser,
    groupId: string,
    role?: 'lead' | 'treasurer',
  ): Promise<void> {
    if (can(actor, 'users:update')) return;

    const officer = await this.groups.adminFor(groupId, actor.id);
    if (!officer) {
      throw new ForbiddenError('Only an officer of this group can do that.');
    }
    if (role === 'lead' && officer.admin_role !== 'lead') {
      throw new ForbiddenError('Only the lead officer of this group can do that.');
    }
    if (role === 'treasurer' && !['lead', 'treasurer'].includes(officer.admin_role)) {
      throw new ForbiddenError('Only the treasurer or lead officer can do that.');
    }
  }

  /** Throws unless this person is on the group's roster. */
  async assertMember(actor: AuthenticatedUser, groupId: string): Promise<void> {
    if (can(actor, 'users:update')) return;

    const member = await this.groups.memberFor(groupId, actor.id);
    if (!member || member.membership_state !== 'active') {
      throw new ForbiddenError('This is for members of the group.');
    }
  }

  // -------------------------------------------------------------------------

  private async notifyReviewers(
    title: string,
    body: string,
    linkPath: string,
    resourceId: string,
  ): Promise<void> {
    const result = await this.env.DB.prepare(
      `SELECT DISTINCT ur."user_id" FROM "user_roles" ur
       INNER JOIN "roles" r ON r."id" = ur."role_id"
       WHERE r."slug" IN ('super_admin', 'deputy_super_admin')`,
    ).all<{ user_id: string }>();

    const reviewers = (result.results ?? []).map((row) => row.user_id);
    if (reviewers.length === 0) return;

    await new NotificationRepository(this.env.DB).notifyMany(reviewers, {
      kind: 'membership',
      title,
      body,
      linkPath,
      resourceType: 'community_group',
      resourceId,
    });
  }

  private async uniqueSlug(title: string): Promise<string> {
    const base = slugify(title) || 'group';
    if (!(await this.groups.slugExists(base))) return base;

    for (let suffix = 2; suffix < 60; suffix += 1) {
      const candidate = `${base}-${suffix}`;
      if (!(await this.groups.slugExists(candidate))) return candidate;
    }
    return `${base}-${Date.now()}`;
  }
}
