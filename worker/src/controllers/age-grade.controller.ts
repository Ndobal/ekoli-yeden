import type { RequestContext } from '../types/api';
import { AgeGradeService } from '../services/age-grade.service';
import { AgeGradeRepository } from '../repositories/age-grade.repository';
import { GalleryService } from '../services/gallery.service';
import { AuditRepository } from '../repositories/audit.repository';
import { CONTENT_STATUS, ALL_CONTENT_STATUSES } from '../types/models';
import { BadRequestError, NotFoundError, UnauthorizedError } from '../utils/errors';
import { readJsonBody, Validator } from '../utils/validation';
import { json, paginated, NO_STORE_HEADERS, publicCacheHeaders } from '../utils/responses';
import { parsePagination } from '../utils/pagination';

/**
 * AGE GRADES
 *
 * The public half of this file renders a grade's page. The rest is the grade's
 * own workspace, gated by one narrow check — "do you administer this grade?" —
 * that grants nothing anywhere else in the archive.
 *
 * Every write handler resolves the grade first and asks that question before
 * doing anything. The check is never inferred from a role and never assumed
 * from a previous request.
 */

const POST_TYPES = [
  'update',
  'announcement',
  'meeting',
  'project',
  'obituary',
  'report',
  'history',
] as const;

/** Statuses a grade's own administrators may see in their workspace. */
const WORKSPACE_STATUSES = [...ALL_CONTENT_STATUSES];

// ---------------------------------------------------------------------------
// Public
// ---------------------------------------------------------------------------

/**
 * `GET /api/age-grades/:identifier`
 *
 * The grade with everything that hangs off it: its posts, its roster, the
 * names of its administrators and its photographs. One request renders the
 * whole page.
 *
 * Registered ahead of the generated content route, which would return the
 * grade's own columns and none of the people or news that make it a grade.
 */
export async function showAgeGrade(context: RequestContext): Promise<Response> {
  const service = new AgeGradeService(context.env);
  const grade = await service.publicGrade(context.params['identifier'] ?? '');

  const repository = service.repo;
  const [posts, members, admins, gallery] = await Promise.all([
    repository.posts(grade.id, [CONTENT_STATUS.PUBLISHED], { limit: 20, offset: 0 }),
    repository.members(grade.id, [CONTENT_STATUS.PUBLISHED]),
    repository.admins(grade.id),
    loadGallery(context, grade.gallery_id),
  ]);

  return json(
    {
      ...grade,
      posts: posts.items,
      posts_total: posts.total,
      members,
      // Names and offices only. An administrator's email address is how the
      // grade reaches them, not something the public page needs.
      administrators: admins.map((admin) => ({
        display_name: admin.display_name,
        admin_role: admin.admin_role,
        office: admin.office,
      })),
      gallery,
    },
    { headers: publicCacheHeaders() },
  );
}

/** `GET /api/age-grades/:identifier/posts` — the grade's news, paginated. */
export async function listAgeGradePosts(context: RequestContext): Promise<Response> {
  const { page, perPage, offset } = parsePagination(context.query);
  const service = new AgeGradeService(context.env);
  const grade = await service.publicGrade(context.params['identifier'] ?? '');

  const { items, total } = await service.repo.posts(grade.id, [CONTENT_STATUS.PUBLISHED], {
    limit: perPage,
    offset,
  });

  return paginated(items, page, perPage, total, publicCacheHeaders());
}

/** `GET /api/age-grades/:identifier/posts/:postSlug` — one post. */
export async function showAgeGradePost(context: RequestContext): Promise<Response> {
  const service = new AgeGradeService(context.env);
  const grade = await service.publicGrade(context.params['identifier'] ?? '');

  const post = await service.repo.findPostBySlug(grade.id, context.params['postSlug'] ?? '');
  if (!post || post.status !== CONTENT_STATUS.PUBLISHED) {
    throw new NotFoundError('That post was not found.');
  }

  return json(
    {
      ...post,
      age_grade: { id: grade.id, slug: grade.slug, title: grade.title },
    },
    { headers: publicCacheHeaders() },
  );
}

/**
 * `GET /api/age-grades-activity`
 *
 * The most recent posts across every published grade — what the section index
 * shows so that the page is a living thing rather than a list of names.
 */
