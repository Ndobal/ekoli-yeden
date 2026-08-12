import type { RequestContext } from '../types/api';
import { requireResource } from '../services/content-registry';
import { ContentService, PUBLIC_STATUSES } from '../services/content.service';
import { decorateVideos } from '../services/video.service';
import { GalleryRepository } from '../repositories/gallery.repository';
import { listRecords, findRecordBy } from '../repositories/base.repository';
import { CONTENT_STATUS } from '../types/models';
import { NotFoundError } from '../utils/errors';
import { json, publicCacheHeaders } from '../utils/responses';
import { publicMediaUrl } from '../utils/files';

/**
 * THE FESTIVAL SYSTEM
 *
 * Leboku is not hard-coded. A festival is a record with a name and a year, so
 * `/leboku/2026`, `/leboku/2027` and every year after it are the same code path
 * reading different rows. Once a festival is over the record stays, which is
 * what turns the section into a year-by-year archive rather than a page that
 * gets overwritten each year.
 */

const FESTIVAL_RESOURCE = requireResource('festivals');

/**
 * `GET /api/festivals`
 *
 * Every published festival, newest first, split into the one to feature and
 * the rest. Leboku is the largest of the community's festivals but not the
 * only one, so the endpoint makes no assumption about which is which — the
 * featured edition is whichever the Editorial Team flagged, falling back to
 * the most recent that has not been archived.
 */
export async function listFestivals(context: RequestContext): Promise<Response> {
  const service = new ContentService(context.env.DB, FESTIVAL_RESOURCE);
  const query = service.buildQuery(context.query, false);
  const { items, total } = await service.list(query);

  const decorated = await Promise.all(
    items.map((row) => decorateFestival(context, parseFestivalJson(row))),
  );

  const featured =
    decorated.find((row) => row['is_featured'] === 1) ??
    decorated.find((row) => row['is_archived'] !== 1) ??
    decorated[0] ??
    null;

  const rest = decorated.filter((row) => row !== featured);

  return json(
    { featured, past: rest, items: decorated, total },
    { headers: publicCacheHeaders() },
  );
}

/**
 * `GET /api/festivals/:slug` and `GET /api/leboku/:year`
 *
 * Returns the festival together with everything attached to it: its events,
 * its gallery items and its videos. One request renders a whole festival page.
 */
export async function showFestival(context: RequestContext): Promise<Response> {
  const identifier = context.params['identifier'] ?? context.params['year'] ?? '';
  const festival = await resolveFestival(context, identifier);

  const festivalId = String(festival['id']);
  const [events, videos, galleryItems] = await Promise.all([
    loadEvents(context.env.DB, festivalId),
    loadVideos(context.env.DB, festivalId),
    loadGallery(context, festival),
  ]);

  return json(
    {
      festival: await decorateFestival(context, parseFestivalJson(festival)),
      events,
      // The programme, grouped the way a festival actually runs: the run-up,
      // the main day, and what follows. A festival is not a single date, and a
      // flat list of activities loses the shape of it.
      programme: groupProgramme(events),
      videos,
      gallery: galleryItems,
    },
    { headers: publicCacheHeaders() },
  );
}

/** Phases in the order they occur. */
const PROGRAMME_PHASES = ['lead_up', 'main_day', 'after', 'other'] as const;

function groupProgramme(events: Record<string, unknown>[]): Record<string, unknown>[] {
  return PROGRAMME_PHASES.map((phase) => ({
    phase,
    items: events
      .filter((event) => (event['festival_phase'] ?? 'other') === phase)
      .sort((a, b) => {
        // Order by explicit position first, then by date where one is known.
        const order = Number(a['sort_order'] ?? 0) - Number(b['sort_order'] ?? 0);
        if (order !== 0) return order;
        const left = String(a['start_datetime'] ?? '');
        const right = String(b['start_datetime'] ?? '');
        return left.localeCompare(right);
      }),
  })).filter((group) => group.items.length > 0);
}

/** Resolves the festival's own logo to a URL the client can render. */
async function decorateFestival(
  context: RequestContext,
  festival: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const logoId = festival['logo_media_id'];
  if (typeof logoId !== 'string' || logoId === '') {
    return { ...festival, logo_url: null };
  }

  const media = await context.env.DB.prepare(
    'SELECT "storage_key", "status" FROM "media_assets" WHERE "id" = ? LIMIT 1',
  )
    .bind(logoId)
    .first<{ storage_key: string; status: string }>();

  return {
    ...festival,
    logo_url:
      media && media.status === CONTENT_STATUS.PUBLISHED
        ? publicMediaUrl(context.env.PUBLIC_MEDIA_BASE_URL, media.storage_key)
        : null,
  };
}

