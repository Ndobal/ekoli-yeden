import { ForumRepository, type ForumSpaceRecord } from '../repositories/forum.repository';
import { MemberRepository } from '../repositories/member.repository';
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
  private readonly members: MemberRepository;

  constructor(env: Env) {
    this.forum = new ForumRepository(env.DB);
    this.members = new MemberRepository(env.DB);
  }

  get repo(): ForumRepository {
    return this.forum;
  }

  /**
   * What this person may do in this space.
   *
   * One method, called by every route, so the rules cannot drift between the
   * list view and the post handler.
   */
  async access(identifier: string, viewer: AuthenticatedUser | null): Promise<ForumAccess> {
    const space = await this.forum.findSpace(identifier);
    if (!space || space.status !== 'published') {
      throw new NotFoundError('That space was not found.');
    }

    const isAdmin = viewer !== null && can(viewer, 'users:update');
    const isModerator =
      isAdmin ||
      (viewer !== null && (await this.forum.isModerator(viewer.id, space.id)));

    // A member is somebody who completed their Yakoli membership — not merely
    // somebody with an account. The forums are a community's conversation, and
    // the community is the membership.
    const profile = viewer === null ? null : await this.members.findByUserId(viewer.id);
    const isMember = profile !== null && profile['membership_status'] === 'active';

    const canRead = space.visibility === 'public' || isMember || isModerator;

    let blockedReason: string | null = null;
    let canPost = false;

    if (!canRead) {
      blockedReason = space.visibility === 'members'
        ? 'This space is for members of the Yakoli community.'
        : 'You cannot read this space.';
    } else if (!isMember && !isModerator) {
      blockedReason = 'Complete your membership to take part in the conversation.';
    } else {
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

    return { space, canRead, canPost, isModerator, isMember, blockedReason };
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
