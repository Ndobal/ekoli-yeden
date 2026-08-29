import { MemberRepository, type MemberProfileRecord } from '../repositories/member.repository';
import { MessagingRepository } from '../repositories/messaging.repository';
import { ForumRepository } from '../repositories/forum.repository';
import { NotificationRepository } from '../repositories/notification.repository';
import { UserRepository } from '../repositories/user.repository';
import { SettingsRepository } from '../repositories/settings.repository';
import { AuditRepository } from '../repositories/audit.repository';
import {
  completionPercent,
  handleFrom,
  isDiaspora,
  isInEkoliYeden,
  nextMembershipNumber,
  visibleProfile,
  workGroupFor,
  type ViewerRelationship,
} from './membership';
import { can } from './permissions';
import { PlacesService } from './places.service';
import type { Env } from '../types/env';
import type { AuthenticatedUser } from '../types/auth';
import { BadRequestError, ConflictError, ForbiddenError, NotFoundError } from '../utils/errors';
import { nowIso } from '../utils/id';
import { publicMediaUrl } from '../utils/files';

/**
 * YAKOLI MEMBERSHIP
 *
 * One Okoli account, and the rules around it.
 *
 * The important thing this file does is decide *who may see what*. Every route
 * that returns a profile passes through `readProfile` or `readOwnProfile`, so a
 * new endpoint cannot leak somebody's phone number by forgetting a check — the
 * check is not something a caller opts into.
 */
export class MembershipService {
  private readonly members: MemberRepository;
  private readonly users: UserRepository;
  private readonly settings: SettingsRepository;

  constructor(private readonly env: Env) {
    this.members = new MemberRepository(env.DB);
    this.users = new UserRepository(env.DB);
    this.settings = new SettingsRepository(env.DB);
  }

  get repo(): MemberRepository {
    return this.members;
  }

  // -------------------------------------------------------------------------
  // Joining
  // -------------------------------------------------------------------------

  /**
   * Turns an account into a membership.
   *
   * Deliberately separate from registration. An Editorial Team volunteer has an
   * account and may never join the Yakoli community; a member may join years
   * after registering. Forcing the two together would mean either every editor
   * gets a profile they never asked for, or joining requires a second account —
   * and the second is exactly what this module exists to prevent.
   */
  async join(
    user: AuthenticatedUser,
    values: { fullName?: string | null },
    context: { requestId: string },
  ): Promise<{ profileId: string; membershipNumber: string; handle: string; status: string }> {
    if (!(await this.settingEnabled('membership_open', true))) {
      throw new ForbiddenError(
        'Membership is closed at the moment. Please contact the Preservation Team.',
      );
    }

    const existing = await this.members.findByUserId(user.id);
    if (existing) {
      throw new ConflictError('You are already a member of the Yakoli community.');
    }

    const fullName = values.fullName?.trim() || user.displayName;
    const handle = await this.uniqueHandle(fullName, user.id);
    const status = (await this.settingEnabled('membership_requires_approval', false))
      ? 'pending'
      : 'active';

    const profileId = await this.members.create({
      userId: user.id,
      membershipNumber: await nextMembershipNumber(this.env.DB),
      handle,
      fullName,
      membershipStatus: status,
    });

    // The role is what actually opens the forums, the opportunities board and
    // the directory. Granted here rather than at registration, for the same
    // reason the profile is.
    const role = await this.users.findRoleBySlug('okoli_member');
    if (role) await this.users.assignRole(user.id, role.id, null);

    // AND THE GENERAL FORUM, IN THE SAME ACT.
    //
    // Every registered person belongs to it from the moment they register and
    // nobody has to ask — that is what makes it the room the whole community
    // can be reached in.
    await this.joinDefaultForum(user.id);

    const profile = await this.members.findByUserId(user.id);
    await this.recalculateCompletion(profile);

    await new NotificationRepository(this.env.DB).notify({
      userId: user.id,
      kind: 'membership',
      title: 'Welcome to the Yakoli community',
      body:
        status === 'pending'
          ? 'Your membership is waiting to be confirmed. You can fill in your profile in the meantime.'
          : 'Your membership is active. Fill in your profile so the community can find you — you '
            + 'decide what appears and what stays private.',
      linkPath: '/account/profile',
      resourceType: 'membership',
      resourceId: profileId,
    });

    await new AuditRepository(this.env.DB).record({
      actorId: user.id,
      actorEmail: user.email,
      action: 'membership.joined',
      resourceType: 'member_profile',
      resourceId: profileId,
      changes: { handle, status },
      requestId: context.requestId,
    });

    return {
      profileId,
      membershipNumber: profile?.membership_number ?? '',
      handle,
      status,
    };
  }

