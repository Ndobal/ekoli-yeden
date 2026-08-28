import type { RouteDefinition } from '../types/api';
import { requireAuth, requireMembership } from '../middleware/auth';
import { rateLimit } from '../middleware/rate-limit';
import {
  createOpportunity,
  listForReview,
  listOpportunities,
  listOpportunityReports,
  opportunityOptions,
  reportOpportunity,
  reviewOpportunity,
  saveOpportunity,
  settleOpportunityReport,
  showOpportunity,
} from '../controllers/opportunity.controller';

/**
 * YAKOLI OPPORTUNITIES (Module 6)
 *
 * Reading requires an account and posting requires a membership. The reasoning
 * is at the top of `opportunity.controller.ts` and comes down to two things:
 * the feature IS the matching, which needs a profile to match against; and a
 * public jobs board carrying a community's name is a standing invitation to
 * whoever wants to defraud that community.
 *
 * `/options` is the exception — open, so a page can render its filters and its
 * fraud warning before the visitor has signed in.
 */
export const opportunityRoutes: RouteDefinition[] = [
  {
    method: 'GET',
    path: '/api/opportunities/options',
    handler: opportunityOptions,
    description: 'The kinds, places and reporting reasons the board recognises',
  },
  {
    method: 'GET',
    path: '/api/opportunities',
    handler: listOpportunities,
    middleware: [requireAuth],
    description: 'The board, ordered by what you can do and how near it is',
  },
  {
    method: 'POST',
    path: '/api/opportunities',
    handler: createOpportunity,
    middleware: [
      requireMembership,
      // A member posts a handful of listings, not a hundred. A tight limit here
      // is one of the cheaper defences against somebody flooding the board with
      // fraudulent listings faster than they can be reviewed.
      rateLimit({ scope: 'opportunity-create', limit: 10, windowSeconds: 86400 }),
    ],
    description: 'Post a job, scholarship or training. Goes to review before anybody sees it',
  },
  {
    method: 'GET',
    path: '/api/opportunities/:identifier',
    handler: showOpportunity,
    middleware: [requireAuth],
    description: 'One listing, with which of its skills you already have',
  },
  {
    method: 'POST',
    path: '/api/opportunities/:id/save',
    handler: saveOpportunity,
    middleware: [requireAuth],
    description: 'Keep a listing for later',
  },
  {
    method: 'DELETE',
    path: '/api/opportunities/:id/save',
    handler: saveOpportunity,
    middleware: [requireAuth],
    description: 'Stop keeping a listing',
  },
  {
    method: 'POST',
    path: '/api/opportunities/:id/report',
    handler: reportOpportunity,
    middleware: [
      requireAuth,
      // Deliberately generous. Reporting a suspected fraud is a thing the
      // archive wants people to do without hesitating, and a member who has
      // just found a scam ring may legitimately report several in a row.
      rateLimit({ scope: 'opportunity-report', limit: 30, windowSeconds: 3600 }),
    ],
    description: 'Report a listing as fraudulent, misleading or closed',
  },

  // --- The Opportunities Editor --------------------------------------------
  {
    method: 'GET',
    path: '/api/admin/opportunities/reports',
    handler: listOpportunityReports,
    middleware: [requireAuth],
    description: 'Listings members have reported',
  },
  {
    method: 'POST',
    path: '/api/admin/opportunities/reports/:id/settle',
    handler: settleOpportunityReport,
    middleware: [requireAuth],
    description: 'Uphold or dismiss a report',
  },
  {
    method: 'GET',
    path: '/api/admin/opportunities',
    handler: listForReview,
    middleware: [requireAuth],
    description: 'Listings awaiting review',
  },
  {
    method: 'PATCH',
    path: '/api/admin/opportunities/:id',
    handler: reviewOpportunity,
    middleware: [requireAuth],
    description: 'Publish, reject, verify or unflag a listing',
  },
];
