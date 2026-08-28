import { BirthdayRepository, type BirthdayPerson } from '../repositories/birthday.repository';
import { KinshipRepository } from '../repositories/kinship.repository';
import { MemberRepository } from '../repositories/member.repository';
import { NotificationRepository } from '../repositories/notification.repository';
import { SettingsRepository } from '../repositories/settings.repository';
import { GroupRepository } from '../repositories/group.repository';
import { communityToday, ageOn } from './kinship';
import type { Env } from '../types/env';
import type { AuthenticatedUser } from '../types/auth';
import { BadRequestError, ForbiddenError, NotFoundError } from '../utils/errors';
import { publicMediaUrl } from '../utils/files';

/**
 * BIRTHDAYS
 *
 * The community wishes its people well, and the wishes are kept.
 *
 * Two things this does that a notification system would not:
 *
 *   It asks ONCE. "Not now" means not now — the card does not reappear on the
 *   next page load. A prompt that nags gets dismissed unread, which defeats it.
 *
 *   It keeps the wishes by YEAR. The question a member actually asks, years
 *   later, is "what did people say to me in 2027?" — and a feed cannot answer
 *   that. Each year is its own page and the earlier ones do not scroll away.
 */
export class BirthdayService {
  private readonly birthdays: BirthdayRepository;
  private readonly kinship: KinshipRepository;
  private readonly members: MemberRepository;
  private readonly settings: SettingsRepository;
  private readonly groups: GroupRepository;

  constructor(private readonly env: Env) {
    this.birthdays = new BirthdayRepository(env.DB);
    this.kinship = new KinshipRepository(env.DB);
    this.members = new MemberRepository(env.DB);
    this.settings = new SettingsRepository(env.DB);
    this.groups = new GroupRepository(env.DB);
  }

  get repo(): BirthdayRepository {
    return this.birthdays;
  }

  /**
   * The birthday cards to show this member today.
   *
   * Who a member is prompted about is a setting, because the right answer
   * depends on how big the community gets. `connections_and_groups` — family,
   * plus everyone in a group they share — is the default: it is the set of
   * people whose birthday somebody would actually want to know about, and it
   * does not turn into a hundred cards once the platform has a thousand
   * members.
   *
   * Already answered — wished or skipped — is filtered out here rather than in
   * the client, so a dismissal survives a page reload.
   */
  async promptsFor(actor: AuthenticatedUser): Promise<Record<string, unknown>[]> {
    if (!(await this.enabled())) return [];

    const today = communityToday();
    const celebrating = await this.birthdays.birthdaysToday();
    if (celebrating.length === 0) return [];

    const answered = await this.birthdays.answeredThisYear(actor.id, today.year);
    const audience = await this.audienceFor(actor.id);

    const cards: Record<string, unknown>[] = [];

    for (const person of celebrating) {
      if (person.user_id === actor.id) continue;
      if (answered.has(person.user_id)) continue;
      if (audience !== null && !audience.has(person.user_id)) continue;

      cards.push(this.shapeCard(person, today.year));
    }

    return cards;
  }

  /** The member's own birthday card, where today is theirs. */
  async ownBirthdayToday(actor: AuthenticatedUser): Promise<Record<string, unknown> | null> {
    const today = communityToday();
    const celebrating = await this.birthdays.birthdaysToday();
    const mine = celebrating.find((person) => person.user_id === actor.id);
    if (!mine) return null;

    const wishes = await this.birthdays.wishesFor(actor.id, today.year);

    return {
      year: today.year,
      // What the platform itself says, which is the "wishes and prayers from
      // the platform" the community asked for. Editable as a CMS string, so
      // the words belong to the community rather than to this file.
      greeting: await this.greeting(),
      wishes_received: wishes.length,
      chart_path: '/account/birthdays',
    };
  }

  /**
   * Who this member is prompted about.
   *
   * Returns null for "everybody", or a set of user ids. Null rather than a set
   * of every member so the common case does not load the whole membership.
   */
  private async audienceFor(userId: string): Promise<Set<string> | null> {
    const setting = await this.settings.get('birthday_prompt_scope').catch(() => null);
    const scope = setting?.value ?? 'connections_and_groups';

    if (scope === 'all_members') return null;

    const connections = await this.kinship.connectedUserIds(userId);
    const audience = new Set<string>(connections);

    if (scope === 'connections_and_groups') {
      // Everybody in a group this member belongs to. This is what makes a
      // birthday appear "in every group the person belongs to" — the notice
      // reaches the people who share a grade, a family or a cultural group
      // with them.
      for (const otherId of await this.groups.fellowMemberIds(userId)) {
        audience.add(otherId);
      }
    }

    return audience;
  }

  private shapeCard(person: BirthdayPerson, year: number): Record<string, unknown> {
    return {
      user_id: person.user_id,
      handle: person.handle,
      name: person.full_name ?? person.display_name,
      headline: person.headline,
      avatar_url: person.avatar_key
        ? publicMediaUrl(this.env.PUBLIC_MEDIA_BASE_URL, person.avatar_key)
        : null,
      year,
      // The age is deliberately absent unless the member turned it on. Somebody
      // can be wished a happy birthday without their age being published.
      wishes_enabled: person.wishes_enabled === 1,
    };
  }

  // -------------------------------------------------------------------------
  // Wishing
  // -------------------------------------------------------------------------

