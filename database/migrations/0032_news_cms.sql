-- ===========================================================================
-- 0032  NEWS BECOMES A REAL PUBLICATION
-- ===========================================================================
--
-- The news table held a title, an excerpt, a body and one cover image. That is
-- enough to record that something happened and not nearly enough to be the
-- community's permanent account of it.
--
-- What the community actually produces looks like this: a meeting happened, on
-- a date, at a place, somebody chaired it, eleven photographs were taken, one
-- person recorded twenty minutes of it on a phone and put it on YouTube, and a
-- member wrote it up and sent it in. All of that is one story, and all of it
-- has to survive.
--
-- ---------------------------------------------------------------------------
-- SOCIAL MEDIA DISTRIBUTES. THIS ARCHIVES.
-- ---------------------------------------------------------------------------
--
-- Facebook, WhatsApp and YouTube are how news reaches people today, and this
-- platform does not try to compete with any of them. It is where the same story
-- is kept so it can still be found in 2046 — which is why a news item can hold
-- the YouTube video rather than replacing it, and why `news_sources` records
-- where a claim came from.
--
-- ---------------------------------------------------------------------------
-- WHY THE TABLE IS REBUILT RATHER THAN ALTERED
-- ---------------------------------------------------------------------------
--
-- Two workflow states are missing — `changes_requested` and `scheduled` — and
-- they live in a CHECK constraint, which SQLite cannot alter in place. So the
-- table is rebuilt by the standard procedure, with `defer_foreign_keys` on so
-- that `news_submissions.news_id` is not set to NULL while the table is gone.
--
-- The mapping is also captured into a temporary table and restored afterwards,
-- belt and braces: the link between a member's submission and the article it
-- became is the contributor's acknowledgement, and losing it silently would be
-- the worst possible outcome of a schema change.
-- ===========================================================================

PRAGMA defer_foreign_keys = on;

-- ---------------------------------------------------------------------------
-- Categories, managed by the Editorial Team rather than by a deployment.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS news_categories (
  id           TEXT PRIMARY KEY,
  slug         TEXT NOT NULL UNIQUE,
  name         TEXT NOT NULL,
  description  TEXT,

  -- A colour and an icon, so a category is recognisable in a list of forty
  -- headlines before any of them is read.
  accent       TEXT,
  icon         TEXT,

  sort_order   INTEGER NOT NULL DEFAULT 0,

  -- Deactivated rather than deleted: a category that has published stories
  -- under it cannot simply disappear, or those stories lose their label.
  is_active    INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),

  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_news_categories_active
  ON news_categories (is_active, sort_order);

INSERT OR IGNORE INTO news_categories (id, slug, name, description, sort_order, is_active, created_at, updated_at)
VALUES
  ('newscat_community',    'community',    'Community News', 'What is happening in Ekoli-Yeden.', 10, 1, datetime('now'), datetime('now')),
  ('newscat_announcement', 'announcements','Announcements',  'Official notices from the community.', 20, 1, datetime('now'), datetime('now')),
  ('newscat_appointment',  'appointments', 'Appointments',   'Who has been appointed to what.', 30, 1, datetime('now'), datetime('now')),
  ('newscat_achievement',  'achievements', 'Achievements',   'Somebody has done something worth recording.', 40, 1, datetime('now'), datetime('now')),
  ('newscat_education',    'education',    'Education',      'Schools, scholarships, examinations and teaching.', 50, 1, datetime('now'), datetime('now')),
  ('newscat_health',       'health',       'Health',         'Clinics, campaigns and public health.', 60, 1, datetime('now'), datetime('now')),
  ('newscat_business',     'business',     'Business',       'Trade, enterprise and work.', 70, 1, datetime('now'), datetime('now')),
  ('newscat_culture',      'culture',      'Culture',        'Practice, music, dress and tradition.', 80, 1, datetime('now'), datetime('now')),
  ('newscat_festivals',    'festivals',    'Festivals',      'Leboku and the other festivals.', 90, 1, datetime('now'), datetime('now')),
  ('newscat_development',  'development',  'Development',    'Roads, boreholes, buildings and projects.', 100, 1, datetime('now'), datetime('now')),
  ('newscat_people',       'people',       'People',         'About people of Ekoli-Yeden.', 110, 1, datetime('now'), datetime('now')),
  ('newscat_obituaries',   'obituaries',   'Obituaries',     'Those the community has lost.', 120, 1, datetime('now'), datetime('now')),
  ('newscat_events',       'events',       'Events',         'Meetings, gatherings and occasions.', 130, 1, datetime('now'), datetime('now')),
  ('newscat_youth',        'youth',        'Youth',          'Young people of Ekoli-Yeden.', 140, 1, datetime('now'), datetime('now')),
  ('newscat_women',        'women',        'Women',          'The women of the community and their work.', 150, 1, datetime('now'), datetime('now')),
  ('newscat_diaspora',     'diaspora',     'Diaspora',       'Ekoli-Yeden people away from home.', 160, 1, datetime('now'), datetime('now')),
  ('newscat_other',        'other',        'Other',          'Anything the other categories do not hold.', 900, 1, datetime('now'), datetime('now'));

