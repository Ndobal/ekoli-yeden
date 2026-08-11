import type { RequestContext } from '../types/api';
import { CmsRepository } from '../repositories/cms.repository';
import { EditorialRepository } from '../repositories/editorial.repository';
import { AuditRepository, AUDIT_ACTIONS } from '../repositories/audit.repository';
import { CONTENT_STATUS } from '../types/models';
import { BadRequestError, NotFoundError, UnauthorizedError } from '../utils/errors';
import { readJsonBody, Validator } from '../utils/validation';
import { json, publicCacheHeaders, NO_STORE_HEADERS } from '../utils/responses';
import { publicMediaUrl } from '../utils/files';

/**
 * THE CMS.
 *
 * `GET /api/cms/bundle` is the endpoint that makes the rule work: one request
 * returns every published string, the hero carousel and the navigation, so the
 * Flutter client can render the entire public site from the database. The
 * client ships a fallback for each string, so the site still works before the
 * CMS is seeded — but when a row exists, the row wins.
 */

/**
 * `GET /api/cms/bundle` — everything the public site needs to render its text.
 *
 * Deliberately one request rather than three: it is fetched on first paint, and
 * a visitor on a slow connection should wait for one round trip, not three.
 */
export async function bundle(context: RequestContext): Promise<Response> {
  const cms = new CmsRepository(context.env.DB);

  const [strings, slides, navigation] = await Promise.all([
    cms.publishedStrings(),
    cms.heroSlides(true),
    cms.navigation(null, true),
  ]);

  return json(
    {
      strings,
      hero: slides.map((slide) => ({
        slideNumber: slide.slide_number,
        eyebrow: slide.eyebrow,
        title: slide.title,
        description: slide.description,
        imageUrl: null as string | null,
        imageAltText: slide.image_alt_text,
        primaryButtonLabel: slide.primary_button_label,
        primaryButtonPath: slide.primary_button_path,
        secondaryButtonLabel: slide.secondary_button_label,
        secondaryButtonPath: slide.secondary_button_path,
      })),
      navigation: {
        primary: navigation.filter((item) => item.menu === 'primary').map(toNavItem),
        footer: navigation.filter((item) => item.menu === 'footer').map(toNavItem),
        utility: navigation.filter((item) => item.menu === 'utility').map(toNavItem),
      },
    },
    { headers: publicCacheHeaders(300) },
  );
}

function toNavItem(item: {
  id: string;
  label: string;
  path: string;
  description: string | null;
  is_cta: number;
}): Record<string, unknown> {
  return {
    id: item.id,
    label: item.label,
    path: item.path,
    description: item.description,
    isCta: item.is_cta === 1,
  };
}

/**
 * `GET /api/cms/hero` — the carousel with its images resolved.
 *
 * Separate from the bundle because a slide's image has to be joined to its
 * media record to produce a URL, and the bundle is on the critical path.
 */
export async function heroCarousel(context: RequestContext): Promise<Response> {
  const cms = new CmsRepository(context.env.DB);
  const slides = await cms.heroSlides(true);

  const withImages = await Promise.all(
    slides.map(async (slide) => {
      let imageUrl: string | null = null;

      // An image slot is empty until the Media Team attaches an approved
      // photograph. The client renders a branded panel in that case rather than
      // a broken image, so the homepage is presentable from day one.
      if (slide.image_media_id) {
        const media = await context.env.DB.prepare(
          'SELECT "storage_key", "status" FROM "media_assets" WHERE "id" = ? LIMIT 1',
        )
          .bind(slide.image_media_id)
          .first<{ storage_key: string; status: string }>();

        if (media && media.status === CONTENT_STATUS.PUBLISHED) {
          imageUrl = publicMediaUrl(context.env.PUBLIC_MEDIA_BASE_URL, media.storage_key);
        }
      }

      return {
        slideNumber: slide.slide_number,
        eyebrow: slide.eyebrow,
        title: slide.title,
        description: slide.description,
        imageUrl,
        imageAltText: slide.image_alt_text,
        primaryButtonLabel: slide.primary_button_label,
        primaryButtonPath: slide.primary_button_path,
        secondaryButtonLabel: slide.secondary_button_label,
        secondaryButtonPath: slide.secondary_button_path,
      };
    }),
  );

  return json({ slides: withImages }, { headers: publicCacheHeaders(300) });
}

