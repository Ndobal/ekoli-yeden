import type { RequestContext } from '../types/api';
import { NewsRepository } from '../repositories/news.repository';
import { AuditRepository } from '../repositories/audit.repository';
import { NotificationRepository } from '../repositories/notification.repository';
import { can } from '../services/permissions';
import { validateNewsBody, plainText, youtubeIdFrom } from '../services/news-content';
import { readJsonBody, Validator } from '../utils/validation';
import { json, paginated, publicCacheHeaders, NO_STORE_HEADERS } from '../utils/responses';
import { parsePagination } from '../utils/pagination';
import { publicMediaUrl, youtubeThumbnailUrl, youtubeEmbedUrl } from '../utils/files';
import { slugify } from '../utils/slug';
import { nowIso } from '../utils/id';
import {
  BadRequestError,
  ForbiddenError,
  NotFoundError,
  UnauthorizedError,
} from '../utils/errors';

/**
 * NEWS.
 *
 * ---------------------------------------------------------------------------
 * THE ARCHIVE IS NOT COMPETING WITH FACEBOOK
 * ---------------------------------------------------------------------------
 *
 * Social media is how news reaches this community and will remain so. What it
 * cannot do is still have the story in 2046. So a news item here holds the
 * photographs, embeds the YouTube video the community already published rather
 * than replacing it, and records where the account came from.
 *
 * ---------------------------------------------------------------------------
 * WHAT THE PUBLIC CAN SEE
 * ---------------------------------------------------------------------------
 *
 * `status = 'published'` AND a publication time that has passed. Both, in SQL,
 * in `publicList` and `publicFind` — not as a filter applied afterwards and not
 * as a flag a caller passes. A draft of the community's news leaking early is
 * the failure this module most has to avoid, and the way to avoid it is to make
 * the public reads incapable of returning anything else.
 */

const SOURCE_TYPES = [
  'community_submission', 'editorial_team', 'community_organization',
  'official_announcement', 'newspaper', 'government', 'interview', 'other',
] as const;

const EDITORIAL_STATUSES = [
  'draft', 'pending_review', 'changes_requested', 'approved',
  'scheduled', 'published', 'archived', 'rejected',
] as const;

// ---------------------------------------------------------------------------
// Public
// ---------------------------------------------------------------------------

/** `GET /api/news-portal` — the portal: stories, filtered and searched. */
export async function listNews(context: RequestContext): Promise<Response> {
  const repository = new NewsRepository(context.env.DB);
  const { page, perPage, offset } = parsePagination(context.query);

  const { items, total } = await repository.publicList({
    limit: perPage,
    offset,
    categorySlug: context.query.get('category'),
    tagSlug: context.query.get('tag'),
    search: context.query.get('q'),
    featuredOnly: context.query.get('featured') === 'true',
    withVideoOnly: context.query.get('video') === 'true',
  });

  return paginated(
    items.map((row) => shapeSummary(context, row)),
    page,
    perPage,
    total,
    publicCacheHeaders(120),
  );
}

/**
 * `GET /api/news-portal/overview`
 *
 * Everything the front of the section needs, in one request: the announcements
 * at the top, the featured story, the latest, the ones with film, and the
 * categories.
 *
 * One request rather than five because this is the page most people land on
 * from a shared link, frequently on a phone on a slow connection, and five
 * round trips before anything renders is the difference between a news site and
 * a spinner.
 */
export async function newsOverview(context: RequestContext): Promise<Response> {
  const repository = new NewsRepository(context.env.DB);

  const [announcements, featured, latest, videos, categories] = await Promise.all([
    repository.importantAnnouncements(),
    repository.publicList({ limit: 1, offset: 0, featuredOnly: true }),
    repository.publicList({ limit: 12, offset: 0 }),
    repository.publicList({ limit: 6, offset: 0, withVideoOnly: true }),
    repository.categories(false),
  ]);

  return json(
    {
      announcements: announcements.map((row) => ({
        id: row['id'],
        slug: row['slug'],
        title: row['title'],
        excerpt: row['excerpt'],
        published_at: row['published_at'],
      })),
      // The featured story falls back to the most recent one. A section whose
      // hero is empty because nobody pressed "feature" looks broken.
      featured: featured.items.length > 0
        ? shapeSummary(context, featured.items[0]!)
        : latest.items.length > 0
          ? shapeSummary(context, latest.items[0]!)
          : null,
      latest: latest.items.map((row) => shapeSummary(context, row)),
      videos: videos.items.map((row) => shapeSummary(context, row)),
      categories: categories.map((row) => ({
        id: row['id'],
        slug: row['slug'],
        name: row['name'],
        description: row['description'],
        accent: row['accent'],
        story_count: Number(row['story_count'] ?? 0),
      })),
      total: latest.total,
    },
    { headers: publicCacheHeaders(120) },
  );
}

