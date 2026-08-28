-- ---------------------------------------------------------------------------
-- 0022  Events that carry their own pictures
-- ---------------------------------------------------------------------------
--
-- Festival editions already own an album each (0014), which is what makes a
-- photograph from Leboku 2026 appear in that year's album AND in the main
-- Gallery from a single upload.
--
-- Every other kind of gathering — a town hall meeting, a burial, a school
-- prize-giving, a launch — had nowhere to put its photographs. They went into
-- the general albums, if anywhere, and the occasion they belonged to was lost.
--
-- An event album works the same way a festival album does, for the same reason:
-- it is an ordinary gallery with an `event_id`, so nothing is filed twice.
-- ---------------------------------------------------------------------------

ALTER TABLE galleries ADD COLUMN event_id TEXT REFERENCES events (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_galleries_event ON galleries (event_id);

-- ---------------------------------------------------------------------------
-- What kind of gathering it is
-- ---------------------------------------------------------------------------
--
-- `category` already exists and is free text, which is useful for a programme
-- entry and useless for filtering a page. A closed list sits alongside it: the
-- community asked specifically for town hall meetings to be findable as such.
-- ---------------------------------------------------------------------------

ALTER TABLE events ADD COLUMN event_type TEXT NOT NULL DEFAULT 'gathering'
  CHECK (event_type IN ('town_hall', 'festival', 'ceremony', 'meeting', 'burial',
                        'launch', 'fundraiser', 'sport', 'religious', 'education',
                        'gathering', 'other'));

-- Which group is holding it, where a group is. An age grade's own meeting
-- should be findable from the age grade as well as from the events page.
ALTER TABLE events ADD COLUMN group_id TEXT REFERENCES community_groups (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_events_type ON events (event_type, start_datetime);
CREATE INDEX IF NOT EXISTS idx_events_group ON events (group_id, start_datetime);

-- ---------------------------------------------------------------------------
-- Albums for the events that already exist
-- ---------------------------------------------------------------------------
--
-- Only for published events. An album for a draft event would appear in the
-- Gallery's filter bar under a name nobody has approved yet.
--
-- The album's title carries the event's name and the year, because that is what
-- a photograph needs to be understood by somebody who was not there — "Town
-- hall meeting 2026" places a picture; "Album 47" does not.
-- ---------------------------------------------------------------------------

INSERT INTO galleries (
  id, slug, title, description, category, event_date, location,
  event_id, is_festival_gallery, sort_order, status, created_at, updated_at
)
SELECT
  'gal_event_' || e.id,
  'event-' || e.slug,
  e.title || CASE
    WHEN e.start_datetime IS NULL THEN ''
    ELSE ' — ' || substr(e.start_datetime, 1, 4)
  END,
  'Photographs and film from ' || e.title || '. Each one is labelled with what it shows, so that '
    || 'somebody who was not there can still understand it.',
  'event',
  e.start_datetime,
  COALESCE(e.venue, e.location),
  e.id,
  0,
  0,
  'published',
  datetime('now'),
  datetime('now')
FROM events e
WHERE e.status = 'published'
  AND NOT EXISTS (SELECT 1 FROM galleries g WHERE g.event_id = e.id);

-- ---------------------------------------------------------------------------
-- The page's own words
-- ---------------------------------------------------------------------------

INSERT OR IGNORE INTO content_strings
  (key, value, group_name, page, label, help_text, value_type, status, created_at, updated_at)
VALUES
  ('page.events.intro',
   'Meetings, ceremonies, festivals and gatherings of Ekoli-Yeden — what is coming, and what has '
   || 'already been held. Each one keeps its own photographs, so an occasion can still be seen '
   || 'years later.',
   'events', 'events',
   'Events — introduction',
   'The paragraph under the heading on the events page',
   'text', 'published', datetime('now'), datetime('now')),

  ('page.events.empty',
   'Nothing is listed yet. Events appear here as they are announced.',
   'events', 'events',
   'Events — when there are none',
   'Shown when no event has been published',
   'text', 'published', datetime('now'), datetime('now'));