// ---------------------------------------------------------------------------
// Editorial endpoints
// ---------------------------------------------------------------------------

/** `GET /api/editorial/strings` — every string with its draft and metadata. */
export async function listStrings(context: RequestContext): Promise<Response> {
  const cms = new CmsRepository(context.env.DB);
  const strings = await cms.allStrings(
    context.query.get('group'),
    context.query.get('page'),
  );

  const groups: Record<string, unknown[]> = {};
  for (const row of strings) {
    (groups[row.group_name] ??= []).push({
      key: row.key,
      value: row.value,
      draftValue: row.draft_value,
      label: row.label,
      helpText: row.help_text,
      page: row.page,
      valueType: row.value_type,
      maxLength: row.max_length,
      status: row.status,
      isLocked: row.is_locked === 1,
      hasPendingChange: row.draft_value !== null && row.draft_value !== row.value,
      updatedAt: row.updated_at,
    });
  }

  return json({ groups, total: strings.length }, { headers: NO_STORE_HEADERS });
}

/**
 * `PUT /api/editorial/strings/:key` — save a draft.
 *
 * Writes only the draft. Nothing a visitor sees changes here.
 */
export async function saveStringDraft(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const key = context.params['key'] ?? '';
  const body = await readJsonBody(context.request);

  const cms = new CmsRepository(context.env.DB);
  const existing = await cms.findString(key);
  if (!existing) throw new NotFoundError('That text does not exist.');
  if (existing.is_locked === 1) {
    throw new BadRequestError('That text is locked and cannot be edited through the CMS.');
  }

  const validated = new Validator(body)
    .string('value', { max: existing.max_length ?? 5000, label: existing.label })
    .validated();
  const draftValue = (validated['value'] as string | null) ?? null;

  await cms.saveDraft(key, draftValue, actor.id);

  await audit(context, AUDIT_ACTIONS.CONTENT_UPDATED, 'content_string', key, {
    action: 'draft saved',
    label: existing.label,
    from: existing.value,
    to: draftValue,
  });

  return json(
    { key, draftValue, status: CONTENT_STATUS.DRAFT, message: 'Draft saved. It is not yet visible on the website.' },
    { headers: NO_STORE_HEADERS },
  );
}

/** `POST /api/editorial/strings/:key/submit` — send a draft for review. */
export async function submitString(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const key = context.params['key'] ?? '';

  const cms = new CmsRepository(context.env.DB);
  const changed = await cms.submitForReview(key, actor.id);
  if (changed === 0) {
    throw new BadRequestError('There is no saved draft to submit for this text.');
  }

  await audit(context, AUDIT_ACTIONS.CONTENT_STATUS_CHANGED, 'content_string', key, {
    to: CONTENT_STATUS.PENDING_REVIEW,
  });

  return json({ key, status: CONTENT_STATUS.PENDING_REVIEW }, { headers: NO_STORE_HEADERS });
}

/** `POST /api/editorial/strings/:key/review` — approve or reject. */
export async function reviewString(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const key = context.params['key'] ?? '';
  const body = await readJsonBody(context.request);
  const validated = new Validator(body).boolean('approved', { required: true }).validated();

  const approved = validated['approved'] === 1;
  const cms = new CmsRepository(context.env.DB);
  const changed = await cms.review(key, approved, actor.id);
  if (changed === 0) throw new BadRequestError('That text is not awaiting review.');

  await audit(context, AUDIT_ACTIONS.CONTENT_STATUS_CHANGED, 'content_string', key, {
    to: approved ? CONTENT_STATUS.APPROVED : CONTENT_STATUS.REJECTED,
  });

  return json(
    { key, status: approved ? CONTENT_STATUS.APPROVED : CONTENT_STATUS.REJECTED },
    { headers: NO_STORE_HEADERS },
  );
}

