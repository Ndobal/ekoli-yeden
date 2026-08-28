import type { RequestContext } from '../types/api';
import { GalleryService } from '../services/gallery.service';
import { AuditRepository } from '../repositories/audit.repository';
import { CONTENT_STATUS } from '../types/models';
import { BadRequestError, NotFoundError, UnauthorizedError } from '../utils/errors';
import { readJsonBody, Validator } from '../utils/validation';
import { json, paginated, NO_STORE_HEADERS, publicCacheHeaders } from '../utils/responses';
import { parsePagination } from '../utils/pagination';

/**
 * GALLERIES
 *
 * A gallery is an album; a gallery item is a photograph plus the labels that
 * make it findable in fifty years. The endpoints below are the two views a
 * visitor actually wants — one album, or everything at once — and the tools the
 * Media Team needs to fill them.
 *
 * Festival galleries are not a special case here. They are ordinary galleries
 * with a `festival_id`, which is exactly why a photograph filed under Leboku
 * 2026 appears in the main Gallery section too.
 */

/**
 * `GET /api/galleries/:identifier`
 *
 * One album with its photographs. The generated content route would return the
 * album's own columns and nothing inside it, which is a page with a title and
 * no pictures.
 */
export async function showGallery(context: RequestContext): Promise<Response> {
  const service = new GalleryService(context.env);
  const gallery = await service.repo.findBySlugOrId(context.params['identifier'] ?? '');

  if (!gallery || gallery.status !== CONTENT_STATUS.PUBLISHED) {
    throw new NotFoundError('That gallery was not found.');
  }

  const items = await service.repo.itemsForGallery(gallery.id, [CONTENT_STATUS.PUBLISHED]);

  return json(
    {
      ...gallery,
      items: items.map((item) => service.decorateItem(item)),
      total: items.length,
    },
    { headers: publicCacheHeaders() },
  );
}

/**
 * `GET /api/galleries/photographs/all`
 *
 * Every published photograph in the archive, newest first, whichever album it
 * belongs to. This is what makes a festival photograph appear in the main
 * gallery without being filed twice.
 *
 * `?festival_id=` narrows it to one festival's years; `?gallery_id=` to one
 * album.
 */
export async function allPhotographs(context: RequestContext): Promise<Response> {
  const { page, perPage, offset } = parsePagination(context.query);
  const service = new GalleryService(context.env);

  const { items, total } = await service.repo.allPublishedItems({
    limit: perPage,
    offset,
    galleryId: context.query.get('gallery_id'),
    festivalId: context.query.get('festival_id'),
  });

  return paginated(
    items.map((item) => service.decorateItem(item)),
    page,
    perPage,
    total,
    publicCacheHeaders(),
  );
}

/**
 * `GET /api/galleries/albums/index`
 *
 * Every published album with a count of what is in it.
 *
 * The gallery page used to open on a list of album titles and descriptions —
 * a wall of prose in a section whose whole purpose is pictures, where a
 * visitor had to read three paragraphs and click before seeing a single
 * photograph. This endpoint turns that list into a filter bar instead, so the
 * page can open on the photographs themselves.
 */
export async function galleryAlbums(context: RequestContext): Promise<Response> {
  const service = new GalleryService(context.env);
  const albums = await service.repo.publishedAlbumsWithCounts();

  return json(
    {
      items: albums,
      total: albums.length,
      // The total across every album, so the "All" filter can be labelled
      // without the client adding up numbers the server already has.
      itemTotal: albums.reduce((sum, album) => sum + album.item_count, 0),
      videoTotal: albums.reduce((sum, album) => sum + album.video_count, 0),
    },
    { headers: publicCacheHeaders() },
  );
}

// ---------------------------------------------------------------------------
// Managing an album
// ---------------------------------------------------------------------------

/**
 * `GET /api/admin/galleries/:id/items`
 *
 * Every photograph in an album in every status, which is what the workspace
 * screen needs — a draft photograph is invisible to a visitor but must be
 * visible to the person cataloguing it.
 */
export async function listGalleryItems(context: RequestContext): Promise<Response> {
  const service = new GalleryService(context.env);
  const gallery = await service.repo.findBySlugOrId(context.params['id'] ?? '');
  if (!gallery) throw new NotFoundError('That gallery was not found.');

  const items = await service.repo.itemsForGallery(gallery.id, [
    CONTENT_STATUS.DRAFT,
    CONTENT_STATUS.PENDING_REVIEW,
    CONTENT_STATUS.APPROVED,
    CONTENT_STATUS.PUBLISHED,
  ]);

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
 * `POST /api/admin/galleries/:id/items`
 *
 * Uploads a photograph straight into an album. One request rather than two,
 * because the Media Team's real task is forty photographs from Saturday, all
 * belonging to the same year, and a two-step flow is how albums end up
 * half-filled.
 */
export async function uploadIntoGallery(context: RequestContext): Promise<Response> {
  const actor = context.user;
  if (!actor) throw new UnauthorizedError('Please sign in to continue.');

  const service = new GalleryService(context.env);
  const gallery = await service.repo.findBySlugOrId(context.params['id'] ?? '');
  if (!gallery) throw new NotFoundError('That gallery was not found.');

  const result = await service.uploadIntoGallery(context.request, gallery.id, actor);

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: 'gallery.item.added',
    resourceType: 'gallery_item',
    resourceId: result.itemId,
    changes: { galleryId: gallery.id, gallery: gallery.title, mediaAssetId: result.mediaAssetId },
    requestId: context.requestId,
  });

  return json(result, { status: 201, headers: NO_STORE_HEADERS });
}

