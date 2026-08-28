import type { RequestContext } from '../types/api';
import { PlacesService, type PlaceRecord } from '../services/places.service';
import { can } from '../services/permissions';
import { AuditRepository } from '../repositories/audit.repository';
import { readJsonBody, Validator } from '../utils/validation';
import { json, NO_STORE_HEADERS } from '../utils/responses';
import { ForbiddenError, NotFoundError, UnauthorizedError } from '../utils/errors';

/**
 * THE PLACES OF EKORI.
 *
 * ---------------------------------------------------------------------------
 * ONE TREE, AND NOTHING FLATTENED
 * ---------------------------------------------------------------------------
 *
 * Ekori is not one place. It is Ajere and Ntan and Epenti and Afrekpe; inside
 * Ajere is Edang, and inside Edang is Ukekeya. Somebody from Ukekeya is from
 * Ukekeya AND from Edang AND from Ajere AND from Ekori — all four at once, and
 * a person asked to choose one of them has been asked the wrong question.
 *
 * So this serves a tree rather than a list, and "who is from Ajere" reaches
 * everybody in Edang and Ukekeya through `descendantIds` rather than through a
 * column that had to be filled in four times.
 *
 * ---------------------------------------------------------------------------
 * THE LIST GROWS FROM WHAT PEOPLE TYPE
 * ---------------------------------------------------------------------------
 *
 * There is no endpoint here for creating a place, and that is deliberate. A
 * place appears because two different members typed its name into their own
 * profiles — one person typing something is a spelling, two people typing the
 * same thing is a place. An administrator can promote a candidate early
 * through the queue below, and can tidy what the threshold created, but the
 * ordinary path runs through the community rather than through an approval.
 */

/** `GET /api/places` — the whole tree, ordered for a picker. */
export async function listPlaces(context: RequestContext): Promise<Response> {
  const service = new PlacesService(context.env);
  const places = await service.list();

  return json({
    items: places.map(shape),
    total: places.length,
  });
}

/**
 * `GET /api/places/:identifier` — one place, what is above it, and what is
 * inside it.
 *
 * The ancestors travel with it because a page about Ukekeya that does not say
 * it is in Edang, in Ajere, in Ekori has thrown away the thing the tree was
 * built to hold.
 */
export async function showPlace(context: RequestContext): Promise<Response> {
  const service = new PlacesService(context.env);
  const place = await service.find(context.params['identifier'] ?? '');

  if (!place || place.status !== 'published') {
    throw new NotFoundError('That place was not found.');
  }

  const all = await service.list();

  const children = all
    .filter((candidate) => candidate.parent_id === place.id)
    .map(shape);

  // Walked from the record rather than parsed out of the cached `path`
  // string, so a renamed ancestor is right here immediately.
  const ancestors: Record<string, unknown>[] = [];
  let cursor: PlaceRecord | undefined = all.find((row) => row.id === place.parent_id);
  for (let depth = 0; depth < 8 && cursor; depth += 1) {
    ancestors.unshift(shape(cursor));
    const parentId: string | null = cursor.parent_id;
    cursor = parentId === null ? undefined : all.find((row) => row.id === parentId);
  }

  // Everybody at or below here — the whole point of nesting.
  const family = await service.descendantIds(place.id);
  const placeholders = family.map(() => '?').join(', ');

  const memberRow = await context.env.DB
    .prepare(
      `SELECT COUNT(*) AS total FROM "member_profiles"
       WHERE "place_id" IN (${placeholders}) AND "membership_status" = 'active'`,
    )
    .bind(...family)
    .first<{ total: number }>();

  const groupRows = await context.env.DB
    .prepare(
      `SELECT "id", "slug", "title", "kind" FROM "community_groups"
       WHERE "place_id" IN (${placeholders}) AND "status" = 'published'
       ORDER BY "title" ASC LIMIT 50`,
    )
    .bind(...family)
    .all<Record<string, unknown>>();

  return json({
    ...shape(place),
    description: place.description,
    history: place.history,
    known_for: place.known_for,
    ancestors,
    children,
    // Of everybody at or below here, not only of this exact level.
    member_count: Number(memberRow?.total ?? 0),
    groups: groupRows.results ?? [],
  });
}