/**
 * `POST /api/editorial/strings/:key/publish` — make the draft live.
 *
 * Behind `strings:publish`, which the Writer and Editor roles do not hold. That
 * is the whole point of separating the roles: writing is not publishing.
 */
export async function publishString(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const key = context.params['key'] ?? '';

  const cms = new CmsRepository(context.env.DB);
  const existing = await cms.findString(key);
  if (!existing) throw new NotFoundError('That text does not exist.');

  const changed = await cms.publish(key, actor.id);
  if (changed === 0) throw new BadRequestError('That text could not be published.');

  await audit(context, AUDIT_ACTIONS.CONTENT_STATUS_CHANGED, 'content_string', key, {
    to: CONTENT_STATUS.PUBLISHED,
    published: existing.draft_value ?? existing.value,
  });

  return json({ key, status: CONTENT_STATUS.PUBLISHED }, { headers: NO_STORE_HEADERS });
}

/** `GET /api/editorial/hero` — the carousel, including unpublished slides. */
export async function editorialHero(context: RequestContext): Promise<Response> {
  const cms = new CmsRepository(context.env.DB);
  const slides = await cms.heroSlides(false);
  return json({ slides }, { headers: NO_STORE_HEADERS });
}

/** Columns an editor may set on a hero slide. */
const HERO_WRITABLE = [
  'eyebrow',
  'title',
  'description',
  'image_media_id',
  'image_alt_text',
  'primary_button_label',
  'primary_button_path',
  'secondary_button_label',
  'secondary_button_path',
  'status',
] as const;

/** `PUT /api/editorial/hero/:slide` */
export async function updateHeroSlide(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const slideNumber = Number(context.params['slide'] ?? '0');
  if (!Number.isInteger(slideNumber) || slideNumber < 1 || slideNumber > 5) {
    throw new BadRequestError('The hero carousel has exactly five slides, numbered 1 to 5.');
  }

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('eyebrow', { max: 80, label: 'Eyebrow' })
    .string('title', { max: 160, label: 'Title' })
    .string('description', { max: 600, label: 'Description' })
    .string('image_alt_text', { max: 300, label: 'Image description' })
    .string('primary_button_label', { max: 60, label: 'Button label' })
    .string('primary_button_path', { max: 200, label: 'Button destination' })
    .string('secondary_button_label', { max: 60, label: 'Second button label' })
    .string('secondary_button_path', { max: 200, label: 'Second button destination' })
    .string('image_media_id', { max: 64, label: 'Image' })
    .validated();

  if ('status' in body) {
    Object.assign(validated, new Validator(body).status('status').validated());
  }

  // Restricted to the allow-list, so no request can reach a column the editor
  // has no business setting.
  const values: Record<string, unknown> = {};
  for (const column of HERO_WRITABLE) {
    if (Object.prototype.hasOwnProperty.call(validated, column)) values[column] = validated[column];
  }
  if (Object.keys(values).length === 0) throw new BadRequestError('No changes were supplied.');

  const cms = new CmsRepository(context.env.DB);
  const changed = await cms.updateHeroSlide(slideNumber, values, actor.id);
  if (changed === 0) throw new NotFoundError('That hero slide was not found.');

  await audit(context, AUDIT_ACTIONS.CONTENT_UPDATED, 'hero_slide', String(slideNumber), {
    fields: Object.keys(values),
  });

  return json({ slideNumber, updated: Object.keys(values) }, { headers: NO_STORE_HEADERS });
}

/** `GET /api/editorial/navigation` */
export async function editorialNavigation(context: RequestContext): Promise<Response> {
  const cms = new CmsRepository(context.env.DB);
  const items = await cms.navigation(context.query.get('menu'), false);
  return json({ items }, { headers: NO_STORE_HEADERS });
}

