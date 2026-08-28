import type { RouteDefinition } from '../types/api';
import {
  joinCommunity,
  listNotifications,
  markAllNotificationsRead,
  markNotificationRead,
  memberDashboard,
  membershipOptions,
  membershipStatistics,
  myProfile,
  searchSkills,
  showMember,
  updateMyInterests,
  updateMyPrivacy,
  updateMyProfile,
  updateMySkills,
  directoryFacets,
  searchDirectory,
} from '../controllers/member.controller';
import { requireAuth, requirePermission } from '../middleware/auth';
import { rateLimit } from '../middleware/rate-limit';

/**
 * YAKOLI MEMBERSHIP — the one Okoli account.
 *
 * The identity every later module hangs off. The forum, the opportunities
 * board and the directory do not get user systems of their own; they read the
 * profile these routes maintain.
 *
 * Two things to notice about the shape:
 *
 * `/api/membership/*` is the account acting on itself — always `requireAuth`,
 * never a permission, because a member editing their own profile is not
 * exercising a privilege.
 *
 * `/api/members/:handle` is one member looking at another. It requires a
 * session, and `visibleProfile` still shapes what comes back — the guard says
 * this is a members' directory, the shaping says what this member may see of
 * that one.
 *
 * THE DIRECTORY IS NOT PUBLIC, AND THAT IS A DELIBERATE CHANGE.
 *
 * It was readable without an account so a relative abroad could find somebody
 * without joining first. The cost of that is a list of real people, with their
 * professions and their locations, standing open to anybody who finds the URL —
 * including anybody assembling one. Joining is free, takes a minute, and is the
 * thing the directory is for. So the door is now behind it.
 */
export const membershipRoutes: RouteDefinition[] = [
  // --- The Yakoli directory (Module 7) --------------------------------------
  // Members only. Only members who opted in appear at all — that is enforced in
  // the query rather than filtered afterwards — and each entry is then shaped
  // by what that member chose to show.
  {
    method: 'GET',
    path: '/api/directory/facets',
    handler: directoryFacets,
    middleware: [requireAuth],
    description: 'The professions and countries that actually have members behind them',
  },
  {
    method: 'GET',
    path: '/api/directory',
    handler: searchDirectory,
    middleware: [requireAuth],
    description: 'Members who chose to be findable, by profession, skill and place',
  },

  // --- Joining and the vocabulary -------------------------------------------
  {
    method: 'GET',
    path: '/api/membership/options',
    handler: membershipOptions,
    description:
      'Professions, skills, interests and the wording for every choice the joining form offers',
  },
  {
    method: 'GET',
    path: '/api/membership/skills',
    handler: searchSkills,
    description: 'The skill vocabulary, searchable, ordered by how many members hold each',
  },
  {
    method: 'POST',
    path: '/api/membership/join',
    handler: joinCommunity,
    middleware: [requireAuth, rateLimit({ scope: 'membership-join', limit: 5, windowSeconds: 3600 })],
    description: 'Turn this account into a Yakoli membership',
  },

  // --- The account acting on itself -----------------------------------------
  {
    method: 'GET',
    path: '/api/membership/dashboard',
    handler: memberDashboard,
    middleware: [requireAuth],
    description: 'The whole Okoli account in one request — profile, notifications, what is missing',
  },
  {
    method: 'GET',
    path: '/api/membership/me',
    handler: myProfile,
    middleware: [requireAuth],
    description: 'Your own profile, in full',
  },
  {
    method: 'PATCH',
    path: '/api/membership/me',
    handler: updateMyProfile,
    middleware: [requireAuth],
    description: 'Save one stage of your profile. Everything is optional',
  },
  {
    method: 'PATCH',
    path: '/api/membership/me/privacy',
    handler: updateMyPrivacy,
    middleware: [requireAuth],
    description: 'Change what other people can see, and whether you appear in the directory',
  },
  {
    method: 'PUT',
    path: '/api/membership/me/skills',
    handler: updateMySkills,
    middleware: [requireAuth],
    description: 'Replace your skills. A skill the list does not have is added to it',
  },
  {
    method: 'PUT',
    path: '/api/membership/me/interests',
    handler: updateMyInterests,
    middleware: [requireAuth],
    description: 'Replace the areas of community life you are interested in',
  },

  // --- Notifications --------------------------------------------------------
  {
    method: 'GET',
    path: '/api/notifications',
    handler: listNotifications,
    middleware: [requireAuth],
    description: 'Your notifications, newest first',
  },
  {
    method: 'POST',
    path: '/api/notifications/read-all',
    handler: markAllNotificationsRead,
    middleware: [requireAuth],
    description: 'Mark every notification read',
  },
  {
    method: 'POST',
    path: '/api/notifications/:id/read',
    handler: markNotificationRead,
    middleware: [requireAuth],
    description: 'Mark one notification read',
  },

  // --- Administration -------------------------------------------------------
  {
    method: 'GET',
    path: '/api/admin/membership/statistics',
    handler: membershipStatistics,
    middleware: [requirePermission('users:read')],
    description:
      'The community snapshot — counts by work situation, country and skill. Aggregates only',
  },

  // --- One member looking at another ----------------------------------------
  // `requireAuth`, and then `visibleProfile` on top of it. The guard decides
  // that this is a members' directory; the shaping still decides what any
  // particular member may read of any particular profile, because being signed
  // in is not the same as being entitled to somebody's phone number.
  {
    method: 'GET',
    path: '/api/members/:handle',
    handler: showMember,
    middleware: [requireAuth],
    description: "One member's profile, shaped to what you are allowed to see",
  },
];
