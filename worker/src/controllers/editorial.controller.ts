import type { RequestContext } from '../types/api';
import { CONTENT_RESOURCES } from '../services/content-registry';
import { can } from '../services/permissions';
import { countByStatus } from '../repositories/base.repository';
import { CONTENT_STATUS } from '../types/models';
import { UnauthorizedError } from '../utils/errors';
import { json, NO_STORE_HEADERS } from '../utils/responses';

/**
 * `GET /api/editorial/dashboard`
 *
 * What the Editorial Team sees when they sign in: how much is in draft, how
 * much is waiting for someone to review it, how much is live, and how much has
 * come back for revision.
 *
 * Deliberately different from the Super Admin dashboard. There are no user
 * counts, no audit summary, no security state and no infrastructure figures
 * here — an editorial account has no business seeing them, and this endpoint
 * does not read them.
 */
export async function editorialDashboard(context: RequestContext): Promise<Response> {
  const user = context.user;
  if (!user) throw new UnauthorizedError('Please sign in to continue.');

  const db = context.env.DB;

  // Only the content types this particular person may work on. A Language
  // Editor's dashboard should not be padded with counts they cannot act on.
  const visible = Object.values(CONTENT_RESOURCES).filter((resource) =>
    can(user, `${resource.key}:read`),
  );

  const counts = await Promise.all(
    visible.map(async (resource) => {
      const byStatus = await countByStatus(db, resource.table);
      return {
        resource: resource.key,
        label: resource.label,
        drafts: byStatus[CONTENT_STATUS.DRAFT] ?? 0,
        pendingReview: byStatus[CONTENT_STATUS.PENDING_REVIEW] ?? 0,
        approved: byStatus[CONTENT_STATUS.APPROVED] ?? 0,
        published: byStatus[CONTENT_STATUS.PUBLISHED] ?? 0,
        rejected: byStatus[CONTENT_STATUS.REJECTED] ?? 0,
      };
    }),
  );

  const strings = await db
    .prepare(
      `SELECT
         SUM(CASE WHEN "status" = 'draft' THEN 1 ELSE 0 END) AS drafts,
         SUM(CASE WHEN "status" = 'pending_review' THEN 1 ELSE 0 END) AS pending,
         SUM(CASE WHEN "status" = 'published' THEN 1 ELSE 0 END) AS published
       FROM "content_strings"`,
    )
    .first<{ drafts: number | null; pending: number | null; published: number | null }>();

  const total = (key: 'drafts' | 'pendingReview' | 'approved' | 'published' | 'rejected'): number =>
    counts.reduce((sum, entry) => sum + entry[key], 0);

  return json(
    {
      user: {
        displayName: user.displayName,
        roles: user.roles,
      },
      // What this person is actually allowed to do, so the interface can hide
      // controls that would only produce a 403. The server still decides.
      capabilities: {
        canCreate: can(user, 'content.create'),
        canEdit: can(user, 'content.edit'),
        canSubmit: can(user, 'content.submit'),
        canReview: can(user, 'content.review'),
        canPublish: can(user, 'content.publish'),
        canEditPages: can(user, 'pages.edit'),
        canEditNavigation: can(user, 'navigation.edit'),
        canEditHomepage: can(user, 'homepage.edit'),
        canManageSources: can(user, 'sources.manage'),
      },
      summary: {
        drafts: total('drafts'),
        pendingReview: total('pendingReview'),
        approved: total('approved'),
        published: total('published'),
        needsRevision: total('rejected'),
      },
      websiteText: {
        drafts: Number(strings?.drafts ?? 0),
        pendingReview: Number(strings?.pending ?? 0),
        published: Number(strings?.published ?? 0),
      },
      content: counts,
    },
    { headers: NO_STORE_HEADERS },
  );
}