  /**
   * Makes sure this account has a membership, creating one if it does not.
   *
   * ---------------------------------------------------------------------------
   * REGISTERING IS JOINING
   * ---------------------------------------------------------------------------
   *
   * There is no separate contributor account. Everybody who registers is a
   * member of Ekoli-Yeden: they get a profile, the member dashboard, and the
   * permission to contribute — which the old `contributor` role did not
   * actually carry, so an account named for contributing could not contribute.
   *
   * Idempotent, and cheap when there is nothing to do, because it is called
   * from two places: at registration, and when a dashboard is opened. The
   * second is what heals every account created before this change — including
   * accounts an administrator made by hand — on their next visit, with a handle
   * built from the name they already have rather than a generated one.
   *
   * Never throws for an account that already has a profile, and never
   * downgrades an existing one.
   */
  /**
   * Puts somebody in the General Forum.
   *
   * Called from BOTH creation paths, which is the whole reason it exists as a
   * method: it was first written inside `join()` alone, and registration goes
   * through `ensureMembership()` — so every account created by registering was
   * a member of the community and a member of no forum. The test account that
   * found it had `isMember: true`, a handle, a membership number, and no way
   * into the room every member is supposed to be in.
   *
   * Silent when no default space is configured. A community that has not
   * nominated one is not an error; it simply has no automatic forum.
   */
  private async joinDefaultForum(userId: string): Promise<void> {
    const forum = new ForumRepository(this.env.DB);
    const general = await forum.defaultSpace();
    if (!general) return;

    // Two indexed reads rather than a write on every call. This runs on every
    // `/api/auth/me`, and the common case by far is that the row already
    // exists — nobody leaves the General Forum, so any row at all means the
    // work is done.
    const existing = await forum.membershipFor(general.id, userId);
    if (existing) return;

    await forum.setMembership({
      spaceId: general.id,
      userId,
      state: 'member',
    });
  }

  async ensureMembership(
    user: AuthenticatedUser,
    context: { requestId: string },
  ): Promise<void> {
    // THE FORUM IS CHECKED BEFORE THE EARLY RETURN, AND SEPARATELY.
    //
    // An account can have a profile and no forum membership: every account
    // registered between the forum-membership migration and the fix below was
    // in exactly that state, and so is every account whose profile was
    // repaired by an earlier version of this method.
    //
    // Putting this after the `existing` check meant the repair only ever ran
    // for accounts that had no profile — which is to say, never for the ones
    // that actually needed it.
    await this.joinDefaultForum(user.id);

    const existing = await this.members.findByUserId(user.id);
    if (existing) return;

    // Membership being closed does not stop an account from existing — it
    // stops new people joining. An account that is already here and has no
    // profile is a gap to close, not a new arrival to turn away.
    const status = (await this.settingEnabled('membership_requires_approval', false))
      ? 'pending'
      : 'active';

    const fullName = user.displayName;
    const handle = await this.uniqueHandle(fullName, user.id);

    const profileId = await this.members.create({
      userId: user.id,
      membershipNumber: await nextMembershipNumber(this.env.DB),
      handle,
      fullName,
      membershipStatus: status,
    });

    const role = await this.users.findRoleBySlug('okoli_member');
    if (role) await this.users.assignRole(user.id, role.id, null);

    // And the General Forum. Registration reaches membership through THIS
    // method, so an account created without this line is a member of the
    // community and a member of no forum.
    await this.joinDefaultForum(user.id);

    const profile = await this.members.findByUserId(user.id);
    await this.recalculateCompletion(profile);

    await new AuditRepository(this.env.DB).record({
      actorId: user.id,
      actorEmail: user.email,
      action: 'membership.created',
      resourceType: 'member_profile',
      resourceId: profileId,
      changes: { handle, status, via: 'automatic' },
      requestId: context.requestId,
    });
  }

