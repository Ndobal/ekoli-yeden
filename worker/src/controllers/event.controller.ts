import type { RequestContext } from '../types/api';
import { GalleryService } from '../services/gallery.service';
import { AuditRepository } from '../repositories/audit.repository';
import { CONTENT_STATUS } from '../types/models';
import { json, NO_STORE_HEADERS, publicCacheHeaders } from '../utils/responses';
import { NotFoundError, UnauthorizedError } from '../utils/errors';
import { slugify } from '../utils/slug';
import { nowIso } from '../utils/id';

/**
 * WHAT IS HAPPENING IN EKOLI-YEDEN
 *
 * The generated content routes already list events. What they cannot do is
 * answer the question the page is actually for — "what is coming up?" — because
 * that means merging two different things.
 *
 * A FESTIVAL IS AN EVENT TO A VISITOR AND A DIFFERENT RECORD TO THE DATABASE.
 *
 * Leboku is a `festival` with editions and a programme; a town hall meeting is
 * an `event`. Somebody looking at a calendar does not care, and a page that
 * showed one and not the other would be wrong in the most confusing way — the
 * biggest thing the community does would be missing from its own list of what
 * is happening.
 *
 * So they are merged here, each keeping the link back to its own kind of page,
 * and sorted by when they happen rather than by what they are.
 */

interface CalendarEntry {
  id: string;
  kind: 'event' | 'festival';
  slug: string;
  title: string;
  description: string | null;
  event_type: string | null;
  starts_at: string | null;
  ends_at: string | null;
  location: string | null;
  venue: string | null;
  organiser: string | null;
  /** Where pressing it should go — the whole point of merging the two. */
  path: string;
  gallery_slug: string | null;
  cover_media_id: string | null;

  /// The wide image for the top of its own page.
  banner_media_id: string | null;

  /// The poster as it was designed — never cropped, and saveable, because the
  /// useful thing to do with a flier is send it to somebody else.
  flier_media_id: string | null;

  /// Which festival it belongs to, where it belongs to one. A Leboku event
  /// appears on the festival's page AND here, from one record.
  festival_slug: string | null;
}

/**
 * `GET /api/events/calendar`
 *
 * Everything happening, split into what is still to come and what has been.
 *
 * Upcoming is ordered soonest-first and past is ordered most-recent-first,
 * because in each case that is the end of the list somebody is looking at.
 */
