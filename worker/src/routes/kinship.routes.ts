import type { RouteDefinition } from '../types/api';
import { requireAuth, requirePermission } from '../middleware/auth';
import { rateLimit } from '../middleware/rate-limit';
import {
  acceptRelationship,
  birthdayChart,
  birthdaysToday,
  confirmDeath,
  contestMemorial,
  declineRelationship,
  hideBirthdayWish,
  listDeathReports,
  memorialNotice,
  myFamily,
  publishMemorial,
  rejectDeathReport,
  relationshipOptions,
  removeRelationship,
  reportDeath,
  requestRelationship,
  skipBirthday,
  wishBirthday,
} from '../controllers/kinship.controller';

/**
 * FAMILY, BIRTHDAYS AND REMEMBRANCE
 *
 * All of it is `requireAuth` rather than permission-gated: a member recording
 * who their brother is, or wishing somebody a happy birthday, is acting on
 * their own account. Permissions belong to the two admin routes at the bottom,
 * where the Preservation Team decides what the archive itself says.
 *
 * RATE LIMITS ARE PART OF THE DESIGN HERE, NOT AN AFTERTHOUGHT.
 *
 * A connection request is how a stranger reaches a member's attention, and a
 * death report is a claim about somebody's life. Unlimited, each is a
 * harassment channel rather than a feature — so both are capped, and the
 * kinship service caps requests per day on top of this.
 */
export const kinshipRoutes: RouteDefinition[] = [
  // --- Family ---------------------------------------------------------------
  {
    method: 'GET',
    path: '/api/membership/family',
    handler: myFamily,
    middleware: [requireAuth],
    description: 'My family: confirmed connections, and the requests waiting on me',
  },
  {
    method: 'GET',
    path: '/api/membership/family/options',
    handler: relationshipOptions,
    middleware: [requireAuth],
    description: 'The relationships the platform recognises, grouped for a picker',
  },
  {
    method: 'POST',
    path: '/api/membership/family/requests',
    handler: requestRelationship,
    middleware: [
      requireAuth,
      rateLimit({ scope: 'kinship-request', limit: 40, windowSeconds: 3600 }),
    ],
    description: 'Ask somebody to confirm a family relationship, by member or by phone number',
  },
  {
    method: 'POST',
    path: '/api/membership/family/:id/accept',
    handler: acceptRelationship,
    middleware: [requireAuth],
    description: 'Confirm a relationship, choosing what you are to them in return',
  },
  {
    method: 'POST',
    path: '/api/membership/family/:id/decline',
    handler: declineRelationship,
    middleware: [requireAuth],
    description: 'Decline a connection request',
  },
  {
    method: 'DELETE',
    path: '/api/membership/family/:id',
    handler: removeRelationship,
    middleware: [requireAuth],
    description: 'End a connection. Either side may, and it takes only one of them',
  },

  // --- Birthdays ------------------------------------------------------------
  {
    method: 'GET',
    path: '/api/membership/birthdays/today',
    handler: birthdaysToday,
    middleware: [requireAuth],
    description: "Whose birthday it is among the people I know, and whether it is my own",
  },
  {
    method: 'DELETE',
    path: '/api/membership/birthdays/wishes/:id',
    handler: hideBirthdayWish,
    middleware: [requireAuth],
    description: 'Hide a message left on my own birthday chart',
  },
  {
    method: 'POST',
    path: '/api/membership/birthdays/:userId/wish',
    handler: wishBirthday,
    middleware: [
      requireAuth,
      rateLimit({ scope: 'birthday-wish', limit: 60, windowSeconds: 3600 }),
    ],
    description: 'Wish a member a happy birthday. Kept in their chart for that year',
  },
  {
    method: 'POST',
    path: '/api/membership/birthdays/:userId/skip',
    handler: skipBirthday,
    middleware: [requireAuth],
    description: 'Not now. The card does not come back until next year',
  },

  // --- Remembrance ----------------------------------------------------------
  {
    method: 'GET',
    path: '/api/membership/remembrance/notice',
    handler: memorialNotice,
    middleware: [requireAuth],
    description: 'What a reported or memorialised account is told when its holder signs in',
  },
  {
    method: 'POST',
    path: '/api/membership/remembrance/contest',
    handler: contestMemorial,
    middleware: [requireAuth],
    description: 'Contest a report about your own account. Restores it immediately',
  },
  {
    method: 'POST',
    path: '/api/membership/remembrance/reports',
    handler: reportDeath,
    middleware: [
      requireAuth,
      // Deliberately tight. This is a claim about somebody's life, and there is
      // no legitimate reason to make many of them in an hour.
      rateLimit({ scope: 'death-report', limit: 5, windowSeconds: 3600 }),
    ],
    description: 'Record that somebody has died. Changes nothing until family confirm it',
  },
  {
    method: 'POST',
    path: '/api/membership/remembrance/reports/:id/confirm',
    handler: confirmDeath,
    middleware: [requireAuth],
    description: 'Confirm a report. Requires a close relationship recorded before it was made',
  },

  // --- The Preservation Team ------------------------------------------------
  {
    method: 'GET',
    path: '/api/admin/remembrance',
    handler: listDeathReports,
    middleware: [requirePermission('users:update')],
    description: 'Death reports awaiting review',
  },
  {
    method: 'POST',
    path: '/api/admin/remembrance/:id/publish',
    handler: publishMemorial,
    middleware: [requirePermission('users:update')],
    description: 'Publish the memorial page in the Ancestry Records',
  },
  {
    method: 'POST',
    path: '/api/admin/remembrance/:id/reject',
    handler: rejectDeathReport,
    middleware: [requirePermission('users:update')],
    description: 'Reject a report and restore the account. Available at any stage',
  },
];

/**
 * A member's public birthday chart, under `/api/members/:handle`.
 *
 * Separate from the list above because it is one member looking at another
 * rather than an account acting on itself, and it follows the same visibility
 * rules as the rest of a profile.
 */
export const publicKinshipRoutes: RouteDefinition[] = [
  {
    method: 'GET',
    path: '/api/members/:handle/birthdays',
    handler: birthdayChart,
    description: 'One year of a member\'s birthday chart, and every year that has wishes in it',
  },
];
