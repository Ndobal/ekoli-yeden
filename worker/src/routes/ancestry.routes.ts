import type { RouteDefinition } from '../types/api';
import { requireAuth } from '../middleware/auth';
import { rateLimit } from '../middleware/rate-limit';
import { addTribute, listAncestry, showAncestry } from '../controllers/ancestry.controller';

/**
 * ANCESTRY RECORDS.
 *
 * The reading routes carry no `requireAuth`, and that is the point of the
 * section: a memorial only members can read is one the family living abroad
 * cannot show their children. The repository serves `published` records only,
 * so there is nothing here for an anonymous caller to reach that the archive
 * has not decided to publish.
 *
 * There is no create route. A memorial exists because a death was reported,
 * confirmed by somebody who was already family, and published by the
 * Preservation Team — three separate acts, each with an undo, all in
 * `remembrance.service.ts`. A create endpoint here would go around every one
 * of them.
 */
export const ancestryRoutes: RouteDefinition[] = [
  {
    method: 'GET',
    path: '/api/ancestry',
    handler: listAncestry,
    description: 'Everybody the archive remembers, most recent first, the undated last',
  },
  {
    // Ahead of `/api/ancestry/:identifier`, so `tributes` is never read as
    // somebody's slug.
    method: 'POST',
    path: '/api/ancestry/:identifier/tributes',
    handler: addTribute,
    middleware: [
      requireAuth,
      rateLimit({ scope: 'tribute', limit: 20, windowSeconds: 3600 }),
    ],
    description: 'Leave a tribute on a memorial',
  },
  {
    method: 'GET',
    path: '/api/ancestry/:identifier',
    handler: showAncestry,
    description: 'One memorial, with the tributes left on it',
  },
];