/** `GET /api/news-portal/:identifier` — one story, whole. */
export async function showNews(context: RequestContext): Promise<Response> {
  const repository = new NewsRepository(context.env.DB);
  const record = await repository.publicFind(context.params['identifier'] ?? '');
  if (!record) throw new NotFoundError('That story was not found.');

  const newsId = String(record['id']);
  const [media, sources, tags, related] = await Promise.all([
    repository.media(newsId),
    repository.sources(newsId),
    repository.tagsFor(newsId),
    repository.related(newsId, (record['category_id'] as string | null) ?? null, 4),
  ]);

  return json(
    {
      ...shapeSummary(context, record),
      body: parseBody(record['body']),
      author_name: record['author_name'],
      source: record['source'],
      source_url: record['source_url'],
      source_note: record['source_note'],
      // WHO SENT IT IN. Carried onto the published article and never cleared by
      // an edit — see `update` below.
      contributor_name: record['contributor_name'],
      media: media.map((row) => shapeMedia(context, row)),
      sources: sources.map((row) => ({
        id: row['id'],
        source_type: row['source_type'],
        title: row['title'],
        author: row['author'],
        publisher: row['publisher'],
        url: row['url'],
        published_on: row['published_on'],
        notes: row['notes'],
      })),
      tags: tags.map((row) => ({ slug: row['slug'], name: row['name'] })),
      related: related.map((row) => shapeSummary(context, row)),
    },
    { headers: publicCacheHeaders(120) },
  );
}

/** `GET /api/news-portal/categories` — for the filter row. */
export async function listCategories(context: RequestContext): Promise<Response> {
  const repository = new NewsRepository(context.env.DB);
  const includeInactive = context.user !== null && can(context.user, 'news:update');
  const categories = await repository.categories(includeInactive);

  return json(
    {
      items: categories.map((row) => ({
        id: row['id'],
        slug: row['slug'],
        name: row['name'],
        description: row['description'],
        accent: row['accent'],
        is_active: row['is_active'] === 1,
        story_count: Number(row['story_count'] ?? 0),
      })),
      total: categories.length,
    },
    { headers: includeInactive ? NO_STORE_HEADERS : publicCacheHeaders(600) },
  );
}

/** `GET /api/news-portal/tags` */
export async function listTags(context: RequestContext): Promise<Response> {
  const repository = new NewsRepository(context.env.DB);
  const tags = await repository.allTags(60);

  return json(
    {
      items: tags.map((row) => ({
        slug: row['slug'],
        name: row['name'],
        usage_count: Number(row['usage_count'] ?? 0),
      })),
      total: tags.length,
    },
    { headers: publicCacheHeaders(600) },
  );
}

// ---------------------------------------------------------------------------
// Editorial
// ---------------------------------------------------------------------------

/** `GET /api/editorial/news` — every story, whatever its state. */
export async function editorialList(context: RequestContext): Promise<Response> {
  requireEditor(context);

  const repository = new NewsRepository(context.env.DB);
  const { page, perPage, offset } = parsePagination(context.query);

  const { items, total } = await repository.editorialList({
    status: context.query.get('status'),
    search: context.query.get('q'),
    limit: perPage,
    offset,
  });

  const counts = await repository.statusCounts();

  return json(
    {
      items: items.map((row) => ({
        id: row['id'],
        slug: row['slug'],
        title: row['title'],
        excerpt: row['excerpt'],
        status: row['status'],
        news_date: row['news_date'],
        published_at: row['published_at'],
        scheduled_publish_at: row['scheduled_publish_at'],
        is_featured: row['is_featured'] === 1,
        is_important: row['is_important'] === 1,
        contributor_name: row['contributor_name'],
        author_name: row['author_name'],
        review_notes: row['review_notes'],
        category_name: row['category_name'],
        cover_url: mediaUrl(context, row['cover_key']),
        updated_at: row['updated_at'],
      })),
      counts,
      total,
      page,
      perPage,
      totalPages: Math.max(1, Math.ceil(total / perPage)),
    },
    { headers: NO_STORE_HEADERS },
  );
}