export async function eventsCalendar(context: RequestContext): Promise<Response> {
  const db = context.env.DB;
  const type = context.query.get('type');

  const [eventRows, festivalRows] = await db.batch<Record<string, unknown>>([
    db
      .prepare(
        // Festival-tied events are NOT excluded. An event that belongs to
        // Leboku should be visible on the festival's page and on this one,
        // from a single record — hiding it inside the festival is how a
        // community's calendar ends up looking empty in a busy year.
        `SELECT e."id", e."slug", e."title", e."description", e."event_type",
                e."start_datetime", e."end_datetime", e."location", e."venue",
                e."organiser", e."cover_media_id", e."banner_media_id", e."flier_media_id",
                g."slug" AS gallery_slug,
                f."slug" AS festival_slug, f."name" AS festival_name
         FROM "events" e
         LEFT JOIN "galleries" g ON g."event_id" = e."id" AND g."status" = 'published'
         LEFT JOIN "festivals" f ON f."id" = e."festival_id" AND f."status" = 'published'
         WHERE e."status" = 'published'
         ORDER BY e."start_datetime" DESC`,
      )
      .bind(),
    db
      .prepare(
        // A festival is named `name`, not `title`, and carries a `year` that
        // an event does not. Aliased here rather than special-cased below, so
        // the merge downstream sees one shape.
        `SELECT f."id", f."slug", f."name" AS title, f."description", f."theme", f."year",
                f."start_date", f."end_date", f."location", f."cover_media_id",
                f."banner_media_id", f."flier_media_id",
                g."slug" AS gallery_slug
         FROM "festivals" f
         LEFT JOIN "galleries" g ON g."festival_id" = f."id" AND g."status" = 'published'
         WHERE f."status" = 'published'
         ORDER BY f."year" DESC`,
      )
      .bind(),
  ]);

  const entries: CalendarEntry[] = [];

  for (const row of eventRows?.results ?? []) {
    if (type && String(row['event_type'] ?? '') !== type) continue;
    entries.push({
      id: String(row['id']),
      kind: 'event',
      slug: String(row['slug']),
      title: String(row['title']),
      description: (row['description'] as string | null) ?? null,
      event_type: (row['event_type'] as string | null) ?? 'gathering',
      starts_at: (row['start_datetime'] as string | null) ?? null,
      ends_at: (row['end_datetime'] as string | null) ?? null,
      location: (row['location'] as string | null) ?? null,
      venue: (row['venue'] as string | null) ?? null,
      organiser: (row['organiser'] as string | null) ?? null,
      path: `/events/${String(row['slug'])}`,
      gallery_slug: (row['gallery_slug'] as string | null) ?? null,
      cover_media_id: (row['cover_media_id'] as string | null) ?? null,
      banner_media_id: (row['banner_media_id'] as string | null) ?? null,
      flier_media_id: (row['flier_media_id'] as string | null) ?? null,
      festival_slug: (row['festival_slug'] as string | null) ?? null,
    });
  }

  // Festivals are excluded when the caller has asked for a specific kind of
  // event, unless that kind IS festival — a filter for "town hall" should not
  // quietly keep returning Leboku.
  if (!type || type === 'festival') {
    for (const row of festivalRows?.results ?? []) {
      entries.push({
        id: String(row['id']),
        kind: 'festival',
        slug: String(row['slug']),
        title: String(row['title']),
        description: (row['theme'] as string | null) ?? (row['description'] as string | null) ?? null,
        event_type: 'festival',
        // An edition with no dates recorded still belongs on the calendar under
        // its year, or the biggest thing the community does goes missing from
        // its own list of what is happening.
        starts_at:
          (row['start_date'] as string | null) ??
          (row['year'] ? `${String(row['year'])}-01-01` : null),
        ends_at: (row['end_date'] as string | null) ?? null,
        location: (row['location'] as string | null) ?? null,
        venue: null,
        organiser: null,
        // Straight to the festival's own page, which carries its editions, its
        // programme and its albums. Sending somebody to a generic event page
        // for Leboku would be a worse answer than not listing it.
        path: `/festivals/${String(row['slug'])}`,
        gallery_slug: (row['gallery_slug'] as string | null) ?? null,
        cover_media_id: (row['cover_media_id'] as string | null) ?? null,
        banner_media_id: (row['banner_media_id'] as string | null) ?? null,
        flier_media_id: (row['flier_media_id'] as string | null) ?? null,
        festival_slug: String(row['slug']),
      });
    }
  }

  // Compared by date only. An event on today's date belongs under "upcoming"
  // for the whole day — it has not been and gone at nine in the morning.
  const today = new Date().toISOString().slice(0, 10);

  // An undated entry belongs in NEITHER list. Comparing a missing date as an
  // empty string quietly sorts it into the past, which is how "Mr & Mrs Leboku
  // Pageant, date to be announced" ends up filed as something that has already
  // happened.
  const dated = entries.filter((entry) => entry.starts_at !== null);
  const undated = entries.filter((entry) => entry.starts_at === null);

  const upcoming = dated
    .filter((entry) => entry.starts_at!.slice(0, 10) >= today)
    .sort((a, b) => a.starts_at!.localeCompare(b.starts_at!));

  const past = dated
    .filter((entry) => entry.starts_at!.slice(0, 10) < today)
    .sort((a, b) => b.starts_at!.localeCompare(a.starts_at!));

  return json(
    {
      upcoming,
      past,
      // Returned rather than dropped, so the page can say "date to be
      // announced" — the true state of a great many gatherings.
      undated,
      types: EVENT_TYPES,
      total: entries.length,
    },
    { headers: publicCacheHeaders() },
  );
}