  // -------------------------------------------------------------------------
  // Reading
  // -------------------------------------------------------------------------

  /** The member's own profile, in full. */
  async readOwnProfile(user: AuthenticatedUser): Promise<Record<string, unknown>> {
    const row = await this.members.findFullByUserId(user.id);
    if (!row) {
      throw new NotFoundError(
        'You are not a member of the Yakoli community yet. Join to keep a profile.',
      );
    }

    const decorated = await this.decorate(row);
    const shaped = visibleProfile(decorated, 'self');
    return shaped ?? decorated;
  }

  /**
   * Somebody else's profile, shaped to what this viewer may see.
   *
   * A profile the viewer may not see is a 404, not a 403. Whether a private
   * profile exists is itself private — "that member exists but you cannot see
   * them" is information, and the platform does not hand it out.
   */
  async readProfile(
    handle: string,
    viewer: AuthenticatedUser | null,
  ): Promise<Record<string, unknown>> {
    const row = await this.members.findFullByHandle(handle);
    if (!row) throw new NotFoundError('That member was not found.');

    // Somebody looking at their own profile through the public route sees it
    // whole, which is what they expect.
    const isSelf = viewer !== null && row['user_id'] === viewer.id;
    const relationship: ViewerRelationship = isSelf
      ? 'self'
      : can(viewer, 'users:read')
        ? 'administrator'
        : viewer !== null
          ? 'member'
          : 'stranger';

    // What this particular reader has been allowed to see of this particular
    // person. Read fresh on every profile, never cached: somebody taking their
    // number back must take effect on the next request, not whenever a cache
    // happens to expire.
    const grant =
      viewer === null || isSelf
        ? { phone: false, email: false }
        : await new MessagingRepository(this.env.DB).grantFor(
            viewer.id,
            String(row['user_id']),
          );

    const decorated = await this.decorate(row);
    const shaped = visibleProfile(decorated, relationship, grant);
    if (!shaped) throw new NotFoundError('That member was not found.');

    // A suspended or departed member is not shown at all, whatever their
    // visibility says.
    if (relationship !== 'self' && relationship !== 'administrator') {
      if (String(row['membership_status']) !== 'active') {
        throw new NotFoundError('That member was not found.');
      }
    }

    return shaped;
  }

  /** Attaches the skills, interests and avatar URL a profile is rendered with. */
  private async decorate(row: Record<string, unknown>): Promise<Record<string, unknown>> {
    const profileId = String(row['id']);
    const [skills, interests] = await Promise.all([
      this.members.skillsFor(profileId),
      this.members.interestsFor(profileId),
    ]);

    const toUrl = (value: unknown): string | null =>
      typeof value === 'string' && value !== ''
        ? publicMediaUrl(this.env.PUBLIC_MEDIA_BASE_URL, value)
        : null;

    const avatarUrl = toUrl(row['avatar_storage_key']);
    const coverUrl = toUrl(row['cover_storage_key']);

    // The storage keys are dropped rather than passed on: the client is given a
    // URL it can render, and an R2 key is an implementation detail that has no
    // business travelling to a browser.
    const { avatar_storage_key: _a, cover_storage_key: _c, ...rest } = row;
    return { ...rest, skills, interests, avatar_url: avatarUrl, cover_url: coverUrl };
  }