/** `PATCH /api/editorial/navigation/:id` */
export async function updateNavigationItem(context: RequestContext): Promise<Response> {
  const id = context.params['id'] ?? '';
  const body = await readJsonBody(context.request);

  const validated = new Validator(body)
    .string('label', { max: 60, label: 'Label' })
    .string('path', { max: 200, label: 'Destination' })
    .string('description', { max: 200, label: 'Description' })
    .integer('sort_order', { min: 0, max: 999, label: 'Order' })
    .validated();

  if ('is_cta' in body) Object.assign(validated, new Validator(body).boolean('is_cta').validated());
  if ('status' in body) Object.assign(validated, new Validator(body).status('status').validated());

  if (Object.keys(validated).length === 0) throw new BadRequestError('No changes were supplied.');

  const cms = new CmsRepository(context.env.DB);
  const changed = await cms.updateNavigationItem(id, validated);
  if (changed === 0) throw new NotFoundError('That navigation item was not found.');

  await audit(context, AUDIT_ACTIONS.CONTENT_UPDATED, 'navigation_item', id, {
    fields: Object.keys(validated),
  });

  return json({ id, updated: Object.keys(validated) }, { headers: NO_STORE_HEADERS });
}

// --- Sources ---------------------------------------------------------------

/**
 * `GET /api/sources/:resourceType/:resourceId`
 *
 * Public. A history page has to be able to show where its claims came from —
 * that is what separates this archive from an unsourced blog.
 */
export async function sourcesForResource(context: RequestContext): Promise<Response> {
  const repository = new EditorialRepository(context.env.DB);
  const sources = await repository.sourcesFor(
    context.params['resourceType'] ?? '',
    context.params['resourceId'] ?? '',
  );
  return json({ sources }, { headers: publicCacheHeaders(600) });
}

/**
 * `GET /api/contributors/:resourceType/:resourceId`
 *
 * Public. Contributor acknowledgement is shown on published material and
 * survives every subsequent edit to the article.
 */
export async function contributorsForResource(context: RequestContext): Promise<Response> {
  const repository = new EditorialRepository(context.env.DB);
  const contributors = await repository.contributorsFor(
    context.params['resourceType'] ?? '',
    context.params['resourceId'] ?? '',
  );

  return json(
    {
      contributors: contributors.map((contributor) => ({
        id: contributor.id,
        name: contributor.contributor_name,
        type: contributor.contributor_type,
        attributionPrefix: contributor.attribution_prefix,
        credit: `${contributor.attribution_prefix}: ${contributor.contributor_name}`,
        approvedAt: contributor.approved_at,
      })),
    },
    { headers: publicCacheHeaders(600) },
  );
}

/** `GET /api/editorial/sources` */
export async function listSources(context: RequestContext): Promise<Response> {
  const repository = new EditorialRepository(context.env.DB);
  const { items, total } = await repository.listSources({
    search: context.query.get('q'),
    limit: 100,
    offset: 0,
  });
  return json({ sources: items, total }, { headers: NO_STORE_HEADERS });
}

/** `POST /api/editorial/sources` */
export async function createSource(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const body = await readJsonBody(context.request);

  const validated = new Validator(body)
    .string('title', { required: true, max: 300, label: 'Title' })
    .string('author', { max: 200, label: 'Author' })
    .string('publication', { max: 200, label: 'Publication' })
    .string('publisher', { max: 200, label: 'Publisher' })
    .string('publication_date', { max: 40, label: 'Publication date' })
    .string('accessed_date', { max: 40, label: 'Date accessed' })
    .string('citation_text', { max: 1000, label: 'Citation' })
    .string('notes', { max: 4000, label: 'Notes' })
    .oneOf('source_type', [
      'web', 'book', 'journal', 'oral_interview', 'archival_document',
      'photograph', 'government_record', 'other',
    ])
    .oneOf('reliability', ['unassessed', 'primary', 'secondary', 'tertiary', 'contested'])
    .validated();

  if (body['url']) {
    Object.assign(validated, new Validator(body).url('url').validated());
  }

  const repository = new EditorialRepository(context.env.DB);
  const id = await repository.createSource(validated, actor.id);

  await audit(context, AUDIT_ACTIONS.CONTENT_CREATED, 'source', id, {
    title: validated['title'],
  });

  return json({ id, ...validated }, { status: 201, headers: NO_STORE_HEADERS });
}