export const EVENT_TYPES = [
  { value: 'town_hall', label: 'Town hall meeting' },
  { value: 'festival', label: 'Festival' },
  { value: 'ceremony', label: 'Ceremony' },
  { value: 'meeting', label: 'Meeting' },
  { value: 'burial', label: 'Burial' },
  { value: 'launch', label: 'Launch' },
  { value: 'fundraiser', label: 'Fundraiser' },
  { value: 'sport', label: 'Sport' },
  { value: 'religious', label: 'Religious' },
  { value: 'education', label: 'Education' },
  { value: 'gathering', label: 'Gathering' },
  { value: 'other', label: 'Other' },
] as const;

/**
 * `POST /api/admin/events/:id/gallery`
 *
 * Gives an event an album, creating one if it has none.
 *
 * The album's title carries the event's name and its year, because that is what
 * a photograph needs in order to be understood by somebody who was not there.
 * "Town hall meeting — 2026" places a picture; "Album 47" does not.
 *
 * Because an event album is an ordinary gallery, a photograph put into it
 * appears in the main Gallery too, from one upload rather than two.
 */
export async function ensureEventGallery(context: RequestContext): Promise<Response> {
  const actor = context.user;
  if (!actor) throw new UnauthorizedError('Please sign in to continue.');

  const db = context.env.DB;
  const identifier = context.params['id'] ?? '';

  const event = await db
    .prepare('SELECT * FROM "events" WHERE "id" = ? OR "slug" = ? LIMIT 1')
    .bind(identifier, identifier)
    .first<Record<string, unknown>>();
  if (!event) throw new NotFoundError('That event was not found.');

  const existing = await db
    .prepare('SELECT "id", "slug", "title" FROM "galleries" WHERE "event_id" = ? LIMIT 1')
    .bind(String(event['id']))
    .first<{ id: string; slug: string; title: string }>();

  if (existing) {
    return json({ ...existing, created: false }, { headers: NO_STORE_HEADERS });
  }

  const service = new GalleryService(context.env);
  const startsAt = (event['start_datetime'] as string | null) ?? null;
  const year = startsAt ? startsAt.slice(0, 4) : null;
  const title = `${String(event['title'])}${year ? ` — ${year}` : ''}`;

  const id = `gal_event_${String(event['id'])}`;
  const slug = await uniqueSlug(db, `event-${slugify(String(event['title']))}`);

  await db
    .prepare(
      `INSERT INTO "galleries"
         ("id", "slug", "title", "description", "category", "event_date", "location",
          "event_id", "is_festival_gallery", "sort_order", "status", "created_at", "updated_at")
       VALUES (?, ?, ?, ?, 'event', ?, ?, ?, 0, 0, ?, ?, ?)`,
    )
    .bind(
      id,
      slug,
      title,
      `Photographs and film from ${String(event['title'])}. Each one is labelled with what it `
        + 'shows, so that somebody who was not there can still understand it.',
      startsAt,
      (event['venue'] as string | null) ?? (event['location'] as string | null) ?? null,
      String(event['id']),
      // Follows the event: a draft event does not get a published album
      // appearing in the Gallery's filter bar under a name nobody approved.
      event['status'] === CONTENT_STATUS.PUBLISHED ? CONTENT_STATUS.PUBLISHED : CONTENT_STATUS.DRAFT,
      nowIso(),
      nowIso(),
    )
    .run();

  await new AuditRepository(db).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: 'event.gallery.created',
    resourceType: 'gallery',
    resourceId: id,
    changes: { eventId: event['id'], title },
    requestId: context.requestId,
  });

  void service;
  return json({ id, slug, title, created: true }, { status: 201, headers: NO_STORE_HEADERS });
}

async function uniqueSlug(db: D1Database, base: string): Promise<string> {
  const root = base || 'event-album';
  for (let suffix = 0; suffix < 60; suffix += 1) {
    const candidate = suffix === 0 ? root : `${root}-${suffix + 1}`;
    const clash = await db
      .prepare('SELECT "id" FROM "galleries" WHERE "slug" = ? LIMIT 1')
      .bind(candidate)
      .first<{ id: string }>();
    if (!clash) return candidate;
  }
  return `${root}-${Date.now()}`;
}