/**
 * `GET /api/leboku` — the festival series, newest first.
 *
 * Kept distinct from `/api/festivals` so the client can link straight to
 * `/leboku/<year>` without needing to know a slug.
 */
export async function lebokuIndex(context: RequestContext): Promise<Response> {
  const { items, total } = await listRecords<Record<string, unknown>>(context.env.DB, 'festivals', {
    status: PUBLIC_STATUSES,
    filters: { name: 'Leboku' },
    sortColumn: 'year',
    sortDirection: 'DESC',
    limit: 100,
    offset: 0,
  });

  // Falls back to every festival if none is named "Leboku" yet — the record is
  // created by the Leboku Manager, not by this code.
  const editions = items.length > 0 ? items : await allFestivals(context.env.DB);

  return json(
    {
      festival: 'Leboku',
      editions: editions.map((row) => ({
        id: row['id'],
        slug: row['slug'],
        name: row['name'],
        year: row['year'],
        theme: row['theme'],
        start_date: row['start_date'],
        end_date: row['end_date'],
        is_archived: row['is_archived'],
      })),
      total: items.length > 0 ? total : editions.length,
    },
    { headers: publicCacheHeaders() },
  );
}

async function allFestivals(db: D1Database): Promise<Record<string, unknown>[]> {
  const { items } = await listRecords<Record<string, unknown>>(db, 'festivals', {
    status: PUBLIC_STATUSES,
    sortColumn: 'year',
    sortDirection: 'DESC',
    limit: 100,
    offset: 0,
  });
  return items;
}

/** Resolves `2026`, `leboku-2026` or a record id to a festival row. */
async function resolveFestival(
  context: RequestContext,
  identifier: string,
): Promise<Record<string, unknown>> {
  const db = context.env.DB;

  if (/^\d{4}$/.test(identifier)) {
    const byYear = await findRecordBy<Record<string, unknown>>(db, 'festivals', 'year', Number(identifier), {
      status: PUBLIC_STATUSES,
    });
    if (byYear) return byYear;
  }

  const service = new ContentService(db, FESTIVAL_RESOURCE);
  const record = await service.findOne(identifier, false).catch(() => null);
  if (!record) {
    throw new NotFoundError(
      'That festival has not been published yet. Festival information is added by the Leboku Manager once it is available.',
    );
  }
  return record;
}

async function loadEvents(db: D1Database, festivalId: string): Promise<Record<string, unknown>[]> {
  const { items } = await listRecords<Record<string, unknown>>(db, 'events', {
    status: PUBLIC_STATUSES,
    filters: { festival_id: festivalId },
    // Ordered by position rather than date: a programme is usually planned
    // before its dates are fixed, and an unfixed date must not scatter it.
    sortColumn: 'sort_order',
    sortDirection: 'ASC',
    limit: 200,
    offset: 0,
  });
  return items;
}

async function loadVideos(db: D1Database, festivalId: string): Promise<Record<string, unknown>[]> {
  const { items } = await listRecords<Record<string, unknown>>(db, 'videos', {
    status: PUBLIC_STATUSES,
    filters: { related_festival_id: festivalId },
    sortColumn: 'published_date',
    sortDirection: 'DESC',
    limit: 100,
    offset: 0,
  });
  return decorateVideos(items);
}

async function loadGallery(
  context: RequestContext,
  festival: Record<string, unknown>,
): Promise<Record<string, unknown>[]> {
  const galleryId = festival['gallery_id'];
  if (typeof galleryId !== 'string' || galleryId === '') return [];

  const repository = new GalleryRepository(context.env.DB);
  const items = await repository.itemsForGallery(galleryId, [CONTENT_STATUS.PUBLISHED]);

  return items.map((item) => ({
    id: item.id,
    caption: item.caption,
    photographer: item.photographer,
    people_pictured: item.people_pictured,
    taken_at: item.taken_at,
    location: item.location,
    alt_text: item.alt_text,
    mime_type: item.mime_type,
    url: publicMediaUrl(context.env.PUBLIC_MEDIA_BASE_URL, item.storage_key),
  }));
}

/** Programme, sponsors, announcements and committee are stored as JSON text. */
function parseFestivalJson(record: Record<string, unknown>): Record<string, unknown> {
  const decoded = { ...record };
  for (const field of ['programme', 'sponsors', 'announcements', 'committee']) {
    const value = decoded[field];
    if (typeof value !== 'string' || value === '') {
      decoded[field] = null;
      continue;
    }
    try {
      decoded[field] = JSON.parse(value);
    } catch {
      // Leave malformed JSON as text rather than dropping an editor's work.
      decoded[field] = value;
    }
  }
  return decoded;
}
