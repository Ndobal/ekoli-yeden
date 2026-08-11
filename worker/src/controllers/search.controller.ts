import type { RequestContext } from '../types/api';
import { searchArchive } from '../services/search.service';
import { CONTENT_RESOURCES } from '../services/content-registry';
import { json, publicCacheHeaders } from '../utils/responses';

/**
 * `GET /api/search?q=`
 *
 * One query across the whole archive: history, people, leaders, news, events,
 * Leboku, language, galleries, videos, businesses, organizations and community
 * projects. Only published records are reachable.
 */
export async function search(context: RequestContext): Promise<Response> {
  const term = context.query.get('q') ?? '';
  const requested = context.query.get('in');
  const resources = requested ? requested.split(',').map((value) => value.trim()) : undefined;

  const results = await searchArchive(context.env.DB, term, { resources });
  return json(results, { headers: publicCacheHeaders(120) });
}

/** `GET /api/search/sources` — what the search covers. */
export async function searchSources(_context: RequestContext): Promise<Response> {
  return json({
    sources: Object.values(CONTENT_RESOURCES)
      .filter((resource) => resource.searchable)
      .map((resource) => ({
        key: resource.key,
        label: resource.label,
        fields: resource.searchableColumns,
      })),
  });
}
