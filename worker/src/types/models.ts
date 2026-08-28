/**
 * Row shapes for the D1 tables created by /database/migrations.
 *
 * These describe the archive's *structure* only. No historical, cultural or
 * language content is defined here — that is supplied by the Ekoli-Yeden
 * Preservation Team through the admin system and stored in D1.
 */

/** Editorial workflow shared by every moderated content type. */
export const CONTENT_STATUS = {
  DRAFT: 'draft',
  PENDING_REVIEW: 'pending_review',
  APPROVED: 'approved',
  PUBLISHED: 'published',
  ARCHIVED: 'archived',
  REJECTED: 'rejected',
} as const;

export type ContentStatus = (typeof CONTENT_STATUS)[keyof typeof CONTENT_STATUS];

export const ALL_CONTENT_STATUSES: ContentStatus[] = Object.values(CONTENT_STATUS);

/** The single status that the public website is allowed to read. */
export const PUBLIC_STATUS: ContentStatus = CONTENT_STATUS.PUBLISHED;

/**
 * Verification state for material that asserts a fact about Ekoli-Yeden —
 * history, leadership, language meanings, oral accounts.
 *
 * `unverified` is the default and is never silently upgraded. Only a member of
 * the Verification Team may move an entry to `verified`.
 */
export const VERIFICATION_STATUS = {
  UNVERIFIED: 'unverified',
  IN_REVIEW: 'in_review',
  VERIFIED: 'verified',
  DISPUTED: 'disputed',
} as const;

export type VerificationStatus =
  (typeof VERIFICATION_STATUS)[keyof typeof VERIFICATION_STATUS];

/** Columns present on every content table. */
export interface BaseRecord {
  id: string;
  status: ContentStatus;
  created_at: string;
  updated_at: string;
}

export interface UserRecord {
  id: string;
  email: string;
  display_name: string;
  password_hash: string | null;
  password_salt: string | null;
  avatar_media_id: string | null;
  phone: string | null;
  bio: string | null;
  preservation_team_position: string | null;
  status: string;
  email_verified_at: string | null;
  last_login_at: string | null;

  /// Set when an administrator has issued a temporary password. While it
  /// stands, signing in yields no session — only the right to choose a real
  /// password. See `issueTemporaryPassword`.
  must_change_password: number;
  password_changed_at: string | null;
  temp_password_issued_by: string | null;
  temp_password_issued_at: string | null;

  created_at: string;
  updated_at: string;
}

export interface RoleRecord {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  /** JSON array of permission strings. */
  permissions: string;
  is_system: number;
  created_at: string;
  updated_at: string;
}

export interface SessionRecord {
  id: string;
  user_id: string;
  refresh_token_hash: string;
  user_agent: string | null;
  ip_hash: string | null;
  expires_at: string;
  revoked_at: string | null;
  created_at: string;
}

export interface SiteSettingRecord {
  key: string;
  value: string | null;
  value_type: string;
  group_name: string;
  is_public: number;
  description: string | null;
  updated_at: string;
}

export interface MediaAssetRecord extends BaseRecord {
  /** Key of the object inside the R2 bucket, e.g. `heritage/2026/xyz.jpg`. */
  storage_key: string;
  folder: string;
  original_filename: string;
  mime_type: string;
  size_bytes: number;
  checksum: string | null;
  title: string | null;
  description: string | null;
  alt_text: string | null;
  credit: string | null;
  /** Where/when the item comes from — left blank until supplied. */
  captured_at: string | null;
  location: string | null;
  verification_status: VerificationStatus;
  uploaded_by: string | null;
}

export interface VideoRecord extends BaseRecord {
  title: string;
  description: string | null;
  youtube_video_id: string;
  thumbnail_url: string | null;
  category: string | null;
  published_date: string | null;
  related_event_id: string | null;
  related_festival_id: string | null;
  duration_seconds: number | null;
  transcript: string | null;
  verification_status: VerificationStatus;
}

export interface FestivalRecord extends BaseRecord {
  slug: string;
  name: string;
  year: number;
  theme: string | null;
  description: string | null;
  start_date: string | null;
  end_date: string | null;
  location: string | null;
  /** JSON array of programme entries. */
  programme: string | null;
  /** JSON array of sponsor objects. */
  sponsors: string | null;
  cover_media_id: string | null;
  gallery_id: string | null;
  is_archived: number;
}

export interface LanguageWordRecord extends BaseRecord {
  word: string;
  english_meaning: string | null;
  category_id: string | null;
  definition: string | null;
  example_sentence: string | null;
  example_translation: string | null;
  part_of_speech: string | null;
  dialect_or_variation: string | null;
  notes: string | null;
  speaker: string | null;
  verification_status: VerificationStatus;
  verified_by: string | null;
  verified_at: string | null;
}

export interface SubmissionRecord extends BaseRecord {
  reference_code: string;
  submission_type: string;
  title: string;
  description: string | null;
  submitter_name: string | null;
  submitter_email: string | null;
  submitter_phone: string | null;
  submitter_relationship: string | null;
  /** JSON array of media asset ids attached by the contributor. */
  media_asset_ids: string | null;
  youtube_url: string | null;
  consent_given: number;
  reviewed_by: string | null;
  reviewed_at: string | null;
  review_notes: string | null;
  published_record_type: string | null;
  published_record_id: string | null;
  submitted_by: string | null;
}

export interface AuditLogRecord {
  id: string;
  actor_id: string | null;
  actor_email: string | null;
  action: string;
  resource_type: string | null;
  resource_id: string | null;
  /** JSON snapshot of what changed. */
  changes: string | null;
  ip_hash: string | null;
  user_agent: string | null;
  request_id: string | null;
  created_at: string;
}