/**
 * `GET /api/admin/places/candidates`
 *
 * What members have typed that the archive does not yet recognise.
 *
 * Worth reading even when nothing needs promoting: a name appearing here again
 * and again is the community telling you about a place, or telling you that
 * one of your spellings is wrong.
 */
export async function listPlaceCandidates(context: RequestContext): Promise<Response> {
  requireReviewer(context);

  const state = context.query.get('state') ?? 'open';
  const result = await context.env.DB
    .prepare(
      `SELECT "id", "raw_name", "normalised", "parent_id", "times_seen", "state",
              "promoted_place_id", "first_seen_at", "last_seen_at"
       FROM "place_candidates"
       WHERE "state" = ?
       ORDER BY "times_seen" DESC, "last_seen_at" DESC
       LIMIT 200`,
    )
    .bind(state)
    .all<Record<string, unknown>>();

  const items = result.results ?? [];
  return json({ items, total: items.length }, { headers: NO_STORE_HEADERS });
}

/**
 * `POST /api/admin/places/candidates/:id/promote`
 *
 * Makes a candidate a real place, early — before two people have said it, or
 * with its spelling and its parent corrected.
 */
export async function promotePlaceCandidate(context: RequestContext): Promise<Response> {
  const actor = requireReviewer(context);

  const candidate = await context.env.DB
    .prepare('SELECT * FROM "place_candidates" WHERE "id" = ? LIMIT 1')
    .bind(context.params['id'] ?? '')
    .first<Record<string, unknown>>();

  if (!candidate) throw new NotFoundError('That was not found.');
  if (candidate['state'] === 'promoted') {
    throw new NotFoundError('That has already been added.');
  }

  const body = await readJsonBody(context.request).catch(() => ({}) as Record<string, unknown>);
  const validated = new Validator(body)
    .string('name', { max: 120, label: 'Name' })
    .string('parent_id', { max: 64, label: 'Sits inside' })
    .validated();

  const service = new PlacesService(context.env);
  const place = await service.promote(
    String(candidate['id']),
    (validated['name'] as string | null) ?? String(candidate['raw_name']),
    (validated['parent_id'] as string | null) ?? null,
  );

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: 'place.promoted',
    resourceType: 'place',
    resourceId: place?.id ?? null,
    changes: { from_candidate: candidate['raw_name'], name: place?.name ?? null },
    requestId: context.requestId,
  });

  return json(
    { id: place?.id, slug: place?.slug, message: 'Added to the places of Ekori.' },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

/** `POST /api/admin/places/candidates/:id/dismiss` — not a place. */
export async function dismissPlaceCandidate(context: RequestContext): Promise<Response> {
  requireReviewer(context);

  const result = await context.env.DB
    .prepare(`UPDATE "place_candidates" SET "state" = 'rejected' WHERE "id" = ?`)
    .bind(context.params['id'] ?? '')
    .run();

  if ((result.meta.changes ?? 0) === 0) throw new NotFoundError('That was not found.');

  return json({ message: 'Set aside.' }, { headers: NO_STORE_HEADERS });
}

// ---------------------------------------------------------------------------

function requireReviewer(context: RequestContext) {
  if (!context.user) throw new UnauthorizedError('Please sign in to continue.');
  if (!can(context.user, 'settings:manage')) {
    throw new ForbiddenError('You do not keep the list of places.');
  }
  return context.user;
}

function shape(place: PlaceRecord): Record<string, unknown> {
  return {
    id: place.id,
    slug: place.slug,
    name: place.name,
    parent_id: place.parent_id,
    kind: place.kind,
    // "Ekori / Ajere / Edang / Ukekeya" — cached on the row, because every
    // profile card and every dropdown needs it and walking the tree per row is
    // a walk too many.
    path: place.path,
    depth: place.depth,
    member_count: place.member_count,
    // An automatically promoted place is marked so a reviewer can find the
    // ones the threshold created and tidy them, without hunting.
    is_canonical: place.is_canonical === 1,
  };
}