export async function ageGradeActivity(context: RequestContext): Promise<Response> {
  const repository = new AgeGradeRepository(context.env.DB);
  const posts = await repository.recentPosts(12);
  return json({ items: posts, total: posts.length }, { headers: publicCacheHeaders() });
}

// ---------------------------------------------------------------------------
// Registering and running a grade
// ---------------------------------------------------------------------------

/**
 * `POST /api/age-grades`
 *
 * Registers a grade. Any signed-in member of the community may do this; the
 * grade waits for the Preservation Team before it appears publicly, and the
 * person who registered it becomes its lead administrator.
 */
export async function registerAgeGrade(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const body = await readJsonBody(context.request);

  const validated = new Validator(body)
    .string('title', { required: true, min: 2, max: 200, label: 'The name of the age grade' })
    .string('subtitle', { max: 200, label: 'Also known as' })
    .string('birth_years', { max: 100, label: 'Birth years' })
    .string('excerpt', { max: 500, label: 'Short description' })
    .string('body', { max: 20_000, label: 'About the grade' })
    .string('motto', { max: 300, label: 'Motto' })
    .string('contact_name', { max: 150, label: 'Contact name' })
    .string('contact_phone', { max: 40, label: 'Contact phone' })
    .string('office', { max: 100, label: 'Your office in the grade' })
    .validated();

  if ('contact_email' in body && body['contact_email']) {
    Object.assign(validated, new Validator(body).email('contact_email').validated());
  }
  if ('formed_year' in body && body['formed_year'] !== null && body['formed_year'] !== '') {
    Object.assign(
      validated,
      new Validator(body)
        .integer('formed_year', { min: 1800, max: 2200, label: 'The year it was formed' })
        .validated(),
    );
  }

  const service = new AgeGradeService(context.env);
  const result = await service.register(
    {
      title: validated['title'] as string,
      subtitle: (validated['subtitle'] as string | null) ?? null,
      formedYear: (validated['formed_year'] as number | undefined) ?? null,
      birthYears: (validated['birth_years'] as string | null) ?? null,
      excerpt: (validated['excerpt'] as string | null) ?? null,
      body: (validated['body'] as string | null) ?? null,
      motto: (validated['motto'] as string | null) ?? null,
      contactName: (validated['contact_name'] as string | null) ?? null,
      contactPhone: (validated['contact_phone'] as string | null) ?? null,
      contactEmail: (validated['contact_email'] as string | null) ?? null,
      office: (validated['office'] as string | null) ?? null,
    },
    actor,
    { requestId: context.requestId },
  );

  return json(
    {
      ...result,
      message:
        'Your age grade has been registered and is waiting for the Ekoli-Yeden Preservation Team '
        + 'to confirm it. You are its lead administrator: you can add its members, its photographs '
        + 'and its news now, and everything will appear as soon as the grade is confirmed.',
    },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

/**
 * `GET /api/my/age-grades`
 *
 * The grades this person administers. The entry point to their workspace, and
 * the answer to "am I allowed to edit anything here?".
 */
export async function myAgeGrades(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const repository = new AgeGradeRepository(context.env.DB);
  const grades = await repository.gradesAdministeredBy(actor.id);

  return json({ items: grades, total: grades.length }, { headers: NO_STORE_HEADERS });
}

/**
 * `GET /api/age-grades/:identifier/manage`
 *
 * Everything about a grade, drafts included, for somebody who administers it.
 */
export async function manageAgeGrade(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const service = new AgeGradeService(context.env);
  const grade = await service.manageableGrade(context.params['identifier'] ?? '');
  await service.assertCanAdminister(actor, grade.id);

  const rights = await service.administrationOf(actor, grade.id);
  const [posts, members, admins] = await Promise.all([
    service.repo.posts(grade.id, WORKSPACE_STATUSES, { limit: 100, offset: 0 }),
    service.repo.members(grade.id, WORKSPACE_STATUSES),
    service.repo.admins(grade.id),
  ]);

  return json(
    {
      grade,
      posts: posts.items,
      members,
      administrators: admins,
      // What this person may actually do, so the workspace draws the right
      // buttons. The server decides again on every write regardless.
      permissions: { canEdit: rights.isAdmin, canAppointAdmins: rights.isLead },
    },
    { headers: NO_STORE_HEADERS },
  );
}

/**
 * `PATCH /api/age-grades/:identifier`
 *
 * The grade editing its own description.
 *
 * `status` and `verification_status` are absent by design — see
 * `AgeGradeRepository.updateOwnFields`. A grade writes its own page; whether
 * the archive vouches for it is not the grade's decision to make.
 */
export async function updateAgeGrade(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const service = new AgeGradeService(context.env);
  const grade = await service.manageableGrade(context.params['identifier'] ?? '');
  await service.assertCanAdminister(actor, grade.id);

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('title', { min: 2, max: 200, label: 'The name of the age grade' })
    .string('subtitle', { max: 200, label: 'Also known as' })
    .string('birth_years', { max: 100, label: 'Birth years' })
    .string('excerpt', { max: 500, label: 'Short description' })
    .string('body', { max: 20_000, label: 'About the grade' })
    .string('motto', { max: 300, label: 'Motto' })
    .string('contact_name', { max: 150, label: 'Contact name' })
    .string('contact_phone', { max: 40, label: 'Contact phone' })
    .string('cover_media_id', { max: 64 })
    .validated();

  if ('contact_email' in body && body['contact_email']) {
    Object.assign(validated, new Validator(body).email('contact_email').validated());
  }
  if ('formed_year' in body && body['formed_year'] !== null && body['formed_year'] !== '') {
    Object.assign(
      validated,
      new Validator(body)
        .integer('formed_year', { min: 1800, max: 2200, label: 'The year it was formed' })
        .validated(),
    );
  }

  const changed = await service.repo.updateOwnFields(grade.id, validated);
  if (changed === 0) throw new BadRequestError('Nothing was changed.');

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: 'age_grade.updated',
    resourceType: 'age_grade',
    resourceId: grade.id,
    changes: { fields: Object.keys(validated) },
    requestId: context.requestId,
  });

  return json(await service.manageableGrade(grade.id), { headers: NO_STORE_HEADERS });
}

