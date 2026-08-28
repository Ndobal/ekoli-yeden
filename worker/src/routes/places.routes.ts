import type { RouteDefinition } from '../types/api';
import { requirePermission } from '../middleware/auth';
import {
  dismissPlaceCandidate,
  listPlaceCandidates,
  listPlaces,
  promotePlaceCandidate,
  showPlace,
} from '../controllers/places.controller';

/**
 * THE PLACES OF EKORI.
 *
 * Reading is open. Where somebody is from is not a secret, and the tree is what
 * every profile card, every dropdown and every "who is from Ajere" question
 * reads from.
 *
 * There is no create route, and no update route. A place appears because two
 * different members typed its name into their own profiles — the administrator
 * queue below promotes one early or corrects one the threshold created, and
 * that is the whole of the write surface. The list of places belongs to the
 * community, not to whoever last edited it.
 */
export const placeRoutes: RouteDefinition[] = [
  // Static and admin paths before `/api/places/:identifier`, so a place whose
  // slug happened to be "candidates" could not shadow the queue.
  {
    method: 'GET',
    path: '/api/admin/places/candidates',
    handler: listPlaceCandidates,
    middleware: [requirePermission('settings:manage')],
    description: 'Names members have typed that are not yet places',
  },
  {
    method: 'POST',
    path: '/api/admin/places/candidates/:id/promote',
    handler: promotePlaceCandidate,
    middleware: [requirePermission('settings:manage')],
    description: 'Make a typed name a real place, early or with its spelling corrected',
  },
  {
    method: 'POST',
    path: '/api/admin/places/candidates/:id/dismiss',
    handler: dismissPlaceCandidate,
    middleware: [requirePermission('settings:manage')],
    description: 'Set aside a name that is not a place',
  },
  {
    method: 'GET',
    path: '/api/places',
    handler: listPlaces,
    description: 'Every place, as a tree ordered for a picker',
  },
  {
    method: 'GET',
    path: '/api/places/:identifier',
    handler: showPlace,
    description: 'One place, what is above it, and what is inside it',
  },
];