-- ---------------------------------------------------------------------------
-- Tags. Cheaper than categories and allowed to multiply — a story is in ONE
-- category and can carry SEVERAL tags.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS news_tags (
  id          TEXT PRIMARY KEY,
  slug        TEXT NOT NULL UNIQUE,
  name        TEXT NOT NULL,
  usage_count INTEGER NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS news_tag_links (
  id       TEXT PRIMARY KEY,
  news_id  TEXT NOT NULL,
  tag_id   TEXT NOT NULL REFERENCES news_tags (id) ON DELETE CASCADE,
  UNIQUE (news_id, tag_id)
);

CREATE INDEX IF NOT EXISTS idx_news_tag_links_news ON news_tag_links (news_id);
CREATE INDEX IF NOT EXISTS idx_news_tag_links_tag ON news_tag_links (tag_id);

-- ---------------------------------------------------------------------------
-- THE PHOTOGRAPHS AND THE FILM.
--
-- One row per attachment, ordered, each carrying its own caption and its own
-- credit. The credit is per-photograph and not per-article because eleven
-- photographs of one meeting are frequently taken by three different people,
-- and an article-level "photographs by" line quietly takes two of them off the
-- record.
--
-- Images reference `media_assets`, which is R2. Videos hold a YouTube id and no
-- file at all: storage cost stays proportional to photographs, and a video the
-- community has already published does not have to be re-uploaded to be
-- organised here.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS news_media (
  id             TEXT PRIMARY KEY,
  news_id        TEXT NOT NULL,

  media_type     TEXT NOT NULL DEFAULT 'image'
                   CHECK (media_type IN ('image', 'youtube_video')),

  -- For an image. Null for a video.
  media_id       TEXT REFERENCES media_assets (id) ON DELETE CASCADE,

  -- For a video. Null for an image.
  youtube_id     TEXT,
  youtube_url    TEXT,
  video_title    TEXT,
  video_description TEXT,

  display_order  INTEGER NOT NULL DEFAULT 0,

  caption        TEXT,
  alt_text       TEXT,
  photographer   TEXT,
  contributor_id TEXT REFERENCES users (id) ON DELETE SET NULL,
  copyright      TEXT,
  taken_at       TEXT,

  created_at     TEXT NOT NULL,

  -- One or the other, never both and never neither.
  CHECK (
    (media_type = 'image' AND media_id IS NOT NULL AND youtube_id IS NULL) OR
    (media_type = 'youtube_video' AND youtube_id IS NOT NULL AND media_id IS NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_news_media_news
  ON news_media (news_id, display_order);

-- ---------------------------------------------------------------------------
-- Where a story came from.
--
-- The same idea as `sources` for history, kept separate because a news source
-- is usually a person or an organisation rather than a publication, and forcing
-- it into a citation record produces citations nobody can read.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS news_sources (
  id             TEXT PRIMARY KEY,
  news_id        TEXT NOT NULL,

  source_type    TEXT NOT NULL DEFAULT 'other'
                   CHECK (source_type IN ('community_submission', 'editorial_team',
                                          'community_organization', 'official_announcement',
                                          'newspaper', 'government', 'interview', 'other')),

  title          TEXT,
  author         TEXT,
  publisher      TEXT,
  url            TEXT,
  published_on   TEXT,
  notes          TEXT,

  created_at     TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_news_sources_news ON news_sources (news_id);

-- ---------------------------------------------------------------------------
-- Editorial decisions, kept as a trail rather than as a status field.
--
-- "Changes requested" is a conversation, not a state: the contributor has to be
-- able to read what was asked for, and the next editor has to be able to see
-- what the last one said.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS news_reviews (
  id           TEXT PRIMARY KEY,
  news_id      TEXT,
  submission_id TEXT,

  decision     TEXT NOT NULL
                 CHECK (decision IN ('approved', 'rejected', 'changes_requested',
                                     'published', 'scheduled', 'archived', 'unpublished')),

  comment      TEXT,

  reviewer_id  TEXT REFERENCES users (id) ON DELETE SET NULL,
  reviewer_name TEXT,
  created_at   TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_news_reviews_news ON news_reviews (news_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_news_reviews_submission ON news_reviews (submission_id);

-- ---------------------------------------------------------------------------
-- Version history.
--
-- A snapshot before each edit. Never deleted — the archive's whole claim is
-- that what it says can be checked, and a record that can be silently rewritten
-- cannot be checked.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS news_revisions (
  id             TEXT PRIMARY KEY,
  news_id        TEXT NOT NULL,

  title          TEXT,
  summary        TEXT,
  content        TEXT,

  change_summary TEXT,
  editor_id      TEXT REFERENCES users (id) ON DELETE SET NULL,
  editor_name    TEXT,
  created_at     TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_news_revisions_news
  ON news_revisions (news_id, created_at DESC);

-- ===========================================================================
-- THE REBUILD
-- ===========================================================================

-- The submission-to-article links, held aside.
CREATE TEMPORARY TABLE _news_submission_links AS
  SELECT id AS submission_id, news_id FROM news_submissions WHERE news_id IS NOT NULL;

CREATE TABLE news_rebuilt (
  id                   TEXT PRIMARY KEY,
  slug                 TEXT NOT NULL UNIQUE,
  title                TEXT NOT NULL,

  -- `excerpt` keeps its name: it is referenced by the content registry, the
  -- search index and every existing client. `summary` would have been a nicer
  -- word and is not worth breaking three things for.
  excerpt              TEXT,

  -- The story. Structured blocks as JSON rather than HTML — see
  -- `news-content.ts` in the Worker. An editor never writes markup, and the
  -- server validates a shape instead of trying to scrub arbitrary HTML, which
  -- is the difference between sanitising and hoping.
  body                 TEXT,

  -- Kept for the records written before categories existed.
  category             TEXT,
  category_id          TEXT REFERENCES news_categories (id) ON DELETE SET NULL,

  author_name          TEXT,

  -- When it HAPPENED, which is not when it was published. A meeting held in
  -- March and written up in June is a March story.
  news_date            TEXT,
  location             TEXT,

  published_at         TEXT,

  is_featured          INTEGER NOT NULL DEFAULT 0 CHECK (is_featured IN (0, 1)),

  -- An announcement that sits at the top of the section, and stops doing so on
  -- its own. Every "IMPORTANT" banner without an expiry becomes furniture.
  is_important         INTEGER NOT NULL DEFAULT 0 CHECK (is_important IN (0, 1)),
  important_expires_at TEXT,

  -- Set for a story approved and waiting for its moment. The cron in the
  -- Worker publishes it; nothing scheduled is readable before then.
  scheduled_publish_at TEXT,

  source               TEXT,
  source_url           TEXT,

  cover_media_id       TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  seo_title            TEXT,
  seo_description      TEXT,
  seo_image_media_id   TEXT REFERENCES media_assets (id) ON DELETE SET NULL,

  -- WHO SENT IT IN. Never cleared by an edit.
  submitted_by         TEXT REFERENCES users (id) ON DELETE SET NULL,
  contributor_name     TEXT,
  source_note          TEXT,

  created_by           TEXT REFERENCES users (id) ON DELETE SET NULL,
  updated_by           TEXT REFERENCES users (id) ON DELETE SET NULL,
  published_by         TEXT REFERENCES users (id) ON DELETE SET NULL,

  review_notes         TEXT,

  status               TEXT NOT NULL DEFAULT 'draft'
                         CHECK (status IN ('draft', 'pending_review', 'changes_requested',
                                           'approved', 'scheduled', 'published',
                                           'archived', 'rejected')),

  created_at           TEXT NOT NULL,
  updated_at           TEXT NOT NULL,
  archived_at          TEXT
);

INSERT INTO news_rebuilt (
  id, slug, title, excerpt, body, category, author_name, published_at,
  is_featured, cover_media_id, seo_title, seo_description, seo_image_media_id,
  status, created_at, updated_at
)
SELECT
  id, slug, title, excerpt, body, category, author_name, published_at,
  is_featured, cover_media_id, seo_title, seo_description, seo_image_media_id,
  status, created_at, updated_at
FROM news;

-- Give the migrated rows a real category where their old text one matches.
UPDATE news_rebuilt
SET category_id = (
  SELECT c.id FROM news_categories c
  WHERE c.slug = lower(replace(trim(news_rebuilt.category), ' ', '-'))
)
WHERE category IS NOT NULL AND category_id IS NULL;

DROP TABLE news;
ALTER TABLE news_rebuilt RENAME TO news;

CREATE INDEX IF NOT EXISTS idx_news_status ON news (status, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_news_category ON news (category_id, status);
CREATE INDEX IF NOT EXISTS idx_news_featured ON news (is_featured, status, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_news_scheduled ON news (status, scheduled_publish_at);
CREATE INDEX IF NOT EXISTS idx_news_date ON news (news_date DESC);

-- Put the submission links back, whatever the rebuild did to them.
UPDATE news_submissions
SET news_id = (
  SELECT l.news_id FROM _news_submission_links l WHERE l.submission_id = news_submissions.id
)
WHERE id IN (SELECT submission_id FROM _news_submission_links);

DROP TABLE _news_submission_links;

-- ---------------------------------------------------------------------------
-- The introduction, in the CMS.
--
-- The old page hard-coded a sentence about social media. It is a good sentence
-- and it is the site's philosophy rather than a caption, so it moves here where
-- the Editorial Team owns it.
-- ---------------------------------------------------------------------------
INSERT OR IGNORE INTO content_strings
  (key, value, draft_value, group_name, page, label, help_text,
   value_type, max_length, status, is_locked, sort_order, created_at, updated_at)
VALUES
  ('page.news.intro',
   'Community news, announcements, appointments, achievements, events and important notices '
   || 'from Ekoli-Yeden.',
   NULL, 'pages', 'news', 'The line under the News heading', NULL, 'text', 500,
   'published', 0, 10, datetime('now'), datetime('now')),

  ('page.news.philosophy.title', 'From social media to a permanent archive',
   NULL, 'pages', 'news', 'The heading of the note at the foot of the News page', NULL, 'text', 200,
   'published', 0, 20, datetime('now'), datetime('now')),

  ('page.news.philosophy.body',
   'Social media helps our community share information today. The Ekoli Yeden Digital Home makes '
   || 'sure the stories, announcements, achievements and events that matter are kept in an '
   || 'organised archive that can still be found years from now. Facebook, WhatsApp and YouTube '
   || 'carry the news; this is where it is remembered.',
   NULL, 'pages', 'news', 'The note at the foot of the News page', NULL, 'text', 800,
   'published', 0, 30, datetime('now'), datetime('now')),

  ('page.news.submit.title', 'Do you have news from Ekoli-Yeden?',
   NULL, 'pages', 'news', 'The heading above the submit button', NULL, 'text', 200,
   'published', 0, 40, datetime('now'), datetime('now'));