/** `GET /api/editorial/news/:identifier` — one story to edit or preview. */
export async function editorialShow(context: RequestContext): Promise<Response> {
  requireEditor(context);

  const repository = new NewsRepository(context.env.DB);
  const record = await repository.find(context.params['identifier'] ?? '');
  if (!record) throw new NotFoundError('That story was not found.');

  const newsId = String(record['id']);
  const [media, sources, tags, reviews, revisions] = await Promise.all([
    repository.media(newsId),
    repository.sources(newsId),
    repository.tagsFor(newsId),
    repository.reviews(newsId),
    repository.revisions(newsId),
  ]);

  return json(
    {
      ...shapeSummary(context, record),
      status: record['status'],
      body: parseBody(record['body']),
      author_name: record['author_name'],
      source: record['source'],
      source_url: record['source_url'],
      source_note: record['source_note'],
      contributor_name: record['contributor_name'],
      category_id: record['category_id'],
      scheduled_publish_at: record['scheduled_publish_at'],
      important_expires_at: record['important_expires_at'],
      review_notes: record['review_notes'],
      seo_title: record['seo_title'],
      seo_description: record['seo_description'],
      media: media.map((row) => shapeMedia(context, row)),
      sources: sources.map((row) => ({ ...row })),
      tags: tags.map((row) => ({ slug: row['slug'], name: row['name'] })),
      reviews: reviews.map((row) => ({
        decision: row['decision'],
        comment: row['comment'],
        reviewer_name: row['reviewer_name'],
        created_at: row['created_at'],
      })),
      revisions: revisions.map((row) => ({
        id: row['id'],
        title: row['title'],
        change_summary: row['change_summary'],
        editor_name: row['editor_name'],
        created_at: row['created_at'],
      })),
    },
    { headers: NO_STORE_HEADERS },
  );
}

/** `POST /api/editorial/news` — start a story. */
export async function createNews(context: RequestContext): Promise<Response> {
  const actor = requireEditor(context);
  const repository = new NewsRepository(context.env.DB);

  const values = await readStoryValues(context, repository);
  const title = (values['title'] as string | null) ?? 'Untitled';

  const id = await repository.create({
    ...values,
    slug: await uniqueSlug(repository, title),
    // Always a draft. Nothing is published by the act of being written, and
    // there is no parameter here that could make it so.
    status: 'draft',
    created_by: actor.id,
    updated_by: actor.id,
  });

  if (Array.isArray(values['__tags'])) {
    await repository.setTags(id, values['__tags'] as string[]);
  }

  await audit(context, 'news.created', id, { title });

  return json({ id, message: 'Draft saved.' }, { status: 201, headers: NO_STORE_HEADERS });
}

/**
 * `PATCH /api/editorial/news/:id`
 *
 * Editing a story.
 *
 * Two things are protected here and both are deliberate:
 *
 * The previous version is snapshotted before the write. Versions are never
 * deleted — the archive's claim is that what it says can be checked, and a
 * record that can be silently rewritten cannot be.
 *
 * `contributor_name` and `submitted_by` are stripped from the payload. Who sent
 * a story in is not an editorial field, and an editor rewording a headline must
 * not be able to take somebody's name off the record — by accident or
 * otherwise.
 */