  // -------------------------------------------------------------------------
  // Writing
  // -------------------------------------------------------------------------

  /**
   * Saves one stage of the profile.
   *
   * Partial by design: registration collects information in stages rather than
   * behind one enormous form, and a member should be able to answer three
   * questions today and three more next week without losing the first three.
   *
   * Four columns are stripped from whatever arrives and recomputed here, so a
   * request cannot set them: the two location flags the opportunity matcher
   * sorts by, the employment timestamp, and the completion score.
   */
  async update(
    user: AuthenticatedUser,
    values: Record<string, unknown>,
    context: { requestId: string },
  ): Promise<Record<string, unknown>> {
    const profile = await this.requireOwnProfile(user);

    const payload = { ...values };
    for (const derived of [
      'is_in_ekoli_yeden',
      'is_diaspora',
      'employment_updated_at',
      'completion_percent',
      'last_active_at',
      'membership_status',
      'membership_number',
      'handle',
      'user_id',
    ]) {
      delete payload[derived];
    }

    // The location tier is derived from what was just typed where it changed,
    // and from what is stored where it did not.
    const communityArea = (payload['community_area'] ?? profile.community_area) as string | null;
    const lga = (payload['lga'] ?? profile.lga) as string | null;
    const country = (payload['country'] ?? profile.country) as string | null;

    if ('community_area' in payload || 'lga' in payload || 'country' in payload) {
      payload['is_in_ekoli_yeden'] = isInEkoliYeden({ communityArea, lga }) ? 1 : 0;
      payload['is_diaspora'] = isDiaspora(country) ? 1 : 0;
    }

    // THE DAY AND THE MONTH ARE DERIVED, THE YEAR IS NOT PUBLISHED.
    //
    // `birth_day` and `birth_month` are what the birthdays page reads, because
    // "whose birthday is it today" is a question about a day and a month and
    // must not require anybody's age to answer it. They are derived here so a
    // member gives one date and cannot leave the three fields disagreeing.
    //
    // The year stays in `birth_date` and `birth_year` and is used for the
    // age-grade brackets. Whether anybody may see it is `show_age`, which is
    // a separate switch from `show_birthday` on purpose: plenty of people are
    // glad to be wished a happy birthday and would rather not publish an age.
    if ('birth_date' in payload) {
      const raw = payload['birth_date'];
      if (raw === null || raw === '') {
        payload['birth_date'] = null;
        payload['birth_day'] = null;
        payload['birth_month'] = null;
        payload['birth_year'] = null;
      } else {
        const parsed = new Date(String(raw));
        if (!Number.isNaN(parsed.getTime())) {
          payload['birth_day'] = parsed.getUTCDate();
          payload['birth_month'] = parsed.getUTCMonth() + 1;
          payload['birth_year'] = parsed.getUTCFullYear();
        }
      }
    }

    // "Where in Ekori are you from?" is answered in the member's own words,
    // and those words are kept. What the archive matched them to is recorded
    // beside them, never instead of them — a wrong match is then something a
    // reviewer can see and correct, rather than a silent overwrite of what
    // somebody said about their own home.
    //
    // A name two different people give becomes a real place automatically, so
    // the list of places grows out of what the community actually says rather
    // than out of a list somebody wrote in advance. See `places.service.ts`.
    if (typeof payload['place_text'] === 'string' && payload['place_text'].trim() !== '') {
      const place = await new PlacesService(this.env).recordAnswer(
        payload['place_text'],
        user.id,
        null,
      );
      payload['place_id'] = place?.id ?? null;
    }

    // Stamped so the community snapshot can say how current its figures are.
    // A "seeking work" count built from answers three years old is worse than
    // no count, because it looks current.
    if ('employment_status' in payload && payload['employment_status'] !== profile.employment_status) {
      payload['employment_updated_at'] = nowIso();
    }

    await this.members.update(profile.id, payload);

    const updated = await this.members.findByUserId(user.id);
    await this.recalculateCompletion(updated);

    // Recorded because a profile holds personal data, and a change to it should
    // be answerable later. The values themselves are not logged — only which
    // fields moved.
    await new AuditRepository(this.env.DB).record({
      actorId: user.id,
      actorEmail: user.email,
      action: 'membership.profile.updated',
      resourceType: 'member_profile',
      resourceId: profile.id,
      changes: { fields: Object.keys(payload) },
      requestId: context.requestId,
    });

    return this.readOwnProfile(user);
  }

