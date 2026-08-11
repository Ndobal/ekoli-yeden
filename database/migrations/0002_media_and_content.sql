-- ---------------------------------------------------------------------------
-- EKOLI YEDEN DIGITAL HOME — Migration 0002
-- Media metadata, pages, history, leadership, people, news and events.
--
-- Every content table carries the same editorial workflow column:
--
--   draft → pending_review → approved → published
--                          ↘ rejected
--                            archived
--
-- Only `published` is ever visible to a visitor. The constraint is repeated on
-- each table rather than centralised so that a bad write fails at the database,
-- not only in application code.
-- ---------------------------------------------------------------------------

-- --------------------------------------------------------------------------
-- media_assets — one row per object in R2.
--
-- D1 holds the record; R2 holds the bytes. Videos are never stored here:
-- YouTube is the video host.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS media_assets (
  id                   TEXT PRIMARY KEY,
  -- Key inside the R2 bucket, e.g. heritage/2026/08/ab12….jpg
  storage_key          TEXT NOT NULL UNIQUE,
  folder               TEXT NOT NULL
                         CHECK (folder IN ('images', 'audio', 'documents', 'avatars',
                                           'heritage', 'language', 'leboku')),
  original_filename    TEXT NOT NULL,
  mime_type            TEXT NOT NULL,
  size_bytes           INTEGER NOT NULL,
  checksum             TEXT,
  title                TEXT,
  description          TEXT,
  alt_text             TEXT,
  credit               TEXT,
  -- When and where the photograph was taken. Left NULL until somebody who
  -- knows supplies it — an unlabelled photograph is still worth preserving.
  captured_at          TEXT,
  location             TEXT,
  verification_status  TEXT NOT NULL DEFAULT 'unverified'
                         CHECK (verification_status IN ('unverified', 'in_review', 'verified', 'disputed')),
  uploaded_by          TEXT REFERENCES users (id) ON DELETE SET NULL,
  status               TEXT NOT NULL DEFAULT 'pending_review'
                         CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at           TEXT NOT NULL,
  updated_at           TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_media_folder ON media_assets (folder, status);
CREATE INDEX IF NOT EXISTS idx_media_status ON media_assets (status);
CREATE INDEX IF NOT EXISTS idx_media_uploader ON media_assets (uploaded_by);

-- --------------------------------------------------------------------------
-- pages — editable static pages such as /about.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pages (
  id                   TEXT PRIMARY KEY,
  slug                 TEXT NOT NULL UNIQUE,
  title                TEXT NOT NULL,
  excerpt              TEXT,
  body                 TEXT,
  template             TEXT NOT NULL DEFAULT 'standard',
  cover_media_id       TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  seo_title            TEXT,
  seo_description      TEXT,
  seo_image_media_id   TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  canonical_url        TEXT,
  sort_order           INTEGER NOT NULL DEFAULT 0,
  status               TEXT NOT NULL DEFAULT 'draft'
                         CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at           TEXT NOT NULL,
  updated_at           TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_pages_status ON pages (status, sort_order);

-- --------------------------------------------------------------------------
-- history_entries — the Ekoli-Yeden historical archive.
--
-- `source_reference` and `verification_status` exist because this is meant to
-- be an authoritative record: an entry states where it came from and whether
-- the Verification Team has checked it.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS history_entries (
  id                   TEXT PRIMARY KEY,
  slug                 TEXT NOT NULL UNIQUE,
  title                TEXT NOT NULL,
  summary              TEXT,
  body                 TEXT,
  -- Free text ("before 1900", "the colonial period") because much of what an
  -- elder can tell us has no exact date, and forcing one would invent precision.
  period_label         TEXT,
  event_date           TEXT,
  era                  TEXT,
  category             TEXT,
  location             TEXT,
  source_reference     TEXT,
  contributed_by       TEXT,
  cover_media_id       TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  seo_title            TEXT,
  seo_description      TEXT,
  seo_image_media_id   TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  verification_status  TEXT NOT NULL DEFAULT 'unverified'
                         CHECK (verification_status IN ('unverified', 'in_review', 'verified', 'disputed')),
  sort_order           INTEGER NOT NULL DEFAULT 0,
  status               TEXT NOT NULL DEFAULT 'draft'
                         CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at           TEXT NOT NULL,
  updated_at           TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_history_status ON history_entries (status, sort_order);
CREATE INDEX IF NOT EXISTS idx_history_category ON history_entries (category);
CREATE INDEX IF NOT EXISTS idx_history_verification ON history_entries (verification_status);

-- --------------------------------------------------------------------------
-- leaders — traditional leadership and community leadership.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS leaders (
  id                   TEXT PRIMARY KEY,
  slug                 TEXT NOT NULL UNIQUE,
  name                 TEXT NOT NULL,
  traditional_title    TEXT,
  role_description     TEXT,
  area_represented     TEXT,
  biography            TEXT,
  contributions        TEXT,
  reign_start          TEXT,
  reign_end            TEXT,
  is_current           INTEGER NOT NULL DEFAULT 0 CHECK (is_current IN (0, 1)),
  portrait_media_id    TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  source_reference     TEXT,
  seo_title            TEXT,
  seo_description      TEXT,
  verification_status  TEXT NOT NULL DEFAULT 'unverified'
                         CHECK (verification_status IN ('unverified', 'in_review', 'verified', 'disputed')),
  sort_order           INTEGER NOT NULL DEFAULT 0,
  status               TEXT NOT NULL DEFAULT 'draft'
                         CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at           TEXT NOT NULL,
  updated_at           TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_leaders_status ON leaders (status, sort_order);
CREATE INDEX IF NOT EXISTS idx_leaders_current ON leaders (is_current);

-- --------------------------------------------------------------------------
-- people — notable Ekoli-Yeden people, and the future Hall of Fame.
--
-- `consent_reference` records that the person (or their family) agreed to be
-- listed. A living person's profile is personal data, not archive material.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS people (
  id                   TEXT PRIMARY KEY,
  slug                 TEXT NOT NULL UNIQUE,
  name                 TEXT NOT NULL,
  headline             TEXT,
  profession           TEXT,
  category             TEXT,
  biography            TEXT,
  achievements         TEXT,
  city                 TEXT,
  country              TEXT,
  website_url          TEXT,
  photo_media_id       TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  is_hall_of_fame      INTEGER NOT NULL DEFAULT 0 CHECK (is_hall_of_fame IN (0, 1)),
  consent_reference    TEXT,
  seo_title            TEXT,
  seo_description      TEXT,
  verification_status  TEXT NOT NULL DEFAULT 'unverified'
                         CHECK (verification_status IN ('unverified', 'in_review', 'verified', 'disputed')),
  sort_order           INTEGER NOT NULL DEFAULT 0,
  status               TEXT NOT NULL DEFAULT 'draft'
                         CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at           TEXT NOT NULL,
  updated_at           TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_people_status ON people (status, name);
CREATE INDEX IF NOT EXISTS idx_people_category ON people (category);
CREATE INDEX IF NOT EXISTS idx_people_hall_of_fame ON people (is_hall_of_fame);

-- --------------------------------------------------------------------------
-- news — the community's official channel.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS news (
  id                   TEXT PRIMARY KEY,
  slug                 TEXT NOT NULL UNIQUE,
  title                TEXT NOT NULL,
  excerpt              TEXT,
  body                 TEXT,
  category             TEXT,
  author_name          TEXT,
  published_at         TEXT,
  is_featured          INTEGER NOT NULL DEFAULT 0 CHECK (is_featured IN (0, 1)),
  cover_media_id       TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  seo_title            TEXT,
  seo_description      TEXT,
  seo_image_media_id   TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  status               TEXT NOT NULL DEFAULT 'draft'
                         CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at           TEXT NOT NULL,
  updated_at           TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_news_status ON news (status, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_news_category ON news (category);