export async function updateNews(context: RequestContext): Promise<Response> {
  const actor = requireEditor(context);
  const repository = new NewsRepository(context.env.DB);

  const existing = await repository.find(context.params['id'] ?? '');
  if (!existing) throw new NotFoundError('That story was not found.');

  const id = String(existing['id']);
  const values = await readStoryValues(context, repository);

  const body = await readJsonBody(context.request).catch(() => ({}) as Record<string, unknown>);
  const changeSummary = typeof body['change_summary'] === 'string'
    ? body['change_summary'].slice(0, 500)
    : null;

  await repository.snapshot({
    newsId: id,
    title: (existing['title'] as string | null) ?? null,
    summary: (existing['excerpt'] as string | null) ?? null,
    content: (existing['body'] as string | null) ?? null,
    changeSummary,
    editorId: actor.id,
    editorName: actor.displayName,
  });

  // The contributor's identity is not editable. Ever.
  delete values['contributor_name'];
  delete values['submitted_by'];
  delete values['source_note'];

  await repository.update(id, { ...values, updated_by: actor.id });

  if (Array.isArray(values['__tags'])) {
    await repository.setTags(id, values['__tags'] as string[]);
  }

  await audit(context, 'news.updated', id, { changeSummary });

  return json({ id, message: 'Saved.' }, { headers: NO_STORE_HEADERS });
}

/**
 * `POST /api/editorial/news/:id/state`
 *
 * Every movement through the workflow, in one place: submit, approve, request
 * changes, publish, schedule, archive, reject.
 *
 * One endpoint rather than seven because the rules about what may follow what
 * belong together — scattered across seven handlers they drift, and a story
 * ends up published from `rejected` because one of them forgot to check.
 */
export async function setNewsState(context: RequestContext): Promise<Response> {
  const actor = requireEditor(context);
  const repository = new NewsRepository(context.env.DB);

  const existing = await repository.find(context.params['id'] ?? '');
  if (!existing) throw new NotFoundError('That story was not found.');

  const id = String(existing['id']);
  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .oneOf('status', EDITORIAL_STATUSES, { required: true })
    .string('comment', { max: 2000, label: 'Comment' })
    .validated();

  const status = validated['status'] as string;
  const comment = (validated['comment'] as string | null) ?? null;
  const changes: Record<string, unknown> = { status, review_notes: comment };

  if (status === 'published' || status === 'scheduled') {
    // Publishing is its own permission. An editor may write and approve; making
    // something public under the community's name is a separate authority.
    if (!can(actor, 'news:publish')) {
      throw new ForbiddenError('You can prepare news, but publishing it is somebody else’s to do.');
    }
  }

  if (status === 'published') {
    changes['published_at'] = nowIso();
    changes['published_by'] = actor.id;
    changes['scheduled_publish_at'] = null;
  }

  if (status === 'scheduled') {
    const when = typeof body['scheduled_publish_at'] === 'string'
      ? body['scheduled_publish_at']
      : null;

    const at = when ? Date.parse(when) : Number.NaN;
    if (Number.isNaN(at)) {
      throw new BadRequestError('Say when it should be published.');
    }
    if (at <= Date.now()) {
      throw new BadRequestError(
        'That moment has already passed. Choose a future time, or publish it now.',
      );
    }

    changes['scheduled_publish_at'] = new Date(at).toISOString();
    // The publication time is set now so the story goes out stamped with the
    // moment it was meant for, not the moment the cron happened to run.
    changes['published_at'] = new Date(at).toISOString();
  }

  if (status === 'archived') {
    changes['archived_at'] = nowIso();
    // Out of the announcement bar and off the front. An archived story stays
    // readable at its own address, which is the point of an archive.
    changes['is_featured'] = 0;
    changes['is_important'] = 0;
  }

  await repository.update(id, changes);

  await repository.recordReview({
    newsId: id,
    submissionId: null,
    decision: reviewDecisionFor(status),
    comment,
    reviewerId: actor.id,
    reviewerName: actor.displayName,
  });

  // The person who sent it in is told what happened to it, whatever happened.
  // Silence after a submission is what stops people sending a second one.
  const contributor = existing['submitted_by'];
  if (typeof contributor === 'string' && contributor.length > 0 && contributor !== actor.id) {
    await new NotificationRepository(context.env.DB).notify({
      userId: contributor,
      kind: 'contribution',
      title: notificationTitleFor(status, String(existing['title'])),
      body: comment ?? notificationBodyFor(status),
      linkPath: status === 'published' ? `/news/${existing['slug']}` : '/account',
      resourceType: 'news',
      resourceId: id,
    });
  }

  await audit(context, `news.${status}`, id, { comment });

  return json({ id, status, message: 'Saved.' }, { headers: NO_STORE_HEADERS });
}

