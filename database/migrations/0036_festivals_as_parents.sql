-- ===========================================================================
-- 0036  A FESTIVAL IS A PARENT, AND EACH YEAR IS AN ALBUM
-- ===========================================================================
--
-- Leboku is not an event that happened in 2026. It is a festival that has been
-- celebrated for generations and will be celebrated again, and the archive
-- should be able to say so — then show 2026, 2025, 2024 underneath it.
--
-- What was here instead was one row per festival-year: `festivals.year` was
-- NOT NULL and `UNIQUE (name, year)` made the pair the identity. "Leboku" had
-- no record of its own; there was only "Leboku 2026". Adding 2025 would have
-- created a second, unrelated festival, and the history of the festival would
-- have been retold in each row or lost.
--
-- ---------------------------------------------------------------------------
-- ONE ALBUM, TWO PLACES — WHICH WAS ALREADY HALF BUILT
-- ---------------------------------------------------------------------------
--
-- `galleries` already carries `festival_id` and `is_festival_gallery`. So a
-- year album is an ordinary gallery that happens to name a festival and a
-- year: the Gallery lists it beside every other album, and the festival page
-- groups the same rows by year.
--
-- One record, two doors. Nothing is copied, so a photograph added in either
-- place is in both, and neither can drift from the other.
--
-- That is why `festivals.gallery_id` goes: pointing from the festival to one
-- album was the old one-year-per-festival shape. Albums point at the festival
-- now, and there can be as many as there are years.
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- WHAT MAKES A GALLERY A YEAR OF A FESTIVAL
-- ---------------------------------------------------------------------------
ALTER TABLE galleries ADD COLUMN year INTEGER;

-- What happened that year, and who is in the photographs. Both are properties
-- of the celebration rather than of the festival, which is why they sit on the
-- album and not on the parent: the programme for 2026 is not the programme for
-- 2025, and saying so once per year is the whole point of an archive.
ALTER TABLE galleries ADD COLUMN programme TEXT;
ALTER TABLE galleries ADD COLUMN people_featured TEXT;

CREATE INDEX IF NOT EXISTS idx_galleries_festival_year
  ON galleries (festival_id, year DESC);


-- ---------------------------------------------------------------------------
-- THE FESTIVAL ITSELF
--
-- Rebuilt, because `year NOT NULL` and `UNIQUE (name, year)` are exactly the
-- two things that have to go, and SQLite cannot drop either in place.
--
-- Three tables point at `festivals` — events, galleries and videos — so the
-- rebuild has to survive their foreign keys. `PRAGMA defer_foreign_keys` is
-- the usual answer and D1 refuses it (SQLITE_AUTH), as it refuses
-- `CREATE TEMPORARY TABLE`. So the references are parked in an ordinary table,
-- the rebuild happens, and they are written back. Same shape as 0032.
-- ---------------------------------------------------------------------------

DROP TABLE IF EXISTS _festival_refs;
CREATE TABLE _festival_refs AS
  SELECT 'gallery' AS kind, id AS row_id, festival_id FROM galleries WHERE festival_id IS NOT NULL
  UNION ALL
  SELECT 'video', id, related_festival_id FROM videos WHERE related_festival_id IS NOT NULL
  UNION ALL
  SELECT 'event', id, festival_id FROM events WHERE festival_id IS NOT NULL;

UPDATE galleries SET festival_id = NULL;
UPDATE videos SET related_festival_id = NULL;
UPDATE events SET festival_id = NULL;

