-- ===========================================================================
-- 0034  FINISHING THE VISION
-- ===========================================================================
--
-- The proposal in `vision.md` describes twenty-six sections. Almost all of
-- them were built. This migration carries the schema for the seven that were
-- not, and they are a mixed set: two of them are a single missing row, and two
-- of them are whole projects the proposal names in capital letters.
--
-- Taken in the order of the proposal:
--
--   §8   VOICES OF EKORI          a table of its own — see below
--   §12  Births and Marriages     two news categories that were never seeded
--   §13  The Ekori Hall of Fame   the column existed; nothing read it
--   §14  Willingness to mentor    one field on a member's profile
--   §16  Digital map              the coordinates already exist. Nothing here
--   §17  Children's area          quizzes, and deliberately no scores
--   §18  Folktales                `content_items` needs no schema change
--
-- Two of those need no SQL at all and are recorded here so that the next
-- person reading this file knows they were considered rather than missed:
--
--   §16  `places.latitude` and `places.longitude` were added in 0028 and have
--        never been read. Nothing is wrong with the schema. What was missing
--        was a map, and a map is not a table.
--
--   §18  `content_items.content_type` carries NO CHECK constraint, by design,
--        so a folktale is a new value and not a new column. Nothing to alter.
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- §12  BIRTHS AND MARRIAGES
--
-- Seventeen news categories were seeded and these two were not. `obituaries`
-- was there from the start, so the archive could record that somebody had
-- died and had nowhere to record that somebody had been born or married.
--
-- For a village archive that is the wrong way round. Births and marriages are
-- the announcements a community actually makes most often, and they are the
-- ones a descendant searching this archive in fifty years will be looking for.
-- ---------------------------------------------------------------------------
INSERT OR IGNORE INTO news_categories (id, slug, name, description, accent, sort_order, created_at, updated_at)
VALUES
  ('newscat_births', 'births', 'Births',
   'New arrivals — announced by the family, and kept.',
   NULL, 45, datetime('now'), datetime('now')),

  ('newscat_marriages', 'marriages', 'Marriages',
   'Traditional and church marriages, and the joining of families.',
   NULL, 46, datetime('now'), datetime('now'));


-- ---------------------------------------------------------------------------
-- §14  WILLINGNESS TO MENTOR
--
-- The proposal lists this among the fields of the global directory, between
-- "area of expertise" and "website". It is the only field in that list that
-- asks the member to offer something rather than to describe themselves, and
-- it is the one most likely to put a young person from Ekori in touch with
-- somebody who can help them.
--
-- `open_to_opportunities` already exists and means something else: it says
-- this person would like to hear about work. Mentoring is the other
-- direction, so it is its own field and not a reuse of that one.
-- ---------------------------------------------------------------------------
ALTER TABLE member_profiles ADD COLUMN open_to_mentoring INTEGER NOT NULL DEFAULT 0
  CHECK (open_to_mentoring IN (0, 1));

-- What they are willing to help with, in their own words. Optional, and shown
-- only when they have switched mentoring on.
ALTER TABLE member_profiles ADD COLUMN mentoring_note TEXT;

CREATE INDEX IF NOT EXISTS idx_member_profiles_mentoring
  ON member_profiles (open_to_mentoring, listed_in_directory);