/** `POST /api/editorial/news/:id/flags` — featured, important, and the expiry. */
export async function setNewsFlags(context: RequestContext): Promise<Response> {
  const actor = requireEditor(context);
  const repository = new NewsRepository(context.env.DB);

  const existing = await repository.find(context.params['id'] ?? '');
  if (!existing) throw new NotFoundError('That story was not found.');

  const body = await readJsonBody(context.request);
  const validator = new Validator(body);
  if ('is_featured' in body) validator.boolean('is_featured');
  if ('is_important' in body) validator.boolean('is_important');
  const validated = validator.validated();

  // Only something the public can actually read may be promoted. Featuring a
  // draft puts a headline on the homepage that leads to a 404.
  const wantsPromotion = validated['is_featured'] === 1 || validated['is_important'] === 1;
  if (wantsPromotion && existing['status'] !== 'published') {
    throw new BadRequestError(
      'Only a published story can be featured or marked important. Publish it first.',
    );
  }

  const changes: Record<string, unknown> = { ...validated };

  if ('important_expires_at' in body) {
    const raw = body['important_expires_at'];
    changes['important_expires_at'] = typeof raw === 'string' && raw.length > 0 ? raw : null;
  }

  await repository.update(String(existing['id']), changes);
  await audit(context, 'news.flags', String(existing['id']), changes);
  void actor;

  return json({ message: 'Saved.' }, { headers: NO_STORE_HEADERS });
}

// ---------------------------------------------------------------------------
// Media on a story
// ---------------------------------------------------------------------------

/**
 * `POST /api/editorial/news/:id/media`
 *
 * Attaches a photograph already in the media library, or a YouTube video.
 *
 * Files are not uploaded through this route. Everything that reaches R2 goes
 * through the media service, which checks the type and the size against a
 * per-folder allow-list — a second upload path would be a second place for
 * those checks to be forgotten.
 */
export async function addNewsMedia(context: RequestContext): Promise<Response> {
  const actor = requireEditor(context);
  const repository = new NewsRepository(context.env.DB);

  const existing = await repository.find(context.params['id'] ?? '');
  if (!existing) throw new NotFoundError('That story was not found.');

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .oneOf('media_type', ['image', 'youtube_video'], { required: true })
    .string('media_id', { max: 64 })
    .string('youtube_url', { max: 500, label: 'YouTube link' })
    .string('caption', { max: 500, label: 'Caption' })
    .string('alt_text', { max: 300, label: 'Description for a screen reader' })
    .string('photographer', { max: 200, label: 'Photographer' })
    .string('copyright', { max: 200 })
    .string('video_title', { max: 300, label: 'Title' })
    .string('video_description', { max: 2000 })
    .string('taken_at', { max: 40 })
    .validated();

  const mediaType = validated['media_type'] as string;
  let youtubeId: string | null = null;

  if (mediaType === 'youtube_video') {
    const raw = (validated['youtube_url'] as string | null) ?? '';
    youtubeId = youtubeIdFrom(raw);
    if (!youtubeId) {
      throw new BadRequestError(
        'That does not look like a YouTube link. Paste the address from the browser, or the '
          + 'share link.',
      );
    }
  } else if (!validated['media_id']) {
    throw new BadRequestError('Choose a photograph from the media library.');
  }

  const id = await repository.addMedia({
    newsId: String(existing['id']),
    mediaType,
    mediaId: mediaType === 'image' ? ((validated['media_id'] as string | null) ?? null) : null,
    youtubeId,
    youtubeUrl: mediaType === 'youtube_video'
      ? ((validated['youtube_url'] as string | null) ?? null)
      : null,
    videoTitle: (validated['video_title'] as string | null) ?? null,
    videoDescription: (validated['video_description'] as string | null) ?? null,
    caption: (validated['caption'] as string | null) ?? null,
    altText: (validated['alt_text'] as string | null) ?? null,
    photographer: (validated['photographer'] as string | null) ?? null,
    contributorId: actor.id,
    copyright: (validated['copyright'] as string | null) ?? null,
    takenAt: (validated['taken_at'] as string | null) ?? null,
  });

  await audit(context, 'news.media.added', String(existing['id']), { mediaType });

  return json({ id, message: 'Added.' }, { status: 201, headers: NO_STORE_HEADERS });
}

