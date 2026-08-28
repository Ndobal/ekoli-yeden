-- ===========================================================================
-- 0026  Contributing a person is a profile, not a form
-- ===========================================================================
--
-- The People section holds structured records — name, headline, profession,
-- biography, achievements, where they are, a photograph. Contributing one went
-- through the generic contribution form, which offers a title, a description
-- and a file.
--
-- So everything that makes a person's record useful arrived as one paragraph of
-- prose that a Heritage editor then had to take apart by hand, and most of it
-- arrived not at all, because nobody thinks to mention a birth year in a box
-- labelled "description".
--
-- This is the same reasoning that gave dictionary words their own submission
-- table in 0015: when the destination is structured, the contribution has to be
-- structured, or the structure is filled in by whoever reviews it — badly, and
-- from memory.
--
-- ---------------------------------------------------------------------------
-- CONSENT IS A COLUMN, NOT AN AFTERTHOUGHT
-- ---------------------------------------------------------------------------
--
-- Most of this archive is about places, practices and things. This is about
-- named people, many of them alive, and a community archive that publishes a
-- biography of a living person who never agreed to it has done something to
-- them rather than for them.
--
-- `is_living` and `consent_basis` are asked at submission and are what a
-- reviewer looks at first. Neither can be inferred later.
-- ===========================================================================

CREATE TABLE IF NOT EXISTS person_submissions (
  id                     TEXT PRIMARY KEY,

  -- The code the contributor keeps, in the same EY-XXXXXX form used elsewhere.
  reference_code         TEXT NOT NULL UNIQUE,

  -- --- The profile ---------------------------------------------------------
  name                   TEXT NOT NULL,
  also_known_as          TEXT,
  headline               TEXT,
  profession             TEXT,
  category               TEXT,

  biography              TEXT,
  -- A JSON array of strings rather than one blob, so a reviewer can promote
  -- them individually and the page can render them as a list.
  achievements           TEXT,

  birth_year             INTEGER,
  death_year             INTEGER,
  is_living              INTEGER CHECK (is_living IS NULL OR is_living IN (0, 1)),

  city                   TEXT,
  country                TEXT,
  community_area         TEXT,
  website_url            TEXT,

  -- What ties them to Ekoli-Yeden. The question the People section exists to
  -- answer, and the one a generic form never asks.
  connection_to_ekoli    TEXT,
  why_notable            TEXT,

  -- --- Media ---------------------------------------------------------------
  -- Uploaded through the contribution route into the submissions area, so
  -- nothing is public until a reviewer promotes it.
  photo_upload_id        TEXT REFERENCES submission_uploads (id) ON DELETE SET NULL,
  video_upload_id        TEXT REFERENCES submission_uploads (id) ON DELETE SET NULL,
  -- Anything further: more photographs, a document, a second recording.
  extra_upload_ids       TEXT,

  -- --- Consent -------------------------------------------------------------
  consent_basis          TEXT NOT NULL DEFAULT 'unspecified'
                           CHECK (consent_basis IN ('person_agreed', 'family_agreed',
                                                    'public_figure', 'deceased_historical',
                                                    'unspecified')),
  consent_note           TEXT,
  consent_contact        TEXT,

  -- --- Who is telling us ---------------------------------------------------
  contributor_name       TEXT,
  contributor_email      TEXT,
  contributor_phone      TEXT,
  contributor_relationship TEXT,
  submitted_by           TEXT REFERENCES users (id) ON DELETE SET NULL,

  -- --- Review --------------------------------------------------------------
  status                 TEXT NOT NULL DEFAULT 'pending_review'
                           CHECK (status IN ('pending_review', 'in_review', 'needs_more',
                                             'promoted', 'rejected', 'duplicate')),
  reviewed_by            TEXT REFERENCES users (id) ON DELETE SET NULL,
  reviewed_at            TEXT,
  review_notes           TEXT,

  -- Set once promoted, so a contributor can be shown the page they created.
  person_id              TEXT REFERENCES people (id) ON DELETE SET NULL,

  created_at             TEXT NOT NULL,
  updated_at             TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_person_submissions_status
  ON person_submissions (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_person_submissions_reference
  ON person_submissions (reference_code);
CREATE INDEX IF NOT EXISTS idx_person_submissions_submitter
  ON person_submissions (submitted_by);

-- ---------------------------------------------------------------------------
-- The people table gains what the builder collects
-- ---------------------------------------------------------------------------
--
-- Promotion should be a copy rather than a translation, so the destination
-- carries the same shape as the submission.
-- ---------------------------------------------------------------------------

ALTER TABLE people ADD COLUMN also_known_as TEXT;
ALTER TABLE people ADD COLUMN birth_year INTEGER;
ALTER TABLE people ADD COLUMN death_year INTEGER;
ALTER TABLE people ADD COLUMN is_living INTEGER CHECK (is_living IS NULL OR is_living IN (0, 1));
ALTER TABLE people ADD COLUMN community_area TEXT;
ALTER TABLE people ADD COLUMN connection_to_ekoli TEXT;

-- A short film about somebody says more than a paragraph can. Held as a media
-- asset like the photograph, so it flows into the Gallery the same way.
ALTER TABLE people ADD COLUMN video_media_id TEXT REFERENCES media_assets (id) ON DELETE SET NULL;

-- Which of the consent bases above the published record rests on. `people`
-- already had a free-text `consent_reference`; this is the part a reviewer can
-- filter and audit on.
ALTER TABLE people ADD COLUMN consent_basis TEXT NOT NULL DEFAULT 'unspecified'
  CHECK (consent_basis IN ('person_agreed', 'family_agreed', 'public_figure',
                           'deceased_historical', 'unspecified'));

CREATE INDEX IF NOT EXISTS idx_people_consent ON people (consent_basis, status);

-- ---------------------------------------------------------------------------
-- The words the page says
-- ---------------------------------------------------------------------------

INSERT OR IGNORE INTO content_strings
  (key, value, group_name, page, label, help_text, value_type, status, created_at, updated_at)
VALUES
  ('page.people.contribute_intro',
   'Tell us about somebody from Ekoli-Yeden — an elder, a teacher, a professional, somebody who '
   || 'did something worth remembering. Fill in as much as you know; a partial record is worth far '
   || 'more than none, and other people can add to it later.',
   'people', 'people',
   'People — introduction to contributing',
   'Shown at the top of the profile builder',
   'text', 'published', datetime('now'), datetime('now')),

  ('page.people.consent_notice',
   'If this person is alive, please only send what they are happy to have published. A community '
   || 'archive that publishes a biography of somebody who never agreed to it has done something to '
   || 'them rather than for them — so we ask, and we do not guess.',
   'people', 'people',
   'People — consent notice',
   'Shown beside the consent question. Please do not soften this.',
   'text', 'published', datetime('now'), datetime('now'));
