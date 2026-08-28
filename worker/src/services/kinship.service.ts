import { KinshipRepository, type RelationshipView } from '../repositories/kinship.repository';
import { MemberRepository } from '../repositories/member.repository';
import { NotificationRepository } from '../repositories/notification.repository';
import { SettingsRepository } from '../repositories/settings.repository';
import { AuditRepository } from '../repositories/audit.repository';
import {
  RELATIONSHIP_LABELS,
  RELATIONSHIP_TYPES,
  inverseOptionsFor,
  normalisePhone,
} from './kinship';
import type { Env } from '../types/env';
import type { AuthenticatedUser } from '../types/auth';
import { BadRequestError, ConflictError, ForbiddenError, NotFoundError } from '../utils/errors';
import { publicMediaUrl } from '../utils/files';

/**
 * KINSHIP — connecting people who are already family.
 *
 * Two rules run through everything here.
 *
 * NOTHING IS A RELATIONSHIP UNTIL BOTH SIDES SAY SO. Anybody can claim anybody
 * is their brother. The platform records that as a request and nothing more.
 * This matters beyond politeness: the death-confirmation safeguard rests on
 * accepted relationships, so a claim that could stand unanswered would be a way
 * to manufacture the authority to still somebody's account.
 *
 * A PHONE NUMBER IS AN ADDRESS, NOT A DIRECTORY. Connecting by number is how
 * the community actually finds each other, but the endpoint must never reveal
 * whether a number has an account — otherwise it becomes a way to test a list
 * of numbers against the membership. It answers identically either way, the
 * same discipline the password reset flow already follows.
 */
export class KinshipService {
  private readonly kinship: KinshipRepository;
  private readonly members: MemberRepository;
  private readonly settings: SettingsRepository;

  constructor(private readonly env: Env) {
    this.kinship = new KinshipRepository(env.DB);
    this.members = new MemberRepository(env.DB);
    this.settings = new SettingsRepository(env.DB);
  }

  get repo(): KinshipRepository {
    return this.kinship;
  }

  // -------------------------------------------------------------------------
  // Asking
  // -------------------------------------------------------------------------

  /**
   * Asks somebody to confirm a relationship.
   *
   * `toUserId` comes either from opening their profile or from looking up a
   * phone number. The caller resolves it; this does not care which, except to
   * record it, because connecting by number is a different act from connecting
   * by profile and the audit trail should say so.
   */
  async request(
    actor: AuthenticatedUser,
    values: { toUserId: string; type: string; note: string | null; via: string },
    context: { requestId: string },
  ): Promise<{ id: string; state: string }> {
    if (values.toUserId === actor.id) {
      throw new BadRequestError('You cannot connect yourself to yourself.');
    }
    if (!(RELATIONSHIP_TYPES as readonly string[]).includes(values.type)) {
      throw new BadRequestError('That is not a relationship the platform recognises.');
    }

    await this.assertUnderDailyLimit(actor.id);

    // Either direction counts. Two rows describing one relationship would
    // eventually disagree about what it is.
    const existing = await this.kinship.between(actor.id, values.toUserId);
    if (existing) {
      if (existing.state === 'accepted') {
        throw new ConflictError('You are already connected to this person.');
      }
      if (existing.state === 'pending') {
        throw new ConflictError(
          existing.requested_by === actor.id
            ? 'You have already asked. They have not answered yet.'
            : 'They have already asked to connect with you — answer their request instead.',
        );
      }
      // A declined or removed connection may be asked for again: people fall
      // out and make up, and the platform should not remember a refusal for
      // ever.
      await this.env.DB.prepare('DELETE FROM "member_relationships" WHERE "id" = ?')
        .bind(existing.id)
        .run();
    }

    const id = await this.kinship.request({
      fromUserId: actor.id,
      toUserId: values.toUserId,
      type: values.type,
      note: values.note,
      via: values.via,
    });

    const label = RELATIONSHIP_LABELS[values.type] ?? 'family';
    await new NotificationRepository(this.env.DB).notify({
      userId: values.toUserId,
      kind: 'general',
      title: `${actor.displayName} says you are their ${label.toLowerCase()}`,
      body: 'Confirm the connection, or decline it. Nothing is recorded until you answer.',
      linkPath: '/account/family',
      resourceType: 'relationship',
      resourceId: id,
    });

    await new AuditRepository(this.env.DB).record({
      actorId: actor.id,
      actorEmail: actor.email,
      action: 'kinship.requested',
      resourceType: 'relationship',
      resourceId: id,
      changes: { type: values.type, via: values.via },
      requestId: context.requestId,
    });

    return { id, state: 'pending' };
  }