/** `PATCH /api/editorial/news/:id/media/:mediaId` — caption, credit, alt text. */
export async function updateNewsMedia(context: RequestContext): Promise<Response> {
  requireEditor(context);
  const repository = new NewsRepository(context.env.DB);

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('caption', { max: 500, label: 'Caption' })
    .string('alt_text', { max: 300 })
    .string('photographer', { max: 200 })
    .string('copyright', { max: 200 })
    .string('taken_at', { max: 40 })
    .string('video_title', { max: 300 })
    .string('video_description', { max: 2000 })
    .validated();

  const changed = await repository.updateMedia(
    context.params['mediaId'] ?? '',
    context.params['id'] ?? '',
    validated,
  );
  if (changed === 0) throw new NotFoundError('That photograph was not found on this story.');

  return json({ message: 'Saved.' }, { headers: NO_STORE_HEADERS });
}

/** `DELETE /api/editorial/news/:id/media/:mediaId` */
export async function removeNewsMedia(context: RequestContext): Promise<Response> {
  requireEditor(context);
  const repository = new NewsRepository(context.env.DB);

  const changed = await repository.removeMedia(
    context.params['mediaId'] ?? '',
    context.params['id'] ?? '',
  );
  if (changed === 0) throw new NotFoundError('That photograph was not found on this story.');

  await audit(context, 'news.media.removed', context.params['id'] ?? '', {});

  return json({ message: 'Removed from this story.' }, { headers: NO_STORE_HEADERS });
}

/** `POST /api/editorial/news/:id/media/order` */
export async function reorderNewsMedia(context: RequestContext): Promise<Response> {
  requireEditor(context);
  const repository = new NewsRepository(context.env.DB);

  const body = await readJsonBody(context.request);
  const order = body['order'];
  if (!Array.isArray(order)) throw new BadRequestError('Send the new order.');

  await repository.reorderMedia(
    context.params['id'] ?? '',
    order.filter((id): id is string => typeof id === 'string').slice(0, 200),
  );

  return json({ message: 'Reordered.' }, { headers: NO_STORE_HEADERS });
}

// ---------------------------------------------------------------------------
// Sources and categories
// ---------------------------------------------------------------------------

/** `POST /api/editorial/news/:id/sources` */
export async function addNewsSource(context: RequestContext): Promise<Response> {
  requireEditor(context);
  const repository = new NewsRepository(context.env.DB);

  const existing = await repository.find(context.params['id'] ?? '');
  if (!existing) throw new NotFoundError('That story was not found.');

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .oneOf('source_type', SOURCE_TYPES, { required: true })
    .string('title', { max: 300, label: 'Source' })
    .string('author', { max: 200 })
    .string('publisher', { max: 200 })
    .string('url', { max: 1000 })
    .string('published_on', { max: 40 })
    .string('notes', { max: 1000 })
    .validated();

  const id = await repository.addSource({
    newsId: String(existing['id']),
    sourceType: validated['source_type'] as string,
    title: (validated['title'] as string | null) ?? null,
    author: (validated['author'] as string | null) ?? null,
    publisher: (validated['publisher'] as string | null) ?? null,
    url: (validated['url'] as string | null) ?? null,
    publishedOn: (validated['published_on'] as string | null) ?? null,
    notes: (validated['notes'] as string | null) ?? null,
  });

  return json({ id, message: 'Added.' }, { status: 201, headers: NO_STORE_HEADERS });
}

/** `DELETE /api/editorial/news/:id/sources/:sourceId` */
export async function removeNewsSource(context: RequestContext): Promise<Response> {
  requireEditor(context);
  const repository = new NewsRepository(context.env.DB);

  const changed = await repository.removeSource(
    context.params['sourceId'] ?? '',
    context.params['id'] ?? '',
  );
  if (changed === 0) throw new NotFoundError('That source was not found on this story.');

  return json({ message: 'Removed.' }, { headers: NO_STORE_HEADERS });
}