// ---------------------------------------------------------------------------
// Posts
// ---------------------------------------------------------------------------

/**
 * `POST /api/age-grades/:identifier/posts`
 *
 * The grade's own news. Published immediately unless the community has turned
 * review on, and always labelled on the page as the grade speaking for itself
 * rather than as verified community history.
 */
export async function createAgeGradePost(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const service = new AgeGradeService(context.env);
  const grade = await service.manageableGrade(context.params['identifier'] ?? '');
  await service.assertCanAdminister(actor, grade.id);

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('title', { required: true, min: 3, max: 250, label: 'Title' })
    .string('excerpt', { max: 500, label: 'Summary' })
    .string('body', { max: 40_000, label: 'The post' })
    .oneOf('post_type', POST_TYPES)
    .string('cover_media_id', { max: 64 })
    .validated();

  if ('event_date' in body && body['event_date']) {
    Object.assign(validated, new Validator(body).date('event_date', { label: 'Date' }).validated());
  }

  const title = validated['title'] as string;
  const status = await service.statusForNewPost();

  const id = await service.repo.createPost({
    ageGradeId: grade.id,
    slug: await service.uniquePostSlug(grade.id, title),
    title,
    excerpt: (validated['excerpt'] as string | null) ?? null,
    body: (validated['body'] as string | null) ?? null,
    postType: (validated['post_type'] as string | undefined) ?? 'update',
    eventDate: (validated['event_date'] as string | null) ?? null,
    coverMediaId: (validated['cover_media_id'] as string | null) ?? null,
    authorId: actor.id,
    // Published under the grade's name, not the archive's. The page says who
    // is speaking, which is what keeps a grade's own account of itself from
    // being mistaken for something the Preservation Team has checked.
    authorName: grade.title,
    status,
  });

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: 'age_grade.post.created',
    resourceType: 'age_grade_post',
    resourceId: id,
    changes: { ageGradeId: grade.id, title, status },
    requestId: context.requestId,
  });

  const post = await service.repo.findPost(id);
  return json(
    {
      ...post,
      message:
        status === CONTENT_STATUS.PUBLISHED
          ? grade.status === CONTENT_STATUS.PUBLISHED
            ? 'Posted. It is on your age grade page now.'
            : 'Posted. It will appear as soon as the Preservation Team confirms your age grade.'
          : 'Sent for review. It will appear once a moderator has read it.',
    },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

/** `PATCH /api/age-grades/:identifier/posts/:postId` */
export async function updateAgeGradePost(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const service = new AgeGradeService(context.env);
  const grade = await service.manageableGrade(context.params['identifier'] ?? '');
  await service.assertCanAdminister(actor, grade.id);

  const post = await service.repo.findPost(context.params['postId'] ?? '');
  // Checked against this grade, not merely that the post exists: an
  // administrator of one grade must not be able to edit another's post by
  // quoting its id.
  if (!post || post.age_grade_id !== grade.id) {
    throw new NotFoundError('That post was not found in this age grade.');
  }

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('title', { min: 3, max: 250, label: 'Title' })
    .string('excerpt', { max: 500, label: 'Summary' })
    .string('body', { max: 40_000, label: 'The post' })
    .oneOf('post_type', POST_TYPES)
    .string('cover_media_id', { max: 64 })
    .validated();

  if ('event_date' in body && body['event_date']) {
    Object.assign(validated, new Validator(body).date('event_date', { label: 'Date' }).validated());
  }

  // A grade may take its own post down or put it back up. It may not move it
  // to `approved`, which is a statement by the archive rather than the grade.
  if ('status' in body) {
    const requested = String(body['status']);
    if (requested !== CONTENT_STATUS.PUBLISHED && requested !== CONTENT_STATUS.ARCHIVED) {
      throw new BadRequestError('A post can be published or taken down, and nothing else.');
    }
    validated['status'] = requested;
    if (requested === CONTENT_STATUS.PUBLISHED && post.published_at === null) {
      validated['published_at'] = new Date().toISOString();
    }
  }

  const changed = await service.repo.updatePost(post.id, validated);
  if (changed === 0) throw new BadRequestError('Nothing was changed.');

  return json(await service.repo.findPost(post.id), { headers: NO_STORE_HEADERS });
}

/** `DELETE /api/age-grades/:identifier/posts/:postId` */
export async function deleteAgeGradePost(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const service = new AgeGradeService(context.env);
  const grade = await service.manageableGrade(context.params['identifier'] ?? '');
  await service.assertCanAdminister(actor, grade.id);

  const post = await service.repo.findPost(context.params['postId'] ?? '');
  if (!post || post.age_grade_id !== grade.id) {
    throw new NotFoundError('That post was not found in this age grade.');
  }

  await service.repo.deletePost(post.id);

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: 'age_grade.post.deleted',
    resourceType: 'age_grade_post',
    resourceId: post.id,
    changes: { ageGradeId: grade.id, title: post.title },
    requestId: context.requestId,
  });

  return json({ id: post.id, deleted: true }, { headers: NO_STORE_HEADERS });
}