  async wish(
    actor: AuthenticatedUser,
    values: { recipientUserId: string; message: string; isPrayer: boolean; groupId: string | null },
  ): Promise<{ id: string; year: number }> {
    if (values.recipientUserId === actor.id) {
      throw new BadRequestError('You cannot wish yourself a happy birthday here.');
    }

    const message = values.message.trim();
    if (message.length < 2) throw new BadRequestError('Please write a short message.');
    if (message.length > 2000) throw new BadRequestError('That message is too long.');

    const recipient = await this.members.findByUserId(values.recipientUserId);
    if (!recipient) throw new NotFoundError('That member was not found.');
    if (recipient.membership_status !== 'active') {
      throw new NotFoundError('That member was not found.');
    }
    if ((recipient as unknown as { birthday_wishes_enabled?: number }).birthday_wishes_enabled === 0) {
      throw new ForbiddenError('This member has asked not to receive birthday messages.');
    }

    const today = communityToday();

    const id = await this.birthdays.wish({
      recipientUserId: values.recipientUserId,
      senderUserId: actor.id,
      senderName: actor.displayName,
      year: today.year,
      message,
      isPrayer: values.isPrayer,
      groupId: values.groupId,
      // Wishes are members-only by default. A birthday message is for the
      // community that sent it, not for a search engine.
      visibility: 'members',
    });

    await this.birthdays.recordPrompt(actor.id, values.recipientUserId, today.year, 'wished');

    await new NotificationRepository(this.env.DB).notify({
      userId: values.recipientUserId,
      kind: 'general',
      title: `${actor.displayName} wished you a happy birthday`,
      body: message.length > 120 ? `${message.slice(0, 119)}…` : message,
      linkPath: '/account/birthdays',
      // Keyed on the year so a member gets one notification per birthday
      // rather than one per well-wisher — twenty notifications on a happy day
      // is not twenty times better than one.
      resourceType: 'birthday',
      resourceId: `${values.recipientUserId}:${today.year}`,
    });

    return { id, year: today.year };
  }

  /** "Not now." Recorded so the card does not come back until next year. */
  async skip(actor: AuthenticatedUser, recipientUserId: string): Promise<void> {
    const today = communityToday();
    await this.birthdays.recordPrompt(actor.id, recipientUserId, today.year, 'skipped');
  }

  // -------------------------------------------------------------------------
  // The chart
  // -------------------------------------------------------------------------

  /**
   * One year of somebody's birthday chart.
   *
   * Visible to the member themselves and, for a public profile, to other
   * members. Wishes are a record of how a community treated somebody, and the
   * member is the one they belong to.
   */
  async chart(
    recipientUserId: string,
    year: number | null,
    viewer: AuthenticatedUser | null,
  ): Promise<Record<string, unknown>> {
    const profile = await this.members.findByUserId(recipientUserId);
    if (!profile) throw new NotFoundError('That member was not found.');

    const isSelf = viewer?.id === recipientUserId;
    if (!isSelf && viewer === null && profile.profile_visibility !== 'public') {
      throw new NotFoundError('That member was not found.');
    }
    if (!isSelf && profile.profile_visibility === 'private') {
      throw new NotFoundError('That member was not found.');
    }

    const years = await this.birthdays.wishYears(recipientUserId);
    const chosen = year ?? years[0]?.year ?? communityToday().year;
    const wishes = await this.birthdays.wishesFor(recipientUserId, chosen);

    return {
      member: {
        user_id: recipientUserId,
        handle: profile.handle,
        name: profile.full_name,
      },
      // The index of the chart: every year that has wishes in it, so a member
      // can move between them.
      years,
      year: chosen,
      wishes: wishes.map((wish) => ({
        id: wish.id,
        message: wish.message,
        is_prayer: wish.is_prayer === 1,
        sender_name: wish.sender_name,
        sender_handle: wish.sender_handle,
        sender_avatar_url: wish.sender_avatar_key
          ? publicMediaUrl(this.env.PUBLIC_MEDIA_BASE_URL, wish.sender_avatar_key)
          : null,
        created_at: wish.created_at,
      })),
      total: wishes.length,
    };
  }

  /** A member may hide a wish left on their own chart. */
  async hideWish(actor: AuthenticatedUser, wishId: string): Promise<void> {
    const wish = await this.birthdays.findWish(wishId);
    if (!wish) throw new NotFoundError('That message was not found.');

    if (wish.recipient_user_id !== actor.id) {
      throw new ForbiddenError('Only the person a message was written for can hide it.');
    }

    await this.birthdays.hideWish(wishId);
  }

  // -------------------------------------------------------------------------

  private async enabled(): Promise<boolean> {
    const setting = await this.settings.get('birthdays_enabled').catch(() => null);
    if (!setting || setting.value === null) return true;
    return setting.value === 'true' || setting.value === '1';
  }

  private async greeting(): Promise<string> {
    const row = await this.env.DB.prepare(
      `SELECT "value" FROM "content_strings" WHERE "key" = 'birthday.greeting.default' LIMIT 1`,
    )
      .first<{ value: string | null }>()
      .catch(() => null);

    return (
      row?.value ??
      'Happy birthday from all of us at Ekoli-Yeden. May the year ahead bring you health, peace ' +
        'and the company of your people.'
    );
  }

  /** Age, computed only where the member asked for it to be shown. */
  ageFor(person: { birth_year: number | null; birth_month: number; birth_day: number }): number | null {
    if (person.birth_year === null) return null;
    return ageOn(person.birth_year, person.birth_month, person.birth_day);
  }
}