/** `POST /api/editorial/news-categories` — create or edit, without a deployment. */
export async function upsertCategory(context: RequestContext): Promise<Response> {
  const actor = requireEditor(context);
  const repository = new NewsRepository(context.env.DB);

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('id', { max: 64 })
    .string('name', { required: true, min: 2, max: 80, label: 'Name' })
    .string('description', { max: 300 })
    .string('accent', { max: 20 })
    .integer('sort_order', { min: 0, max: 9999 })
    .boolean('is_active')
    .validated();

  const name = validated['name'] as string;
  const slug = slugify(name).slice(0, 60) || 'category';

  const id = await repository.upsertCategory({
    id: (validated['id'] as string | null) ?? null,
    slug,
    name,
    description: (validated['description'] as string | null) ?? null,
    accent: (validated['accent'] as string | null) ?? null,
    sortOrder: (validated['sort_order'] as number | null) ?? 500,
    isActive: validated['is_active'] !== 0 && validated['is_active'] !== false,
  });

  await audit(context, 'news.category.saved', id, { name });
  void actor;

  return json({ id, message: 'Saved.' }, { headers: NO_STORE_HEADERS });
}

// ---------------------------------------------------------------------------
// Scheduled publication
// ---------------------------------------------------------------------------

/**
 * Publishes everything whose moment has arrived.
 *
 * Called by the Worker's scheduled handler. Exported so it can also be run by
 * hand from an administrative route if a cron is ever missed — a story that
 * should have gone out at eight and did not is a real problem, and "wait for
 * the next cron" is not an answer anybody wants to give.
 */
export async function publishDueNews(env: { DB: D1Database }): Promise<{ published: number }> {
  const repository = new NewsRepository(env.DB);
  const due = await repository.dueForPublication(nowIso(), 50);

  for (const row of due) {
    await repository.update(String(row['id']), {
      status: 'published',
      scheduled_publish_at: null,
    });

    await repository.recordReview({
      newsId: String(row['id']),
      submissionId: null,
      decision: 'published',
      comment: 'Published automatically at the scheduled time.',
      reviewerId: null,
      reviewerName: 'Scheduled publication',
    });
  }

  return { published: due.length };
}

/** `POST /api/editorial/news/publish-due` — run the scheduler by hand. */
export async function runScheduledPublication(context: RequestContext): Promise<Response> {
  requireEditor(context);
  const result = await publishDueNews(context.env);
  return json(
    {
      ...result,
      message: result.published === 0
        ? 'Nothing was waiting.'
        : `Published ${result.published} ${result.published === 1 ? 'story' : 'stories'}.`,
    },
    { headers: NO_STORE_HEADERS },
  );
}

// ---------------------------------------------------------------------------

function requireEditor(context: RequestContext) {
  if (!context.user) throw new UnauthorizedError('Please sign in to continue.');
  if (!can(context.user, 'news:update')) {
    throw new ForbiddenError('You do not edit the news.');
  }
  return context.user;
}

/** Everything a story's fields are read and validated from, in one place. */
async function readStoryValues(
  context: RequestContext,
  repository: NewsRepository,
): Promise<Record<string, unknown>> {
  const body = await readJsonBody(context.request);

  const validated = new Validator(body)
    .string('title', { max: 300, label: 'Headline' })
    .string('excerpt', { max: 1000, label: 'Summary' })
    .string('category_id', { max: 64 })
    .string('author_name', { max: 200, label: 'Author' })
    .string('news_date', { max: 40 })
    .string('location', { max: 200, label: 'Where' })
    .string('source', { max: 300 })
    .string('source_url', { max: 1000 })
    .string('cover_media_id', { max: 64 })
    .string('seo_title', { max: 200 })
    .string('seo_description', { max: 400 })
    .validated();

  const values: Record<string, unknown> = { ...validated };

  if ('body' in body) {
    const blocks = validateNewsBody(body['body']);
    values['body'] = JSON.stringify(blocks);

    // The summary writes itself from the story when nobody supplied one, so a
    // list of headlines never shows an empty line under one of them.
    if (!values['excerpt']) {
      values['excerpt'] = plainText(blocks).slice(0, 280);
    }
  }

  if (validated['category_id']) {
    const category = await repository.findCategory(validated['category_id'] as string);
    if (!category) throw new BadRequestError('That category does not exist.');
    values['category_id'] = category['id'];
  }

  if (Array.isArray(body['tags'])) {
    values['__tags'] = body['tags'].filter((tag): tag is string => typeof tag === 'string');
  }

  return values;
}

async function uniqueSlug(repository: NewsRepository, title: string): Promise<string> {
  const root = slugify(title).slice(0, 80) || 'story';
  if (!(await repository.slugExists(root))) return root;

  for (let suffix = 2; suffix < 60; suffix += 1) {
    const candidate = `${root}-${suffix}`;
    if (!(await repository.slugExists(candidate))) return candidate;
  }
  return `${root}-${Date.now()}`;
}

