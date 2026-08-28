import { GalleryRepository, type GalleryRecord, type GalleryItemWithMedia } from '../repositories/gallery.repository';
import { MediaService } from './media.service';
import type { Env } from '../types/env';
import type { AuthenticatedUser } from '../types/auth';
import { CONTENT_STATUS } from '../types/models';
import { NotFoundError } from '../utils/errors';
import { publicMediaUrl } from '../utils/files';
import { slugify } from '../utils/slug';

/**
 * GALLERIES, AND THE FESTIVAL GALLERIES IN PARTICULAR
 *
 * The rule this file exists to enforce: a photograph belongs to a year.
 *
 * Every festival edition owns exactly one gallery, created with it. A
 * photograph from Leboku 2026 is added to that gallery and is thereby filed
 * under 2026 forever — which is the difference between a festival archive and
 * a page of pictures that gets replaced each August.
 *
 * Because a festival gallery is an ordinary row in `galleries`, the same
 * photograph also appears in the main Gallery section, in the album list and
 * in the combined photograph stream, without anybody copying it. One upload,
 * one record, three places it can be found.
 */
export class GalleryService {
  private readonly repository: GalleryRepository;
  private readonly media: MediaService;

  constructor(private readonly env: Env) {
    this.repository = new GalleryRepository(env.DB);
    this.media = new MediaService(env);
  }

  get repo(): GalleryRepository {
    return this.repository;
  }

  /**
   * The gallery a festival's photographs belong to, creating it if it is
   * missing.
   *
   * Called when a festival is created and again whenever somebody opens its
   * gallery, so a festival added before this existed — or one created through
   * a route that forgot — still ends up with an album rather than an error.
   *
   * The gallery inherits the festival's status. Preparing next year's festival
   * page must not put an empty photograph album on the public site.
   */
  async ensureFestivalGallery(festival: {
    id: string;
    slug: string;
    name: string;
    year: number | string;
    start_date?: string | null;
    location?: string | null;
    status?: string | null;
  }): Promise<GalleryRecord> {
    const existing = await this.repository.findPrimaryForFestival(festival.id);
    if (existing) return existing;

    const title = `${festival.name} ${festival.year} — photographs`;
    const slug = await this.uniqueSlug(`${festival.slug}-photographs`);

    // A derived id rather than a random one: the relationship stays legible to
    // anybody reading the table, and a repeated call cannot make a second album.
    const id = `gallery_${festival.id}`;

    await this.repository.createGallery({
      id,
      slug,
      title,
      description:
        `Photographs from ${festival.name} ${festival.year}. Each one is labelled with what it ` +
        `shows, so that somebody who was not there can still understand it.`,
      category: 'festival',
      eventDate: festival.start_date ?? null,
      location: festival.location ?? null,
      festivalId: festival.id,
      isFestivalGallery: true,
      // Negative year sorts the newest edition first under the default
      // `sort_order ASC` every gallery listing uses.
      sortOrder: -Number(festival.year || 0),
      status: festival.status ?? CONTENT_STATUS.DRAFT,
    });

    await this.env.DB.prepare('UPDATE "festivals" SET "gallery_id" = ? WHERE "id" = ?')
      .bind(id, festival.id)
      .run();

    const created = await this.repository.findById(id);
    if (!created) throw new NotFoundError('The festival gallery could not be read back.');
    return created;
  }

  /**
   * Keeps a festival gallery's visibility in step with its festival.
   *
   * Publishing a festival should publish its album; archiving one should not
   * leave the photographs advertised on a page that no longer exists.
   */
  async syncFestivalGalleryStatus(festivalId: string, status: string): Promise<void> {
    const gallery = await this.repository.findPrimaryForFestival(festivalId);
    if (!gallery || gallery.status === status) return;
    await this.repository.setStatus(gallery.id, status);
  }