  /**
   * Asks by phone number.
   *
   * Returns the same shape whether or not a member was found. The caller must
   * not vary its response either — see the note at the top of this file.
   */
  async requestByPhone(
    actor: AuthenticatedUser,
    values: { phone: string; type: string; note: string | null },
    context: { requestId: string },
  ): Promise<{ sent: boolean }> {
    const normalised = normalisePhone(values.phone);
    if (!normalised) {
      throw new BadRequestError('That does not look like a phone number.');
    }

    await this.assertUnderDailyLimit(actor.id);

    const found = await this.kinship.findByPhone(values.phone);

    // A miss is recorded so that somebody working through a list of numbers is
    // visible in the audit trail even though the response tells them nothing.
    if (!found || found.user_id === actor.id) {
      await new AuditRepository(this.env.DB).record({
        actorId: actor.id,
        actorEmail: actor.email,
        action: 'kinship.phone_lookup.miss',
        resourceType: 'relationship',
        resourceId: 'none',
        requestId: context.requestId,
      });
      return { sent: true };
    }

    try {
      await this.request(
        actor,
        { toUserId: found.user_id, type: values.type, note: values.note, via: 'phone' },
        context,
      );
    } catch (error) {
      // An "already connected" answer would confirm the number belongs to a
      // member. Swallowed for that reason; the requester sees the same thing
      // either way.
      if (!(error instanceof ConflictError)) throw error;
    }

    return { sent: true };
  }

  // -------------------------------------------------------------------------
  // Answering
  // -------------------------------------------------------------------------

  /**
   * Accepts, with the accepter choosing their own side of it.
   *
   * Only they can say whether they are the son or the daughter, and the
   * platform does not ask anybody to record their sex just so it can guess.
   */
  async accept(
    actor: AuthenticatedUser,
    relationshipId: string,
    reverseType: string,
    context: { requestId: string },
  ): Promise<void> {
    const relationship = await this.kinship.findById(relationshipId);
    if (!relationship) throw new NotFoundError('That connection request was not found.');

    if (relationship.to_user_id !== actor.id) {
      throw new ForbiddenError('Only the person who was asked can answer this.');
    }
    if (relationship.state !== 'pending') {
      throw new BadRequestError('That request has already been answered.');
    }

    const allowed = inverseOptionsFor(relationship.type);
    const chosen = allowed.includes(reverseType) ? reverseType : (allowed[0] ?? 'kin');

    await this.kinship.accept(relationshipId, chosen);

    await new NotificationRepository(this.env.DB).notify({
      userId: relationship.from_user_id,
      kind: 'general',
      title: `${actor.displayName} confirmed your connection`,
      body: `You are now recorded as their ${(RELATIONSHIP_LABELS[chosen] ?? 'family').toLowerCase()}.`,
      linkPath: '/account/family',
      resourceType: 'relationship',
      resourceId: relationshipId,
    });

    await new AuditRepository(this.env.DB).record({
      actorId: actor.id,
      actorEmail: actor.email,
      action: 'kinship.accepted',
      resourceType: 'relationship',
      resourceId: relationshipId,
      changes: { type: relationship.type, reverse: chosen },
      requestId: context.requestId,
    });
  }

