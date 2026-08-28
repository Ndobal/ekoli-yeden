import type { RouteDefinition } from '../types/api';
import {
  addAgeGradeMember,
  ageGradeActivity,
  appointAgeGradeAdmin,
  createAgeGradePost,
  deleteAgeGradePost,
  listAgeGradePosts,
  manageAgeGrade,
  myAgeGrades,
  registerAgeGrade,
  removeAgeGradeAdmin,
  removeAgeGradeMember,
  showAgeGrade,
  showAgeGradePost,
  updateAgeGrade,
  updateAgeGradeMember,
  updateAgeGradePost,
} from '../controllers/age-grade.controller';
import { requireAuth } from '../middleware/auth';
import { rateLimit } from '../middleware/rate-limit';

/**
 * AGE GRADES
 *
 * A fourth protected surface, and the narrowest one. Alongside:
 *
 *   /api/contribute/*  anyone, rate-limited, everything lands pending review
 *   /api/editorial/*   the Editorial Team — the website's content
 *   /api/admin/*       administration — users, roles, security, the audit trail
 *
 * these routes are authorised by something none of those three use: whether
 * the caller administers *this particular grade*. There is no middleware for
 * it, because a middleware would have to guess which grade from the path
 * before the handler had resolved it — so each write handler resolves the
 * grade and asks, in that order, every time.
 *
 * Registered before the generated `/api/age-grades/:identifier` route, which
 * would otherwise answer with the grade's own columns and none of the people
 * or news that make it a grade.
 */
export const ageGradeRoutes: RouteDefinition[] = [
  // --- Public ---------------------------------------------------------------
  {
    method: 'GET',
    path: '/api/age-grades-activity',
    handler: ageGradeActivity,
    description: 'The most recent posts across every published age grade',
  },
  {
    method: 'GET',
    path: '/api/my/age-grades',
    handler: myAgeGrades,
    middleware: [requireAuth],
    description: 'The age grades you administer',
  },
  {
    method: 'POST',
    path: '/api/age-grades',
    handler: registerAgeGrade,
    middleware: [requireAuth, rateLimit({ scope: 'age-grade-register', limit: 5, windowSeconds: 3600 })],
    description: 'Register your age grade. You become its lead administrator',
  },

  // The workspace route goes in before `:identifier/posts` and friends so that
  // `manage` is never read as a post slug.
  {
    method: 'GET',
    path: '/api/age-grades/:identifier/manage',
    handler: manageAgeGrade,
    middleware: [requireAuth],
    description: 'Everything about a grade, drafts included, for its administrators',
  },

  {
    method: 'GET',
    path: '/api/age-grades/:identifier/posts',
    handler: listAgeGradePosts,
    description: "An age grade's news, newest first",
  },
  {
    method: 'GET',
    path: '/api/age-grades/:identifier/posts/:postSlug',
    handler: showAgeGradePost,
    description: 'One post by an age grade',
  },
  {
    method: 'GET',
    path: '/api/age-grades/:identifier',
    handler: showAgeGrade,
    description: 'One age grade with its posts, its roster and its photographs',
  },

  // --- Run by the grade's own administrators --------------------------------
  {
    method: 'PATCH',
    path: '/api/age-grades/:identifier',
    handler: updateAgeGrade,
    middleware: [requireAuth],
    description: "Edit your age grade's own description",
  },
  {
    method: 'POST',
    path: '/api/age-grades/:identifier/posts',
    handler: createAgeGradePost,
    middleware: [requireAuth, rateLimit({ scope: 'age-grade-post', limit: 30, windowSeconds: 3600 })],
    description: 'Post news, a meeting notice or a report under your age grade',
  },
  {
    method: 'PATCH',
    path: '/api/age-grades/:identifier/posts/:postId',
    handler: updateAgeGradePost,
    middleware: [requireAuth],
    description: 'Edit or take down one of your age grade posts',
  },
  {
    method: 'DELETE',
    path: '/api/age-grades/:identifier/posts/:postId',
    handler: deleteAgeGradePost,
    middleware: [requireAuth],
    description: 'Delete one of your age grade posts',
  },

  // Appointing an administrator is reserved to the lead, so that no single
  // admin can quietly take a grade over.
  {
    method: 'POST',
    path: '/api/age-grades/:identifier/admins',
    handler: appointAgeGradeAdmin,
    middleware: [requireAuth],
    description: 'Appoint another administrator for your age grade. Lead administrators only',
  },
  {
    method: 'DELETE',
    path: '/api/age-grades/:identifier/admins/:userId',
    handler: removeAgeGradeAdmin,
    middleware: [requireAuth],
    description: 'Remove an administrator. The last lead cannot be removed',
  },

  {
    method: 'POST',
    path: '/api/age-grades/:identifier/members',
    handler: addAgeGradeMember,
    middleware: [requireAuth],
    description: 'Add somebody to your age grade roster',
  },
  {
    method: 'PATCH',
    path: '/api/age-grades/:identifier/members/:memberId',
    handler: updateAgeGradeMember,
    middleware: [requireAuth],
    description: 'Update a member of your age grade roster',
  },
  {
    method: 'DELETE',
    path: '/api/age-grades/:identifier/members/:memberId',
    handler: removeAgeGradeMember,
    middleware: [requireAuth],
    description: 'Remove somebody from your age grade roster',
  },
];