CREATE TABLE festivals_rebuilt (
  id                     TEXT PRIMARY KEY,
  slug                   TEXT NOT NULL UNIQUE,

  -- "Leboku", and "The Leboku New Yam Festival of Ekoli-Yeden".
  name                   TEXT NOT NULL UNIQUE,
  full_name              TEXT,
  tagline                TEXT,

  -- The four pieces of prose a festival needs. `description` is the long one.
  short_description      TEXT,
  description            TEXT,
  origin_significance    TEXT,
  cultural_significance  TEXT,

  -- "The last week of August, after the yam harvest" — a sentence, not a date,
  -- because that is how a community actually holds it.
  usually_celebrated     TEXT,

  -- One film for the festival as a whole. A year's films live on its album.
  youtube_video_id       TEXT,

  location               TEXT,
  place_id               TEXT REFERENCES places (id) ON DELETE SET NULL,

  -- Who runs it and who pays for it change slowly, so they stay on the parent.
  committee              TEXT,
  sponsors               TEXT,

  cover_media_id         TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  logo_media_id          TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  banner_media_id        TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  flier_media_id         TEXT REFERENCES media_assets (id) ON DELETE SET NULL,

  is_featured            INTEGER NOT NULL DEFAULT 0 CHECK (is_featured IN (0, 1)),
  is_archived            INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
  sort_order             INTEGER NOT NULL DEFAULT 0,

  seo_title              TEXT,
  seo_description        TEXT,
  seo_image_media_id     TEXT REFERENCES media_assets (id) ON DELETE SET NULL,

  author_id              TEXT REFERENCES users (id) ON DELETE SET NULL,
  editor_id              TEXT REFERENCES users (id) ON DELETE SET NULL,
  reviewer_id            TEXT REFERENCES users (id) ON DELETE SET NULL,
  published_by           TEXT REFERENCES users (id) ON DELETE SET NULL,
  submitted_at           TEXT,
  published_at_workflow  TEXT,
  review_notes           TEXT,

  status                 TEXT NOT NULL DEFAULT 'draft'
                           CHECK (status IN ('draft', 'pending_review', 'approved',
                                             'published', 'archived', 'rejected')),
  created_at             TEXT NOT NULL,
  updated_at             TEXT NOT NULL
);

-- The existing rows become their own parents.
--
-- `fest_leboku_2026` was "Leboku, 2026". It becomes "Leboku", and its 2026
-- celebration becomes the album below. The id is kept so nothing that already
-- points at it has to be rewritten, and the slug loses the year because the
-- record is no longer about one.
INSERT INTO festivals_rebuilt (
  id, slug, name, full_name, tagline, short_description, description,
  usually_celebrated, location, place_id, committee, sponsors,
  cover_media_id, logo_media_id, banner_media_id, flier_media_id,
  is_featured, is_archived, sort_order,
  seo_title, seo_description, seo_image_media_id,
  author_id, editor_id, reviewer_id, published_by,
  submitted_at, published_at_workflow, review_notes,
  status, created_at, updated_at
)
SELECT
  f.id,
  -- "leboku-2026" becomes "leboku". Where two years of the same festival exist
  -- only the earliest keeps the bare name; the rest are suffixed and can be
  -- merged by hand, which is safer than silently discarding one.
  CASE
    WHEN (SELECT COUNT(*) FROM festivals x WHERE x.name = f.name) = 1
      THEN lower(replace(f.name, ' ', '-'))
    ELSE f.slug
  END,
  f.name,
  f.full_name,
  f.tagline,
  f.theme,
  f.description,
  NULL,
  f.location,
  f.place_id,
  f.committee,
  f.sponsors,
  f.cover_media_id, f.logo_media_id, f.banner_media_id, f.flier_media_id,
  f.is_featured, f.is_archived, 0,
  f.seo_title, f.seo_description, f.seo_image_media_id,
  f.author_id, f.editor_id, f.reviewer_id, f.published_by,
  f.submitted_at, f.published_at_workflow, f.review_notes,
  f.status, f.created_at, f.updated_at
FROM festivals f
WHERE f.id = (SELECT MIN(x.id) FROM festivals x WHERE x.name = f.name);

-- Each old festival-year becomes an album of its parent.
--
-- Where a gallery was already attached, it is reused rather than a second one
-- being made — that gallery already holds the photographs.
UPDATE galleries
SET year = (SELECT f.year FROM festivals f WHERE f.gallery_id = galleries.id),
    is_festival_gallery = 1,
    programme = COALESCE(
      galleries.programme,
      (SELECT f.programme FROM festivals f WHERE f.gallery_id = galleries.id)
    )
WHERE EXISTS (SELECT 1 FROM festivals f WHERE f.gallery_id = galleries.id);

