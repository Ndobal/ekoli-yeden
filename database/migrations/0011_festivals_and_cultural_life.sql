-- ---------------------------------------------------------------------------
-- EKOLI YEDEN DIGITAL HOME — Migration 0011
-- Generalises festivals, gives them a programme, and adds the community's
-- age grades, cultural groups and cultural music.
--
-- WHY THIS CHANGES THE SHAPE OF THE SITE
--
-- Leboku was being treated as *the* festival. It is one of them. The section
-- becomes "Festivals": the Editorial Team creates a festival, visitors see the
-- current or upcoming one given prominence and the past ones listed beneath it,
-- and each has its own page with its own programme.
--
-- A festival is not a single day. There is a run-up, a main day, and activities
-- afterwards — so a programme entry now records which phase it belongs to and
-- where it sits in the order.
--
-- SOURCE OF WHAT IS SEEDED HERE
--
-- Unlike migrations 0009 and 0010, the facts below come from the community
-- itself rather than from web sources: the festival's full name and tagline are
-- read from the official 2026 logo supplied by the community, and the age
-- grades, cultural groups and musical forms were named directly by a community
-- member. That is a better source than anything scraped, and it is recorded as
-- such — but details beyond the names have still not been invented. Each record
-- carries the name and an honest statement of what remains to be documented.
-- ---------------------------------------------------------------------------

-- ===========================================================================
-- FESTIVALS — identity and branding
-- ===========================================================================

-- The full ceremonial name, where it differs from the short one people use.
ALTER TABLE festivals ADD COLUMN full_name TEXT;
-- The festival's own logo, held in R2 like any other media.
ALTER TABLE festivals ADD COLUMN logo_media_id TEXT REFERENCES media_assets (id) ON DELETE SET NULL;
-- The line that appears on the festival's own materials.
ALTER TABLE festivals ADD COLUMN tagline TEXT;
-- Marks the edition the site should feature. Exactly one should be set.
ALTER TABLE festivals ADD COLUMN is_featured INTEGER NOT NULL DEFAULT 0
  CHECK (is_featured IN (0, 1));

-- ===========================================================================
-- PROGRAMME — a festival has a shape, not just a date
-- ===========================================================================

-- Which part of the festival an activity belongs to. The run-up matters: much
-- of what a festival is happens before the main day.
ALTER TABLE events ADD COLUMN festival_phase TEXT
  CHECK (festival_phase IS NULL OR festival_phase IN ('lead_up', 'main_day', 'after', 'other'));
-- A human label for the day, e.g. "Day 1" or "Eve of the festival", because a
-- programme is often planned by day before the calendar dates are fixed.
ALTER TABLE events ADD COLUMN programme_day TEXT;
-- Ordering within a phase, for programmes that have no times yet.
ALTER TABLE events ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0;
-- The headline activities a visitor should see first.
ALTER TABLE events ADD COLUMN is_headline INTEGER NOT NULL DEFAULT 0
  CHECK (is_headline IN (0, 1));

CREATE INDEX IF NOT EXISTS idx_events_festival_phase
  ON events (festival_id, festival_phase, sort_order);

-- ===========================================================================
-- LEKOLI BOKU 2026
--
-- Name and tagline taken from the official 2026 festival logo supplied by the
-- community. Dates and the full programme are still not seeded — those are the
-- Leboku Manager's to enter once fixed.
-- ===========================================================================

UPDATE festivals
SET name = 'Leboku',
    full_name = 'Lekoli Boku New Yam Festival',
    tagline = 'Celebrating Our Heritage, Yam and Unity',
    theme = 'Celebrating Our Heritage, Yam and Unity',
    is_featured = 1,
    description = 'Lekoli Boku — commonly called Leboku — is the New Yam Festival of Ekoli-Yeden. The 2026 edition is held under the words carried on its official logo: Celebrating Our Heritage, Yam and Unity.

The festival is not a single day. There is a run-up of activities leading to the main day, the main celebration itself, and further activities afterwards. The programme below fills out as the committee confirms it.