/**
 * `POST /api/admin/galleries/:id/items/existing`
 *
 * Files a photograph already in the media library into an album — the path a
 * community contribution takes once it has been approved.
 */
export async function addExistingMediaToGallery(context: RequestContext): Promise<Response> {
  const actor = context.user;
  if (!actor) throw new UnauthorizedError('Please sign in to continue.');

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('media_asset_id', { required: true, max: 64, label: 'Media item' })
    .string('caption', { max: 1000, label: 'Caption' })
    .string('photographer', { max: 200, label: 'Photographer' })
    .string('people_pictured', { max: 1000, label: 'People pictured' })
    .string('location', { max: 300, label: 'Location' })
    .string('contributed_by', { max: 200, label: 'Contributed by' })
    .validated();

  if ('taken_at' in body && body['taken_at']) {
    Object.assign(validated, new Validator(body).date('taken_at', { label: 'Date taken' }).validated());
  }

  const service = new GalleryService(context.env);
  const gallery = await service.repo.findBySlugOrId(context.params['id'] ?? '');
  if (!gallery) throw new NotFoundError('That gallery was not found.');

  const itemId = await service.addExistingMedia(
    gallery.id,
    validated['media_asset_id'] as string,
    {
      caption: (validated['caption'] as string | null) ?? null,
      photographer: (validated['photographer'] as string | null) ?? null,
      peoplePictured: (validated['people_pictured'] as string | null) ?? null,
      takenAt: (validated['taken_at'] as string | null) ?? null,
      location: (validated['location'] as string | null) ?? null,
      contributedBy: (validated['contributed_by'] as string | null) ?? null,
    },
    actor,
  );

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: 'gallery.item.added',
    resourceType: 'gallery_item',
    resourceId: itemId,
    changes: { galleryId: gallery.id, mediaAssetId: validated['media_asset_id'] },
    requestId: context.requestId,
  });

  return json({ id: itemId, galleryId: gallery.id }, { status: 201, headers: NO_STORE_HEADERS });
}

/**
 * `PATCH /api/admin/gallery-items/:id`
 *
 * Cataloguing: who is in it, where, when, who took it. This is the step that
 * turns a picture into an archive record, and it usually happens long after
 * the upload — often from an elder's answer to "who is that?".
 */
export async function updateGalleryItem(context: RequestContext): Promise<Response> {
  const actor = context.user;
  if (!actor) throw new UnauthorizedError('Please sign in to continue.');

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('caption', { max: 1000, label: 'Caption' })
    .string('people_pictured', { max: 1000, label: 'People pictured' })
    .string('photographer', { max: 200, label: 'Photographer' })
    .string('location', { max: 300, label: 'Location' })
    .validated();

  if ('taken_at' in body && body['taken_at']) {
    Object.assign(validated, new Validator(body).date('taken_at', { label: 'Date taken' }).validated());
  }
  if ('status' in body) {
    Object.assign(validated, new Validator(body).status('status').validated());
  }
  if ('sort_order' in body) {
    Object.assign(
      validated,
      new Validator(body).integer('sort_order', { min: 0, max: 100_000, label: 'Position' }).validated(),
    );
  }

  const service = new GalleryService(context.env);
  const id = context.params['id'] ?? '';
  const changed = await service.repo.updateItem(id, validated);
  if (changed === 0) throw new BadRequestError('That photograph was not found, or nothing was changed.');

  const item = await service.repo.findItem(id);
  return json(item, { headers: NO_STORE_HEADERS });
}

/**
 * `DELETE /api/admin/gallery-items/:id`
 *
 * Removes a photograph from an album. The file itself and its media record
 * stay: taking a picture out of an album is a decision about presentation, not
 * a decision to destroy it, and those two should never be the same click.
 */
export async function removeGalleryItem(context: RequestContext): Promise<Response> {
  const actor = context.user;
  if (!actor) throw new UnauthorizedError('Please sign in to continue.');

  const service = new GalleryService(context.env);
  const id = context.params['id'] ?? '';
  const item = await service.repo.findItem(id);
  if (!item) throw new NotFoundError('That photograph was not found in this album.');

  await service.repo.removeItem(id);

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: 'gallery.item.removed',
    resourceType: 'gallery_item',
    resourceId: id,
    changes: { galleryId: item.gallery_id, mediaAssetId: item.media_asset_id },
    requestId: context.requestId,
  });

  return json(
    {
      id,
      removed: true,
      message: 'Removed from the album. The photograph itself is still in the media library.',
    },
    { headers: NO_STORE_HEADERS },
  );
}