-- And the album points at the parent.
INSERT INTO _festival_refs (kind, row_id, festival_id)
SELECT 'gallery', f.gallery_id,
       (SELECT r.id FROM festivals_rebuilt r WHERE r.name = f.name)
FROM festivals f
WHERE f.gallery_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM _festival_refs fr WHERE fr.kind = 'gallery' AND fr.row_id = f.gallery_id
  );

-- Any reference to a festival-year that is no longer its own row is repointed
-- at the parent of the same name, so nothing is orphaned.
UPDATE _festival_refs
SET festival_id = COALESCE(
  (SELECT r.id FROM festivals_rebuilt r
    WHERE r.name = (SELECT f.name FROM festivals f WHERE f.id = _festival_refs.festival_id)),
  festival_id
);

DROP TABLE festivals;
ALTER TABLE festivals_rebuilt RENAME TO festivals;

CREATE INDEX IF NOT EXISTS idx_festivals_status ON festivals (status, sort_order);
CREATE INDEX IF NOT EXISTS idx_festivals_featured ON festivals (is_featured, status);

-- Write the references back, dropping any that no longer resolve.
UPDATE galleries
SET festival_id = (
  SELECT fr.festival_id FROM _festival_refs fr
  WHERE fr.kind = 'gallery' AND fr.row_id = galleries.id
)
WHERE EXISTS (
  SELECT 1 FROM _festival_refs fr
  WHERE fr.kind = 'gallery' AND fr.row_id = galleries.id
    AND fr.festival_id IN (SELECT id FROM festivals)
);

UPDATE videos
SET related_festival_id = (
  SELECT fr.festival_id FROM _festival_refs fr
  WHERE fr.kind = 'video' AND fr.row_id = videos.id
)
WHERE EXISTS (
  SELECT 1 FROM _festival_refs fr
  WHERE fr.kind = 'video' AND fr.row_id = videos.id
    AND fr.festival_id IN (SELECT id FROM festivals)
);

UPDATE events
SET festival_id = (
  SELECT fr.festival_id FROM _festival_refs fr
  WHERE fr.kind = 'event' AND fr.row_id = events.id
)
WHERE EXISTS (
  SELECT 1 FROM _festival_refs fr
  WHERE fr.kind = 'event' AND fr.row_id = events.id
    AND fr.festival_id IN (SELECT id FROM festivals)
);

DROP TABLE _festival_refs;


-- ---------------------------------------------------------------------------
-- ALBUM CATEGORIES, FOR THE GALLERY'S FILTERS
--
-- `galleries.category` already exists and was free text. These are the values
-- the filters offer; anything else still stores and still shows under "All".
-- Not a CHECK constraint: a community will want a category nobody thought of,
-- and it should not need a migration to add one.
-- ---------------------------------------------------------------------------
UPDATE galleries SET category = 'festival'
WHERE is_festival_gallery = 1 AND (category IS NULL OR category = '');

UPDATE galleries SET category = 'community'
WHERE id = 'gal_community_contributions';


-- ---------------------------------------------------------------------------
-- THE WORDING
-- ---------------------------------------------------------------------------
INSERT OR IGNORE INTO content_strings
  (key, value, draft_value, group_name, page, label, help_text,
   value_type, max_length, status, is_locked, sort_order, created_at, updated_at)
VALUES
  ('page.festivals.archive_title', 'Festival Archive', NULL, 'pages', 'festivals',
   'The heading above the year-by-year list', NULL, 'text', 120,
   'published', 0, 10, datetime('now'), datetime('now')),

  ('page.festivals.archive_intro',
   'Every celebration the archive holds, year by year. Each year has its own album of '
   || 'photographs and film.',
   NULL, 'pages', 'festivals', 'The line under the archive heading', NULL, 'text', 400,
   'published', 0, 20, datetime('now'), datetime('now')),

  ('page.festivals.no_years',
   'No celebrations have been recorded for this festival yet. When photographs and film from a '
   || 'year are added, that year appears here.',
   NULL, 'pages', 'festivals', 'Shown when a festival has no albums', NULL, 'text', 400,
   'published', 0, 30, datetime('now'), datetime('now'));
