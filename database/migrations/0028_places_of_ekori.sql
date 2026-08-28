-- ===========================================================================
-- 0028  THE PLACES OF EKORI
-- ===========================================================================
--
-- Ekori is not one place. It is Ajere and Ntan and Epenti and Afrekpe; and
-- inside Ajere is Edang, and inside Edang is Ukekeya; and there is Odagum and
-- Ogbeti and Yejele Kapil and Okem and Little Bird, and there are the beaches.
--
-- Somebody from Ukekeya is from Ukekeya. They are also from Edang, and from
-- Ajere, and from Ekori — all four are true at once, and a person who is asked
-- to choose one of them has been asked the wrong question.
--
-- ---------------------------------------------------------------------------
-- SO: ONE TABLE, NESTED, AND NOTHING FLATTENED
-- ---------------------------------------------------------------------------
--
-- `parent_id` points up the tree. Ukekeya → Edang → Ajere → Ekori. A member
-- attached to Ukekeya belongs to every place above it without anybody having to
-- record that four times, and a search for "who is from Ajere" reaches everyone
-- in Edang and Ukekeya too.
--
-- The alternative — a fixed set of columns like `quarter`, `compound`,
-- `street` — was rejected because it decides in advance how deep the community
-- goes and what each level is called, and it is wrong the first time somebody
-- names a level it does not have.
--
-- ---------------------------------------------------------------------------
-- AND: THE LIST GROWS FROM WHAT PEOPLE ACTUALLY TYPE
-- ---------------------------------------------------------------------------
--
-- No list written by an administrator will ever contain every compound in
-- Ekori, and a member whose home is missing from a dropdown will either pick
-- the wrong thing or give up. So the field takes free text, every answer is
-- recorded in `place_candidates`, and a name that two different people give is
-- promoted into the real list automatically.
--
-- Two, not one: one person typing something is a spelling. Two people typing
-- the same thing is a place.
-- ===========================================================================

