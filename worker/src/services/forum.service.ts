import { ForumRepository, type ForumSpaceRecord } from '../repositories/forum.repository';
import { can } from './permissions';
import type { Env } from '../types/env';
import type { AuthenticatedUser } from '../types/auth';
import { ForbiddenError, NotFoundError } from '../utils/errors';

/** What a particular person may do in a particular space. */
export interface ForumAccess {
  space: ForumSpaceRecord;
  canRead: boolean;
  canPost: boolean;
  isModerator: boolean;
  isMember: boolean;
  /** Why they cannot post, in words they can act on. */
  blockedReason: string | null;
  /** Their standing in this space: pending, member, rejected, removed… */
  membershipState: string | null;
  /** How this space is joined: automatic, request or closed. */
  joinPolicy: string;
  /** Whether the interface should offer a "join this forum" button. */
  canRequestToJoin: boolean;
}

/**
 * THE YAKOLI FORUMS (Module 5)
 *
 * ---------------------------------------------------------------------------
 * THE STUDENT SPACE IS THE REASON THIS FILE IS CAREFUL
 * ---------------------------------------------------------------------------
 *
 * Two of the three spaces may contain minors. That single fact decides most of
 * what follows:
 *
 *   A space marked `members` is never readable by an anonymous visitor, and
 *   `is_indexable = 0` keeps it out of search engines. Both are checked here
 *   rather than trusted to the client.
 *
 *   In a youth space, an author card carries a name and nothing else — no
 *   phone number, no precise location, no employer. A forum post by a
 *   fifteen-year-old should not also publish where to find them.
 *
 *   Reports marked `child_safety` jump the moderation queue. It is the only
 *   thing in this module that reorders anything.
 *
 * ---------------------------------------------------------------------------
 * AND ONE THING THAT IS NOT AN ACCIDENT
 * ---------------------------------------------------------------------------
 *
 * Nothing anywhere sorts by reactions. Ordering a community's conversation by
 * what gets the most approval is how the loudest thing wins and the quiet
 * question goes unanswered. Topics are ordered by when somebody last spoke.
 */
export class ForumService {
  private readonly forum: ForumRepository;

  constructor(env: Env) {
    this.forum = new ForumRepository(env.DB);
  }

  get repo(): ForumRepository {
    return this.forum;
  }

