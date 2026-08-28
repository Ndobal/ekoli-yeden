import type { Handler, RequestContext } from '../types/api';
import { SettingsRepository } from '../repositories/settings.repository';
import { AuditRepository, AUDIT_ACTIONS } from '../repositories/audit.repository';
import { NotFoundError, UnauthorizedError, ValidationError } from '../utils/errors';
import { json, publicCacheHeaders, NO_STORE_HEADERS } from '../utils/responses';
import { readJsonBody } from '../utils/validation';
import { publicMediaUrl } from '../utils/files';
import { nowIso } from '../utils/id';

/**
 * DISCOVER EKORI — §13 and §16 of the proposal.
 *
 * Two things the archive described and did not show: the Hall of Fame, and the
 * map.
 */

function requireActor(context: RequestContext) {
  if (!context.user) throw new UnauthorizedError('Please sign in to continue.');
  return context.user;
}

// ---------------------------------------------------------------------------
// §13  THE EKORI HALL OF FAME
// ---------------------------------------------------------------------------

/**
 * `GET /api/hall-of-fame`
 *
 * ---------------------------------------------------------------------------
 * WHY THIS RETURNS AN EMPTY LIST RATHER THAN A 404 WHEN IT IS SWITCHED OFF
 * ---------------------------------------------------------------------------
 *
 * `people.is_hall_of_fame` has existed since the second migration and
 * `feature_hall_of_fame` has sat in the settings at `false` since then. Neither
 * was read by anything, so for the whole life of this archive the flag was a
 * promise the code did not keep. Somebody could mark an elder as belonging in
 * the Hall of Fame and nothing anywhere would show it.
 *
 * The switch stays off. Who belongs in a hall of fame is the community's
 * decision and not this website's, and turning it on from a migration would be
 * the archive making that decision for them. What has changed is that the
 * switch now does something when they turn it.
 *
 * When it is off the endpoint answers honestly — the feature exists, it is not
 * enabled — rather than pretending the address does not exist.
 */
export const hallOfFame: Handler = async (context: RequestContext) => {
  const setting = await new SettingsRepository(context.env.DB).get('feature_hall_of_fame');
  const enabled = String(setting?.value ?? 'false').toLowerCase() === 'true';

  if (!enabled) {
    return json(
      { enabled: false, items: [] },
      { headers: publicCacheHeaders(300) },
    );
  }

  const result = await context.env.DB.prepare(
    `SELECT p."id", p."slug", p."name", p."headline", p."profession",
            p."biography", p."achievements", p."city", p."country",
            m."storage_key" AS portrait_key, m."alt_text" AS portrait_alt
     FROM "people" p
     LEFT JOIN "media_assets" m ON m."id" = p."photo_media_id"
     WHERE p."status" = 'published' AND p."is_hall_of_fame" = 1
     ORDER BY p."sort_order", p."name"`,
  ).all<Record<string, unknown>>();

  const items = (result.results ?? []).map((row) => ({
    id: row['id'],
    slug: row['slug'],
    name: row['name'],
    headline: row['headline'],
    profession: row['profession'],
    biography: row['biography'],
    achievements: row['achievements'],
    city: row['city'],
    country: row['country'],
    portrait_url: row['portrait_key']
      ? publicMediaUrl(context.env.PUBLIC_MEDIA_BASE_URL, String(row['portrait_key']))
      : null,
    portrait_alt: row['portrait_alt'],
  }));

  return json({ enabled: true, items }, { headers: publicCacheHeaders(300) });
};

// ---------------------------------------------------------------------------
// §16  DISCOVER EKORI — THE MAP
// ---------------------------------------------------------------------------

/**
 * `GET /api/map/places`
 *
 * ---------------------------------------------------------------------------
 * THE ARCHIVE DOES NOT GUESS WHERE ANYWHERE IS
 * ---------------------------------------------------------------------------
 *
 * `places.latitude` and `places.longitude` were added in migration 0028 and
 * every one of the fourteen places recorded so far has both of them null.
 *
 * The obvious way to launch a map is to look up approximate coordinates and
 * seed them. This archive will not do that. Ajere Beach, Edang, Ukekeya and the
 * rest are real places that real families come from, and a plausible-looking
 * pin in roughly the right area is worse than no pin at all: it is wrong, it
 * looks authoritative, and the person best placed to notice — somebody who
 * grew up there — is exactly who this archive is asking to trust it.
 *
 * So the map shows what the community has recorded and says plainly when that
 * is nothing. `bounds` is computed from real coordinates only, and is null
 * until at least one place has been marked.
 */