CREATE TABLE IF NOT EXISTS places (
  id            TEXT PRIMARY KEY,
  slug          TEXT NOT NULL UNIQUE,
  name          TEXT NOT NULL,

  -- Up the tree. NULL for Ekori itself, which is the root.
  parent_id     TEXT REFERENCES places (id) ON DELETE SET NULL,

  -- Named rather than numbered, because the community's own words for these
  -- are not interchangeable and "level 3" means nothing to anybody.
  kind          TEXT NOT NULL DEFAULT 'quarter'
                  CHECK (kind IN ('village', 'ward', 'quarter', 'compound', 'street',
                                  'clan', 'beach', 'landmark', 'farmland', 'market',
                                  'school', 'other')),

  -- The full path, cached: "Ekori / Ajere / Edang / Ukekeya". Denormalised
  -- because every profile card, every search result and every dropdown needs
  -- it, and walking the tree per row is a walk too many.
  path          TEXT,
  depth         INTEGER NOT NULL DEFAULT 0,

  description   TEXT,
  history       TEXT,
  -- What this place is known for. The material the AI summary draws on.
  known_for     TEXT,

  cover_media_id TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  gallery_id    TEXT REFERENCES galleries (id) ON DELETE SET NULL,

  latitude      REAL,
  longitude     REAL,

  -- How many members give this as where they are from. Maintained on write,
  -- and what makes the dropdown order itself usefully.
  member_count  INTEGER NOT NULL DEFAULT 0,

  -- A place created by an administrator is canonical from the start. One
  -- promoted automatically from what people typed is marked so a reviewer can
  -- tidy spelling later without hunting for it.
  is_canonical  INTEGER NOT NULL DEFAULT 1 CHECK (is_canonical IN (0, 1)),
  created_from_candidate INTEGER NOT NULL DEFAULT 0
                  CHECK (created_from_candidate IN (0, 1)),

  sort_order    INTEGER NOT NULL DEFAULT 0,
  status        TEXT NOT NULL DEFAULT 'published'
                  CHECK (status IN ('draft', 'pending_review', 'published', 'archived')),

  created_by    TEXT REFERENCES users (id) ON DELETE SET NULL,
  created_at    TEXT NOT NULL,
  updated_at    TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_places_parent ON places (parent_id, sort_order, name);
CREATE INDEX IF NOT EXISTS idx_places_kind ON places (kind, status);
CREATE INDEX IF NOT EXISTS idx_places_members ON places (member_count DESC);

-- ---------------------------------------------------------------------------
-- place_aliases — the other names for the same place
--
-- Ekori and Ekoli-Yeden. Ajere and Ajere Beach. Spellings that differ by a
-- letter. Matching typed text against these is what stops the same compound
-- being promoted three times under three spellings.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS place_aliases (
  id          TEXT PRIMARY KEY,
  place_id    TEXT NOT NULL REFERENCES places (id) ON DELETE CASCADE,
  alias       TEXT NOT NULL,
  -- Lowercased, punctuation stripped — what the matching actually compares.
  normalised  TEXT NOT NULL,
  created_at  TEXT NOT NULL,
  UNIQUE (normalised)
);

CREATE INDEX IF NOT EXISTS idx_place_aliases_place ON place_aliases (place_id);

-- ---------------------------------------------------------------------------
-- place_candidates — what people typed that is not yet a place
--
-- Every free-text answer lands here. `times_seen` counts DISTINCT people, not
-- submissions, so one person filling a form twice does not conjure a village.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS place_candidates (
  id            TEXT PRIMARY KEY,
  raw_name      TEXT NOT NULL,
  normalised    TEXT NOT NULL UNIQUE,

  -- Where the person said it sits, if they said. Gives a promoted place its
  -- parent without a reviewer having to guess.
  parent_id     TEXT REFERENCES places (id) ON DELETE SET NULL,

  times_seen    INTEGER NOT NULL DEFAULT 1,
  -- The user ids that gave it, as JSON. Kept so the count is of PEOPLE.
  seen_by       TEXT,

  promoted_place_id TEXT REFERENCES places (id) ON DELETE SET NULL,
  state         TEXT NOT NULL DEFAULT 'open'
                  CHECK (state IN ('open', 'promoted', 'merged', 'rejected')),

  first_seen_at TEXT NOT NULL,
  last_seen_at  TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_place_candidates_state
  ON place_candidates (state, times_seen DESC);

-- ---------------------------------------------------------------------------
-- place_admins — a place runs its own page
--
-- The same narrow authority as `group_admins`: a row here grants nothing
-- anywhere else in the archive. Ajere's administrator keeps Ajere's page, its
-- festival and its photographs, and holds nothing over Ntan or over the
-- archive itself.
--
-- This is what "accommodate the diversity without losing the ideas" means in
-- practice: each place writes its own record, and the shared structures —
-- galleries, events, festivals — stay shared, so what Ajere uploads appears in
-- the main Gallery too.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS place_admins (
  id           TEXT PRIMARY KEY,
  place_id     TEXT NOT NULL REFERENCES places (id) ON DELETE CASCADE,
  user_id      TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  admin_role   TEXT NOT NULL DEFAULT 'admin'
                 CHECK (admin_role IN ('lead', 'admin')),
  office       TEXT,
  appointed_by TEXT REFERENCES users (id) ON DELETE SET NULL,
  created_at   TEXT NOT NULL,
  UNIQUE (place_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_place_admins_user ON place_admins (user_id);

-- ---------------------------------------------------------------------------
-- Everything a place can own
--
-- Not new tables — the same festivals, events, galleries and groups the rest of
-- the archive uses, with a place attached. Ajere's New Yam festival is a
-- festival; it is simply Ajere's.
-- ---------------------------------------------------------------------------

ALTER TABLE festivals ADD COLUMN place_id TEXT REFERENCES places (id) ON DELETE SET NULL;
ALTER TABLE events ADD COLUMN place_id TEXT REFERENCES places (id) ON DELETE SET NULL;
ALTER TABLE galleries ADD COLUMN place_id TEXT REFERENCES places (id) ON DELETE SET NULL;
ALTER TABLE community_groups ADD COLUMN place_id TEXT REFERENCES places (id) ON DELETE SET NULL;
ALTER TABLE people ADD COLUMN place_id TEXT REFERENCES places (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_festivals_place ON festivals (place_id);
CREATE INDEX IF NOT EXISTS idx_events_place ON events (place_id);
CREATE INDEX IF NOT EXISTS idx_galleries_place ON galleries (place_id);
CREATE INDEX IF NOT EXISTS idx_people_place ON people (place_id);

-- A member says where they are from, down to the compound or street.
ALTER TABLE member_profiles ADD COLUMN place_id TEXT REFERENCES places (id) ON DELETE SET NULL;
-- What they typed, kept even after it is matched — so a mis-match can be
-- spotted and corrected rather than silently overwriting what they said.
ALTER TABLE member_profiles ADD COLUMN place_text TEXT;
ALTER TABLE member_profiles ADD COLUMN clan TEXT;

CREATE INDEX IF NOT EXISTS idx_member_profiles_place ON member_profiles (place_id);

-- ---------------------------------------------------------------------------
-- The AI-written overview of Ekori
--
-- Cloudflare Workers AI reads what the places have recorded about themselves
-- and writes one page that introduces Ekori as a whole.
--
-- KEPT AS A DRAFT UNTIL A PERSON APPROVES IT. A model writing about a real
-- community's history will get things wrong, and an archive that publishes
-- machine-written history unreviewed is worse than one with no overview at all.
-- Every version is kept, with the exact source material it was given, so a
-- reader can be told what it was written from.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS place_summaries (
  id             TEXT PRIMARY KEY,
  place_id       TEXT NOT NULL REFERENCES places (id) ON DELETE CASCADE,

  summary        TEXT NOT NULL,
  -- What the model was shown. Kept so a reviewer can check a claim against its
  -- source rather than against their memory.
  source_digest  TEXT,
  model          TEXT,

  -- Nothing generated is published without a person saying so.
  status         TEXT NOT NULL DEFAULT 'draft'
                   CHECK (status IN ('draft', 'approved', 'published', 'rejected', 'superseded')),
  approved_by    TEXT REFERENCES users (id) ON DELETE SET NULL,
  approved_at    TEXT,
  review_notes   TEXT,

  created_at     TEXT NOT NULL,
  updated_at     TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_place_summaries_place
  ON place_summaries (place_id, status, created_at DESC);

-- ---------------------------------------------------------------------------
-- Seed: Ekori and the places named so far
--
-- Enough of the real structure to be immediately useful, and correct as far as
-- it goes. Everything else arrives from the community — either created by an
-- administrator or promoted from what two people typed.
-- ---------------------------------------------------------------------------

INSERT OR IGNORE INTO places (id, slug, name, parent_id, kind, path, depth, sort_order, status, created_at, updated_at)
VALUES ('place_ekori', 'ekori', 'Ekori', NULL, 'village', 'Ekori', 0, 0, 'published', datetime('now'), datetime('now'));

INSERT OR IGNORE INTO places (id, slug, name, parent_id, kind, path, depth, sort_order, status, created_at, updated_at)
VALUES
  ('place_ajere',   'ajere',   'Ajere',   'place_ekori', 'ward', 'Ekori / Ajere',   1, 10, 'published', datetime('now'), datetime('now')),
  ('place_ntan',    'ntan',    'Ntan',    'place_ekori', 'ward', 'Ekori / Ntan',    1, 20, 'published', datetime('now'), datetime('now')),
  ('place_epenti',  'epenti',  'Epenti',  'place_ekori', 'ward', 'Ekori / Epenti',  1, 30, 'published', datetime('now'), datetime('now')),
  ('place_afrekpe', 'afrekpe', 'Afrekpe', 'place_ekori', 'ward', 'Ekori / Afrekpe', 1, 40, 'published', datetime('now'), datetime('now'));

-- Inside Ajere.
INSERT OR IGNORE INTO places (id, slug, name, parent_id, kind, path, depth, sort_order, status, created_at, updated_at)
VALUES
  ('place_edang',        'edang',        'Edang',        'place_ajere', 'quarter', 'Ekori / Ajere / Edang',        2, 10, 'published', datetime('now'), datetime('now')),
  ('place_odagum',       'odagum',       'Odagum',       'place_ajere', 'quarter', 'Ekori / Ajere / Odagum',       2, 20, 'published', datetime('now'), datetime('now')),
  ('place_ogbeti',       'ogbeti',       'Ogbeti',       'place_ajere', 'quarter', 'Ekori / Ajere / Ogbeti',       2, 30, 'published', datetime('now'), datetime('now')),
  ('place_yejele_kapil', 'yejele-kapil', 'Yejele Kapil', 'place_ajere', 'quarter', 'Ekori / Ajere / Yejele Kapil', 2, 40, 'published', datetime('now'), datetime('now')),
  ('place_okem',         'okem',         'Okem',         'place_ajere', 'quarter', 'Ekori / Ajere / Okem',         2, 50, 'published', datetime('now'), datetime('now')),
  ('place_little_bird',  'little-bird',  'Little Bird',  'place_ajere', 'quarter', 'Ekori / Ajere / Little Bird',  2, 60, 'published', datetime('now'), datetime('now'));

-- Inside Edang.
INSERT OR IGNORE INTO places (id, slug, name, parent_id, kind, path, depth, sort_order, status, created_at, updated_at)
VALUES
  ('place_ukekeya', 'ukekeya', 'Ukekeya', 'place_edang', 'compound', 'Ekori / Ajere / Edang / Ukekeya', 3, 10, 'published', datetime('now'), datetime('now'));

-- The beaches.
INSERT OR IGNORE INTO places (id, slug, name, parent_id, kind, path, depth, sort_order, status, created_at, updated_at)
VALUES
  ('place_ajere_beach',  'ajere-beach',  'Ajere Beach',  'place_ajere',  'beach', 'Ekori / Ajere / Ajere Beach',   2, 90, 'published', datetime('now'), datetime('now')),
  ('place_epenti_beach', 'epenti-beach', 'Epenti Beach', 'place_epenti', 'beach', 'Ekori / Epenti / Epenti Beach', 2, 90, 'published', datetime('now'), datetime('now'));

-- The names the same places are also known by.
INSERT OR IGNORE INTO place_aliases (id, place_id, alias, normalised, created_at)
VALUES
  ('alias_ekori_1', 'place_ekori', 'Ekoli-Yeden', 'ekoliyeden', datetime('now')),
  ('alias_ekori_2', 'place_ekori', 'Ekoli Yeden', 'ekoli yeden', datetime('now')),
  ('alias_ekori_3', 'place_ekori', 'Yeden',       'yeden',       datetime('now')),
  ('alias_ekori_4', 'place_ekori', 'Ekori Town',  'ekori town',  datetime('now'));

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------

INSERT OR IGNORE INTO site_settings (key, value, value_type, group_name, description, is_public, updated_at)
VALUES
  ('place_promotion_threshold', '2', 'number', 'places',
   'How many DIFFERENT people must name a place before it joins the list automatically',
   0, datetime('now')),

  ('place_ai_summary_enabled', 'true', 'boolean', 'places',
   'Whether Workers AI drafts an overview of Ekori from what the places record about themselves',
   0, datetime('now')),

  ('place_ai_model', '@cf/meta/llama-3.1-8b-instruct', 'string', 'places',
   'The Workers AI model used to draft place overviews',
   0, datetime('now'));
