import type { RequestContext } from '../types/api';
import { requireResource } from '../services/content-registry';
import { ContentService, PUBLIC_STATUSES } from '../services/content.service';
import { adminCreate, adminChangeStatus } from './content.controller';
import { decorateVideos } from '../services/video.service';
import { GalleryService } from '../services/gallery.service';
import { listRecords, findRecordBy } from '../repositories/base.repository';
import { CONTENT_STATUS } from '../types/models';
import { NotFoundError } from '../utils/errors';
import { json, publicCacheHeaders, NO_STORE_HEADERS } from '../utils/responses';
import { publicMediaUrl } from '../utils/files';
import { UnauthorizedError } from '../utils/errors';
import { readJsonBody, Validator } from '../utils/validation';
import { AuditRepository, AUDIT_ACTIONS } from '../repositories/audit.repository';

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
  const [events, videos, gallery, albums] = await Promise.all([
    loadEvents(context.env.DB, festivalId),
    loadVideos(context.env.DB, festivalId),
    loadGallery(context, festival),
    // The festival archive: every year, newest first. Each is an ordinary
    // gallery, so the Gallery section lists the same records.
    new GalleryService(context.env).repo.albumsForFestival(festivalId),
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
      gallery: gallery.items,
      // The album itself, so the page can link to it and invite photographs
      // into the right year. Every edition has one, which is what gives a
      // photograph a year to belong to — and because it is an ordinary
      // gallery, the same pictures also reach the main Gallery section.
      gallery_id: gallery.id,
      gallery_slug: gallery.slug,

      // Year by year — 2026, 2025, 2024 — which is what makes this a heritage
      // archive rather than a page about the most recent celebration.
      albums: albums.map((album) => ({
        id: album['id'],
        slug: album['slug'],
        title: album['title'],
        description: album['description'],
        year: album['year'],
        event_date: album['event_date'],
        location: album['location'],
        programme: album['programme'],
        people_featured: album['people_featured'],
        photo_count: Number(album['photo_count'] ?? 0),
        video_count: Number(album['video_count'] ?? 0),
        cover_url: album['cover_key']
          ? publicMediaUrl(context.env.PUBLIC_MEDIA_BASE_URL, String(album['cover_key']))
          : null,
      })),
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
 * `GET /api/leboku` — the festival and every year of it, newest first.
 *
 * WHAT AN "EDITION" IS NOW.
 *
 * It used to be a row in `festivals`: Leboku 2026 and Leboku 2025 were two
 * unrelated festivals that happened to share a name, and the history of the
 * festival had to be retold in each or lost. Since 0036 a festival is the
 * permanent parent and each year is an album — an ordinary gallery carrying
 * `festival_id` and `year`.
 *
 * So the editions here are albums. The shape of the response is unchanged for
 * anything that was reading it: an id, a slug, a year, a title.
 *
 * Kept distinct from `/api/festivals` so a client can link straight to a year
 * without knowing a slug.
 */
export async function lebokuIndex(context: RequestContext): Promise<Response> {
  const { items } = await listRecords<Record<string, unknown>>(context.env.DB, 'festivals', {
    status: PUBLIC_STATUSES,
    filters: { name: 'Leboku' },
    sortColumn: 'sort_order',
    sortDirection: 'ASC',
    limit: 1,
    offset: 0,
  });

  // Falls back to the first festival on record if none is named "Leboku" — the
  // record is created by the Leboku Manager, not by this code.
  const festival = items[0] ?? (await allFestivals(context.env.DB))[0] ?? null;

  if (!festival) {
    return json({ festival: 'Leboku', editions: [], total: 0 }, { headers: publicCacheHeaders() });
  }

  const albums = await new GalleryService(context.env).repo.albumsForFestival(
    String(festival['id']),
  );

  return json(
    {
      festival: festival['name'] ?? 'Leboku',
      festival_slug: festival['slug'],
      editions: albums.map((album) => ({
        id: album['id'],
        slug: album['slug'],
        name: album['title'],
        year: album['year'],
        location: album['location'],
        event_date: album['event_date'],
        photo_count: Number(album['photo_count'] ?? 0),
        video_count: Number(album['video_count'] ?? 0),
        cover_url: album['cover_key']
          ? publicMediaUrl(context.env.PUBLIC_MEDIA_BASE_URL, String(album['cover_key']))
          : null,
      })),
      total: albums.length,
    },
    { headers: publicCacheHeaders() },
  );
}

async function allFestivals(db: D1Database): Promise<Record<string, unknown>[]> {
  const { items } = await listRecords<Record<string, unknown>>(db, 'festivals', {
    status: PUBLIC_STATUSES,
    sortColumn: 'sort_order',
    sortDirection: 'ASC',
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

  // A four-digit identifier is a YEAR, and a year is no longer a property of a
  // festival — it is a property of one of its albums. `/leboku/2026` therefore
  // means "the festival that has a 2026 album", which is the festival page
  // opened on that year.
  //
  // Links printed on a banner in 2026 keep resolving, which is the whole
  // reason this branch survives the restructuring at all.
  if (/^\d{4}$/.test(identifier)) {
    const byAlbumYear = await db
      .prepare(
        `SELECT f.* FROM "festivals" f
         INNER JOIN "galleries" g ON g."festival_id" = f."id"
         WHERE g."year" = ? AND f."status" = 'published' AND g."status" = 'published'
         ORDER BY f."sort_order"
         LIMIT 1`,
      )
      .bind(Number(identifier))
      .first<Record<string, unknown>>();
    if (byAlbumYear) return byAlbumYear;
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

/**
 * A festival's photographs.
 *
 * Resolved through `festivals.gallery_id` where it is set, and otherwise by
 * looking for a gallery that names this festival. The fallback matters: an
 * edition created before galleries were attached to festivals, or through a
 * path that forgot, still finds its album instead of showing nothing.
 */
async function loadGallery(
  context: RequestContext,
  festival: Record<string, unknown>,
): Promise<{ id: string | null; slug: string | null; items: Record<string, unknown>[] }> {
  const service = new GalleryService(context.env);
  const festivalId = String(festival['id'] ?? '');
  const galleryId = festival['gallery_id'];

  let gallery =
    typeof galleryId === 'string' && galleryId !== ''
      ? await service.repo.findById(galleryId)
      : null;

  gallery ??= festivalId === '' ? null : await service.repo.findPrimaryForFestival(festivalId);

  if (!gallery || gallery.status !== CONTENT_STATUS.PUBLISHED) {
    return { id: gallery?.id ?? null, slug: gallery?.slug ?? null, items: [] };
  }

  const items = await service.repo.itemsForGallery(gallery.id, [CONTENT_STATUS.PUBLISHED]);
  return {
    id: gallery.id,
    slug: gallery.slug,
    items: items.map((item) => service.decorateItem(item)),
  };
}

/**
 * `POST /api/admin/festivals/:id/gallery`
 *
 * The festival's album, created if it is missing.
 *
 * Idempotent on purpose. The workspace calls it whenever somebody opens a
 * festival's photographs, so an edition that predates this — or one added
 * through a path that did not make an album — is repaired by being looked at,
 * rather than waiting for somebody to notice.
 */
export async function ensureFestivalGallery(context: RequestContext): Promise<Response> {
  const festival = await findRecordBy<Record<string, unknown>>(
    context.env.DB,
    'festivals',
    'id',
    context.params['id'] ?? '',
  );
  if (!festival) throw new NotFoundError('That festival was not found.');

  const service = new GalleryService(context.env);
  const gallery = await ensureAlbumFor(service, festival);

  const items = await service.repo.itemsForGallery(gallery.id, ALL_EDITABLE_STATUSES);

  return json(
    {
      gallery,
      items: items.map((item) => service.decorateItem(item)),
      counts: await service.repo.countsForGallery(gallery.id),
    },
    { headers: NO_STORE_HEADERS },
  );
}

/**
 * `GET /api/admin/festival-galleries`
 *
 * Every festival with its years beneath it.
 *
 * It used to return one album per festival and create it on the way past,
 * because a festival WAS a year. Since 0036 a festival is the permanent parent
 * and a year is an album, so there is nothing to create here: a festival with
 * no years yet is a perfectly ordinary state — somebody has recorded that
 * Odagum exists and has not yet added a celebration of it.
 */
export async function festivalGalleryIndex(context: RequestContext): Promise<Response> {
  const service = new GalleryService(context.env);
  const { items: festivals } = await listRecords<Record<string, unknown>>(
    context.env.DB,
    'festivals',
    { sortColumn: 'sort_order', sortDirection: 'ASC', limit: 200, offset: 0 },
  );

  const rows: Record<string, unknown>[] = [];
  for (const festival of festivals) {
    const albums = await service.repo.albumsForFestival(String(festival['id']), [
      'draft',
      'pending_review',
      'approved',
      'published',
      'archived',
    ]);

    rows.push({
      festival_id: festival['id'],
      festival_name: festival['name'],
      festival_slug: festival['slug'],
      festival_status: festival['status'],
      short_description: festival['short_description'],
      years: albums.map((album) => ({
        gallery_id: album['id'],
        gallery_slug: album['slug'],
        gallery_title: album['title'],
        gallery_status: album['status'],
        year: album['year'],
        photo_count: Number(album['photo_count'] ?? 0),
        video_count: Number(album['video_count'] ?? 0),
      })),
    });
  }

  return json({ items: rows, total: rows.length }, { headers: NO_STORE_HEADERS });
}

/**
 * `POST /api/admin/festivals` — a new festival.
 *
 * Odagum, Ekpirikum, and whatever else the community celebrates. The parent
 * only: no album is created with it, because a festival that has just been
 * recorded has no year yet and inventing one would put an empty "0" in the
 * archive's timeline.
 *
 * Wraps the generated create handler rather than replacing it, so festivals
 * keep exactly the validation, versioning and audit behaviour every other
 * content type has.
 */
export async function createFestival(context: RequestContext): Promise<Response> {
  return adminCreate(FESTIVAL_RESOURCE)(context);
}

/**
 * `POST /api/admin/festivals/:id/years`
 *
 * Adds a year to a festival: Leboku 2025, Leboku 2024.
 *
 * The album is an ordinary gallery carrying `festival_id` and `year`, which is
 * what puts it in two places at once — the festival's own archive and the
 * Gallery's list of albums — without a second record existing anywhere.
 */
export async function addFestivalYear(context: RequestContext): Promise<Response> {
  const actor = context.user;
  if (!actor) throw new UnauthorizedError('Please sign in to continue.');

  const festivalId = context.params['id'] ?? '';
  const festival = await findRecordBy<Record<string, unknown>>(
    context.env.DB,
    'festivals',
    'id',
    festivalId,
  );
  if (!festival) throw new NotFoundError('That festival was not found.');

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .integer('year', { required: true, min: 1900, max: 2200, label: 'Year' })
    .string('title', { max: 200, label: 'Album name' })
    .string('description', { max: 4000, label: 'Description' })
    .string('location', { max: 200, label: 'Where it was held' })
    .string('event_date', { max: 40, label: 'Date' })
    .validated();

  const year = Number(validated['year']);
  const name = String(festival['name'] ?? 'Festival');

  // One album per festival-year. Asking twice is somebody pressing a button
  // again, not a request for a duplicate.
  const existing = await context.env.DB.prepare(
    `SELECT "id", "slug" FROM "galleries" WHERE "festival_id" = ? AND "year" = ? LIMIT 1`,
  )
    .bind(festivalId, year)
    .first<{ id: string; slug: string }>();

  if (existing) {
    return json(
      { ...existing, year, created: false, message: `${name} ${year} already exists.` },
      { headers: NO_STORE_HEADERS },
    );
  }

  const service = new GalleryService(context.env);
  const title = (validated['title'] as string | null) ?? `${name} ${year}`;
  const slug = await service.repo.uniqueSlug(
    `${String(festival['slug'] ?? 'festival')}-${year}`,
  );

  const galleryId = await service.repo.createGallery({
    slug,
    title,
    description: (validated['description'] as string | null) ?? null,
    category: 'festival',
    eventDate: (validated['event_date'] as string | null) ?? null,
    location: (validated['location'] as string | null) ?? (festival['location'] as string | null) ?? null,
    festivalId,
    year,
    isFestivalGallery: true,
    // A new year starts as a draft. Publishing it is the act of saying the
    // photographs in it are ready to be seen.
    status: CONTENT_STATUS.DRAFT,
  });

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: AUDIT_ACTIONS.CONTENT_CREATED,
    resourceType: 'galleries',
    resourceId: galleryId,
    changes: { festivalId, year, title },
    requestId: context.requestId,
  });

  return json(
    {
      id: galleryId,
      slug,
      title,
      year,
      created: true,
      message: `${title} is ready. Add photographs and film to it, then publish it.`,
    },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

/**
 * `PATCH /api/admin/festivals/:id/status`
 *
 * Moves an edition through the workflow and takes its album with it.
 * Publishing a festival whose photographs stay in draft produces a page that
 * says "Photographs" above nothing at all.
 */
export async function changeFestivalStatus(context: RequestContext): Promise<Response> {
  const response = await adminChangeStatus(FESTIVAL_RESOURCE)(context);
  if (!response.ok) return response;

  const cloned = response.clone();
  const payload = (await cloned.json().catch(() => null)) as { data?: Record<string, unknown> } | null;
  const festival = payload?.data;
  if (!festival || typeof festival['id'] !== 'string') return response;

  await new GalleryService(context.env).syncFestivalGalleryStatus(
    festival['id'],
    String(festival['status'] ?? CONTENT_STATUS.DRAFT),
  );

  return response;
}

/** Statuses the workspace may see. Everything except a deleted row. */
const ALL_EDITABLE_STATUSES = [
  CONTENT_STATUS.DRAFT,
  CONTENT_STATUS.PENDING_REVIEW,
  CONTENT_STATUS.APPROVED,
  CONTENT_STATUS.PUBLISHED,
  CONTENT_STATUS.ARCHIVED,
];

/** Finds or creates a festival's album and keeps its visibility in step. */
async function ensureAlbumFor(service: GalleryService, festival: Record<string, unknown>) {
  const gallery = await service.ensureFestivalGallery({
    id: String(festival['id']),
    slug: String(festival['slug'] ?? festival['id']),
    name: String(festival['name'] ?? 'Festival'),
    year: Number(festival['year'] ?? 0),
    start_date: (festival['start_date'] as string | null) ?? null,
    location: (festival['location'] as string | null) ?? null,
    status: (festival['status'] as string | null) ?? CONTENT_STATUS.DRAFT,
  });

  // Publishing an edition should publish its photographs; archiving one should
  // not leave them advertised on a page nobody links to any more.
  await service.syncFestivalGalleryStatus(
    String(festival['id']),
    String(festival['status'] ?? gallery.status),
  );

  return (await service.repo.findById(gallery.id)) ?? gallery;
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