  async decline(actor: AuthenticatedUser, relationshipId: string): Promise<void> {
    const relationship = await this.kinship.findById(relationshipId);
    if (!relationship) throw new NotFoundError('That connection request was not found.');
    if (relationship.to_user_id !== actor.id) {
      throw new ForbiddenError('Only the person who was asked can answer this.');
    }

    await this.kinship.decline(relationshipId);
    // The requester is not told. Being declined is not something anybody needs
    // a notification about, and telling them invites a second attempt.
  }

  /**
   * Ends a connection. Either side may, and it takes only one.
   *
   * Requiring both to agree would be a way to hold somebody inside a claim they
   * have rejected.
   */
  async remove(
    actor: AuthenticatedUser,
    relationshipId: string,
    context: { requestId: string },
  ): Promise<void> {
    const relationship = await this.kinship.findById(relationshipId);
    if (!relationship) throw new NotFoundError('That connection was not found.');

    if (relationship.from_user_id !== actor.id && relationship.to_user_id !== actor.id) {
      throw new ForbiddenError('Only the two people connected can end a connection.');
    }

    await this.kinship.remove(relationshipId, actor.id);

    await new AuditRepository(this.env.DB).record({
      actorId: actor.id,
      actorEmail: actor.email,
      action: 'kinship.removed',
      resourceType: 'relationship',
      resourceId: relationshipId,
      requestId: context.requestId,
    });
  }

  // -------------------------------------------------------------------------
  // Reading
  // -------------------------------------------------------------------------

  /** Somebody's family, as they see it: accepted, plus what awaits them. */
  async family(userId: string): Promise<{
    accepted: Record<string, unknown>[];
    incoming: Record<string, unknown>[];
    outgoing: Record<string, unknown>[];
  }> {
    const [accepted, pending] = await Promise.all([
      this.kinship.forUser(userId, ['accepted']),
      this.kinship.forUser(userId, ['pending']),
    ]);

    return {
      accepted: accepted.map((row) => this.shape(row)),
      incoming: pending.filter((row) => row.awaiting_me).map((row) => this.shape(row)),
      outgoing: pending.filter((row) => !row.awaiting_me).map((row) => this.shape(row)),
    };
  }

  private shape(row: RelationshipView): Record<string, unknown> {
    return {
      id: row.id,
      state: row.state,
      type: row.as_seen,
      type_label: RELATIONSHIP_LABELS[row.as_seen] ?? 'Related',
      // What the requester asked for, so a pending card can say "they say you
      // are their father" rather than something vaguer.
      requested_type: row.type,
      requested_type_label: RELATIONSHIP_LABELS[row.type] ?? 'Related',
      reverse_options: inverseOptionsFor(row.type).map((option) => ({
        value: option,
        label: RELATIONSHIP_LABELS[option] ?? option,
      })),
      note: row.note,
      via: row.via,
      awaiting_me: row.awaiting_me,
      created_at: row.created_at,
      person: {
        user_id: row.other_user_id,
        name: row.other_name,
        handle: row.other_handle,
        avatar_url: row.other_avatar_key
          ? publicMediaUrl(this.env.PUBLIC_MEDIA_BASE_URL, row.other_avatar_key)
          : null,
      },
    };
  }

  // -------------------------------------------------------------------------

  /**
   * A brake on somebody working through the membership list.
   *
   * Connection requests are how a stranger reaches a member's attention, so
   * unlimited requests are a harassment channel rather than a feature.
   */
  private async assertUnderDailyLimit(userId: string): Promise<void> {
    const setting = await this.settings.get('relationship_requests_per_day').catch(() => null);
    const limit = Number(setting?.value ?? 25);
    if (!Number.isFinite(limit) || limit <= 0) return;

    const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
    const sent = await this.kinship.requestsSince(userId, since);

    if (sent >= limit) {
      throw new ForbiddenError(
        'You have sent a lot of connection requests today. Please try again tomorrow.',
      );
    }
  }

  /** Ensures the searchable form of a phone number matches what was stored. */
  async refreshPhone(userId: string, phone: string | null): Promise<void> {
    const profile = await this.members.findByUserId(userId);
    if (!profile) return;

    await this.members.update(profile.id, {
      phone_normalised: normalisePhone(phone),
    });
  }
}
