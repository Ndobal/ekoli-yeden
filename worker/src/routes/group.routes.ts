import type { RouteDefinition } from '../types/api';
import { requireAuth } from '../middleware/auth';
import { rateLimit } from '../middleware/rate-limit';
import {
  accountHistory,
  addOfficer,
  addPaymentAccount,
  createGroup,
  decideJoinRequest,
  declareDues,
  groupKinds,
  groupSuggestions,
  joinGroup,
  listDues,
  listGroups,
  listIssues,
  listJoinRequests,
  raiseIssue,
  removeOfficer,
  settleDues,
  settleIssue,
  showGroup,
  updateGroup,
  updatePaymentAccount,
} from '../controllers/group.controller';

/**
 * COMMUNITY GROUPS
 *
 * Age grades, cultural groups, associations and unions.
 *
 * The authority these routes check is narrow by design: a row in `group_admins`
 * for one group. Being an officer of the Ijom grade is not a role, grants
 * nothing anywhere else in the archive, and no route outside this file consults
 * it. That is the whole reason a community can be handed the running of its own
 * page without being handed the archive.
 *
 * ORDERING. The static segments — `/kinds`, and everything under
 * `/api/groups/members`, `/api/groups/dues`, `/api/groups/issues` — are
 * registered before `/:identifier`, or a group whose slug is "kinds" would
 * shadow the picker and a POST to `/api/groups/dues/x/settle` would be read as
 * a group called "dues".
 */
export const groupRoutes: RouteDefinition[] = [
  // --- Static segments first ------------------------------------------------
  {
    method: 'GET',
    path: '/api/groups/kinds',
    handler: groupKinds,
    description: 'The kinds of group the archive recognises, and how joining can work',
  },
  {
    method: 'POST',
    path: '/api/groups/members/:memberId/decide',
    handler: decideJoinRequest,
    middleware: [requireAuth],
    description: 'An officer answering a request to join',
  },
  {
    method: 'POST',
    path: '/api/groups/dues/:paymentId/settle',
    handler: settleDues,
    middleware: [requireAuth],
    description: 'The treasurer confirming a declared payment against the account',
  },
  {
    method: 'POST',
    path: '/api/groups/issues/:issueId/settle',
    handler: settleIssue,
    middleware: [requireAuth],
    description: 'An officer answering something a member raised',
  },

  // --- A member's own view --------------------------------------------------
  {
    method: 'GET',
    path: '/api/membership/groups/suggestions',
    handler: groupSuggestions,
    middleware: [requireAuth],
    description: 'Which age grade is mine, and which groups I already belong to',
  },

  // --- The list, and registering one ---------------------------------------
  {
    method: 'GET',
    path: '/api/groups',
    handler: listGroups,
    description: 'The community groups of Ekoli-Yeden',
  },
  {
    method: 'POST',
    path: '/api/groups',
    handler: createGroup,
    middleware: [
      requireAuth,
      // A community forms a handful of groups a year, not a handful an hour.
      rateLimit({ scope: 'group-create', limit: 5, windowSeconds: 86400 }),
    ],
    description: 'Register a group. The person who registers it becomes its lead officer',
  },

  // --- One group ------------------------------------------------------------
  {
    method: 'GET',
    path: '/api/groups/:identifier',
    handler: showGroup,
    description: 'One group: its page, its officers, its roster and where the viewer stands in it',
  },
  {
    method: 'PATCH',
    path: '/api/groups/:id',
    handler: updateGroup,
    middleware: [requireAuth],
    description: "A group's own officers editing its page and its dues",
  },
  {
    method: 'POST',
    path: '/api/groups/:id/join',
    handler: joinGroup,
    middleware: [
      requireAuth,
      rateLimit({ scope: 'group-join', limit: 20, windowSeconds: 3600 }),
    ],
    description: 'Ask to join, or join outright where the group allows it',
  },
  {
    method: 'GET',
    path: '/api/groups/:id/requests',
    handler: listJoinRequests,
    middleware: [requireAuth],
    description: 'Who has asked to join, for the officers',
  },
  {
    method: 'POST',
    path: '/api/groups/:id/officers',
    handler: addOfficer,
    middleware: [requireAuth],
    description: 'The lead officer appointing another',
  },
  {
    method: 'DELETE',
    path: '/api/groups/:id/officers/:userId',
    handler: removeOfficer,
    middleware: [requireAuth],
    description: 'Stand an officer down. The last lead officer cannot be removed',
  },

  // --- Money ----------------------------------------------------------------
  {
    method: 'POST',
    path: '/api/groups/:id/accounts',
    handler: addPaymentAccount,
    middleware: [requireAuth],
    description: 'Where members should send the dues. Shown to members, never to the public',
  },
  {
    method: 'PATCH',
    path: '/api/groups/:id/accounts/:accountId',
    handler: updatePaymentAccount,
    middleware: [requireAuth],
    description: 'Change the account details. Every change keeps what the value was before',
  },
  {
    method: 'GET',
    path: '/api/groups/:id/accounts/history',
    handler: accountHistory,
    middleware: [requireAuth],
    description: 'Who changed the account details, when, and what they were before',
  },
  {
    method: 'GET',
    path: '/api/groups/:id/dues',
    handler: listDues,
    middleware: [requireAuth],
    description: 'My payments, or every payment where I am an officer',
  },
  {
    method: 'POST',
    path: '/api/groups/:id/dues',
    handler: declareDues,
    middleware: [requireAuth],
    description: 'Record a payment made. No money passes through this website',
  },

  // --- Issues ---------------------------------------------------------------
  {
    method: 'GET',
    path: '/api/groups/:id/issues',
    handler: listIssues,
    middleware: [requireAuth],
    description: 'What I have raised, or everything where I am an officer',
  },
  {
    method: 'POST',
    path: '/api/groups/:id/issues',
    handler: raiseIssue,
    middleware: [requireAuth],
    description: 'Raise something with the officers of a group. Private by default',
  },
];
