-- ---------------------------------------------------------------------------
-- EKOLI YEDEN DIGITAL HOME — Migration 0015
-- A real dictionary, not a word list.
--
-- WHAT WAS WRONG WITH THE OLD SHAPE
--
-- `language_words` had one meaning, one part of speech and one example
-- sentence per row. That is a glossary. A dictionary has to hold what a
-- language actually does:
--
--   * A word is often several parts of speech at once. In Lokaa as in English,
--     the same form can be a noun and a verb, and forcing a choice between
--     them loses half the entry.
--   * A word has senses, and each sense has its own part of speech, its own
--     definition and its own examples. Collapsing them into one field makes
--     the second meaning unfindable.
--   * A word has variants — how a different quarter says it, an older form, a
--     plural, an alternative spelling. Recorded as separate rows they are
--     searchable; recorded as a note in a text field they are not.
--   * An example sentence is a pair, not a string: the Lokaa sentence and its
--     English, plus how the Lokaa is pronounced. All three matter to a learner,
--     and the pronunciation matters most, because it is the part that written
--     words preserve worst.
--
-- The old columns are kept and backfilled rather than dropped. Entries already
-- recorded stay readable, and a language editor can migrate an entry to the
-- richer shape when they next touch it — not in one anxious pass.
--
-- WHAT HAS NOT CHANGED
--
-- Nothing here generates, guesses or completes the meaning of a word. Every
-- new column and every new table is a shelf, and every shelf is empty until a
-- native speaker or a recognised Lokaa scholar fills it. A sense with no
-- definition is displayed as awaiting one.
-- ---------------------------------------------------------------------------

-- ===========================================================================
-- THE HEADWORD
-- ===========================================================================

-- A word can be a noun AND a verb. JSON array of part-of-speech slugs; the
-- existing single `part_of_speech` column is kept and backfilled below so
-- nothing that reads it breaks.
ALTER TABLE language_words ADD COLUMN parts_of_speech TEXT;

-- How the word sounds, written down three ways because different readers need
-- different ones: a respelling anybody can read aloud, IPA for a linguist, and
-- the tone pattern, which is not optional in a tonal language — two words that
-- differ only in tone are two different words.
ALTER TABLE language_words ADD COLUMN phonetic_respelling TEXT;
ALTER TABLE language_words ADD COLUMN ipa TEXT;
ALTER TABLE language_words ADD COLUMN tone_pattern TEXT;

ALTER TABLE language_words ADD COLUMN plural_form TEXT;
ALTER TABLE language_words ADD COLUMN singular_form TEXT;

-- What the word literally says, where that differs from what it means. Often
-- the most interesting line in an entry.
ALTER TABLE language_words ADD COLUMN literal_translation TEXT;

ALTER TABLE language_words ADD COLUMN usage_notes TEXT;

-- Who says this, and when. A word used only by elders, or only at a funeral,
-- or only between age-mates, is mis-taught without this.
ALTER TABLE language_words ADD COLUMN register TEXT;

ALTER TABLE language_words ADD COLUMN etymology TEXT;
ALTER TABLE language_words ADD COLUMN see_also TEXT;

-- Search and browse support.
--
-- `word_normalised` is the word lowercased and stripped of the diacritics that
-- a visitor typing on a phone keyboard cannot produce. Searching it means
-- somebody who types the word without its tone marks still finds it, which is
-- how the dictionary will actually be used.
--
-- `initial_letter` drives the A–Z index. Stored rather than computed so the
-- index is one indexed read instead of a scan with substr() on every row.
ALTER TABLE language_words ADD COLUMN word_normalised TEXT;
ALTER TABLE language_words ADD COLUMN initial_letter TEXT;

-- Backfill. `lower()` in SQLite only folds ASCII, which is exactly right here:
-- the Worker writes the fully normalised form on every create and update, and
-- this is only ever the starting point for entries that already exist.
UPDATE language_words
SET word_normalised = lower(trim(word)),
    initial_letter = upper(substr(trim(word), 1, 1))
