import type { RouteDefinition } from '../types/api';
import {
  attachSource,
  createSource,
  editorialHero,
  editorialNavigation,
  listSources,
  listStrings,
  listVersions,
  publishString,
  reviewString,
  saveStringDraft,
  showVersion,
  submitString,
  updateHeroSlide,
  updateNavigationItem,
} from '../controllers/cms.controller';
import { editorialDashboard } from '../controllers/editorial.controller';
import { requireAuth, requirePermission } from '../middleware/auth';

/**
 * THE EDITORIAL API.
 *
 * Everything the Editorial Team needs to run the public website, and nothing
 * else. There is no route in this file that touches users, roles, permissions,
 * security settings, the audit log, or any Cloudflare resource — an editorial
 * account cannot reach those, because the endpoints that would let it are in
 * `admin.routes.ts` behind permissions no editorial role holds.
 *
 * The permission on each route is the specific thing it does. `content.edit`
 * is not `content.publish`, so a Writer can change the homepage text and a
 * Publisher is still required to make that change visible.
 */
export const editorialRoutes: RouteDefinition[] = [
  {
    method: 'GET',
    path: '/api/editorial/dashboard',
    handler: editorialDashboard,
    middleware: [requireAuth],
    description: 'Draft, pending, published and rejected counts for the Editorial Team',
  },

  // --- Website text ---------------------------------------------------------
  {
    method: 'GET',
    path: '/api/editorial/strings',
    handler: listStrings,
    middleware: [requirePermission('strings:read')],
    description: 'All editable website text, grouped, with drafts',
  },
  {
    method: 'PUT',
    path: '/api/editorial/strings/:key',
    handler: saveStringDraft,
    middleware: [requirePermission('strings:update')],
    description: 'Save a draft change to a piece of website text',
  },
  {
    method: 'POST',
    path: '/api/editorial/strings/:key/submit',
    handler: submitString,
    middleware: [requirePermission('strings:update')],
    description: 'Submit a text draft for review',
  },
  {
    method: 'POST',
    path: '/api/editorial/strings/:key/review',
    handler: reviewString,
    middleware: [requirePermission('content.review')],
    description: 'Approve or reject a submitted text change',
  },
  {
    method: 'POST',
    path: '/api/editorial/strings/:key/publish',
    handler: publishString,
    middleware: [requirePermission('strings:publish')],
    description: 'Publish an approved text change to the live website',
  },

  // --- Hero carousel --------------------------------------------------------
  {
    method: 'GET',
    path: '/api/editorial/hero',
    handler: editorialHero,
    middleware: [requirePermission('strings:read')],
    description: 'The five homepage hero slides, including unpublished ones',
  },
  {
    method: 'PUT',
    path: '/api/editorial/hero/:slide',
    handler: updateHeroSlide,
    middleware: [requirePermission('hero:update')],
    description: 'Edit one hero slide',
  },

  // --- Navigation -----------------------------------------------------------
  {
    method: 'GET',
    path: '/api/editorial/navigation',
    handler: editorialNavigation,
    middleware: [requirePermission('strings:read')],
    description: 'Navigation menus',
  },
  {
    method: 'PATCH',
    path: '/api/editorial/navigation/:id',
    handler: updateNavigationItem,
    middleware: [requirePermission('navigation:update')],
    description: 'Edit a navigation label, destination or order',
  },

  // --- Sources and references -----------------------------------------------
  {
    method: 'GET',
    path: '/api/editorial/sources',
    handler: listSources,
    middleware: [requirePermission('sources:read')],
    description: 'The citation library',
  },
  {
    method: 'POST',
    path: '/api/editorial/sources',
    handler: createSource,
    middleware: [requirePermission('sources:create')],
    description: 'Record a new source',
  },
  {
    method: 'POST',
    path: '/api/editorial/sources/attach',
    handler: attachSource,
    middleware: [requirePermission('sources:update')],
    description: 'Cite a source on a record',
  },

  // --- Version history ------------------------------------------------------
  {
    method: 'GET',
    path: '/api/editorial/versions/:resourceType/:resourceId',
    handler: listVersions,
    middleware: [requirePermission('versions:read')],
    description: 'The edit history of one record',
  },
  {
    method: 'GET',
    path: '/api/editorial/versions/:resourceType/:resourceId/:version',
    handler: showVersion,
    middleware: [requirePermission('versions:read')],
    description: 'One earlier version of a record, in full',
  },
];