  /**
   * What this person may do in this space.
   *
   * One method, called by every route, so the rules cannot drift between the
   * list view and the post handler.
   *
   * ---------------------------------------------------------------------------
   * MEMBERSHIP IS PER SPACE
   * ---------------------------------------------------------------------------
   *
   * This used to ask one question — is this person an active member of the
   * community — and answer it for every members-only space at once. Belonging
   * to the Youth Forum did not exist as a thing that could be true or false, so
   * neither did being approved into it, removed from it or suspended from one
   * space while staying in another.
   *
   * Since 0039 a `forum_members` row is the answer. The General Forum grants
   * one automatically at registration; every other space is asked for and
   * decided by its own admin.
   */
  async access(identifier: string, viewer: AuthenticatedUser | null): Promise<ForumAccess> {
    const space = await this.forum.findSpace(identifier);
    if (!space || space.status !== 'published') {
      throw new NotFoundError('That space was not found.');
    }

    // A Super Admin or anybody who may manage users can read and moderate every
    // space. That is deliberate and is the only way in that does not require a
    // membership row.
    const isGlobalAdmin = viewer !== null && can(viewer, 'users:update');

    const membership =
      viewer === null ? null : await this.forum.membershipFor(space.id, viewer.id);

    const state = membership?.state ?? null;
    const isMember = state === 'member';
    const isSuspended = state === 'suspended';

    const isModerator =
      isGlobalAdmin || (isMember && (membership?.role === 'admin' || membership?.role === 'moderator'));

    // A public space is readable by anybody, member or not — the General Forum
    // is public so that somebody deciding whether to join can see what the
    // community talks about. Everything else needs a membership.
    const canRead = space.visibility === 'public' || isMember || isModerator;

    let blockedReason: string | null = null;
    let canPost = false;

    if (!canRead) {
      blockedReason =
        state === 'pending'
          ? 'Your request to join this forum is waiting on its administrator.'
          : state === 'rejected'
            ? membership?.decision_note ?? 'Your request to join this forum was not accepted.'
            : state === 'removed'
              ? 'You are no longer a member of this forum.'
              : 'This forum is for its members. You can ask to join it.';
    } else if (isSuspended) {
      const until = membership?.suspended_until ?? null;
      blockedReason = until
        ? `You are suspended from this forum until ${until.slice(0, 10)}.`
        : 'You are suspended from this forum.';
    } else if (!isMember && !isModerator) {
      // Readable but not joined — a visitor, or a member who has not asked yet.
      blockedReason =
        viewer === null
          ? 'Sign in to take part in the conversation.'
          : state === 'pending'
            ? 'Your request to join this forum is waiting on its administrator.'
            : 'Join this forum to take part in the conversation.';
    } else {
      // A sanction is the older, forum-wide instrument and still applies: a ban
      // silences somebody everywhere, which a per-space suspension cannot.
      const sanction = viewer === null
        ? null
        : await this.forum.activeSanction(viewer.id, space.id);

      if (sanction) {
        // Said plainly, with the end date where there is one. Somebody who has
        // been suspended and cannot tell whether it is permanent will assume
        // the worst and leave.
        const kind = String(sanction['kind']);
        const until = sanction['expires_at'] as string | null;
        blockedReason = kind === 'ban'
          ? 'You are no longer able to post in the forums. Contact the moderators if you think '
            + 'that is wrong.'
          : until === null
            ? 'Your posting is suspended.'
            : `Your posting is suspended until ${until.slice(0, 10)}.`;
      } else {
        canPost = true;
      }
    }

    return {
      space,
      canRead,
      canPost,
      isModerator,
      isMember,
      blockedReason,
      // What the interface needs to draw the right button: Join, Asked,
      // Approved, or nothing at all.
      membershipState: state,
      joinPolicy: String(space.join_policy ?? 'request'),
      canRequestToJoin:
        viewer !== null &&
        !isMember &&
        !isModerator &&
        String(space.join_policy ?? 'request') === 'request' &&
        (state === null || state === 'removed'),
    };
  }

  /** Throws unless this person may read the space. */
  assertCanRead(access: ForumAccess): void {
    if (!access.canRead) {
      // The same message as a genuine miss for a members-only space, so its
      // existence and its contents are not probeable by an anonymous caller.
      throw new NotFoundError('That space was not found.');
    }
  }

  /** Throws unless this person may post in the space. */
  assertCanPost(access: ForumAccess): void {
    this.assertCanRead(access);
    if (!access.canPost) {
      throw new ForbiddenError(access.blockedReason ?? 'You cannot post here.');
    }
  }

  /**
   * Which statuses of content this viewer may see.
   *
   * A moderator sees hidden content, because reviewing a hidden post requires
   * reading it. Everybody else sees only what is published — including the
   * author of a hidden post, who is told separately that it was hidden rather
   * than being left to wonder why nobody replied.
   */
  visibleStatuses(access: ForumAccess): string[] {
    return access.isModerator
      ? ['published', 'pending_review', 'hidden']
      : ['published'];
  }

  /**
   * An author, shaped for the space they posted in.
   *
   * In a youth space this is a name and nothing else. Contact details and
   * precise locations are suppressed — a post by a fifteen-year-old should not
   * also publish where to find them.
   */
  shapeAuthor(
    space: ForumSpaceRecord,
    row: Record<string, unknown>,
  ): Record<string, unknown> {
    const name = (row['author_name'] as string | null) ?? 'A member';

    if (space.is_youth_space === 1) {
      return { name, handle: null, avatar_url: null };
    }

    return {
      name,
      handle: (row['author_handle'] as string | null) ?? null,
      avatar_url: null,
    };
  }
}
