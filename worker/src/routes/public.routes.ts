import type { RouteDefinition } from '../types/api';
import { communityOverview } from '../controllers/community.controller';
import { CONTENT_RESOURCES } from '../services/content-registry';
import { publicList, publicShow } from '../controllers/content.controller';
import { listFestivals, showFestival, lebokuIndex } from '../controllers/festival.controller';
import { allPhotographs, showGallery, galleryAlbums } from '../controllers/gallery.controller';
import { eventsCalendar } from '../controllers/event.controller';
import {
  dictionaryIndex,
  listCategories,
  listWords,
  showCategory,
  showWord,
} from '../controllers/language.controller';
import { publicSettings } from '../controllers/settings.controller';
import { search, searchSources } from '../controllers/search.controller';
import { serveFile, mediaConfig } from '../controllers/media.controller';
import { health, readiness } from '../controllers/health.controller';
import { preservationTeamStructure } from '../controllers/auth.controller';
import {
  bundle,
  contributorsForResource,
  heroCarousel,
  sourcesForResource,
} from '../controllers/cms.controller';

/**
 * Public read endpoints.
 *
 * Everything here is anonymous and returns published content only. The status
 * filter is applied in `ContentService`, not here, so no route can accidentally
 * expose a draft.
 */

/** Content types whose list/show routes are generated from the registry. */
const GENERATED_KEYS = [
  'pages',
  'history',
  'culture',
  'age-grades',
  'cultural-groups',
  'music',
  'leaders',
  'people',
  'news',
  'events',
  'galleries',
  'videos',
  'stories',
  'recordings',
  'quizzes',
  'businesses',
  'organizations',
  'community',
] as const;

function generatedContentRoutes(): RouteDefinition[] {
  const routes: RouteDefinition[] = [];

  for (const key of GENERATED_KEYS) {
    const resource = CONTENT_RESOURCES[key];
    if (!resource) continue;

    routes.push(
      {
        method: 'GET',
        path: `/api/${resource.key}`,
        handler: publicList(resource),
        description: `List published ${resource.label.toLowerCase()} records`,
      },
      {
        method: 'GET',
        path: `/api/${resource.key}/:identifier`,
        handler: publicShow(resource),
        description: `Read one published ${resource.label.toLowerCase()} by slug or id`,
      },
    );
  }
  return routes;
}

export const publicRoutes: RouteDefinition[] = [
  // --- Health --------------------------------------------------------------
  { method: 'GET', path: '/api/health', handler: health, description: 'Service health check' },
  {
    method: 'GET',
    path: '/api/health/ready',
    handler: readiness,
    description: 'Deep readiness check across D1, R2 and configuration',
  },

  // --- Settings ------------------------------------------------------------
  {
    method: 'GET',
    path: '/api/settings',
    handler: publicSettings,
    description: 'Public site settings used to render the website',
  },

  // --- CMS -----------------------------------------------------------------
  // The endpoint that makes the site content-driven: one request returns every
  // published string, the hero carousel and the navigation.
  {
    method: 'GET',
    path: '/api/cms/bundle',
    handler: bundle,
    description: 'All published website text, hero slides and navigation, in one request',
  },
  {
    method: 'GET',
    path: '/api/cms/hero',
    handler: heroCarousel,
    description: 'The five homepage hero slides with their images resolved',
  },
  {
    method: 'GET',
    path: '/api/sources/:resourceType/:resourceId',
    handler: sourcesForResource,
    description: 'The sources and references cited by one record',
  },
  {
    method: 'GET',
    path: '/api/contributors/:resourceType/:resourceId',
    handler: contributorsForResource,
    description: 'Contributor acknowledgement for one record',
  },

  // --- Search --------------------------------------------------------------
  { method: 'GET', path: '/api/search', handler: search, description: 'Search the whole archive' },
  // The community hub: who is here, what they belong to, and what has happened.
  {
    method: 'GET',
    path: '/api/community/overview',
    handler: communityOverview,
    description: 'Members, groups, counts and a feed of what has happened lately',
  },
  {
    method: 'GET',
    path: '/api/search/sources',
    handler: searchSources,
    description: 'What the archive search covers',
  },

  // --- Language ------------------------------------------------------------
  // The named routes are registered before `/api/language/:identifier` so that
  // `categories` and `index` are never mistaken for a word id.
  {
    method: 'GET',
    path: '/api/language/index',
    handler: dictionaryIndex,
    description:
      'The A–Z index with counts, the parts of speech and entry types to filter by, and how much '
      + 'of the language is recorded so far',
  },
  {
    method: 'GET',
    path: '/api/language/categories',
    handler: listCategories,
    description: 'Ekoli language categories',
  },
  {
    method: 'GET',
    path: '/api/language/categories/:slug',
    handler: showCategory,
    description: 'One language category and its words',
  },
  { method: 'GET', path: '/api/language', handler: listWords, description: 'Ekoli language entries' },
  {
    method: 'GET',
    path: '/api/language/:identifier',
    handler: showWord,
    description: 'One Ekoli language entry with its pronunciation recordings',
  },

  // --- Festivals and Leboku ------------------------------------------------
  {
    method: 'GET',
    path: '/api/festivals',
    handler: listFestivals,
    description: 'All published festivals, with the featured edition separated out',
  },
  {
    method: 'GET',
    path: '/api/festivals/:identifier',
    handler: showFestival,
    description: 'One festival with its events, gallery and videos',
  },
  {
    method: 'GET',
    path: '/api/leboku',
    handler: lebokuIndex,
    description: 'The Leboku festival series, year by year',
  },
  {
    method: 'GET',
    path: '/api/leboku/:year',
    handler: showFestival,
    description: 'One Leboku edition, e.g. /api/leboku/2026',
  },

  // --- Galleries -----------------------------------------------------------
  // Registered ahead of the generated content routes so that a gallery is
  // returned with its photographs in it. The generated route would answer with
  // the album's own columns and nothing inside — a page with a title and no
  // pictures.
  {
    method: 'GET',
    path: '/api/photographs',
    handler: allPhotographs,
    description:
      'Every published photograph in the archive, newest first, whichever album it belongs to',
  },
  {
    method: 'GET',
    path: '/api/events/calendar',
    handler: eventsCalendar,
    description:
      'Everything happening — events and festivals together — split into upcoming and past',
  },

  // Ahead of `:identifier` so the static segment wins the match. It has an
  // extra segment and would not collide today, but a route that relies on
  // segment counts staying put is a route waiting to break.
  {
    method: 'GET',
    path: '/api/galleries/albums/index',
    handler: galleryAlbums,
    description: 'Every published album with a count of what it holds, for the gallery filter bar',
  },
  {
    method: 'GET',
    path: '/api/galleries/:identifier',
    handler: showGallery,
    description: 'One album with its photographs and their labels',
  },

  // --- Media ---------------------------------------------------------------
  {
    method: 'GET',
    path: '/api/media/config',
    handler: mediaConfig,
    description: 'Accepted media folders, types and size limits',
  },
  {
    method: 'GET',
    path: '/api/media/file/*',
    handler: serveFile,
    description: 'Stream a file from R2 by storage key',
  },

  // --- Preservation Team ---------------------------------------------------
  {
    method: 'GET',
    path: '/api/preservation-team',
    handler: preservationTeamStructure,
    description: 'Structure of the Ekoli-Yeden Preservation Team',
  },

  ...generatedContentRoutes(),
];
