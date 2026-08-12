import { ROLES, type RoleSlug } from '../types/auth';

/**
 * THE CONTENT REGISTRY
 *
 * This is what makes the platform CMS-driven rather than code-driven. Each
 * entry describes one content type completely: its table, its public URL, the
 * columns an editor may write, the columns a visitor may search, and who is
 * allowed to touch it.
 *
 * Routes, permissions, validation and search are all generated from this file.
 * When the Preservation Team supplies Ekoli-Yeden history, nobody edits Dart or
 * TypeScript — they sign in and add a record.
 */

export interface ContentResource {
  /** URL segment, e.g. `history` -> `/api/history` and `/api/admin/history`. */
  key: string;
  table: string;
  /** Human label used in audit logs and admin screens. */
  label: string;
  /** Column used to look a record up by a friendly URL. */
  slugColumn: string | null;
  /** Columns an editor may set. Anything else is ignored on write. */
  writableColumns: string[];
  /** Columns exposed to anonymous visitors. `null` means "every column". */
  publicColumns: string[] | null;
  /** Columns included in `LIKE` search. */
  searchableColumns: string[];
  /** Columns permitted in `?sort=`. */
  sortableColumns: string[];
  /** Default ordering for list endpoints. */
  defaultSort: string;
  defaultOrder: 'ASC' | 'DESC';
  /** Roles that may create/update/delete. Super Admin is always implied. */
  managedBy: RoleSlug[];
  /** Whether the table carries a `verification_status` column. */
  hasVerification: boolean;
  /** Whether the resource participates in global search. */
  searchable: boolean;
  /**
   * Column values every row of this resource must carry.
   *
   * Used by resources that share a table. `culture` and any future article type
   * both live in `content_items`, discriminated by `content_type`; these filters
   * are applied to every read and stamped onto every write, so one resource can
   * never see or overwrite another's rows.
   */
  fixedFilters?: Record<string, string>;
}

const CONTENT_ADMIN: RoleSlug[] = [ROLES.CONTENT_ADMINISTRATOR];
const HERITAGE: RoleSlug[] = [ROLES.CONTENT_ADMINISTRATOR, ROLES.HERITAGE_EDITOR];
const LANGUAGE: RoleSlug[] = [ROLES.CONTENT_ADMINISTRATOR, ROLES.LANGUAGE_EDITOR];
const MEDIA: RoleSlug[] = [ROLES.CONTENT_ADMINISTRATOR, ROLES.MEDIA_MANAGER];
const LEBOKU: RoleSlug[] = [ROLES.CONTENT_ADMINISTRATOR, ROLES.LEBOKU_MANAGER];

const AUDIT_COLUMNS = ['status', 'created_at', 'updated_at'];