function parseBody(value: unknown): unknown[] {
  if (typeof value !== 'string' || value.trim().length === 0) return [];
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    // Written before the block editor existed: plain text, shown as paragraphs
    // rather than lost.
    return validateNewsBody(value) as unknown[];
  }
}

function shapeSummary(
  context: RequestContext,
  row: Record<string, unknown>,
): Record<string, unknown> {
  return {
    id: row['id'],
    slug: row['slug'],
    title: row['title'],
    excerpt: row['excerpt'],
    news_date: row['news_date'],
    location: row['location'],
    published_at: row['published_at'],
    is_featured: row['is_featured'] === 1,
    is_important: row['is_important'] === 1,
    author_name: row['author_name'],
    contributor_name: row['contributor_name'],
    category_slug: row['category_slug'],
    category_name: row['category_name'],
    category_accent: row['category_accent'],
    cover_url: mediaUrl(context, row['cover_key']),
    cover_alt: row['cover_alt'],
    photo_count: Number(row['photo_count'] ?? 0),
    video_count: Number(row['video_count'] ?? 0),
    first_video_thumbnail: typeof row['first_video_id'] === 'string'
      ? youtubeThumbnailUrl(row['first_video_id'])
      : null,
  };
}

function shapeMedia(
  context: RequestContext,
  row: Record<string, unknown>,
): Record<string, unknown> {
  const isVideo = row['media_type'] === 'youtube_video';
  const youtubeId = row['youtube_id'];

  return {
    id: row['id'],
    media_type: row['media_type'],
    url: isVideo ? null : mediaUrl(context, row['storage_key']),
    mime_type: row['mime_type'],
    youtube_id: youtubeId,
    embed_url: typeof youtubeId === 'string' ? youtubeEmbedUrl(youtubeId) : null,
    thumbnail_url: typeof youtubeId === 'string' ? youtubeThumbnailUrl(youtubeId) : null,
    video_title: row['video_title'],
    video_description: row['video_description'],
    caption: row['caption'],
    alt_text: row['alt_text'],
    photographer: row['photographer'],
    copyright: row['copyright'],
    taken_at: row['taken_at'],
    display_order: row['display_order'],
  };
}

function mediaUrl(context: RequestContext, key: unknown): string | null {
  return typeof key === 'string' && key.length > 0
    ? publicMediaUrl(context.env.PUBLIC_MEDIA_BASE_URL, key)
    : null;
}

function reviewDecisionFor(status: string): string {
  switch (status) {
    case 'approved':
      return 'approved';
    case 'rejected':
      return 'rejected';
    case 'changes_requested':
      return 'changes_requested';
    case 'published':
      return 'published';
    case 'scheduled':
      return 'scheduled';
    case 'archived':
      return 'archived';
    default:
      return 'changes_requested';
  }
}

function notificationTitleFor(status: string, title: string): string {
  switch (status) {
    case 'published':
      return `Your news has been published: ${title}`;
    case 'changes_requested':
      return `The Editorial Team has a question about "${title}"`;
    case 'rejected':
      return `"${title}" will not be published`;
    case 'approved':
    case 'scheduled':
      return `"${title}" has been approved`;
    default:
      return `An update on "${title}"`;
  }
}

function notificationBodyFor(status: string): string {
  switch (status) {
    case 'published':
      return 'Thank you. It is part of the archive now, with your name on it.';
    case 'changes_requested':
      return 'They would like a little more before publishing it.';
    case 'rejected':
      return 'Please write to the Preservation Team if you would like to know more.';
    case 'scheduled':
      return 'It will go out at the time the Editorial Team set.';
    default:
      return 'The Editorial Team has looked at what you sent.';
  }
}

async function audit(
  context: RequestContext,
  action: string,
  resourceId: string,
  changes: Record<string, unknown>,
): Promise<void> {
  await new AuditRepository(context.env.DB).record({
    actorId: context.user?.id ?? null,
    actorEmail: context.user?.email ?? null,
    action,
    resourceType: 'news',
    resourceId,
    changes,
    requestId: context.requestId,
  });
}