  /**
   * Replaces the member's skills.
   *
   * A name the vocabulary does not have is added to it rather than refused.
   * Turning somebody away because their trade is not on a seed list is how a
   * profile gets abandoned half-finished, and the community knows its own
   * skills better than a seed list does.
   */
  async setSkills(
    user: AuthenticatedUser,
    entries: { skillId?: string | null; name?: string | null; proficiency?: string; years?: number | null }[],
  ): Promise<Record<string, unknown>[]> {
    const profile = await this.requireOwnProfile(user);
    if (entries.length > 40) {
      throw new BadRequestError('Please choose no more than 40 skills.');
    }

    const resolved: { skillId: string; proficiency: string; years: number | null }[] = [];

    for (const entry of entries) {
      let skillId = entry.skillId ?? null;

      if (!skillId && entry.name && entry.name.trim() !== '') {
        const proposed = await this.members.proposeSkill(entry.name, user.id);
        skillId = proposed.id;
      }
      if (!skillId) continue;

      resolved.push({
        skillId,
        proficiency: entry.proficiency ?? 'unspecified',
        years: entry.years ?? null,
      });
    }

    await this.members.replaceSkills(profile.id, resolved);
    await this.recalculateCompletion(await this.members.findByUserId(user.id));

    return this.members.skillsFor(profile.id) as unknown as Record<string, unknown>[];
  }

  async setInterests(user: AuthenticatedUser, interestIds: string[]): Promise<Record<string, unknown>[]> {
    const profile = await this.requireOwnProfile(user);
    await this.members.replaceInterests(profile.id, interestIds.slice(0, 30));
    await this.recalculateCompletion(await this.members.findByUserId(user.id));
    return this.members.interestsFor(profile.id) as unknown as Record<string, unknown>[];
  }

  /**
   * The account overview — "one Okoli account", as a single response.
   *
   * Everything the dashboard shows in one request rather than six, because the
   * dashboard is the first thing a member sees and six sequential round trips
   * on a slow connection is the difference between a platform that feels alive
   * and one that feels broken.
   */
  async dashboard(user: AuthenticatedUser): Promise<Record<string, unknown>> {
    const profile = await this.readOwnProfile(user);
    const notifications = new NotificationRepository(this.env.DB);

    const [unread, recent] = await Promise.all([
      notifications.unreadCount(user.id),
      notifications.list(user.id, { unreadOnly: false, limit: 8, offset: 0 }),
    ]);

    const completion = Number(profile['completion_percent'] ?? 0);

    return {
      profile,
      roles: user.roles,
      notifications: { unread, recent: recent.items },
      // What is still worth filling in, phrased as the thing it unlocks rather
      // than as a scolding. A member who has not added a skill is not doing
      // anything wrong; they simply will not be matched to anything yet.
      suggestions: this.suggestionsFor(profile, completion),
    };
  }