-- ---------------------------------------------------------------------------
-- §8  VOICES OF EKORI
--
-- The proposal asks for interviews with elders preserved as
--
--     Video + Audio + Written Transcript + English Interpretation
--
-- and that does not fit the `videos` table. `videos.youtube_video_id` is NOT
-- NULL, because a video archive of YouTube films is what that table is for.
-- An elder recorded on a phone in a compound with no film at all has no row
-- to sit in, and widening that column would mean rebuilding a table to hold
-- something that is not really a video.
--
-- So the oral history project gets its own table, which is what the proposal
-- describes anyway: it is section 8, a named project, not a category of film.
--
-- WHAT IS DIFFERENT ABOUT THIS TABLE
--
-- Consent is a column, not an afterthought. These recordings are of named
-- living people, often elderly, speaking about their own families. The archive
-- should be able to say who agreed to what, and an entry cannot be published
-- without that reference being filled in — enforced in the Worker, because
-- SQLite cannot make a CHECK depend on another row's status cleanly.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS recordings (
  id                     TEXT PRIMARY KEY,
  slug                   TEXT NOT NULL UNIQUE,
  title                  TEXT NOT NULL,
  summary                TEXT,

  -- Who is speaking. `speaker` is the name as it should be shown; the other
  -- two say who they are and how they are connected to what they describe.
  speaker                TEXT,
  speaker_role           TEXT,
  speaker_place_id       TEXT REFERENCES places (id) ON DELETE SET NULL,

  -- One of these two must be present. A recording with neither is a note, not
  -- a recording; the Worker refuses it.
  youtube_video_id       TEXT,
  audio_media_id         TEXT REFERENCES media_assets (id) ON DELETE SET NULL,

  -- The words. `transcript` is what was actually said, in whatever language it
  -- was said in. `english_interpretation` is separate on purpose: an
  -- interpretation is somebody's reading of the words and must never be
  -- mistaken for the words themselves.
  transcript             TEXT,
  transcript_language    TEXT NOT NULL DEFAULT 'ekoli'
                           CHECK (transcript_language IN ('ekoli', 'english', 'mixed', 'other')),
  english_interpretation TEXT,
  interpreted_by         TEXT,

  -- What it is about. The proposal's own list of topics.
  topic                  TEXT
                           CHECK (topic IS NULL OR topic IN (
                             'life_in_old_ekori', 'history', 'traditional_practices',
                             'leboku', 'marriage', 'naming', 'farming', 'food',
                             'songs', 'folklore', 'proverbs', 'community_development',
                             'historical_events', 'people', 'other')),

  recorded_at            TEXT,
  recorded_location      TEXT,
  recorded_by            TEXT,
  duration_seconds       INTEGER,

  -- Who agreed, and to what. Required before publication.
  consent_reference      TEXT,
  consent_note           TEXT,

  cover_media_id         TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  is_featured            INTEGER NOT NULL DEFAULT 0 CHECK (is_featured IN (0, 1)),
  sort_order             INTEGER NOT NULL DEFAULT 0,

  seo_title              TEXT,
  seo_description        TEXT,

  verification_status    TEXT NOT NULL DEFAULT 'unverified'
                           CHECK (verification_status IN ('unverified', 'in_review', 'verified', 'disputed')),

  author_id              TEXT REFERENCES users (id) ON DELETE SET NULL,
  editor_id              TEXT REFERENCES users (id) ON DELETE SET NULL,
  reviewer_id            TEXT REFERENCES users (id) ON DELETE SET NULL,
  published_by           TEXT REFERENCES users (id) ON DELETE SET NULL,
  submitted_at           TEXT,
  published_at_workflow  TEXT,
  review_notes           TEXT,

  status                 TEXT NOT NULL DEFAULT 'draft'
                           CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at             TEXT NOT NULL,
  updated_at             TEXT NOT NULL,

  -- A recording has to be one or the other, or both. Never neither.
  CHECK (youtube_video_id IS NOT NULL OR audio_media_id IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_recordings_status  ON recordings (status, sort_order);
CREATE INDEX IF NOT EXISTS idx_recordings_topic   ON recordings (topic, status);
CREATE INDEX IF NOT EXISTS idx_recordings_speaker ON recordings (speaker);
CREATE INDEX IF NOT EXISTS idx_recordings_place   ON recordings (speaker_place_id);


-- ---------------------------------------------------------------------------
-- §17  EKORI CHILDREN & EDUCATIONAL RESOURCES
--
-- "Interactive quizzes and learning activities can eventually be introduced."
--
-- WHAT IS DELIBERATELY NOT HERE
--
-- There is no attempts table, no scores table, and no per-child record of any
-- kind. A quiz is marked in the browser and the result is shown to the child
-- and then forgotten.
--
-- That is a deliberate refusal, not an omission to fill in later. The users of
-- this section are children, many of them in the diaspora and under thirteen.
-- Storing what a named child got wrong about their own heritage creates a
-- record that serves nobody here and would have to be protected forever. The
-- community wants children to learn the language, not to be assessed in it.
--
-- If the schools ever ask for class results, that is a different feature with
-- a different consent conversation, and it should be built then and not
-- quietly enabled by a column that was added early just in case.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS quizzes (
  id                  TEXT PRIMARY KEY,
  slug                TEXT NOT NULL UNIQUE,
  title               TEXT NOT NULL,
  description         TEXT,

  -- What the quiz is about, matching the proposal's list of what children
  -- should be able to learn.
  subject             TEXT NOT NULL DEFAULT 'general'
                        CHECK (subject IN ('language', 'greetings', 'numbers', 'proverbs',
                                           'history', 'culture', 'leboku', 'people',
                                           'places', 'values', 'general')),

  -- Roughly who it is for. Not an age gate — a signpost.
  level               TEXT NOT NULL DEFAULT 'starter'
                        CHECK (level IN ('starter', 'growing', 'confident')),

  intro               TEXT,
  closing             TEXT,
  cover_media_id      TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  sort_order          INTEGER NOT NULL DEFAULT 0,

  author_id           TEXT REFERENCES users (id) ON DELETE SET NULL,
  editor_id           TEXT REFERENCES users (id) ON DELETE SET NULL,
  reviewer_id         TEXT REFERENCES users (id) ON DELETE SET NULL,
  published_by        TEXT REFERENCES users (id) ON DELETE SET NULL,
  submitted_at        TEXT,
  published_at_workflow TEXT,
  review_notes        TEXT,

  status              TEXT NOT NULL DEFAULT 'draft'
                        CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at          TEXT NOT NULL,
  updated_at          TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_quizzes_status  ON quizzes (status, sort_order);
CREATE INDEX IF NOT EXISTS idx_quizzes_subject ON quizzes (subject, status);

CREATE TABLE IF NOT EXISTS quiz_questions (
  id            TEXT PRIMARY KEY,
  quiz_id       TEXT NOT NULL REFERENCES quizzes (id) ON DELETE CASCADE,
  prompt        TEXT NOT NULL,

  -- Shown after the child answers, right or wrong. This is the part that
  -- teaches; the score is not.
  explanation   TEXT,

  -- An Ekoli word or phrase the question is about, so a question can carry
  -- the language itself and not only a description of it.
  ekoli_text    TEXT,
  audio_media_id TEXT REFERENCES media_assets (id) ON DELETE SET NULL,

  display_order INTEGER NOT NULL DEFAULT 0,
  created_at    TEXT NOT NULL,
  updated_at    TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_quiz_questions_quiz ON quiz_questions (quiz_id, display_order);

CREATE TABLE IF NOT EXISTS quiz_options (
  id            TEXT PRIMARY KEY,
  question_id   TEXT NOT NULL REFERENCES quiz_questions (id) ON DELETE CASCADE,
  label         TEXT NOT NULL,
  is_correct    INTEGER NOT NULL DEFAULT 0 CHECK (is_correct IN (0, 1)),
  display_order INTEGER NOT NULL DEFAULT 0,
  created_at    TEXT NOT NULL,
  updated_at    TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_quiz_options_question ON quiz_options (question_id, display_order);


-- ---------------------------------------------------------------------------
-- §13  THE HALL OF FAME
--
-- `people.is_hall_of_fame` has existed since 0002 and `feature_hall_of_fame`
-- has been sitting in the settings at `false`. Neither was ever read, so the
-- flag was a promise the code did not keep.
--
-- The setting stays off. The community decides who belongs in a hall of fame,
-- and switching it on from a migration would be this archive deciding for
-- them. What changes is that the switch is now wired to something.
-- ---------------------------------------------------------------------------
INSERT OR IGNORE INTO site_settings (key, value, value_type, group_name, is_public, description, updated_at)
VALUES ('feature_hall_of_fame', 'false', 'boolean', 'features', 1,
        'Show the Hall of Fame. Off until the community decides who belongs in it.',
        datetime('now'));


-- ---------------------------------------------------------------------------
-- THE WORDING
--
-- Every visitor-facing line is a row, as everywhere else in this archive, so
-- the community can change it without a deployment.
-- ---------------------------------------------------------------------------
INSERT OR IGNORE INTO content_strings
  (key, value, draft_value, group_name, page, label, help_text,
   value_type, max_length, status, is_locked, sort_order, created_at, updated_at)
VALUES
  -- Voices of Ekori
  ('page.voices.title', 'Voices of Ekori', NULL, 'pages', 'voices',
   'The oral history page title', NULL, 'text', 120,
   'published', 0, 10, datetime('now'), datetime('now')),

  ('page.voices.intro',
   'Elders, traditional leaders and others who remember, recorded in their own words. Each '
   || 'recording is kept as it was spoken. Where an English interpretation is given it sits '
   || 'beside the original and never replaces it.',
   NULL, 'pages', 'voices', 'The line under the Voices heading', NULL, 'text', 600,
   'published', 0, 20, datetime('now'), datetime('now')),

  -- Stories and folklore
  ('page.stories.title', 'Stories and Folklore', NULL, 'pages', 'stories',
   'The stories page title', NULL, 'text', 120,
   'published', 0, 30, datetime('now'), datetime('now')),

  ('page.stories.intro',
   'Folktales, children''s stories and the long tellings that do not fit in a dictionary. '
   || 'Proverbs, riddles, praise names and songs live in the language section, where they can '
   || 'carry their pronunciation.',
   NULL, 'pages', 'stories', 'The line under the Stories heading', NULL, 'text', 600,
   'published', 0, 40, datetime('now'), datetime('now')),

  -- Children
  ('page.children.title', 'Learn About Ekori', NULL, 'pages', 'children',
   'The children''s area title', NULL, 'text', 120,
   'published', 0, 50, datetime('now'), datetime('now')),

  ('page.children.intro',
   'For children of Ekori, wherever they are growing up. Greetings, numbers, proverbs and the '
   || 'story of where your family comes from — with quizzes to try. Nothing you answer here is '
   || 'saved or sent anywhere.',
   NULL, 'pages', 'children', 'The line under the children''s heading', NULL, 'text', 600,
   'published', 0, 60, datetime('now'), datetime('now')),

  -- Map
  ('page.map.title', 'Discover Ekori', NULL, 'pages', 'map',
   'The map page title', NULL, 'text', 120,
   'published', 0, 70, datetime('now'), datetime('now')),

  ('page.map.intro',
   'The wards, quarters, compounds and landmarks of Ekori, and where they sit in relation to one '
   || 'another. Choose a place to read what is known about it.',
   NULL, 'pages', 'map', 'The line under the map heading', NULL, 'text', 600,
   'published', 0, 80, datetime('now'), datetime('now')),

  ('page.map.empty',
   'No positions have been recorded yet. The map will fill in as the community marks where each '
   || 'ward, quarter and landmark stands — and until somebody who knows records it, this archive '
   || 'will not guess.',
   NULL, 'pages', 'map', 'Shown when no place has coordinates', NULL, 'text', 600,
   'published', 0, 90, datetime('now'), datetime('now')),

  -- Hall of Fame
  ('page.hall.title', 'Ekori Hall of Fame', NULL, 'pages', 'hall',
   'The Hall of Fame title', NULL, 'text', 120,
   'published', 0, 100, datetime('now'), datetime('now')),

  ('page.hall.intro',
   'A permanent record of people who have contributed positively to Ekori and beyond. Entry is '
   || 'decided by the community, not by this website.',
   NULL, 'pages', 'hall', 'The line under the Hall of Fame heading', NULL, 'text', 600,
   'published', 0, 110, datetime('now'), datetime('now')),

  -- Mentoring
  ('profile.mentoring.question', 'Are you willing to mentor young people from Ekori?',
   NULL, 'membership', 'account',
   'The mentoring question on a member''s profile', NULL, 'text', 200,
   'published', 0, 120, datetime('now'), datetime('now'));
