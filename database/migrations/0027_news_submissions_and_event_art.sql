-- ===========================================================================
-- 0027  News anybody can send in, and events that look like events
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- PART ONE — news_submissions
-- ---------------------------------------------------------------------------
--
-- Publishing to News stays with the Content Administrators, and should. It is
-- the community's official channel: what appears there is taken as the
-- community speaking, and an open channel would make that meaningless.
--
-- But "only administrators may publish" had quietly become "only
-- administrators may know". A member who hears that the borehole is finished,
-- or that a scholarship deadline has moved, had nowhere to put it except the
-- generic contribution form, where it arrived as an untitled file attachment
-- and sat in a media queue.
--
-- So: anybody may WRITE news, nobody but an administrator may PUBLISH it. The
-- two are different permissions and this table is the gap between them.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS news_submissions (
  id                  TEXT PRIMARY KEY,
  reference_code      TEXT NOT NULL UNIQUE,

  title               TEXT NOT NULL,
  excerpt             TEXT,
  body                TEXT NOT NULL,
  category            TEXT,

  -- When the thing being reported happened, which is not the same as when it
  -- was written or when it will be published.
  happened_on         TEXT,
  location            TEXT,

  -- Uploaded through the contribution route, so nothing is public until an
  -- administrator promotes it.
  cover_upload_id     TEXT REFERENCES submission_uploads (id) ON DELETE SET NULL,
  extra_upload_ids    TEXT,

  -- --- Who is telling us, and how they know ------------------------------
  -- The second question matters more than the first. News from somebody who
  -- was there is a different thing from news somebody read in a WhatsApp
  -- group, and an administrator deciding whether to publish needs to know
  -- which they are holding.
  contributor_name    TEXT,
  contributor_email   TEXT,
  contributor_phone   TEXT,
  source_note         TEXT,
  submitted_by        TEXT REFERENCES users (id) ON DELETE SET NULL,

  status              TEXT NOT NULL DEFAULT 'pending_review'
                        CHECK (status IN ('pending_review', 'in_review', 'needs_more',
                                          'promoted', 'rejected')),
  reviewed_by         TEXT REFERENCES users (id) ON DELETE SET NULL,
  reviewed_at         TEXT,
  review_notes        TEXT,

  news_id             TEXT REFERENCES news (id) ON DELETE SET NULL,

  created_at          TEXT NOT NULL,
  updated_at          TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_news_submissions_status
  ON news_submissions (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_news_submissions_reference
  ON news_submissions (reference_code);

-- Where a published item came from, so the newsroom can see at a glance what
-- the community sent in versus what it wrote itself.
ALTER TABLE news ADD COLUMN submitted_by TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE news ADD COLUMN source_note TEXT;

-- ---------------------------------------------------------------------------
-- PART TWO — events that look like events
-- ---------------------------------------------------------------------------
--
-- An event in this community is announced with a flier. That is simply how it
-- is done: a designed image, shared on WhatsApp, carrying the date, the venue
-- and the names. An events page that cannot show one is an events page that
-- cannot show the thing people actually made.
--
-- Two images rather than one, because they are different objects:
--
--   BANNER  wide, for the top of the event's own page. Cropped by the layout.
--   FLIER   the poster itself, whatever shape it was designed in. Never
--           cropped, shown whole, and downloadable — because the useful thing
--           to do with a flier is send it to somebody else.
--
-- `cover_media_id` already existed and stays what it is: the small image on the
-- card in a list.
-- ---------------------------------------------------------------------------

ALTER TABLE events ADD COLUMN banner_media_id TEXT REFERENCES media_assets (id) ON DELETE SET NULL;
ALTER TABLE events ADD COLUMN flier_media_id TEXT REFERENCES media_assets (id) ON DELETE SET NULL;

-- Festivals get the same, so a Leboku edition can carry its own poster.
ALTER TABLE festivals ADD COLUMN banner_media_id TEXT REFERENCES media_assets (id) ON DELETE SET NULL;
ALTER TABLE festivals ADD COLUMN flier_media_id TEXT REFERENCES media_assets (id) ON DELETE SET NULL;

-- ---------------------------------------------------------------------------
-- The words these pages say
-- ---------------------------------------------------------------------------

INSERT OR IGNORE INTO content_strings
  (key, value, group_name, page, label, help_text, value_type, status, created_at, updated_at)
VALUES
  ('page.news.submit_intro',
   'Heard something the community should know? Send it in. News is published by the '
   || 'administrators — that is what makes this the community''s official channel rather than a '
   || 'noticeboard — but anybody may write it, and they read everything that arrives.',
   'news', 'news',
   'News — introduction to submitting',
   'Shown at the top of the news submission form',
   'text', 'published', datetime('now'), datetime('now')),

  ('page.events.flier_note',
   'The flier is shown whole and can be saved, because the useful thing to do with a flier is '
   || 'send it to somebody else.',
   'events', 'events',
   'Events — about the flier',
   'Shown beside an event flier',
   'text', 'published', datetime('now'), datetime('now'));