WHERE word_normalised IS NULL;

UPDATE language_words
SET parts_of_speech = '["' || part_of_speech || '"]'
WHERE parts_of_speech IS NULL
  AND part_of_speech IS NOT NULL
  AND trim(part_of_speech) <> '';

CREATE INDEX IF NOT EXISTS idx_language_words_normalised
  ON language_words (word_normalised);
CREATE INDEX IF NOT EXISTS idx_language_words_letter
  ON language_words (initial_letter, word_normalised);

-- ===========================================================================
-- PARTS OF SPEECH
--
-- A table rather than a CHECK constraint. Lokaa grammar is not English
-- grammar, and the categories the community's language scholars end up wanting
-- should not require a migration to add. The rows below are the ones every
-- dictionary needs; they are a starting vocabulary, not a claim about the
-- structure of the language.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS language_parts_of_speech (
  slug         TEXT PRIMARY KEY,
  label        TEXT NOT NULL,
  abbreviation TEXT,
  description  TEXT,
  sort_order   INTEGER NOT NULL DEFAULT 0,
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL
);

INSERT OR IGNORE INTO language_parts_of_speech (slug, label, abbreviation, description, sort_order, created_at, updated_at)
VALUES
  ('noun',         'Noun',         'n.',      'A person, place, thing or idea.', 10, '2026-08-26T00:00:00.000Z', '2026-08-26T00:00:00.000Z'),
  ('verb',         'Verb',         'v.',      'An action or a state.', 20, '2026-08-26T00:00:00.000Z', '2026-08-26T00:00:00.000Z'),
  ('adjective',    'Adjective',    'adj.',    'Describes a noun.', 30, '2026-08-26T00:00:00.000Z', '2026-08-26T00:00:00.000Z'),
  ('adverb',       'Adverb',       'adv.',    'Describes a verb, adjective or another adverb.', 40, '2026-08-26T00:00:00.000Z', '2026-08-26T00:00:00.000Z'),
  ('pronoun',      'Pronoun',      'pron.',   'Stands in for a noun.', 50, '2026-08-26T00:00:00.000Z', '2026-08-26T00:00:00.000Z'),
  ('preposition',  'Preposition',  'prep.',   'Relates one word to another.', 60, '2026-08-26T00:00:00.000Z', '2026-08-26T00:00:00.000Z'),
  ('conjunction',  'Conjunction',  'conj.',   'Joins words or clauses.', 70, '2026-08-26T00:00:00.000Z', '2026-08-26T00:00:00.000Z'),
  ('interjection', 'Interjection', 'interj.', 'An exclamation.', 80, '2026-08-26T00:00:00.000Z', '2026-08-26T00:00:00.000Z'),
  ('numeral',      'Numeral',      'num.',    'A number word.', 90, '2026-08-26T00:00:00.000Z', '2026-08-26T00:00:00.000Z'),
  ('determiner',   'Determiner',   'det.',    'Introduces a noun.', 100, '2026-08-26T00:00:00.000Z', '2026-08-26T00:00:00.000Z'),
  ('particle',     'Particle',     'part.',   'A small word carrying grammatical meaning.', 110, '2026-08-26T00:00:00.000Z', '2026-08-26T00:00:00.000Z'),
  ('ideophone',    'Ideophone',    'ideo.',   'A word that evokes an idea in sound — common across West African languages and rarely captured in a wordlist.', 120, '2026-08-26T00:00:00.000Z', '2026-08-26T00:00:00.000Z'),
  ('phrase',       'Phrase',       'phr.',    'A set expression rather than a single word.', 130, '2026-08-26T00:00:00.000Z', '2026-08-26T00:00:00.000Z');

