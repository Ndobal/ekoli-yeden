import type { RouteDefinition } from '../types/api';
import { Router } from '../middleware/router';
import { publicRoutes } from './public.routes';
import { authRoutes } from './auth.routes';
import { contributeRoutes } from './contribute.routes';
import { editorialRoutes } from './editorial.routes';
import { adminRoutes } from './admin.routes';
import { ageGradeRoutes } from './age-grade.routes';
import { membershipRoutes } from './membership.routes';
import { kinshipRoutes, publicKinshipRoutes } from './kinship.routes';
import { groupRoutes } from './group.routes';
import { opportunityRoutes } from './opportunity.routes';
import { forumRoutes } from './forum.routes';
import { ancestryRoutes } from './ancestry.routes';
import { placeRoutes } from './places.routes';
import { contactRoutes } from './contact.routes';
import { messagingRoutes } from './messaging.routes';
import { newsRoutes } from './news.routes';

/**
 * The complete route table.
 *
 * Registration order matters: more specific paths go in before the generated
 * catch-alls, so `/api/language/categories` is not swallowed by
 * `/api/language/:identifier`.
 *
 * The four protected surfaces are separate on purpose:
 *
 *   /api/contribute/*  anyone, rate-limited, everything lands pending review
 *   /api/editorial/*   the Editorial Team — the website's content, nothing more
 *   /api/admin/*       administration — users, roles, security, the audit trail
 *   /api/age-grades/*  a grade's own administrators, and only their own grade
 *   /api/membership/*  the Okoli account acting on itself — never a privilege
 *
 * Membership is the identity the later modules hang off: the forum, the
 * opportunities board and the directory read the profile these routes maintain
 * rather than keeping user systems of their own.
 *
 * An editorial account cannot reach `/api/admin/*`, because those routes
 * require permissions no editorial role is granted. An age grade administrator
 * reaches none of the other three: their authority is one row in
 * `age_grade_admins` for one grade, and nothing else in the archive consults it.
 */
export function buildRouter(): Router {
  const router = new Router();

  router.registerAll(authRoutes);
  router.registerAll(contributeRoutes);
  router.registerAll(editorialRoutes);
  router.registerAll(adminRoutes);
  // Before the public routes: these give an age grade its posts and its roster,
  // where the generated content route would return the bare record.
  router.registerAll(ageGradeRoutes);
  router.registerAll(membershipRoutes);
  // Ahead of the membership catch-alls and the public `/api/members/:handle`,
  // so `/api/members/:handle/birthdays` is matched as itself rather than being
  // read as a member whose handle happens to end in "/birthdays".
  router.registerAll(kinshipRoutes);
  router.registerAll(publicKinshipRoutes);
  router.registerAll(groupRoutes);
  router.registerAll(opportunityRoutes);
  router.registerAll(forumRoutes);
  router.registerAll(ancestryRoutes);
  router.registerAll(placeRoutes);
  router.registerAll(contactRoutes);
  router.registerAll(messagingRoutes);
  // Before the generated public routes: `/api/news-portal` must not be read as
  // a content resource named "news-portal".
  router.registerAll(newsRoutes);
  router.registerAll(publicRoutes);

  return router;
}

export const allRoutes: RouteDefinition[] = [
  ...authRoutes,
  ...contributeRoutes,
  ...editorialRoutes,
  ...adminRoutes,
  ...ageGradeRoutes,
  ...membershipRoutes,
  ...kinshipRoutes,
  ...publicKinshipRoutes,
  ...groupRoutes,
  ...opportunityRoutes,
  ...forumRoutes,
  ...ancestryRoutes,
  ...placeRoutes,
  ...contactRoutes,
  ...messagingRoutes,
  ...newsRoutes,
  ...publicRoutes,
];
