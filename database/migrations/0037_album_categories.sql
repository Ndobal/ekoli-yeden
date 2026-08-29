-- ===========================================================================
-- 0037  ONE VOCABULARY FOR ALBUM CATEGORIES
-- ===========================================================================
--
-- `galleries.category` was free text filled in by whoever seeded or created
-- each album, and it had become: 'festival', 'event', 'Leadership',
-- 'Community', 'Leboku', 'community'. Two of those differ only in case, one is
-- the name of a festival rather than a kind of album, and a filter built from
-- that list would offer "Community" and "community" as separate choices.
--
-- These are the values the Gallery's filters are built from. Still not a CHECK
-- constraint: a community will want a category nobody thought of, and adding
-- one should not need a migration. Anything unrecognised simply shows under
-- "All", which is the right failure.
--
-- WHY 'Leboku' IS NOT A CATEGORY
--
-- It is a festival, and an album belonging to it says so through `festival_id`.
-- The Gallery offers each festival as its own filter from that column, so
-- naming one in `category` would make Leboku both a kind of album and a
-- particular festival — and the two would disagree the moment somebody
-- retitled something.
-- ===========================================================================

UPDATE galleries SET category = lower(trim(category))
WHERE category IS NOT NULL AND category <> lower(trim(category));

UPDATE galleries SET category = 'festival'
WHERE category IN ('leboku', 'festivals', 'new yam', 'new yam festival');

UPDATE galleries SET category = 'leadership'
WHERE category IN ('leaders', 'traditional leadership', 'elders');

UPDATE galleries SET category = 'community'
WHERE category IN ('community life', 'community events', 'development');

UPDATE galleries SET category = 'event'
WHERE category IN ('events', 'ceremony', 'ceremonies');

-- An album attached to a festival is a festival album whatever it was called.
UPDATE galleries SET category = 'festival'
WHERE festival_id IS NOT NULL;

-- Everything still uncategorised becomes 'community', which is what an album
-- of photographs from Ekoli-Yeden is when nobody has said otherwise.
UPDATE galleries SET category = 'community'
WHERE category IS NULL OR category = '';

CREATE INDEX IF NOT EXISTS idx_galleries_category ON galleries (category, status);