  /**
   * Adds an already-uploaded media asset to a gallery.
   *
   * Separate from the upload itself so that a photograph already in the media
   * library — or one just approved from a community contribution — can be
   * filed into a festival year without being uploaded a second time.
   */
  async addExistingMedia(
    galleryId: string,
    mediaAssetId: string,
    labels: {
      caption?: string | null;
      photographer?: string | null;
      peoplePictured?: string | null;
      takenAt?: string | null;
      location?: string | null;
      contributedBy?: string | null;
      submissionUploadId?: string | null;
      status?: string;
    },
    actor: AuthenticatedUser | null,
  ): Promise<string> {
    const gallery = await this.repository.findById(galleryId);
    if (!gallery) throw new NotFoundError('That gallery was not found.');

    const media = await this.media.repo.findById(mediaAssetId);
    if (!media) throw new NotFoundError('That media item was not found.');

    return this.repository.addItem({
      galleryId,
      mediaAssetId,
      caption: labels.caption ?? null,
      photographer: labels.photographer ?? null,
      peoplePictured: labels.peoplePictured ?? null,
      takenAt: labels.takenAt ?? null,
      location: labels.location ?? null,
      sortOrder: await this.repository.nextSortOrder(galleryId),
      // An item is only as visible as the album it sits in. Adding a photograph
      // to a published festival gallery puts it on the site; adding one to a
      // draft gallery does not.
      status: labels.status ?? gallery.status,
      contributedBy: labels.contributedBy ?? null,
      submissionUploadId: labels.submissionUploadId ?? null,
      addedBy: actor?.id ?? null,
    });
  }

  /**
   * Uploads a file and files it into a gallery in one request.
   *
   * The Media Team's actual workflow: forty photographs from Saturday, all
   * belonging to the same year. Making them upload to a library and then
   * attach each one separately is how albums end up half-filled.
   */
  async uploadIntoGallery(
    request: Request,
    galleryId: string,
    actor: AuthenticatedUser,
  ): Promise<{ itemId: string; mediaAssetId: string; url: string }> {
    const gallery = await this.repository.findById(galleryId);
    if (!gallery) throw new NotFoundError('That gallery was not found.');

    // `upload` consumes the multipart body, and the descriptive fields travel
    // with it, so the labels are read back off the created media record rather
    // than the request — the form is only parsed once.
    const uploaded = await this.media.upload(request, actor, {
      defaultStatus: CONTENT_STATUS.APPROVED,
    });
    const media = await this.media.repo.findById(uploaded.id);

    const itemId = await this.repository.addItem({
      galleryId,
      mediaAssetId: uploaded.id,
      caption: media?.title ?? media?.description ?? null,
      photographer: media?.credit ?? null,
      peoplePictured: null,
      takenAt: media?.captured_at ?? null,
      location: media?.location ?? null,
      sortOrder: await this.repository.nextSortOrder(galleryId),
      status: gallery.status,
      addedBy: actor.id,
    });

    // A photograph in a published album has to be published itself, or the
    // album shows an empty frame.
    if (gallery.status === CONTENT_STATUS.PUBLISHED) {
      await this.media.repo.update(uploaded.id, { status: CONTENT_STATUS.PUBLISHED });
    }

    return { itemId, mediaAssetId: uploaded.id, url: uploaded.url };
  }

  /** Shapes a gallery item for the client, with its file resolved to a URL. */
  decorateItem(item: GalleryItemWithMedia & { gallery_slug?: string; gallery_title?: string }): Record<string, unknown> {
    return {
      id: item.id,
      gallery_id: item.gallery_id,
      gallery_slug: item.gallery_slug ?? null,
      gallery_title: item.gallery_title ?? null,
      media_asset_id: item.media_asset_id,
      caption: item.caption,
      photographer: item.photographer,
      people_pictured: item.people_pictured,
      taken_at: item.taken_at,
      location: item.location,
      contributed_by: item.contributed_by,
      alt_text: item.alt_text,
      mime_type: item.mime_type,
      sort_order: item.sort_order,
      status: item.status,
      url: publicMediaUrl(this.env.PUBLIC_MEDIA_BASE_URL, item.storage_key),
    };
  }

  /** A slug nobody else is using, so a second festival cannot clash. */
  private async uniqueSlug(base: string): Promise<string> {
    const root = slugify(base) || 'gallery';
    if (!(await this.repository.slugExists(root))) return root;

    for (let suffix = 2; suffix < 50; suffix += 1) {
      const candidate = `${root}-${suffix}`;
      if (!(await this.repository.slugExists(candidate))) return candidate;
    }
    return `${root}-${Date.now()}`;
  }
}