-- ===========================================================================
-- SENSES
--
-- One row per distinct meaning. A word with three meanings has three rows,
-- numbered, each with its own part of speech — which is what lets the entry
-- read like a dictionary entry rather than a run-on sentence.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS language_senses (
  id               TEXT PRIMARY KEY,
  word_id          TEXT NOT NULL REFERENCES language_words (id) ON DELETE CASCADE,

  -- 1, 2, 3 — the numbers printed against each meaning.
  sense_number     INTEGER NOT NULL DEFAULT 1,

  part_of_speech   TEXT REFERENCES language_parts_of_speech (slug) ON DELETE SET NULL,

  -- The short gloss, and the fuller definition. Both stay NULL until somebody
  -- who speaks the language supplies them.
  english_meaning  TEXT,
  definition       TEXT,

  -- Where this sense is used, and by whom.
  usage_note       TEXT,
  register         TEXT,
  domain           TEXT,

  verification_status TEXT NOT NULL DEFAULT 'unverified'
                        CHECK (verification_status IN ('unverified', 'in_review', 'verified', 'disputed')),
  status           TEXT NOT NULL DEFAULT 'draft'
                     CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at       TEXT NOT NULL,
  updated_at       TEXT NOT NULL,
  UNIQUE (word_id, sense_number)
);

CREATE INDEX IF NOT EXISTS idx_language_senses_word ON language_senses (word_id, sense_number);
CREATE INDEX IF NOT EXISTS idx_language_senses_status ON language_senses (status);

-- Carry the existing single meaning across as sense 1, so no entry loses what
-- it already said. Entries with nothing recorded stay empty rather than
-- gaining a hollow sense row.
INSERT OR IGNORE INTO language_senses
  (id, word_id, sense_number, part_of_speech, english_meaning, definition,
   verification_status, status, created_at, updated_at)
SELECT
  'sense_' || w.id || '_1',
  w.id,
  1,
  CASE WHEN w.part_of_speech IN (SELECT slug FROM language_parts_of_speech)
       THEN w.part_of_speech ELSE NULL END,
  w.english_meaning,
  w.definition,
  w.verification_status,
  w.status,
  w.created_at,
  w.updated_at
FROM language_words w
WHERE w.english_meaning IS NOT NULL OR w.definition IS NOT NULL;