Dates, the full programme, the committee and the announcements for this edition have not been published here yet. They will be added by the Leboku Manager once the community has confirmed them — nothing about the festival has been assumed.',
    seo_title = 'Lekoli Boku New Yam Festival 2026 — Ekoli Yeden Digital Home',
    seo_description = 'Lekoli Boku (Leboku) 2026, the New Yam Festival of Ekoli-Yeden: Celebrating Our Heritage, Yam and Unity. Programme, events, photographs and videos.',
    updated_at = '2026-08-12T00:00:00.000Z'
WHERE id = 'fest_leboku_2026';

-- ---------------------------------------------------------------------------
-- Known festival activities.
--
-- Only activities the community has actually named are seeded. No dates or
-- times are invented — each carries its phase and its order so the programme
-- reads correctly while the calendar is still being fixed.
-- ---------------------------------------------------------------------------
INSERT OR IGNORE INTO events
  (id, slug, title, description, category, start_datetime, end_datetime, location, venue,
   organiser, contact_info, festival_id, is_featured, festival_phase, programme_day,
   sort_order, is_headline, seo_title, seo_description, status, created_at, updated_at)
VALUES
  ('evt_leboku26_pageant', 'mr-and-mrs-leboku-2026', 'Mr & Mrs Leboku Pageant',
   'The pageant held as part of the Lekoli Boku New Yam Festival.

The date, venue, entry requirements and the names of past winners have not been recorded here yet. If you hold that information — particularly results from previous years — the archive would welcome it.',
   'Pageant', NULL, NULL, NULL, NULL, NULL, NULL,
   'fest_leboku_2026', 1, 'lead_up', NULL, 1, 1,
   'Mr & Mrs Leboku Pageant 2026', 'The Mr & Mrs Leboku pageant, part of the Lekoli Boku New Yam Festival.',
   'published', '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),

  ('evt_leboku26_mainday', 'leboku-2026-main-day', 'Main Day Celebration',
   'The main day of the Lekoli Boku New Yam Festival.

The date, the order of the day and the rites that mark it have not been published here. They will be added once the committee confirms them.',
   'Celebration', NULL, NULL, NULL, NULL, NULL, NULL,
   'fest_leboku_2026', 1, 'main_day', NULL, 1, 1,
   'Leboku 2026 Main Day', 'The main day of the Lekoli Boku New Yam Festival 2026.',
   'published', '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z');

-- ===========================================================================
-- AGE GRADES, CULTURAL GROUPS AND CULTURAL MUSIC
--
-- Three new content types, stored in the shared `content_items` table and
-- discriminated by `content_type` — the same arrangement culture articles use.
--
-- The names below were supplied by a member of the community. Everything
-- beyond the name is left to be documented, and each record says so.
-- ===========================================================================

INSERT OR IGNORE INTO content_items
  (id, content_type, slug, title, subtitle, excerpt, body, category,
   verification_status, research_edition, sort_order, status, created_at, updated_at)
VALUES
  -- --- Cultural groups ---------------------------------------------------
  ('grp_obam', 'cultural_groups', 'obam', 'Obam', 'Cultural group',
   'A cultural group of Ekoli-Yeden. Its history and practice are still to be documented.',
   'Obam is one of the cultural groups of Ekoli-Yeden.

WHAT THIS RECORD STILL NEEDS

What the group is, and what it does. How and when it was formed. Who may belong to it, and how membership is entered. What it wears, plays or performs, and on which occasions. Its role in the festival year and in the life of the community. What elders remember of it from earlier generations.

The name is recorded here because a member of the community supplied it. The rest belongs to the people who know the group, and the archive would welcome their account.',
   'Cultural group', 'unverified', 0, 1, 'published',
   '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),

  ('grp_igban', 'cultural_groups', 'igban', 'Igban', 'Cultural group',
   'A cultural group of Ekoli-Yeden. Its history and practice are still to be documented.',
   'Igban is one of the cultural groups of Ekoli-Yeden.

WHAT THIS RECORD STILL NEEDS

What the group is, and what it does. How and when it was formed. Who may belong to it, and how membership is entered. What it wears, plays or performs, and on which occasions. Its role in the festival year and in the life of the community.

The name is recorded here because a member of the community supplied it. Everything else is still to be told.',
   'Cultural group', 'unverified', 0, 2, 'published',
   '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),

  -- --- Cultural music ----------------------------------------------------
  ('mus_onene', 'cultural_music', 'onene', 'Onene', 'Cultural music',
   'A musical form of Ekoli-Yeden. Its instruments, occasions and repertoire are still to be recorded.',
   'Onene is one of the musical forms of Ekoli-Yeden.

WHAT THIS RECORD STILL NEEDS

What Onene sounds like, and what instruments carry it. Who plays it, and how the playing is learned. On which occasions it is performed. What its songs say, and in which language. Whether particular groups or families hold it.

A RECORDING WOULD MATTER MORE THAN A DESCRIPTION

Music is the part of a heritage that written words preserve worst. A single recording of Onene being played, with the names of the players and the occasion, would be worth more to this archive than several pages about it. Audio can be uploaded through the contribution page; video can be published on YouTube and catalogued here.',
   'Music', 'unverified', 0, 1, 'published',
   '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),

  -- --- Age grades --------------------------------------------------------
  ('age_overview', 'age_grades', 'about-the-age-grades', 'The Age Grades of Ekoli-Yeden',
   'How the community organises itself by generation',
   'Age grades are one of the structures by which Ekoli-Yeden organises itself. The individual grades and their responsibilities are still to be recorded.',
   'Ekoli-Yeden organises itself in part through age grades — groupings of people of a similar age who take on responsibilities together.

Published sources refer to age-grade associations in Ekori under the name Ekoh, and describe a wrestling practice, KEPU, used when celebrating people of certain ages. A member of the community has confirmed that age grades are part of how the community is organised.

WHAT THIS SECTION IS FOR

Each age grade should have its own record here: its name, when it was formed, who belongs to it, what it is responsible for, what marks its formation and its milestones, and what it has done for the community.

That is a substantial piece of work, and it is exactly the kind that becomes impossible once the people who remember the older grades are gone. It is also the kind that only the community can do — nothing about the age grades has been written here from assumption.

If you belong to an age grade, or can name the grades and the years they were formed, please use the contribution page. Photographs of a grade together are particularly valuable.',
   'Age grades', 'unverified', 0, 1, 'published',
   '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z');

-- Cite the sources that touch age grades.
INSERT OR IGNORE INTO content_sources
  (id, resource_type, resource_id, source_id, supports, page_reference, sort_order, created_at)
VALUES
  ('csrc_age_1', 'age_grades', 'age_overview', 'src_wikipedia_ekori',
   'Age-grade associations referred to as Ekoh, and KEPU as a practice marking certain ages',
   NULL, 1, '2026-08-12T00:00:00.000Z');

-- ===========================================================================
-- NAVIGATION — Leboku becomes Festivals
-- ===========================================================================

UPDATE navigation_items
SET label = 'Festivals',
    path = '/festivals',
    description = 'Lekoli Boku and the festivals of Ekoli-Yeden',
    updated_at = '2026-08-12T00:00:00.000Z'
WHERE id = 'nav_leboku';

INSERT OR IGNORE INTO navigation_items
  (id, menu, label, path, description, is_cta, sort_order, status, created_at, updated_at)
VALUES
  ('nav_f_agegrades', 'footer', 'Age grades', '/age-grades', NULL, 0, 7, 'published', '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),
  ('nav_f_groups', 'footer', 'Cultural groups', '/cultural-groups', NULL, 0, 8, 'published', '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),
  ('nav_f_music', 'footer', 'Cultural music', '/music', NULL, 0, 9, 'published', '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z');

-- ===========================================================================
-- CONTENT STRINGS for the new sections
-- ===========================================================================

INSERT OR IGNORE INTO content_strings
  (key, value, draft_value, group_name, page, label, help_text, value_type, max_length, status, is_locked, sort_order, created_at, updated_at)
VALUES
  ('page.festivals.title', 'Festivals', NULL, 'pages', 'festivals', 'Festivals page title', NULL, 'text', 120, 'published', 0, 150, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),
  ('page.festivals.intro',
   'The festivals of Ekoli-Yeden, each with its own permanent page. Lekoli Boku — the New Yam Festival — is the largest, but it is not the only one. Every edition keeps its programme, announcements, photographs and videos, so that when a festival ends the year is not lost.',
   NULL, 'pages', 'festivals', 'Festivals introduction', NULL, 'richtext', 800, 'published', 0, 151, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),
  ('page.festivals.upcoming_label', 'Coming up', NULL, 'pages', 'festivals', 'Label above the featured festival', NULL, 'text', 60, 'published', 0, 152, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),
  ('page.festivals.past_label', 'Past festivals', NULL, 'pages', 'festivals', 'Heading above earlier editions', NULL, 'text', 60, 'published', 0, 153, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),
  ('page.festivals.empty',
   'No festival has been published yet. When the Editorial Team creates one, it appears here with its programme, its events and its archive.',
   NULL, 'pages', 'festivals', 'Festivals empty state', NULL, 'richtext', 400, 'published', 0, 154, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),

  ('festival.programme.title', 'Programme of events', NULL, 'festival', NULL, 'Programme heading', NULL, 'text', 80, 'published', 0, 160, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),
  ('festival.phase.lead_up', 'Leading up to the main day', NULL, 'festival', NULL, 'Run-up phase heading', NULL, 'text', 80, 'published', 0, 161, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),
  ('festival.phase.main_day', 'The main day', NULL, 'festival', NULL, 'Main day heading', NULL, 'text', 80, 'published', 0, 162, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),
  ('festival.phase.after', 'After the main day', NULL, 'festival', NULL, 'Post-festival heading', NULL, 'text', 80, 'published', 0, 163, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),
  ('festival.phase.other', 'Other activities', NULL, 'festival', NULL, 'Other activities heading', NULL, 'text', 80, 'published', 0, 164, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),
  ('festival.programme.empty',
   'The programme for this festival has not been published yet. It will appear here once the committee has confirmed it.',
   NULL, 'festival', NULL, 'Empty programme notice', NULL, 'richtext', 400, 'published', 0, 165, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),

  ('page.age_grades.title', 'Age Grades', NULL, 'pages', 'age-grades', 'Age grades page title', NULL, 'text', 120, 'published', 0, 170, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),
  ('page.age_grades.intro',
   'Age grades are one of the ways Ekoli-Yeden organises itself — groupings of people of a similar age who take on responsibilities together. Each grade should have its own record here: its name, when it was formed, who belongs to it, and what it has done.',
   NULL, 'pages', 'age-grades', 'Age grades introduction', NULL, 'richtext', 800, 'published', 0, 171, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),

  ('page.cultural_groups.title', 'Cultural Groups', NULL, 'pages', 'cultural-groups', 'Cultural groups page title', NULL, 'text', 120, 'published', 0, 172, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),
  ('page.cultural_groups.intro',
   'The cultural groups of Ekoli-Yeden — among them Obam and Igban. Each carries its own practice, its own occasions and its own membership, and each deserves a full record here.',
   NULL, 'pages', 'cultural-groups', 'Cultural groups introduction', NULL, 'richtext', 800, 'published', 0, 173, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),

  ('page.music.title', 'Cultural Music', NULL, 'pages', 'music', 'Music page title', NULL, 'text', 120, 'published', 0, 174, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),
  ('page.music.intro',
   'The musical forms of Ekoli-Yeden — among them Onene. Music is the part of a heritage that written words preserve worst, which is why a recording matters here more than a description. If you can record a performance, with the players named and the occasion given, that is among the most valuable things this archive can receive.',
   NULL, 'pages', 'music', 'Music introduction', NULL, 'richtext', 800, 'published', 0, 175, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z');

-- The homepage festival section now speaks of festivals in general.
UPDATE content_strings SET value = 'Festivals & Heritage', updated_at = '2026-08-12T00:00:00.000Z'
WHERE key = 'home.s2.title';

UPDATE content_strings SET value =
  'Lekoli Boku — the New Yam Festival, celebrated under the words "Celebrating Our Heritage, Yam and Unity" — is the largest of the festivals of Ekoli-Yeden, but it is not the only one. Each festival keeps its own permanent page here: its programme from the run-up to the main day and beyond, its events, its photographs and its videos.',
  updated_at = '2026-08-12T00:00:00.000Z'
WHERE key = 'home.s2.description';

UPDATE content_strings SET value = 'Explore the festivals', updated_at = '2026-08-12T00:00:00.000Z'
WHERE key = 'home.s2.cta';