export const mapPlaces: Handler = async (context: RequestContext) => {
  const result = await context.env.DB.prepare(
    `SELECT p."id", p."slug", p."name", p."kind", p."description", p."known_for",
            p."latitude", p."longitude", p."parent_id", p."depth",
            m."storage_key" AS cover_key
     FROM "places" p
     LEFT JOIN "media_assets" m ON m."id" = p."cover_media_id"
     WHERE p."status" = 'published'
     ORDER BY p."depth", p."sort_order", p."name"`,
  ).all<Record<string, unknown>>();

  const rows = result.results ?? [];

  const placed = rows.filter(
    (row) => typeof row['latitude'] === 'number' && typeof row['longitude'] === 'number',
  );

  // Only real coordinates shape the frame.
  let bounds: Record<string, number> | null = null;
  if (placed.length > 0) {
    const lats = placed.map((row) => Number(row['latitude']));
    const lngs = placed.map((row) => Number(row['longitude']));
    bounds = {
      min_lat: Math.min(...lats),
      max_lat: Math.max(...lats),
      min_lng: Math.min(...lngs),
      max_lng: Math.max(...lngs),
    };
  }

  const shape = (row: Record<string, unknown>) => ({
    id: row['id'],
    slug: row['slug'],
    name: row['name'],
    kind: row['kind'],
    description: row['description'],
    known_for: row['known_for'],
    latitude: row['latitude'],
    longitude: row['longitude'],
    parent_id: row['parent_id'],
    cover_url: row['cover_key']
      ? publicMediaUrl(context.env.PUBLIC_MEDIA_BASE_URL, String(row['cover_key']))
      : null,
  });

  return json(
    {
      // Everything published, so the page can list the places that have no
      // position yet instead of hiding them.
      items: rows.map(shape),
      placed_count: placed.length,
      unplaced_count: rows.length - placed.length,
      bounds,
    },
    { headers: publicCacheHeaders(300) },
  );
};

/**
 * `POST /api/editorial/places/:id/coordinates`
 *
 * Records where a place actually is. Send `null` for both to clear a position
 * that was recorded in error — which matters more than it sounds, because the
 * only thing worse than an unmarked place is a confidently wrong one.
 */
export const setPlaceCoordinates: Handler = async (context: RequestContext) => {
  const actor = requireActor(context);
  const id = context.params['id'] ?? '';

  const place = await context.env.DB.prepare(
    `SELECT "id", "name" FROM "places" WHERE "id" = ? LIMIT 1`,
  ).bind(id).first<{ id: string; name: string }>();
  if (!place) throw new NotFoundError('That place could not be found.');

  const body = await readJsonBody(context.request);
  const rawLat = body['latitude'];
  const rawLng = body['longitude'];

  const clearing = rawLat === null && rawLng === null;

  let latitude: number | null = null;
  let longitude: number | null = null;

  if (!clearing) {
    latitude = typeof rawLat === 'number' ? rawLat : Number.NaN;
    longitude = typeof rawLng === 'number' ? rawLng : Number.NaN;

    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      throw new ValidationError(
        { latitude: ['Give both a latitude and a longitude, or send null for both to clear them.'] },
      );
    }
    if (latitude < -90 || latitude > 90) {
      throw new ValidationError({ latitude: ['A latitude runs from -90 to 90.'] });
    }
    if (longitude < -180 || longitude > 180) {
      throw new ValidationError({ longitude: ['A longitude runs from -180 to 180.'] });
    }
  }

  await context.env.DB.prepare(
    `UPDATE "places" SET "latitude" = ?, "longitude" = ?, "updated_at" = ? WHERE "id" = ?`,
  ).bind(latitude, longitude, nowIso(), id).run();

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: context.user?.email ?? null,
    action: AUDIT_ACTIONS.CONTENT_UPDATED,
    resourceType: 'places',
    resourceId: id,
    changes: { latitude, longitude, cleared: clearing },
    userAgent: context.request.headers.get('user-agent'),
  });

  return json(
    { id, name: place.name, latitude, longitude },
    { headers: NO_STORE_HEADERS },
  );
};
