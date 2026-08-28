import type { RouteDefinition } from '../types/api';
import { requireAnyPermission, requirePermission } from '../middleware/auth';
import {
  addNewsMedia,
  addNewsSource,
  createNews,
  editorialList,
  editorialShow,
  listCategories,
  listNews,
  listTags,
  newsOverview,
  removeNewsMedia,
  removeNewsSource,
  reorderNewsMedia,
  runScheduledPublication,
  setNewsFlags,
  setNewsState,
  showNews,
  updateNews,
  updateNewsMedia,
  upsertCategory,
} from '../controllers/news.controller';

/**
 * NEWS.
 *
 * ---------------------------------------------------------------------------
 * WHY THE PUBLIC ROUTES ARE UNDER `/api/news-portal`
 * ---------------------------------------------------------------------------
 *
 * `/api/news` already exists: it is generated from the content registry, and
 * it serves the plain record that the archive's other sections use. Taking that
 * path over would break every existing caller — including the SEO middleware at
 * the edge, which looks a story up by slug to build a link preview.
 *
 * So the portal, which returns the same stories with their photographs, their
 * film, their category and their sources attached, sits beside it. Both are
 * real; one is the record and one is the publication.
 *
 * ---------------------------------------------------------------------------
 * NOTHING HERE TRUSTS THE CLIENT
 * ---------------------------------------------------------------------------
 *
 * The public routes carry no middleware because they need none: the queries
 * behind them cannot return anything that is not published. The editorial
 * routes carry `news:update`, and publishing additionally requires
 * `news:publish`, checked inside the handler — writing a story and making it
 * public under the community's name are different authorities.
 */
export const newsRoutes: RouteDefinition[] = [
  // --- Public: static segments before `:identifier` ------------------------
  {
    method: 'GET',
    path: '/api/news-portal/overview',
    handler: newsOverview,
    description: 'The front of the section in one request: announcements, featured, latest, film',
  },
  {
    method: 'GET',
    path: '/api/news-portal/categories',
    handler: listCategories,
    description: 'The categories, managed by the Editorial Team',
  },
  {
    method: 'GET',
    path: '/api/news-portal/tags',
    handler: listTags,
    description: 'The tags in use, most used first',
  },
  {
    method: 'GET',
    path: '/api/news-portal',
    handler: listNews,
    description: 'Published stories, searchable and filterable. Never anything else',
  },
  {
    method: 'GET',
    path: '/api/news-portal/:identifier',
    handler: showNews,
    description: 'One published story with its photographs, film, sources and tags',
  },

  // --- Editorial -----------------------------------------------------------
  // The newsroom's own three doors.
  //
  // `news:update` alone was the wrong guard here. The bridge in
  // `acceptedPermissionsFor` maps `news:update` onto `content.edit`, which the
  // Writer and the Editor hold — and the Reviewer and the Publisher do not.
  // A Reviewer therefore could not open the queue they exist to work, and the
  // Publisher was stopped at the door of the very endpoint that publishes, so
  // the `news:publish` check inside it could never be reached at all.
  //
  // Reaching the newsroom and acting inside it are separate questions. These
  // routes ask the first; `setNewsState` still asks the second before anything
  // becomes public.
  {
    method: 'GET',
    path: '/api/editorial/news-list',
    handler: editorialList,
    middleware: [requireAnyPermission(['news:update', 'news:review', 'news:publish'])],
    description: 'Every story, whatever its state, with the counts for the tabs',
  },
  {
    method: 'POST',
    path: '/api/editorial/news-categories',
    handler: upsertCategory,
    middleware: [requirePermission('news:update')],
    description: 'Create or edit a category without a deployment',
  },
  {
    method: 'POST',
    path: '/api/editorial/news/publish-due',
    handler: runScheduledPublication,
    middleware: [requirePermission('news:publish')],
    description: 'Publish everything whose scheduled moment has passed, by hand',
  },
  {
    method: 'POST',
    path: '/api/editorial/news',
    handler: createNews,
    middleware: [requirePermission('news:update')],
    description: 'Start a story. Always as a draft',
  },

  // Static sub-paths before the bare `:id`.
  {
    method: 'POST',
    path: '/api/editorial/news/:id/state',
    handler: setNewsState,
    middleware: [requireAnyPermission(['news:update', 'news:review', 'news:publish'])],
    description: 'Submit, approve, request changes, publish, schedule, archive or reject',
  },
  {
    method: 'POST',
    path: '/api/editorial/news/:id/flags',
    handler: setNewsFlags,
    middleware: [requirePermission('news:update')],
    description: 'Feature a story, or mark it important with an expiry',
  },
  {
    method: 'POST',
    path: '/api/editorial/news/:id/media/order',
    handler: reorderNewsMedia,
    middleware: [requirePermission('news:update')],
    description: 'Reorder a story photograph gallery',
  },
  {
    method: 'POST',
    path: '/api/editorial/news/:id/media',
    handler: addNewsMedia,
    middleware: [requirePermission('news:update')],
    description: 'Attach a photograph from the media library, or a YouTube video',
  },
  {
    method: 'PATCH',
    path: '/api/editorial/news/:id/media/:mediaId',
    handler: updateNewsMedia,
    middleware: [requirePermission('news:update')],
    description: 'Caption, credit and alt text for one photograph',
  },
  {
    method: 'DELETE',
    path: '/api/editorial/news/:id/media/:mediaId',
    handler: removeNewsMedia,
    middleware: [requirePermission('news:update')],
    description: 'Take a photograph off this story. The file stays in the library',
  },
  {
    method: 'POST',
    path: '/api/editorial/news/:id/sources',
    handler: addNewsSource,
    middleware: [requirePermission('news:update')],
    description: 'Record where the story came from',
  },
  {
    method: 'DELETE',
    path: '/api/editorial/news/:id/sources/:sourceId',
    handler: removeNewsSource,
    middleware: [requirePermission('news:update')],
    description: 'Remove a source',
  },
  {
    method: 'GET',
    path: '/api/editorial/news/:identifier',
    handler: editorialShow,
    middleware: [requireAnyPermission(['news:update', 'news:review', 'news:publish'])],
    description: 'One story to edit or preview, whatever its state',
  },
  {
    method: 'PATCH',
    path: '/api/editorial/news/:id',
    handler: updateNews,
    middleware: [requirePermission('news:update')],
    description: 'Edit a story. Snapshots the previous version and keeps the contributor',
  },
];