/** `POST /api/editorial/sources/attach` — cite a source on a record. */
export async function attachSource(context: RequestContext): Promise<Response> {
  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('resource_type', { required: true, max: 60, label: 'Content type' })
    .string('resource_id', { required: true, max: 64, label: 'Record' })
    .string('source_id', { required: true, max: 64, label: 'Source' })
    .string('supports', { max: 500, label: 'What this source supports' })
    .string('page_reference', { max: 100, label: 'Page reference' })
    .integer('sort_order', { min: 0, max: 999 })
    .validated();

  const repository = new EditorialRepository(context.env.DB);
  const id = await repository.attachSource({
    resourceType: validated['resource_type'] as string,
    resourceId: validated['resource_id'] as string,
    sourceId: validated['source_id'] as string,
    supports: (validated['supports'] as string | null) ?? null,
    pageReference: (validated['page_reference'] as string | null) ?? null,
    sortOrder: (validated['sort_order'] as number | undefined) ?? 0,
  });

  await audit(context, AUDIT_ACTIONS.CONTENT_UPDATED, 'content_source', id, {
    action: 'source cited',
    resource: `${validated['resource_type']}/${validated['resource_id']}`,
  });

  return json({ id }, { status: 201, headers: NO_STORE_HEADERS });
}

// --- Versions --------------------------------------------------------------

/** `GET /api/editorial/versions/:resourceType/:resourceId` */
export async function listVersions(context: RequestContext): Promise<Response> {
  const repository = new EditorialRepository(context.env.DB);
  const versions = await repository.versionsFor(
    context.params['resourceType'] ?? '',
    context.params['resourceId'] ?? '',
  );

  return json(
    {
      versions: versions.map((version) => ({
        versionNumber: version.version_number,
        changeSummary: version.change_summary,
        statusAtTime: version.status_at_time,
        changedByName: version.changed_by_name,
        changedFields: safeParse(version.changed_fields),
        createdAt: version.created_at,
      })),
    },
    { headers: NO_STORE_HEADERS },
  );
}

/** `GET /api/editorial/versions/:resourceType/:resourceId/:version` */
export async function showVersion(context: RequestContext): Promise<Response> {
  const repository = new EditorialRepository(context.env.DB);
  const version = await repository.findVersion(
    context.params['resourceType'] ?? '',
    context.params['resourceId'] ?? '',
    Number(context.params['version'] ?? '0'),
  );
  if (!version) throw new NotFoundError('That version was not found.');

  return json(
    {
      versionNumber: version.version_number,
      snapshot: safeParse(version.snapshot),
      changedFields: safeParse(version.changed_fields),
      changeSummary: version.change_summary,
      changedByName: version.changed_by_name,
      createdAt: version.created_at,
    },
    { headers: NO_STORE_HEADERS },
  );
}

// --- Shared ----------------------------------------------------------------

function requireActor(context: RequestContext) {
  if (!context.user) throw new UnauthorizedError('Please sign in to continue.');
  return context.user;
}

async function audit(
  context: RequestContext,
  action: string,
  resourceType: string,
  resourceId: string,
  changes?: unknown,
): Promise<void> {
  await new AuditRepository(context.env.DB).record({
    actorId: context.user?.id ?? null,
    actorEmail: context.user?.email ?? null,
    action,
    resourceType,
    resourceId,
    changes,
    userAgent: context.request.headers.get('user-agent'),
    requestId: context.requestId,
  });
}

function safeParse(value: string | null): unknown {
  if (value === null) return null;
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}
