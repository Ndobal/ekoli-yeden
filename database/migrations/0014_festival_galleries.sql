-- ---------------------------------------------------------------------------
-- EKOLI YEDEN DIGITAL HOME — Migration 0014
-- A gallery for every festival, every year.
--
-- THE PROBLEM THIS SOLVES
--
-- Leboku 2026 and Leboku 2027 are already separate records, which is what makes
-- the section an archive rather than a page that is overwritten annually. But
-- the photographs had nowhere to go: `galleries.festival_id` existed and
-- `festivals.gallery_id` existed, and nothing ever filled either in. A
-- photograph taken at the 2026 festival could be uploaded to the media library
-- and then belonged to no year at all.
--
-- After this migration every festival has exactly one gallery, created with it
-- and pointed at from both directions. Photographs land in the year they were
-- taken, and because a festival gallery is an ordinary row in `galleries`, the
-- same photographs also appear in the main Gallery section without being
-- filed twice. One upload, two places, one record.
--
-- The galleries created here inherit the festival's own status. A gallery
-- attached to a draft festival is itself a draft, so preparing next year's
-- festival page cannot accidentally publish an empty photograph album.
-- ---------------------------------------------------------------------------

-- --------------------------------------------------------------------------
-- Provenance on a gallery item.
--
-- A photograph that arrives through the public contribution form and one that
-- a Media Team volunteer uploads are both gallery items, but only one of them
-- has somebody outside the team to thank. `contributed_by` carries the name
-- through to the caption; `submission_upload_id` keeps the link back to what
-- was actually sent, so "is this really the photograph she gave us?" stays
-- answerable years later.
-- --------------------------------------------------------------------------
ALTER TABLE gallery_items ADD COLUMN contributed_by TEXT;
ALTER TABLE gallery_items ADD COLUMN submission_upload_id TEXT
  REFERENCES submission_uploads (id) ON DELETE SET NULL;
ALTER TABLE gallery_items ADD COLUMN added_by TEXT REFERENCES users (id) ON DELETE SET NULL;

-- The main Gallery section reads every published item across every gallery in
-- one query, newest first. Without this index that becomes a full scan the day
-- the archive has real material in it.
CREATE INDEX IF NOT EXISTS idx_gallery_items_status
  ON gallery_items (status, taken_at DESC);

-- --------------------------------------------------------------------------
-- Distinguishes a festival's own gallery from any other gallery that happens
-- to be about the festival.
--
-- A festival may well end up with several galleries — "the wrestling", "the
-- procession" — but exactly one of them is the album the festival page shows
-- and new photographs default into. That one is flagged here rather than
-- inferred from creation order, which would silently pick the wrong album the
-- first time somebody deleted and recreated one.
-- --------------------------------------------------------------------------
ALTER TABLE galleries ADD COLUMN is_festival_gallery INTEGER NOT NULL DEFAULT 0
  CHECK (is_festival_gallery IN (0, 1));

-- Photographs and videos both belong to a year. Videos already carry
-- `related_festival_id`; this is the equivalent for the album itself.
CREATE INDEX IF NOT EXISTS idx_galleries_festival_primary
  ON galleries (festival_id, is_festival_gallery);

-- --------------------------------------------------------------------------
-- Backfill: one gallery per existing festival.
--
-- Guarded by NOT EXISTS so that re-running on a database where somebody has
-- already made a festival gallery by hand does not produce a second one. The
-- id is derived from the festival id rather than random, which makes the
-- statement idempotent and makes the relationship legible to anybody reading
-- the table directly.
-- --------------------------------------------------------------------------
INSERT OR IGNORE INTO galleries (
  id, slug, title, description, category, event_date, location,
  festival_id, is_festival_gallery, sort_order, status, created_at, updated_at
)
SELECT
  'gallery_' || f.id,
  f.slug || '-photographs',
  f.name || ' ' || f.year || ' — photographs',
  'Photographs from ' || f.name || ' ' || f.year || '. Each one is labelled with '
    || 'what it shows, so that somebody who was not there can still understand it.',
  'festival',
  f.start_date,
  f.location,
  f.id,
  1,
  -- Negative year sorts the newest festival album first under the default
  -- `sort_order ASC` used by every gallery listing.
  -f.year,
  f.status,
  datetime('now'),
  datetime('now')
FROM festivals f
WHERE NOT EXISTS (
  SELECT 1 FROM galleries g WHERE g.festival_id = f.id
);

-- Point each festival at its gallery, so the festival page can load its
-- photographs without a second lookup.
UPDATE festivals
SET gallery_id = (
  SELECT g.id FROM galleries g
  WHERE g.festival_id = festivals.id
  ORDER BY g.is_festival_gallery DESC, g.created_at ASC
  LIMIT 1
)
WHERE gallery_id IS NULL OR gallery_id = '';

-- Where a festival gallery already existed before this migration, flag it as
-- the primary one so the festival page and the upload default agree.
UPDATE galleries
SET is_festival_gallery = 1
WHERE festival_id IS NOT NULL
  AND id IN (SELECT gallery_id FROM festivals WHERE gallery_id IS NOT NULL);

-- --------------------------------------------------------------------------
-- Settings.
-- --------------------------------------------------------------------------
INSERT OR IGNORE INTO site_settings (key, value, value_type, group_name, is_public, description, updated_at)
VALUES
  ('festival_gallery_auto_create', 'true', 'boolean', 'festivals', 0,
   'Create a gallery automatically whenever a new festival edition is added, so photographs '
   || 'always have a year to belong to.',
   '2026-08-26T00:00:00.000Z'),
  ('gallery_show_all_photographs', 'true', 'boolean', 'gallery', 1,
   'Show a combined stream of every published photograph on the Gallery page, alongside the '
   || 'individual albums. Festival photographs appear in both.',
   '2026-08-26T00:00:00.000Z');
