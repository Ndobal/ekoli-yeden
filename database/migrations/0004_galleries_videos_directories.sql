-- ---------------------------------------------------------------------------
-- EKOLI YEDEN DIGITAL HOME — Migration 0004
-- Galleries, the YouTube video archive, and the community directories.
-- ---------------------------------------------------------------------------

-- --------------------------------------------------------------------------
-- galleries
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS galleries (
  id               TEXT PRIMARY KEY,
  slug             TEXT NOT NULL UNIQUE,
  title            TEXT NOT NULL,
  description      TEXT,
  category         TEXT,
  event_date       TEXT,
  location         TEXT,
  festival_id      TEXT REFERENCES festivals (id) ON DELETE SET NULL,
  cover_media_id   TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  sort_order       INTEGER NOT NULL DEFAULT 0,
  seo_title        TEXT,
  seo_description  TEXT,
  status           TEXT NOT NULL DEFAULT 'draft'
                     CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at       TEXT NOT NULL,
  updated_at       TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_galleries_status ON galleries (status, sort_order);
CREATE INDEX IF NOT EXISTS idx_galleries_festival ON galleries (festival_id);

-- --------------------------------------------------------------------------
-- gallery_items
--
-- The descriptive columns are what turn a photograph into an archive record:
-- who is pictured, where, when and who took it. They stay NULL until somebody
-- who was there tells us — an unlabelled photograph is still preserved, it is
-- simply not yet documented.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gallery_items (
  id               TEXT PRIMARY KEY,
  gallery_id       TEXT NOT NULL REFERENCES galleries (id) ON DELETE CASCADE,
  media_asset_id   TEXT NOT NULL REFERENCES media_assets (id) ON DELETE CASCADE,
  caption          TEXT,
  people_pictured  TEXT,
  photographer     TEXT,
  taken_at         TEXT,
  location         TEXT,
  sort_order       INTEGER NOT NULL DEFAULT 0,
  status           TEXT NOT NULL DEFAULT 'draft'
                     CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at       TEXT NOT NULL,
  updated_at       TEXT NOT NULL,
  UNIQUE (gallery_id, media_asset_id)
);

CREATE INDEX IF NOT EXISTS idx_gallery_items_gallery ON gallery_items (gallery_id, sort_order);

-- --------------------------------------------------------------------------
-- videos
--
-- YouTube hosts every video; this table holds only the catalogue record. That
-- keeps R2 costs proportional to photographs and audio, and it means the
-- videos the community has already published can be organised here without
-- being re-uploaded anywhere.
--
-- thumbnail_url is optional: when it is NULL the API derives the thumbnail
-- from the video id, so the archive renders without any YouTube API call.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS videos (
  id                   TEXT PRIMARY KEY,
  slug                 TEXT UNIQUE,
  title                TEXT NOT NULL,
  description          TEXT,
  youtube_video_id     TEXT NOT NULL,
  thumbnail_url        TEXT,
  category             TEXT
                         CHECK (category IS NULL OR category IN ('leboku', 'history', 'interviews',
                                'culture', 'community', 'events', 'documentaries', 'music', 'oral_history')),
  published_date       TEXT,
  related_event_id     TEXT REFERENCES events (id) ON DELETE SET NULL,
  related_festival_id  TEXT REFERENCES festivals (id) ON DELETE SET NULL,
  duration_seconds     INTEGER,
  -- A written transcript makes an oral-history recording searchable, which is
  -- the difference between a video existing and a video being findable.
  transcript           TEXT,
  speaker              TEXT,
  is_featured          INTEGER NOT NULL DEFAULT 0 CHECK (is_featured IN (0, 1)),
  seo_title            TEXT,
  seo_description      TEXT,
  verification_status  TEXT NOT NULL DEFAULT 'unverified'
                         CHECK (verification_status IN ('unverified', 'in_review', 'verified', 'disputed')),
  status               TEXT NOT NULL DEFAULT 'draft'
                         CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at           TEXT NOT NULL,
  updated_at           TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_videos_status ON videos (status, published_date DESC);
CREATE INDEX IF NOT EXISTS idx_videos_category ON videos (category);
CREATE INDEX IF NOT EXISTS idx_videos_festival ON videos (related_festival_id);
CREATE INDEX IF NOT EXISTS idx_videos_youtube ON videos (youtube_video_id);

-- --------------------------------------------------------------------------
-- businesses — the Ekoli-Yeden business and professional directory.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS businesses (
  id               TEXT PRIMARY KEY,
  slug             TEXT NOT NULL UNIQUE,
  name             TEXT NOT NULL,
  category         TEXT,
  description      TEXT,
  services         TEXT,
  owner_name       TEXT,
  phone            TEXT,
  email            TEXT,
  website_url      TEXT,
  address          TEXT,
  city             TEXT,
  country          TEXT,
  logo_media_id    TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  is_verified      INTEGER NOT NULL DEFAULT 0 CHECK (is_verified IN (0, 1)),
  seo_title        TEXT,
  seo_description  TEXT,
  status           TEXT NOT NULL DEFAULT 'draft'
                     CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at       TEXT NOT NULL,
  updated_at       TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_businesses_status ON businesses (status, name);
CREATE INDEX IF NOT EXISTS idx_businesses_category ON businesses (category);

-- --------------------------------------------------------------------------
-- organizations — unions, associations, societies, schools, churches.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS organizations (
  id                 TEXT PRIMARY KEY,
  slug               TEXT NOT NULL UNIQUE,
  name               TEXT NOT NULL,
  organization_type  TEXT,
  description        TEXT,
  mission            TEXT,
  founded_year       INTEGER,
  contact_name       TEXT,
  phone              TEXT,
  email              TEXT,
  website_url        TEXT,
  address            TEXT,
  logo_media_id      TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  seo_title          TEXT,
  seo_description    TEXT,
  status             TEXT NOT NULL DEFAULT 'draft'
                       CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at         TEXT NOT NULL,
  updated_at         TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_organizations_status ON organizations (status, name);
CREATE INDEX IF NOT EXISTS idx_organizations_type ON organizations (organization_type);

-- --------------------------------------------------------------------------
-- community_projects
--
-- Funding figures are recorded so a project page can show progress honestly.
-- They are entered by an administrator from the project committee's own
-- records; nothing here is estimated by the platform.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS community_projects (
  id                TEXT PRIMARY KEY,
  slug              TEXT NOT NULL UNIQUE,
  title             TEXT NOT NULL,
  description       TEXT,
  purpose           TEXT,
  location          TEXT,
  committee         TEXT,
  funding_target    REAL,
  funds_raised      REAL,
  currency          TEXT NOT NULL DEFAULT 'NGN',
  progress_percent  INTEGER NOT NULL DEFAULT 0
                      CHECK (progress_percent >= 0 AND progress_percent <= 100),
  start_date        TEXT,
  completion_date   TEXT,
  project_status    TEXT NOT NULL DEFAULT 'proposed'
                      CHECK (project_status IN ('proposed', 'fundraising', 'in_progress', 'completed', 'paused', 'cancelled')),
  cover_media_id    TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  seo_title         TEXT,
  seo_description   TEXT,
  status            TEXT NOT NULL DEFAULT 'draft'
                      CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at        TEXT NOT NULL,
  updated_at        TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_community_projects_status ON community_projects (status, start_date DESC);
CREATE INDEX IF NOT EXISTS idx_community_projects_state ON community_projects (project_status);

-- --------------------------------------------------------------------------
-- submissions — CONTRIBUTE TO EKOLI YEDEN
--
-- A submission is a proposal, never content. It enters at 'pending_review' and
-- only a moderator can move it. published_record_type / published_record_id
-- record what it eventually became, so a contributor's work stays traceable.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS submissions (
  id                      TEXT PRIMARY KEY,
  -- Short human-quotable code (EY-XXXXXX) the contributor uses to follow up.
  reference_code          TEXT NOT NULL UNIQUE,
  submission_type         TEXT NOT NULL
                            CHECK (submission_type IN ('historical_photograph', 'historical_document',
                                   'story', 'oral_history', 'language_recording', 'video',
                                   'notable_person', 'cultural_material', 'correction', 'other')),
  title                   TEXT NOT NULL,
  description             TEXT,
  submitter_name          TEXT,
  submitter_email         TEXT,
  submitter_phone         TEXT,
  submitter_relationship  TEXT,
  -- JSON array of media_assets.id uploaded with the contribution.
  media_asset_ids         TEXT,
  youtube_url             TEXT,
  consent_given           INTEGER NOT NULL DEFAULT 0 CHECK (consent_given IN (0, 1)),
  reviewed_by             TEXT REFERENCES users (id) ON DELETE SET NULL,
  reviewed_at             TEXT,
  review_notes            TEXT,
  published_record_type   TEXT,
  published_record_id     TEXT,
  submitted_by            TEXT REFERENCES users (id) ON DELETE SET NULL,
  status                  TEXT NOT NULL DEFAULT 'pending_review'
                            CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at              TEXT NOT NULL,
  updated_at              TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_submissions_status ON submissions (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_submissions_type ON submissions (submission_type);
CREATE INDEX IF NOT EXISTS idx_submissions_reference ON submissions (reference_code);