export const CONTENT_RESOURCES: Record<string, ContentResource> = {
  pages: {
    key: 'pages',
    table: 'pages',
    label: 'Page',
    slugColumn: 'slug',
    writableColumns: [
      'slug', 'title', 'body', 'excerpt', 'template', 'cover_media_id',
      'seo_title', 'seo_description', 'seo_image_media_id', 'canonical_url', 'sort_order', 'status',
    ],
    publicColumns: null,
    searchableColumns: ['title', 'excerpt', 'body'],
    sortableColumns: ['title', 'sort_order', ...AUDIT_COLUMNS],
    defaultSort: 'sort_order',
    defaultOrder: 'ASC',
    managedBy: CONTENT_ADMIN,
    hasVerification: false,
    searchable: true,
  },

  history: {
    key: 'history',
    table: 'history_entries',
    label: 'History entry',
    slugColumn: 'slug',
    writableColumns: [
      'slug', 'title', 'summary', 'body', 'period_label', 'event_date', 'era',
      'category', 'location', 'source_reference', 'contributed_by', 'cover_media_id',
      'seo_title', 'seo_description', 'seo_image_media_id',
      'verification_status', 'sort_order', 'status',
    ],
    publicColumns: null,
    searchableColumns: ['title', 'summary', 'body', 'period_label', 'location'],
    sortableColumns: ['title', 'event_date', 'sort_order', ...AUDIT_COLUMNS],
    defaultSort: 'sort_order',
    defaultOrder: 'ASC',
    managedBy: HERITAGE,
    hasVerification: true,
    searchable: true,
  },

  leaders: {
    key: 'leaders',
    table: 'leaders',
    label: 'Leader',
    slugColumn: 'slug',
    writableColumns: [
      'slug', 'name', 'traditional_title', 'role_description', 'area_represented',
      'biography', 'contributions', 'reign_start', 'reign_end', 'is_current',
      'portrait_media_id', 'source_reference', 'sort_order',
      'seo_title', 'seo_description', 'verification_status', 'status',
    ],
    publicColumns: null,
    searchableColumns: ['name', 'traditional_title', 'area_represented', 'biography'],
    sortableColumns: ['name', 'sort_order', 'reign_start', ...AUDIT_COLUMNS],
    defaultSort: 'sort_order',
    defaultOrder: 'ASC',
    managedBy: HERITAGE,
    hasVerification: true,
    searchable: true,
  },

  people: {
    key: 'people',
    table: 'people',
    label: 'Person',
    slugColumn: 'slug',
    writableColumns: [
      'slug', 'name', 'headline', 'profession', 'category', 'biography',
      'achievements', 'city', 'country', 'website_url', 'photo_media_id',
      'is_hall_of_fame', 'consent_reference', 'sort_order',
      'seo_title', 'seo_description', 'verification_status', 'status',
    ],
    publicColumns: null,
    searchableColumns: ['name', 'headline', 'profession', 'biography', 'city', 'country'],
    sortableColumns: ['name', 'sort_order', ...AUDIT_COLUMNS],
    defaultSort: 'name',
    defaultOrder: 'ASC',
    managedBy: HERITAGE,
    hasVerification: true,
    searchable: true,
  },

  news: {
    key: 'news',
    table: 'news',
    label: 'News item',
    slugColumn: 'slug',
    writableColumns: [
      'slug', 'title', 'excerpt', 'body', 'category', 'author_name',
      'published_at', 'is_featured', 'cover_media_id',
      'seo_title', 'seo_description', 'seo_image_media_id', 'status',
    ],
    publicColumns: null,
    searchableColumns: ['title', 'excerpt', 'body', 'category'],
    sortableColumns: ['title', 'published_at', ...AUDIT_COLUMNS],
    defaultSort: 'published_at',
    defaultOrder: 'DESC',
    managedBy: CONTENT_ADMIN,
    hasVerification: false,
    searchable: true,
  },

  events: {
    key: 'events',
    table: 'events',
    label: 'Event',
    slugColumn: 'slug',
    writableColumns: [
      'slug', 'title', 'description', 'category', 'start_datetime', 'end_datetime',
      'location', 'venue', 'organiser', 'contact_info', 'festival_id',
      'is_featured', 'cover_media_id', 'seo_title', 'seo_description', 'status',
    ],
    publicColumns: null,
    searchableColumns: ['title', 'description', 'location', 'venue'],
    sortableColumns: ['title', 'start_datetime', ...AUDIT_COLUMNS],
    defaultSort: 'start_datetime',
    defaultOrder: 'DESC',
    managedBy: CONTENT_ADMIN,
    hasVerification: false,
    searchable: true,
  },

  festivals: {
    key: 'festivals',
    table: 'festivals',
    label: 'Festival',
    slugColumn: 'slug',
    writableColumns: [
      'slug', 'name', 'full_name', 'year', 'theme', 'tagline', 'description',
      'start_date', 'end_date', 'location', 'programme', 'sponsors',
      'announcements', 'committee', 'cover_media_id', 'logo_media_id',
      'gallery_id', 'is_archived', 'is_featured',
      'seo_title', 'seo_description', 'seo_image_media_id', 'status',
    ],
    publicColumns: null,
    searchableColumns: ['name', 'full_name', 'theme', 'tagline', 'description', 'location'],
    sortableColumns: ['year', 'name', 'start_date', ...AUDIT_COLUMNS],
    defaultSort: 'year',
    defaultOrder: 'DESC',
    managedBy: LEBOKU,
    hasVerification: false,
    searchable: true,
  },

  'language-categories': {
    key: 'language-categories',
    table: 'language_categories',
    label: 'Language category',
    slugColumn: 'slug',
    writableColumns: ['slug', 'name', 'description', 'sort_order', 'status'],
    publicColumns: null,
    searchableColumns: ['name', 'description'],
    sortableColumns: ['name', 'sort_order', ...AUDIT_COLUMNS],
    defaultSort: 'sort_order',
    defaultOrder: 'ASC',
    managedBy: LANGUAGE,
    hasVerification: false,
    searchable: false,
  },

  language: {
    key: 'language',
    table: 'language_words',
    label: 'Ekoli word',
    slugColumn: null,
    writableColumns: [
      'word', 'english_meaning', 'category_id', 'definition', 'example_sentence',
      'example_translation', 'part_of_speech', 'dialect_or_variation', 'notes',
      'speaker', 'entry_type', 'verification_status', 'status',
    ],
    publicColumns: null,
    searchableColumns: ['word', 'english_meaning', 'definition', 'example_sentence'],
    sortableColumns: ['word', 'english_meaning', ...AUDIT_COLUMNS],
    defaultSort: 'word',
    defaultOrder: 'ASC',
    managedBy: LANGUAGE,
    hasVerification: true,
    searchable: true,
  },

  galleries: {
    key: 'galleries',
    table: 'galleries',
    label: 'Gallery',
    slugColumn: 'slug',
    writableColumns: [
      'slug', 'title', 'description', 'category', 'event_date', 'location',
      'festival_id', 'cover_media_id', 'sort_order',
      'seo_title', 'seo_description', 'status',
    ],
    publicColumns: null,
    searchableColumns: ['title', 'description', 'category', 'location'],
    sortableColumns: ['title', 'event_date', 'sort_order', ...AUDIT_COLUMNS],
    defaultSort: 'sort_order',
    defaultOrder: 'ASC',
    managedBy: MEDIA,
    hasVerification: false,
    searchable: true,
  },

  videos: {
    key: 'videos',
    table: 'videos',
    label: 'Video',
    slugColumn: 'slug',
    writableColumns: [
      'slug', 'title', 'description', 'youtube_video_id', 'thumbnail_url',
      'category', 'published_date', 'related_event_id', 'related_festival_id',
      'duration_seconds', 'transcript', 'speaker', 'is_featured',
      'seo_title', 'seo_description', 'verification_status', 'status',
    ],
    publicColumns: null,
    searchableColumns: ['title', 'description', 'category', 'transcript'],
    sortableColumns: ['title', 'published_date', ...AUDIT_COLUMNS],
    defaultSort: 'published_date',
    defaultOrder: 'DESC',
    managedBy: MEDIA,
    hasVerification: true,
    searchable: true,
  },

  businesses: {
    key: 'businesses',
    table: 'businesses',
    label: 'Business',
    slugColumn: 'slug',
    writableColumns: [
      'slug', 'name', 'category', 'description', 'services', 'owner_name',
      'phone', 'email', 'website_url', 'address', 'city', 'country',
      'logo_media_id', 'is_verified', 'seo_title', 'seo_description', 'status',
    ],
    publicColumns: null,
    searchableColumns: ['name', 'category', 'description', 'services', 'city'],
    sortableColumns: ['name', ...AUDIT_COLUMNS],
    defaultSort: 'name',
    defaultOrder: 'ASC',
    managedBy: CONTENT_ADMIN,
    hasVerification: false,
    searchable: true,
  },

  organizations: {
    key: 'organizations',
    table: 'organizations',
    label: 'Organization',
    slugColumn: 'slug',
    writableColumns: [
      'slug', 'name', 'organization_type', 'description', 'mission',
      'founded_year', 'contact_name', 'phone', 'email', 'website_url',
      'address', 'logo_media_id', 'seo_title', 'seo_description', 'status',
    ],
    publicColumns: null,
    searchableColumns: ['name', 'organization_type', 'description', 'mission'],
    sortableColumns: ['name', 'founded_year', ...AUDIT_COLUMNS],
    defaultSort: 'name',
    defaultOrder: 'ASC',
    managedBy: CONTENT_ADMIN,
    hasVerification: false,
    searchable: true,
  },

  // Culture & Heritage. Stored in the shared `content_items` table rather than
  // a table of its own: a culture article is "a titled article with a body",
  // and so is whatever content type the community asks for next.
  culture: {
    key: 'culture',
    table: 'content_items',
    label: 'Culture article',
    slugColumn: 'slug',
    writableColumns: [
      'slug', 'title', 'subtitle', 'excerpt', 'body', 'category', 'cover_media_id',
      'seo_title', 'seo_description', 'seo_image_media_id', 'sort_order',
      'verification_status', 'research_edition', 'status',
    ],
    publicColumns: null,
    searchableColumns: ['title', 'subtitle', 'excerpt', 'body', 'category'],
    sortableColumns: ['title', 'sort_order', ...AUDIT_COLUMNS],
    defaultSort: 'sort_order',
    defaultOrder: 'ASC',
    managedBy: HERITAGE,
    hasVerification: true,
    searchable: true,
    fixedFilters: { content_type: 'culture' },
  },

  // Age grades, cultural groups and cultural music. Like `culture`, these share
  // the `content_items` table and are discriminated by `content_type` — three
  // more shelves in the same cupboard rather than three new tables.
  'age-grades': {
    key: 'age-grades',
    table: 'content_items',
    label: 'Age grade',
    slugColumn: 'slug',
    writableColumns: [
      'slug', 'title', 'subtitle', 'excerpt', 'body', 'category', 'cover_media_id',
      'seo_title', 'seo_description', 'sort_order', 'verification_status', 'status',
    ],
    publicColumns: null,
    searchableColumns: ['title', 'subtitle', 'excerpt', 'body'],
    sortableColumns: ['title', 'sort_order', ...AUDIT_COLUMNS],
    defaultSort: 'sort_order',
    defaultOrder: 'ASC',
    managedBy: HERITAGE,
    hasVerification: true,
    searchable: true,
    fixedFilters: { content_type: 'age_grades' },
  },

  'cultural-groups': {
    key: 'cultural-groups',
    table: 'content_items',
    label: 'Cultural group',
    slugColumn: 'slug',
    writableColumns: [
      'slug', 'title', 'subtitle', 'excerpt', 'body', 'category', 'cover_media_id',
      'seo_title', 'seo_description', 'sort_order', 'verification_status', 'status',
    ],
    publicColumns: null,
    searchableColumns: ['title', 'subtitle', 'excerpt', 'body'],
    sortableColumns: ['title', 'sort_order', ...AUDIT_COLUMNS],
    defaultSort: 'sort_order',
    defaultOrder: 'ASC',
    managedBy: HERITAGE,
    hasVerification: true,
    searchable: true,
    fixedFilters: { content_type: 'cultural_groups' },
  },

  music: {
    key: 'music',
    table: 'content_items',
    label: 'Cultural music',
    slugColumn: 'slug',
    writableColumns: [
      'slug', 'title', 'subtitle', 'excerpt', 'body', 'category', 'cover_media_id',
      'seo_title', 'seo_description', 'sort_order', 'verification_status', 'status',
    ],
    publicColumns: null,
    searchableColumns: ['title', 'subtitle', 'excerpt', 'body'],
    sortableColumns: ['title', 'sort_order', ...AUDIT_COLUMNS],
    defaultSort: 'sort_order',
    defaultOrder: 'ASC',
    managedBy: HERITAGE,
    hasVerification: true,
    searchable: true,
    fixedFilters: { content_type: 'cultural_music' },
  },

  community: {
    key: 'community',
    table: 'community_projects',
    label: 'Community project',
    slugColumn: 'slug',
    writableColumns: [
      'slug', 'title', 'description', 'purpose', 'location', 'committee',
      'funding_target', 'funds_raised', 'currency', 'progress_percent',
      'start_date', 'completion_date', 'project_status', 'cover_media_id',
      'seo_title', 'seo_description', 'status',
    ],
    publicColumns: null,
    searchableColumns: ['title', 'description', 'purpose', 'location'],
    sortableColumns: ['title', 'start_date', 'progress_percent', ...AUDIT_COLUMNS],
    defaultSort: 'start_date',
    defaultOrder: 'DESC',
    managedBy: CONTENT_ADMIN,
    hasVerification: false,
    searchable: true,
  },
};