  private suggestionsFor(profile: Record<string, unknown>, completion: number): string[] {
    const suggestions: string[] = [];
    const skills = Array.isArray(profile['skills']) ? profile['skills'] : [];

    if (skills.length === 0) {
      suggestions.push(
        'Add what you can do. Skills are what opportunities are matched against — without them, '
        + 'nothing will find you.',
      );
    }
    if (!profile['profession_id'] && !profile['profession_other']) {
      suggestions.push('Say what you do for a living, so people looking for it can find you.');
    }
    if (!profile['country'] && !profile['community_area']) {
      suggestions.push(
        'Add where you are. Opportunities are shown nearest first, and without a location you get '
        + 'the far ones too.',
      );
    }
    if (profile['listed_in_directory'] !== 1) {
      suggestions.push(
        'You are not in the Yakoli directory. Turning it on lets other members find you by what '
        + 'you do — you can turn it off again at any time.',
      );
    }
    if (completion >= 80 && suggestions.length === 0) {
      suggestions.push('Your profile is in good shape. Thank you.');
    }
    return suggestions;
  }

  // -------------------------------------------------------------------------

  /// Public so a controller acting for the member — setting their own
  /// portrait, say — can resolve the profile without duplicating the lookup and
  /// the "you have no profile yet" error alongside it.
  async requireOwnProfile(user: AuthenticatedUser): Promise<MemberProfileRecord> {
    const profile = await this.members.findByUserId(user.id);
    if (!profile) {
      throw new NotFoundError(
        'You are not a member of the Yakoli community yet. Join to keep a profile.',
      );
    }
    if (profile.membership_status === 'suspended') {
      throw new ForbiddenError(
        'This membership is suspended. Please contact the Preservation Team.',
      );
    }
    return profile;
  }

  /** Recomputes the completion score after anything that could move it. */
  private async recalculateCompletion(profile: MemberProfileRecord | null): Promise<void> {
    if (!profile) return;

    const [skills, interests] = await Promise.all([
      this.members.skillsFor(profile.id),
      this.members.interestsFor(profile.id),
    ]);

    const percent = completionPercent(profile as unknown as Record<string, unknown>, {
      skills: skills.length,
      interests: interests.length,
    });

    if (percent !== profile.completion_percent) {
      await this.members.update(profile.id, { completion_percent: percent });
    }
  }

  /** A handle nobody else is using. */
  private async uniqueHandle(name: string, userId: string): Promise<string> {
    const base = handleFrom(name, `okoli-${userId.slice(0, 8)}`);
    if (!(await this.members.handleExists(base))) return base;

    for (let suffix = 2; suffix < 60; suffix += 1) {
      const candidate = `${base}-${suffix}`;
      if (!(await this.members.handleExists(candidate))) return candidate;
    }
    return `${base}-${userId.slice(0, 6)}`;
  }

  private async settingEnabled(key: string, fallback: boolean): Promise<boolean> {
    const setting = await this.settings.get(key).catch(() => null);
    if (!setting || setting.value === null) return fallback;
    return setting.value === 'true' || setting.value === '1';
  }

  /** Whether this account holds a membership at all. */
  async isMember(user: AuthenticatedUser | null): Promise<boolean> {
    if (!user) return false;
    const profile = await this.members.findByUserId(user.id);
    return profile !== null && profile.membership_status === 'active';
  }

  /** Exposed for the admin snapshot. Aggregates only — never names. */
  async statistics(): Promise<Record<string, unknown>> {
    const stats = await this.members.statistics();

    // Regrouped into the five buckets the community actually plans around.
    const byGroup: Record<string, number> = {};
    for (const [status, total] of Object.entries(stats.byEmployment)) {
      const group = workGroupFor(status === 'not_said' ? null : status);
      byGroup[group] = (byGroup[group] ?? 0) + total;
    }

    return {
      total: stats.total,
      byWorkGroup: byGroup,
      byEmploymentStatus: stats.byEmployment,
      byCountry: stats.byCountry,
      topSkills: stats.topSkills,
      inDirectory: stats.inDirectory,
      inEkoliYeden: stats.inEkoliYeden,
      diaspora: stats.diaspora,
      note:
        'Aggregated counts only. Individual employment details are not exposed here, and the '
        + 'platform does not publish that any named member is out of work.',
    };
  }
}