// ---------------------------------------------------------------------------
// Administrators
// ---------------------------------------------------------------------------

/** `POST /api/age-grades/:identifier/admins` — lead only. */
export async function appointAgeGradeAdmin(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const service = new AgeGradeService(context.env);
  const grade = await service.manageableGrade(context.params['identifier'] ?? '');

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .email('email', { required: true })
    .oneOf('admin_role', ['lead', 'admin'] as const)
    .string('office', { max: 100, label: 'Office' })
    .validated();

  const result = await service.appointAdmin(
    grade.id,
    validated['email'] as string,
    {
      adminRole: ((validated['admin_role'] as string | undefined) ?? 'admin') as 'lead' | 'admin',
      office: (validated['office'] as string | null) ?? null,
    },
    actor,
    { requestId: context.requestId },
  );

  return json(
    {
      ...result,
      message: `${result.displayName} can now help run this age grade's page.`,
    },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

/** `DELETE /api/age-grades/:identifier/admins/:userId` — lead only. */
export async function removeAgeGradeAdmin(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const service = new AgeGradeService(context.env);
  const grade = await service.manageableGrade(context.params['identifier'] ?? '');

  await service.removeAdmin(grade.id, context.params['userId'] ?? '', actor, {
    requestId: context.requestId,
  });

  return json({ removed: true }, { headers: NO_STORE_HEADERS });
}

// ---------------------------------------------------------------------------
// Members
// ---------------------------------------------------------------------------

/**
 * `POST /api/age-grades/:identifier/members`
 *
 * The roster. A living person's name on a public page is personal data, so a
 * new member waits for confirmation by default — the one setting that is on
 * rather than off.
 */
export async function addAgeGradeMember(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const service = new AgeGradeService(context.env);
  const grade = await service.manageableGrade(context.params['identifier'] ?? '');
  await service.assertCanAdminister(actor, grade.id);

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('full_name', { required: true, min: 2, max: 200, label: 'Name' })
    .string('office', { max: 100, label: 'Office' })
    .string('notes', { max: 1000, label: 'Notes' })
    .boolean('is_deceased')
    .validated();

  for (const field of ['joined_year', 'deceased_year']) {
    if (field in body && body[field] !== null && body[field] !== '') {
      Object.assign(
        validated,
        new Validator(body).integer(field, { min: 1800, max: 2200, label: 'Year' }).validated(),
      );
    }
  }

  const id = await service.repo.addMember({
    ageGradeId: grade.id,
    fullName: validated['full_name'] as string,
    office: (validated['office'] as string | null) ?? null,
    joinedYear: (validated['joined_year'] as number | undefined) ?? null,
    notes: (validated['notes'] as string | null) ?? null,
    isDeceased: validated['is_deceased'] === 1,
    deceasedYear: (validated['deceased_year'] as number | undefined) ?? null,
    status: await service.statusForNewMember(),
    addedBy: actor.id,
  });

  return json(await service.repo.findMember(id), { status: 201, headers: NO_STORE_HEADERS });
}

/** `PATCH /api/age-grades/:identifier/members/:memberId` */
export async function updateAgeGradeMember(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const service = new AgeGradeService(context.env);
  const grade = await service.manageableGrade(context.params['identifier'] ?? '');
  await service.assertCanAdminister(actor, grade.id);

  const member = await service.repo.findMember(context.params['memberId'] ?? '');
  if (!member || member.age_grade_id !== grade.id) {
    throw new NotFoundError('That member was not found in this age grade.');
  }

  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('full_name', { min: 2, max: 200, label: 'Name' })
    .string('office', { max: 100, label: 'Office' })
    .string('notes', { max: 1000, label: 'Notes' })
    .boolean('is_deceased')
    .validated();

  for (const field of ['joined_year', 'deceased_year', 'sort_order']) {
    if (field in body && body[field] !== null && body[field] !== '') {
      Object.assign(
        validated,
        new Validator(body).integer(field, { min: 0, max: 2200 }).validated(),
      );
    }
  }

  const changed = await service.repo.updateMember(member.id, validated);
  if (changed === 0) throw new BadRequestError('Nothing was changed.');

  return json(await service.repo.findMember(member.id), { headers: NO_STORE_HEADERS });
}

/** `DELETE /api/age-grades/:identifier/members/:memberId` */
export async function removeAgeGradeMember(context: RequestContext): Promise<Response> {
  const actor = requireActor(context);
  const service = new AgeGradeService(context.env);
  const grade = await service.manageableGrade(context.params['identifier'] ?? '');
  await service.assertCanAdminister(actor, grade.id);

  const member = await service.repo.findMember(context.params['memberId'] ?? '');
  if (!member || member.age_grade_id !== grade.id) {
    throw new NotFoundError('That member was not found in this age grade.');
  }

  await service.repo.deleteMember(member.id);
  return json({ id: member.id, removed: true }, { headers: NO_STORE_HEADERS });
}

// ---------------------------------------------------------------------------

function requireActor(context: RequestContext) {
  if (!context.user) throw new UnauthorizedError('Please sign in to continue.');
  return context.user;
}

/** A grade's photographs, where it has an album. */
async function loadGallery(
  context: RequestContext,
  galleryId: string | null,
): Promise<Record<string, unknown>[]> {
  if (!galleryId) return [];

  const service = new GalleryService(context.env);
  const items = await service.repo.itemsForGallery(galleryId, [CONTENT_STATUS.PUBLISHED]);
  return items.map((item) => service.decorateItem(item));
}