export const CONTENT_KEYS = Object.keys(CONTENT_RESOURCES);

export function getResource(key: string): ContentResource | undefined {
  return CONTENT_RESOURCES[key];
}

/**
 * Looks a resource up and fails loudly if it is missing.
 *
 * Used by the controllers that name a resource directly (festivals, language).
 * A missing key means the registry and the controller have drifted apart, which
 * is a programming error worth crashing the isolate over rather than a runtime
 * condition to handle.
 */
export function requireResource(key: string): ContentResource {
  const resource = CONTENT_RESOURCES[key];
  if (!resource) {
    throw new Error(`The "${key}" resource is missing from the content registry.`);
  }
  return resource;
}

/** Permission strings implied by a resource, e.g. `history:create`. */
export type ContentAction = 'read' | 'create' | 'update' | 'delete' | 'publish';

export const CONTENT_ACTIONS: ContentAction[] = ['read', 'create', 'update', 'delete', 'publish'];

export function permissionFor(resourceKey: string, action: ContentAction): string {
  return `${resourceKey}:${action}`;
}

/**
 * The full permission list a role receives for the resources it manages.
 * Used by the migration seed and by `docs/architecture.md`.
 */
export function permissionsForRole(role: RoleSlug): string[] {
  const permissions: string[] = [];
  for (const resource of Object.values(CONTENT_RESOURCES)) {
    if (!resource.managedBy.includes(role)) continue;
    for (const action of CONTENT_ACTIONS) {
      permissions.push(permissionFor(resource.key, action));
    }
  }
  return permissions;
}
