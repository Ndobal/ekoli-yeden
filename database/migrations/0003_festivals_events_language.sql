-- ---------------------------------------------------------------------------
-- EKOLI YEDEN DIGITAL HOME — Migration 0003
-- Festivals (Leboku), events, and the Ekoli language system.
-- ---------------------------------------------------------------------------

-- --------------------------------------------------------------------------
-- festivals
--
-- Leboku is a row, not a page. Each year is its own record, so /leboku/2026,
-- /leboku/2027 and every year after are the same code reading different rows —
-- and once a festival is over its record stays, which is what makes the
-- section an archive rather than a page that is overwritten annually.
--
-- programme, sponsors, announcements and committee are JSON text: their shape
-- differs from year to year and the community should not need a migration to
-- change how a programme is laid out.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS festivals (
  id                   TEXT PRIMARY KEY,
  slug                 TEXT NOT NULL UNIQUE,
  name                 TEXT NOT NULL,
  year                 INTEGER NOT NULL,
  theme                TEXT,
  description          TEXT,
  start_date           TEXT,
  end_date             TEXT,
  location             TEXT,
  programme            TEXT,
  sponsors             TEXT,
  announcements        TEXT,
  committee            TEXT,
  cover_media_id       TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  gallery_id           TEXT,
  -- Set once the edition has finished and its record becomes historical.
  is_archived          INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
  seo_title            TEXT,
  seo_description      TEXT,
  seo_image_media_id   TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  status               TEXT NOT NULL DEFAULT 'draft'
                         CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at           TEXT NOT NULL,
  updated_at           TEXT NOT NULL,
  UNIQUE (name, year)
);

CREATE INDEX IF NOT EXISTS idx_festivals_year ON festivals (year DESC);
CREATE INDEX IF NOT EXISTS idx_festivals_status ON festivals (status, year DESC);

-- --------------------------------------------------------------------------
-- events
--
-- An event may stand alone (a community meeting) or belong to a festival
-- edition, which is how a Leboku programme is assembled.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS events (
  id                TEXT PRIMARY KEY,
  slug              TEXT NOT NULL UNIQUE,
  title             TEXT NOT NULL,
  description       TEXT,
  category          TEXT,
  start_datetime    TEXT,
  end_datetime      TEXT,
  location          TEXT,
  venue             TEXT,
  organiser         TEXT,
  contact_info      TEXT,
  festival_id       TEXT REFERENCES festivals (id) ON DELETE SET NULL,
  is_featured       INTEGER NOT NULL DEFAULT 0 CHECK (is_featured IN (0, 1)),
  cover_media_id    TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  seo_title         TEXT,
  seo_description   TEXT,
  status            TEXT NOT NULL DEFAULT 'draft'
                      CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at        TEXT NOT NULL,
  updated_at        TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_events_status ON events (status, start_datetime);
CREATE INDEX IF NOT EXISTS idx_events_festival ON events (festival_id);

-- --------------------------------------------------------------------------
-- language_categories — how the dictionary is grouped.
--
-- Categories are structural (greetings, numbers, family terms). The words that
-- go inside them are supplied by native speakers.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS language_categories (
  id           TEXT PRIMARY KEY,
  slug         TEXT NOT NULL UNIQUE,
  name         TEXT NOT NULL,
  description  TEXT,
  sort_order   INTEGER NOT NULL DEFAULT 0,
  status       TEXT NOT NULL DEFAULT 'draft'
                 CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_language_categories_status ON language_categories (status, sort_order);

-- --------------------------------------------------------------------------
-- language_words — the Ekoli dictionary.
--
-- IMPORTANT: every column below is filled in by a native speaker or a
-- recognised Ekoli language scholar through the admin system. The platform
-- never generates, guesses or completes the meaning of an Ekoli word. An entry
-- with english_meaning NULL is displayed as awaiting verification, which is
-- the honest state for a word nobody has confirmed yet.
--
-- verification_status starts at 'unverified' and is only ever raised by the
-- Verification Team.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS language_words (
  id                    TEXT PRIMARY KEY,
  word                  TEXT NOT NULL,
  english_meaning       TEXT,
  category_id           TEXT REFERENCES language_categories (id) ON DELETE SET NULL,
  definition            TEXT,
  example_sentence      TEXT,
  example_translation   TEXT,
  part_of_speech        TEXT,
  -- Ekoli-Yeden speech varies between families and quarters; recording the
  -- variation is part of preserving the language accurately.
  dialect_or_variation  TEXT,
  notes                 TEXT,
  speaker               TEXT,
  entry_type            TEXT NOT NULL DEFAULT 'word'
                          CHECK (entry_type IN ('word', 'phrase', 'greeting', 'proverb',
                                                'idiom', 'number', 'name', 'song', 'riddle')),
  verification_status   TEXT NOT NULL DEFAULT 'unverified'
                          CHECK (verification_status IN ('unverified', 'in_review', 'verified', 'disputed')),
  verified_by           TEXT REFERENCES users (id) ON DELETE SET NULL,
  verified_at           TEXT,
  status                TEXT NOT NULL DEFAULT 'draft'
                          CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at            TEXT NOT NULL,
  updated_at            TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_language_words_word ON language_words (word);
CREATE INDEX IF NOT EXISTS idx_language_words_status ON language_words (status, word);
CREATE INDEX IF NOT EXISTS idx_language_words_category ON language_words (category_id);
CREATE INDEX IF NOT EXISTS idx_language_words_type ON language_words (entry_type);
CREATE INDEX IF NOT EXISTS idx_language_words_verification ON language_words (verification_status);

-- --------------------------------------------------------------------------
-- language_audio — pronunciation recordings.
--
-- A word may have several recordings: different speakers and different
-- variations. That is a feature of the archive, not a duplicate to be removed.
-- The audio file itself lives in R2 under language/.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS language_audio (
  id                    TEXT PRIMARY KEY,
  word_id               TEXT NOT NULL REFERENCES language_words (id) ON DELETE CASCADE,
  media_asset_id        TEXT NOT NULL REFERENCES media_assets (id) ON DELETE CASCADE,
  speaker               TEXT,
  dialect_or_variation  TEXT,
  notes                 TEXT,
  recorded_at           TEXT,
  status                TEXT NOT NULL DEFAULT 'pending_review'
                          CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at            TEXT NOT NULL,
  updated_at            TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_language_audio_word ON language_audio (word_id, status);