-- ===========================================================================
-- EXAMPLE SENTENCES
--
-- The pair, plus how to say it. A sentence in Lokaa with no pronunciation is
-- half an example: the learner can read it and still not know what it sounds
-- like. `media_asset_id` points at a recording of the whole sentence, which is
-- better than all three text fields together.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS language_examples (
  id               TEXT PRIMARY KEY,
  word_id          TEXT NOT NULL REFERENCES language_words (id) ON DELETE CASCADE,

  -- Which meaning this illustrates. NULL where it illustrates the word
  -- generally, which is the common case for a one-sense entry.
  sense_id         TEXT REFERENCES language_senses (id) ON DELETE SET NULL,

  -- The sentence in the language, and in English.
  sentence_ekoli   TEXT NOT NULL,
  sentence_english TEXT,

  -- How the Lokaa sentence is pronounced, written for somebody to read aloud.
  pronunciation    TEXT,

  -- A recording of the sentence itself, in R2 under `language/`.
  media_asset_id   TEXT REFERENCES media_assets (id) ON DELETE SET NULL,

  speaker          TEXT,
  context_note     TEXT,
  sort_order       INTEGER NOT NULL DEFAULT 0,
  status           TEXT NOT NULL DEFAULT 'draft'
                     CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at       TEXT NOT NULL,
  updated_at       TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_language_examples_word ON language_examples (word_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_language_examples_sense ON language_examples (sense_id);

-- Carry existing example sentences across.
INSERT OR IGNORE INTO language_examples
  (id, word_id, sense_id, sentence_ekoli, sentence_english, speaker, sort_order, status, created_at, updated_at)
SELECT
  'example_' || w.id || '_1',
  w.id,
  NULL,
  w.example_sentence,
  w.example_translation,
  w.speaker,
  0,
  w.status,
  w.created_at,
  w.updated_at
FROM language_words w
WHERE w.example_sentence IS NOT NULL AND trim(w.example_sentence) <> '';

-- ===========================================================================
-- VARIANTS
--
-- Ekoli-Yeden speech varies between families and quarters. A variant recorded
-- as its own row is findable by somebody who only knows that form; the same
-- variant written into a notes field is not. `variant_normalised` is searched
-- alongside the headword, so looking up a variant finds the main entry.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS language_variants (
  id                  TEXT PRIMARY KEY,
  word_id             TEXT NOT NULL REFERENCES language_words (id) ON DELETE CASCADE,
  variant             TEXT NOT NULL,
  variant_normalised  TEXT,

  variant_type        TEXT NOT NULL DEFAULT 'alternate'
                        CHECK (variant_type IN ('alternate', 'spelling', 'dialect', 'plural',
                                                'singular', 'archaic', 'diminutive', 'honorific')),

  -- Which quarter, family or age group says it this way.
  dialect_or_area     TEXT,
  speaker             TEXT,
  notes               TEXT,
  status              TEXT NOT NULL DEFAULT 'draft'
                        CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at          TEXT NOT NULL,
  updated_at          TEXT NOT NULL,
  UNIQUE (word_id, variant)
);

CREATE INDEX IF NOT EXISTS idx_language_variants_word ON language_variants (word_id);
CREATE INDEX IF NOT EXISTS idx_language_variants_search
  ON language_variants (variant_normalised, status);

-- The existing free-text `dialect_or_variation` becomes a first variant row
-- where it looks like a form rather than a sentence of commentary.
INSERT OR IGNORE INTO language_variants
  (id, word_id, variant, variant_normalised, variant_type, notes, status, created_at, updated_at)
SELECT
  'variant_' || w.id || '_1',
  w.id,
  trim(w.dialect_or_variation),
  lower(trim(w.dialect_or_variation)),
  'dialect',
  NULL,
  w.status,
  w.created_at,
  w.updated_at
FROM language_words w
WHERE w.dialect_or_variation IS NOT NULL
  AND trim(w.dialect_or_variation) <> ''
  AND length(trim(w.dialect_or_variation)) <= 60;

-- ===========================================================================
-- WORD CONTRIBUTIONS
--
-- Contributing a word is not contributing a photograph, and the general
-- contribution form was the wrong shape for it: a word arrives with variants,
-- parts of speech, several meanings and example sentences, none of which fit
-- in "title" and "description".
--
-- This is a separate queue for that reason. A submission holds the whole
-- proposed entry as structured JSON, so a language editor reviews something
-- that already looks like a dictionary entry and promotes it in one action
-- instead of retyping it.
--
-- Nothing here is ever published directly. `promoted_word_id` records what the
-- submission became, so the contributor stays connected to their word.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS word_submissions (
  id                     TEXT PRIMARY KEY,

  -- The code the contributor keeps, in the same EY-XXXXXX form used elsewhere.
  reference_code         TEXT NOT NULL UNIQUE,

  -- The headword, and the normalised form used to spot duplicates before a
  -- reviewer has to.
  word                   TEXT NOT NULL,
  word_normalised        TEXT,

  entry_type             TEXT NOT NULL DEFAULT 'word'
                           CHECK (entry_type IN ('word', 'phrase', 'greeting', 'proverb',
                                                 'idiom', 'number', 'name', 'song', 'riddle')),

  -- JSON arrays, matching the shape of the tables above so promotion is a
  -- copy rather than a translation:
  --   parts_of_speech  ["noun", "verb"]
  --   variants         [{ "variant": "...", "variant_type": "dialect", "dialect_or_area": "..." }]
  --   senses           [{ "part_of_speech": "noun", "english_meaning": "...", "definition": "..." }]
  --   examples         [{ "sentence_ekoli": "...", "sentence_english": "...", "pronunciation": "..." }]
  parts_of_speech        TEXT,
  variants               TEXT,
  senses                 TEXT,
  examples               TEXT,

  phonetic_respelling    TEXT,
  tone_pattern           TEXT,
  literal_translation    TEXT,
  usage_notes            TEXT,
  dialect_or_area        TEXT,
  category_id            TEXT REFERENCES language_categories (id) ON DELETE SET NULL,

  -- A recording of the word, uploaded through the contribution upload route.
  audio_upload_id        TEXT REFERENCES submission_uploads (id) ON DELETE SET NULL,

  -- Who supplied it. A word's authority rests on who said it, so this is the
  -- part of the record a language editor reads first.
  contributor_name       TEXT,
  contributor_email      TEXT,
  contributor_phone      TEXT,
  -- "Born and raised here", "my grandmother taught me this", "I am a Lokaa
  -- teacher". Free text, because the useful answers are not a fixed list.
  speaker_credentials    TEXT,
  submitted_by           TEXT REFERENCES users (id) ON DELETE SET NULL,
  consent_given          INTEGER NOT NULL DEFAULT 0 CHECK (consent_given IN (0, 1)),

  status                 TEXT NOT NULL DEFAULT 'pending_review'
                           CHECK (status IN ('pending_review', 'approved', 'rejected', 'promoted', 'archived')),
  review_notes           TEXT,
  reviewed_by            TEXT REFERENCES users (id) ON DELETE SET NULL,
  reviewed_at            TEXT,
  promoted_word_id       TEXT REFERENCES language_words (id) ON DELETE SET NULL,

  ip_hash                TEXT,
  created_at             TEXT NOT NULL,
  updated_at             TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_word_submissions_status
  ON word_submissions (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_word_submissions_word
  ON word_submissions (word_normalised);
CREATE INDEX IF NOT EXISTS idx_word_submissions_reference
  ON word_submissions (reference_code);

-- ===========================================================================
-- Settings.
-- ===========================================================================
INSERT OR IGNORE INTO site_settings (key, value, value_type, group_name, is_public, description, updated_at)
VALUES
  ('dictionary_contributions_open', 'true', 'boolean', 'language', 1,
   'Whether the public may propose new dictionary entries.',
   '2026-08-26T00:00:00.000Z'),
  ('dictionary_language_name', 'Lokaa', 'string', 'language', 1,
   'What the language is called on the dictionary pages. Ekoli-Yeden speaks Lokaa; the community '
   || 'can set whichever name it prefers to publish under.',
   '2026-08-26T00:00:00.000Z'),
  ('dictionary_page_size', '50', 'number', 'language', 1,
   'Entries shown per page in the dictionary.',
   '2026-08-26T00:00:00.000Z');

-- Dictionary page text, editable by the Editorial Team like every other string.
INSERT OR IGNORE INTO content_strings
  (key, value, draft_value, group_name, page, label, help_text, value_type,
   max_length, status, is_locked, sort_order, created_at, updated_at)
VALUES
  ('page.language.contribute.title', 'Contribute a word', NULL, 'pages', 'language',
   'Dictionary contribution form title', NULL, 'text', 120, 'published', 0, 300,
   '2026-08-26T00:00:00.000Z', '2026-08-26T00:00:00.000Z'),
  ('page.language.contribute.intro',
   'If you speak the language, you can add to this dictionary. Give the word, what it means, and '
   || 'a sentence using it. A recording of your own voice saying it is the most valuable part — it '
   || 'is the thing that written words preserve worst. A language editor checks every entry before '
   || 'it is published.',
   NULL, 'pages', 'language',
   'Dictionary contribution form introduction', NULL, 'text', 800, 'published', 0, 310,
   '2026-08-26T00:00:00.000Z', '2026-08-26T00:00:00.000Z'),
  ('page.language.search.hint',
   'Search in either direction — type a word in the language, or type the English meaning.',
   NULL, 'pages', 'language',
   'Hint above the dictionary search box', NULL, 'text', 200, 'published', 0, 320,
   '2026-08-26T00:00:00.000Z', '2026-08-26T00:00:00.000Z');
