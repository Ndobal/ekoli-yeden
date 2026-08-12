-- ---------------------------------------------------------------------------
-- EKOLI YEDEN DIGITAL HOME — Migration 0013
-- A second administrator who cannot make or unmake Super Admins, and storage
-- for material contributed by the community before it is reviewed.
--
-- WHY A DEPUTY RATHER THAN A SECOND SUPER ADMIN
--
-- Super Admin holds the wildcard permission "*", which by definition includes
-- the power to appoint another Super Admin and to remove an existing one. That
-- is the one power a community platform should not hand out twice casually: it
-- is the power to take the archive away from the people who built it.
--
-- The Deputy Administrator therefore holds every administrative permission
-- named explicitly — users, content, media, submissions, sources, settings,
-- audit — and does NOT hold the wildcard. The two permissions governing Super
-- Admin appointment are withheld, and the Worker refuses those operations for
-- anybody who is not themselves a Super Admin.
--
-- The distinction is enforced in three places, deliberately: the permission
-- array here, an explicit guard in the role-assignment endpoint, and the
-- existing "the last Super Admin cannot be removed" rule.
-- ---------------------------------------------------------------------------

INSERT OR IGNORE INTO roles (id, slug, name, description, permissions, is_system, created_at, updated_at)
VALUES
  (
    'role_deputy_super_admin',
    'deputy_super_admin',
    'Deputy Administrator',
    'Full administration of the platform — users, roles below Super Admin, content, media, '
    || 'submissions, sources, settings and the audit log. Cannot appoint or remove a Super Admin, '
    || 'and cannot grant itself that power.',
    '["users.manage","users:read","users:create","users:update","users:assign_roles","roles.manage","content.manage","content.create","content.read","content.edit","content.review","content.submit","content.publish","content.unpublish","content.delete","pages.edit","navigation.edit","homepage.edit","seo.edit","media.manage","media.metadata.edit","media:read","media:create","media:update","media:delete","submissions.manage","submissions:read","submissions:review","sources.manage","sources.read","settings.manage","settings:read","settings:update","audit.view","audit:read","versions:read","versions:restore","strings:read","strings:update","strings:publish","navigation:update","hero:update","hero:publish","contributors:manage"]',
    1,
    '2026-08-12T00:00:00.000Z',
    '2026-08-12T00:00:00.000Z'
  );

-- The two permissions that separate a Super Admin from a Deputy. They are
-- recorded as settings so the rule is visible to an administrator reading the
-- database, not only to somebody reading the Worker's source.
INSERT OR IGNORE INTO site_settings (key, value, value_type, group_name, is_public, description, updated_at)
VALUES
  ('superadmin_appointment_restricted', 'true', 'boolean', 'security', 0,
   'Only a Super Admin may appoint or remove another Super Admin. Deputy Administrators cannot, '
   || 'however their role is configured.',
   '2026-08-12T00:00:00.000Z');

-- ===========================================================================
-- CONTRIBUTOR UPLOADS
--
-- Material the community sends in, before anybody has looked at it, is held in
-- its own R2 bucket rather than a folder of the published archive. Unreviewed
-- material and the archive have different audiences and different risk; a
-- bucket boundary means a mistake in the media-serving path cannot expose
-- something nobody has checked.
--
-- On approval the object is copied across into the archive bucket and a normal
-- media_assets record is created. The original stays where it is, so the chain
-- from "what was sent" to "what was published" is never broken.
-- ===========================================================================

CREATE TABLE IF NOT EXISTS submission_uploads (
  id                 TEXT PRIMARY KEY,

  -- The contribution this file belongs to. Nullable because a file may be
  -- uploaded first, while the contributor is still filling in the form.
  submission_id      TEXT REFERENCES submissions (id) ON DELETE CASCADE,

  -- Key inside the SUBMISSIONS bucket.
  storage_key        TEXT NOT NULL UNIQUE,
  original_filename  TEXT NOT NULL,
  mime_type          TEXT NOT NULL,
  size_bytes         INTEGER NOT NULL,
  checksum           TEXT,

  -- What the contributor told us about it. Often partial, and that is fine —
  -- a photograph with a half-remembered date is still worth having.
  caption            TEXT,
  people_pictured    TEXT,
  taken_at           TEXT,
  location           TEXT,

  -- Who sent it, and what they permitted. Recorded at the moment of upload,
  -- because consent given later is not the same thing.
  contributor_name   TEXT,
  contributor_email  TEXT,
  contributor_phone  TEXT,
  uploaded_by        TEXT REFERENCES users (id) ON DELETE SET NULL,
  usage_permission   TEXT NOT NULL DEFAULT 'unspecified'
                       CHECK (usage_permission IN ('unspecified', 'archive_only', 'public_display',
                              'public_display_with_credit', 'unrestricted')),

  -- Review state. `promoted` means it has been copied into the archive.
  status             TEXT NOT NULL DEFAULT 'pending_review'
                       CHECK (status IN ('pending_review', 'approved', 'rejected', 'promoted', 'archived')),
  review_notes       TEXT,
  reviewed_by        TEXT REFERENCES users (id) ON DELETE SET NULL,
  reviewed_at        TEXT,

  -- The archive record this became, once approved and copied across.
  media_asset_id     TEXT REFERENCES media_assets (id) ON DELETE SET NULL,

  ip_hash            TEXT,
  created_at         TEXT NOT NULL,
  updated_at         TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_submission_uploads_status
  ON submission_uploads (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_submission_uploads_submission
  ON submission_uploads (submission_id);

INSERT OR IGNORE INTO site_settings (key, value, value_type, group_name, is_public, description, updated_at)
VALUES
  ('contributor_upload_max_bytes', '26214400', 'number', 'contributions', 1,
   'Largest single file a contributor may upload, in bytes.',
   '2026-08-12T00:00:00.000Z'),
  ('contributor_uploads_open', 'true', 'boolean', 'contributions', 1,
   'Whether the public may upload files with a contribution.',
   '2026-08-12T00:00:00.000Z');
