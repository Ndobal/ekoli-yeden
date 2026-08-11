-- ---------------------------------------------------------------------------
-- EKOLI YEDEN DIGITAL HOME — Migration 0009
-- Seeds the public website text, the hero carousel, the navigation, and the
-- Initial Research Edition of the history article.
--
-- Everything seeded here is editable by the Editorial Team through the CMS.
-- The values are starting points, not fixed copy.
--
-- WHAT IS AND IS NOT ASSERTED HERE:
--
-- The website copy below describes the *platform* — what the archive is for and
-- how to contribute to it. That is project text, not a historical claim, and it
-- is safe to seed.
--
-- The history article at the end of this file is different. It is drawn from
-- two secondary web sources and every claim in it is attributed inline. It is
-- flagged `research_edition = 1` and `verification_status = 'unverified'`, so
-- the page renders it under an "Initial Research Edition" notice with its
-- citations and a correction button. Nothing in it is presented as settled
-- community history, because neither source establishes that — one of them
-- carries Wikipedia's own banner saying it cites no sources at all.
-- ---------------------------------------------------------------------------

-- ===========================================================================
-- NAVIGATION
-- ===========================================================================
INSERT OR IGNORE INTO navigation_items (id, menu, label, path, description, is_cta, sort_order, status, created_at, updated_at)
VALUES
  ('nav_home',          'primary', 'Home',      '/',           NULL,                                          0,  1, 'published', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('nav_about',         'primary', 'About',     '/about',      'About Ekoli-Yeden and this archive',           0,  2, 'published', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('nav_history',       'primary', 'History',   '/history',    'Our history and heritage',                    0,  3, 'published', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('nav_culture',       'primary', 'Culture',   '/culture',    'Traditions, practices and community life',    0,  4, 'published', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('nav_language',      'primary', 'Language',  '/language',   'Learn the Ekoli language',                    0,  5, 'published', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('nav_leboku',        'primary', 'Leboku',    '/leboku',     'The Leboku festival, year by year',           0,  6, 'published', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('nav_people',        'primary', 'People',    '/people',     'People of Ekoli-Yeden',                       0,  7, 'published', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('nav_news',          'primary', 'News',      '/news',       'Community news and announcements',            0,  8, 'published', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('nav_gallery',       'primary', 'Gallery',   '/gallery',    'Photographs from the archive',                0,  9, 'published', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('nav_videos',        'primary', 'Videos',    '/videos',     'The video archive',                           0, 10, 'published', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('nav_community',     'primary', 'Community', '/community',  'Projects, organizations and businesses',      0, 11, 'published', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('nav_contribute',    'primary', 'Contribute','/contribute', 'Share material with the archive',             1, 12, 'published', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),

  ('nav_f_events',      'footer',  'Events',            '/events',            NULL, 0, 1, 'published', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('nav_f_businesses',  'footer',  'Businesses',        '/businesses',        NULL, 0, 2, 'published', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('nav_f_orgs',        'footer',  'Organizations',     '/organizations',     NULL, 0, 3, 'published', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('nav_f_team',        'footer',  'Preservation Team', '/preservation-team', NULL, 0, 4, 'published', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('nav_f_contact',     'footer',  'Contact',           '/contact',           NULL, 0, 5, 'published', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('nav_f_search',      'footer',  'Search the archive','/search',            NULL, 0, 6, 'published', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z');

-- ===========================================================================
-- HERO CAROUSEL — exactly five slides.
--
-- Image slots are intentionally NULL. Until the Media Team attaches approved
-- photographs, each slide renders as a branded panel rather than a broken
-- image — the homepage is presentable on day one and improves as real
-- photographs of Ekoli-Yeden arrive.
-- ===========================================================================
INSERT OR IGNORE INTO hero_slides
  (id, slide_number, eyebrow, title, description, image_media_id, image_alt_text,
   primary_button_label, primary_button_path, secondary_button_label, secondary_button_path,
   status, created_at, updated_at)
VALUES
  ('hero_1', 1,
   'Welcome to',
   'EKOLI YEDEN DIGITAL HOME',
   'Preserving Our Past. Celebrating Our Present. Building Our Future.',
   NULL, 'The Ekoli Yeden Digital Home',
   'Explore Our Heritage', '/history',
   'Contribute to Ekoli-Yeden', '/contribute',
   'published', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),

  ('hero_2', 2,
   'Our story',
   'Our History',
   'The origins, migrations, institutions and events that made this community — recorded with their sources and checked before they are published.',
   NULL, 'A photograph representing the history of Ekoli-Yeden',
   'Read our history', '/history',
   NULL, NULL,
   'published', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),

  ('hero_3', 3,
   'How we live',
   'Our Culture',
   'Traditions, festivals, food, dress, farming, proverbs and the practices carried from one generation to the next.',
   NULL, 'A photograph representing the culture of Ekoli-Yeden',
   'Explore our culture', '/culture',
   NULL, NULL,
   'published', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),

  ('hero_4', 4,
   'Who we are',
   'Our People',
   'Scholars, farmers, professionals, artists and community builders — at home and across the world.',
   NULL, 'A photograph representing the people of Ekoli-Yeden',
   'Meet our people', '/people',
   NULL, NULL,
   'published', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),

  ('hero_5', 5,
   'What comes next',
   'Our Future',
   'What we preserve today is what our children will inherit. Help us record it while it can still be recorded.',
   NULL, 'A photograph representing the future of Ekoli-Yeden',
   'Contribute Materials', '/contribute',
   'Join the Preservation Team', '/preservation-team',
   'published', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z');

-- ===========================================================================
-- CONTENT STRINGS
-- ===========================================================================
INSERT OR IGNORE INTO content_strings
  (key, value, draft_value, group_name, page, label, help_text, value_type, max_length, status, is_locked, sort_order, created_at, updated_at)
VALUES
  -- --- Brand -------------------------------------------------------------
  ('brand.name', 'EKOLI YEDEN DIGITAL HOME', NULL, 'brand', NULL, 'Site name', 'Shown in the header, the browser tab and the footer.', 'text', 80, 'published', 0, 1, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('brand.tagline', 'Preserving Our Past. Celebrating Our Present. Building Our Future.', NULL, 'brand', NULL, 'Tagline', 'Appears under the site name.', 'text', 160, 'published', 0, 2, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('brand.motto', 'Unity · Progress · Development', NULL, 'brand', NULL, 'Motto', 'The three words carried on the community logo.', 'text', 80, 'published', 0, 3, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),

  -- --- Homepage welcome ---------------------------------------------------
  ('home.welcome.eyebrow', 'Welcome', NULL, 'home', 'home', 'Welcome eyebrow', 'Small label above the welcome heading.', 'text', 60, 'published', 0, 10, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('home.welcome.title', 'Welcome to Ekoli-Yeden', NULL, 'home', 'home', 'Welcome heading', NULL, 'text', 120, 'published', 0, 11, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('home.welcome.body',
   'EKOLI YEDEN DIGITAL HOME is a digital heritage and community platform dedicated to preserving, documenting and celebrating the history, culture, language, people and development of Ekoli-Yeden. It is being built as a living digital archive, bringing together historical materials, community stories, photographs, videos, language resources, festivals and contributions from Ekoli-Yeden and its people around the world.',
   NULL, 'home', 'home', 'Welcome text', 'The opening paragraph of the homepage.', 'richtext', 1200, 'published', 0, 12, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),

  -- --- Section 1: Discover ------------------------------------------------
  ('home.s1.eyebrow', 'Discover', NULL, 'home', 'home', 'Section 1 eyebrow', NULL, 'text', 60, 'published', 0, 20, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('home.s1.title', 'Discover Ekoli-Yeden', NULL, 'home', 'home', 'Section 1 heading', NULL, 'text', 120, 'published', 0, 21, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('home.s1.description', 'Four ways into the archive.', NULL, 'home', 'home', 'Section 1 description', NULL, 'text', 300, 'published', 0, 22, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('home.s1.card1.title', 'Our History', NULL, 'home', 'home', 'Card 1 title', NULL, 'text', 60, 'published', 0, 23, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('home.s1.card1.description', 'Origins, migrations, institutions and the events that shaped this community.', NULL, 'home', 'home', 'Card 1 description', NULL, 'text', 240, 'published', 0, 24, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('home.s1.card2.title', 'Our Culture', NULL, 'home', 'home', 'Card 2 title', NULL, 'text', 60, 'published', 0, 25, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('home.s1.card2.description', 'Festivals, traditional practices, food, dress, farming, proverbs and folklore.', NULL, 'home', 'home', 'Card 2 description', NULL, 'text', 240, 'published', 0, 26, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('home.s1.card3.title', 'Our People', NULL, 'home', 'home', 'Card 3 title', NULL, 'text', 60, 'published', 0, 27, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('home.s1.card3.description', 'Leaders, scholars, professionals, artists and community builders, at home and abroad.', NULL, 'home', 'home', 'Card 3 description', NULL, 'text', 240, 'published', 0, 28, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('home.s1.card4.title', 'Our Language', NULL, 'home', 'home', 'Card 4 title', NULL, 'text', 60, 'published', 0, 29, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('home.s1.card4.description', 'Words, meanings, expressions and proverbs, with pronunciation recorded by native speakers.', NULL, 'home', 'home', 'Card 4 description', NULL, 'text', 240, 'published', 0, 30, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),

  -- --- Section 2: Leboku --------------------------------------------------
  ('home.s2.eyebrow', 'Festival', NULL, 'home', 'home', 'Section 2 eyebrow', NULL, 'text', 60, 'published', 0, 40, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('home.s2.title', 'Leboku & Heritage', NULL, 'home', 'home', 'Section 2 heading', NULL, 'text', 120, 'published', 0, 41, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('home.s2.description',
   'Discover the traditions, stories, celebrations and memories surrounding one of the most important cultural festivals associated with Yakurr communities. Each year keeps its own permanent page, so that when a festival is over, the year is not lost.',
   NULL, 'home', 'home', 'Section 2 text', NULL, 'richtext', 800, 'published', 0, 42, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('home.s2.cta', 'Explore Leboku', NULL, 'home', 'home', 'Section 2 button', NULL, 'text', 60, 'published', 0, 43, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),

  -- --- Section 3: Today ---------------------------------------------------
  ('home.s3.eyebrow', 'Today', NULL, 'home', 'home', 'Section 3 eyebrow', NULL, 'text', 60, 'published', 0, 50, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('home.s3.title', 'Ekoli-Yeden Today', NULL, 'home', 'home', 'Section 3 heading', NULL, 'text', 120, 'published', 0, 51, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('home.s3.description', 'The community as it is now: its news, its development projects, its businesses, its organizations and its achievements.', NULL, 'home', 'home', 'Section 3 description', NULL, 'text', 400, 'published', 0, 52, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),

  -- --- Section 4: Archive -------------------------------------------------
  ('home.s4.eyebrow', 'The archive', NULL, 'home', 'home', 'Section 4 eyebrow', NULL, 'text', 60, 'published', 0, 60, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('home.s4.title', 'From Our Archive', NULL, 'home', 'home', 'Section 4 heading', NULL, 'text', 120, 'published', 0, 61, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('home.s4.description', 'Photographs, videos and historical documents, catalogued so they can still be found in fifty years.', NULL, 'home', 'home', 'Section 4 description', NULL, 'text', 400, 'published', 0, 62, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),

  -- --- Section 5: Preserve ------------------------------------------------
  ('home.s5.eyebrow', 'Preserve our heritage', NULL, 'home', 'home', 'Section 5 eyebrow', NULL, 'text', 60, 'published', 0, 70, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('home.s5.title', 'Your photograph could be history tomorrow.', NULL, 'home', 'home', 'Section 5 heading', NULL, 'text', 160, 'published', 0, 71, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('home.s5.description',
   'Help preserve the stories, images, language and memories of Ekoli-Yeden for generations to come. Every contribution is reviewed by the Preservation Team before it is published, so the archive stays trustworthy.',
   NULL, 'home', 'home', 'Section 5 text', NULL, 'richtext', 800, 'published', 0, 72, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('home.s5.cta1', 'Contribute Materials', NULL, 'home', 'home', 'Section 5 first button', NULL, 'text', 60, 'published', 0, 73, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('home.s5.cta2', 'Join the Preservation Team', NULL, 'home', 'home', 'Section 5 second button', NULL, 'text', 60, 'published', 0, 74, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),

  -- --- Footer -------------------------------------------------------------
  ('footer.about.title', 'About this archive', NULL, 'footer', NULL, 'Footer heading', NULL, 'text', 80, 'published', 0, 80, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('footer.about.body', 'A permanent digital home for the history, culture, language and people of Ekoli-Yeden, built and maintained by the community.', NULL, 'footer', NULL, 'Footer text', NULL, 'text', 400, 'published', 0, 81, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('footer.contact.title', 'Contact', NULL, 'footer', NULL, 'Footer contact heading', NULL, 'text', 60, 'published', 0, 82, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('footer.copyright', 'This archive is built and maintained by the Ekoli-Yeden Preservation Team and the wider community.', NULL, 'footer', NULL, 'Copyright line', 'The year is added automatically.', 'text', 300, 'published', 0, 83, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),

  -- --- System labels ------------------------------------------------------
  ('system.loading', 'Loading…', NULL, 'system', NULL, '"Loading" label', NULL, 'text', 40, 'published', 0, 90, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('system.read_more', 'Read more', NULL, 'system', NULL, '"Read more" label', NULL, 'text', 40, 'published', 0, 91, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('system.search', 'Search', NULL, 'system', NULL, '"Search" label', NULL, 'text', 40, 'published', 0, 92, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('system.search_placeholder', 'Search the archive…', NULL, 'system', NULL, 'Search box placeholder', NULL, 'text', 80, 'published', 0, 93, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('system.submit', 'Submit', NULL, 'system', NULL, '"Submit" button', NULL, 'text', 40, 'published', 0, 94, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('system.retry', 'Try again', NULL, 'system', NULL, '"Try again" button', NULL, 'text', 40, 'published', 0, 95, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('system.back', 'Back', NULL, 'system', NULL, '"Back" label', NULL, 'text', 40, 'published', 0, 96, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('system.coming_soon', 'Coming soon', NULL, 'system', NULL, '"Coming soon" label', NULL, 'text', 60, 'published', 0, 97, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('system.empty.default',
   'Our community archive is being prepared. Historical and contemporary material will appear here as it is collected and verified.',
   NULL, 'system', NULL, 'Default empty state', 'Shown wherever a section has no published material yet.', 'text', 400, 'published', 0, 98, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('system.empty.contribute_prompt', 'Do you have photographs, documents, stories or recordings that belong here? Please share them.', NULL, 'system', NULL, 'Empty-state invitation', NULL, 'text', 300, 'published', 0, 99, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('system.empty.contribute_cta', 'Contribute to the archive', NULL, 'system', NULL, 'Empty-state button', NULL, 'text', 60, 'published', 0, 100, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('system.awaiting_verification', 'This entry has not yet been verified by the Ekoli-Yeden Preservation Team.', NULL, 'system', NULL, 'Unverified notice', NULL, 'text', 300, 'published', 0, 101, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('system.not_supplied', 'To be supplied', NULL, 'system', NULL, '"Not supplied" label', 'Shown where the community has not yet provided a value.', 'text', 60, 'published', 0, 102, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('system.contributed_by', 'Contributed by', NULL, 'system', NULL, 'Contributor credit prefix', NULL, 'text', 60, 'published', 0, 103, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('system.sources_heading', 'Sources & References', NULL, 'system', NULL, 'Sources heading', NULL, 'text', 60, 'published', 0, 104, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('system.suggest_correction', 'Suggest a Correction / Add Historical Evidence', NULL, 'system', NULL, 'Correction button', NULL, 'text', 80, 'published', 0, 105, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('system.research_edition.label', 'Initial Research Edition', NULL, 'system', NULL, 'Research edition badge', NULL, 'text', 60, 'published', 0, 106, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('system.research_edition.notice',
   'This account has been compiled from secondary web sources as a starting point for research. It has NOT been verified by the Ekoli-Yeden Preservation Team, and it should not be treated as settled community history. Every claim below names the source it came from. If you can confirm, correct or add to it — particularly from oral accounts, family records or documents — please do.',
   NULL, 'system', NULL, 'Research edition notice', 'Shown above any history marked as an Initial Research Edition.', 'richtext', 800, 'published', 0, 107, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),

  -- --- Page introductions -------------------------------------------------
  ('page.about.title', 'About Ekoli-Yeden', NULL, 'pages', 'about', 'About page title', NULL, 'text', 120, 'published', 0, 110, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('page.about.intro',
   'This platform exists because much of what we know about our community lives in places that were never built to last — personal phones, WhatsApp groups, family collections, and the memories of elders. A photograph is lost when a phone breaks. A message disappears. Knowledge that is never recorded goes with the person who held it. This archive is the alternative.',
   NULL, 'pages', 'about', 'About page introduction', NULL, 'richtext', 1500, 'published', 0, 111, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('page.history.title', 'Our History', NULL, 'pages', 'history', 'History page title', NULL, 'text', 120, 'published', 0, 112, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('page.history.intro', 'The recorded history of Ekoli-Yeden. Each entry names its source and shows whether the Preservation Team has verified it.', NULL, 'pages', 'history', 'History page introduction', NULL, 'richtext', 800, 'published', 0, 113, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('page.culture.title', 'Culture & Heritage', NULL, 'pages', 'culture', 'Culture page title', NULL, 'text', 120, 'published', 0, 114, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('page.culture.intro', 'Traditions, festivals, practices, food, dress, farming, proverbs and community life. This section grows as the Preservation Team documents and verifies each area.', NULL, 'pages', 'culture', 'Culture page introduction', NULL, 'richtext', 800, 'published', 0, 115, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('page.language.title', 'Learn Ekoli', NULL, 'pages', 'language', 'Language page title', NULL, 'text', 120, 'published', 0, 116, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('page.language.intro', 'Words, expressions, greetings, numbers and proverbs, with pronunciation recorded by native speakers. Search in Ekoli or in English — both are searched together.', NULL, 'pages', 'language', 'Language page introduction', NULL, 'richtext', 800, 'published', 0, 117, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('page.contribute.title', 'Contribute to Ekoli-Yeden', NULL, 'pages', 'contribute', 'Contribute page title', NULL, 'text', 120, 'published', 0, 118, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('page.contribute.intro',
   'Every Ekoli-Yeden person can help build this archive. Old photographs, documents, stories, oral accounts, language recordings and information about notable people are all welcome. Nothing you send is published automatically — it is reviewed by the Preservation Team first, and you keep a reference code so you can follow its progress.',
   NULL, 'pages', 'contribute', 'Contribute page introduction', NULL, 'richtext', 1200, 'published', 0, 119, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('page.preservation_team.title', 'The Ekoli-Yeden Preservation Team', NULL, 'pages', 'preservation-team', 'Preservation Team page title', NULL, 'text', 120, 'published', 0, 120, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('page.preservation_team.intro',
   'The volunteer organisation that collects, checks and preserves the material in this archive. Its work is what separates a verified community record from a collection of unchecked claims.',
   NULL, 'pages', 'preservation-team', 'Preservation Team introduction', NULL, 'richtext', 800, 'published', 0, 121, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('page.contact.title', 'Contact', NULL, 'pages', 'contact', 'Contact page title', NULL, 'text', 120, 'published', 0, 122, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),
  ('page.contact.intro', 'How to reach the people who maintain this archive.', NULL, 'pages', 'contact', 'Contact page introduction', NULL, 'richtext', 600, 'published', 0, 123, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z');

-- ===========================================================================
-- SOURCES — the two research sources supplied for the initial edition.
-- ===========================================================================
INSERT OR IGNORE INTO sources
  (id, title, author, url, publication, publisher, publication_date, accessed_date,
   source_type, reliability, citation_text, notes, created_by, created_at, updated_at)
VALUES
  ('src_yakurrwatch_2017',
   'The History of Yakurr Kingdom',
   'Emmanuel Obeten',
   'https://yakurrwatchblog.wordpress.com/2017/05/28/the-history-of-yakurr-kingdom/',
   'Yakurrwatchblog',
   'WordPress',
   '2017-05-28',
   '2026-08-11',
   'web',
   'secondary',
   'Obeten, Emmanuel. "The History of Yakurr Kingdom." Yakurrwatchblog, 28 May 2017.',
   'A community blog account. It attributes different origin claims to several named historians and gives specific date ranges for the founding of settlements. It is a useful starting point and is not a primary record; the internal chronology also needs reconciling (see the notes on the history entry). To be cross-checked against oral accounts and documentary evidence by the Preservation Team.',
   NULL, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),

  ('src_wikipedia_ekori',
   'Ekori',
   NULL,
   'https://en.wikipedia.org/wiki/Ekori',
   'Wikipedia',
   'Wikimedia Foundation',
   NULL,
   '2026-08-11',
   'web',
   'contested',
   '"Ekori." Wikipedia, Wikimedia Foundation. Accessed 11 August 2026.',
   'IMPORTANT: at the time of access this article carried Wikipedia''s own maintenance banner stating that it does not cite any sources. Its contents are therefore recorded here as unverified assertions requiring independent confirmation, not as established fact. It does cite Daryll Forde (1964) for one population claim, which is worth chasing to the original.',
   NULL, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z'),

  ('src_forde_1964',
   'Yakö Studies',
   'Daryll Forde',
   NULL,
   NULL,
   'Oxford University Press',
   '1964',
   NULL,
   'book',
   'unassessed',
   'Forde, Daryll. Yakö Studies. Oxford University Press, 1964.',
   'Cited second-hand by the Wikipedia article for a claim about community size. Recorded here so the Preservation Team can consult the original work rather than relying on the citation of a citation. Not yet consulted.',
   NULL, '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z');

-- ===========================================================================
-- HISTORY — the Initial Research Edition.
--
-- Published so the section is not empty, but flagged research_edition = 1 and
-- verification_status = 'unverified', which makes the page render it beneath
-- the research notice with its citations and a correction button. Every claim
-- names its source inline.
-- ===========================================================================
INSERT OR IGNORE INTO history_entries
  (id, slug, title, summary, body, period_label, event_date, era, category, location,
   source_reference, contributed_by, cover_media_id, seo_title, seo_description,
   seo_image_media_id, verification_status, sort_order, status,
   research_edition, created_at, updated_at)
VALUES
  ('hist_initial_research_edition',
   'history-of-ekoli-yeden-initial-research-edition',
   'History of Ekoli-Yeden',
   'A first compilation drawn from two secondary web sources, presented for review. Not yet verified by the Preservation Team.',
   'WHAT THIS IS

This is a starting point, not a settled account. It gathers what two publicly available web sources say, so that the Ekoli-Yeden Preservation Team, elders, and researchers have something concrete to correct, expand and verify. Each claim below names where it came from. Nothing here has been confirmed by the community.

A caution about the sources: the Wikipedia article on Ekori carried, at the time it was consulted, Wikipedia''s own notice stating that it does not cite any sources. The Yakurrwatchblog article is a community blog post from 2017. Both are secondary. Neither establishes historical fact on its own.

ON THE NAME

According to the Yakurrwatchblog account, the Yakurr community comprises nine clans: Assiga, Inyima, Ugep, Idomi, Agoi Ibami, Mkpani, Ekori, Nko and Agoi Ekpo. That source states that earlier names included "Umor, Ekoli, Iloli and Yakurr Ibe", and attributes the change in form to difficulty of pronunciation by Europeans.

The relationship between the names Ekoli and Ekori is exactly the sort of question this archive exists to settle properly, from the community''s own knowledge rather than from a blog post. It is recorded here as a claim to be examined.

ON ORIGINS

The Yakurrwatchblog account reports that different researchers have proposed different origins. It attributes to Captain Chessmab the suggestion that the Yakurr people first lived near Okuni. It attributes to Dr. Otu Abami the assertion that the ancestral home was located at "Lekanakpakpa", and states that the historian Enang Basset confirmed this. These are presented in the source as competing scholarly positions, and are reproduced here as such.

The same source relates that a Princess Obia, described as from Abiriba in Igboland, married a hunter and founded the first dynasty, and that her son Ibe established the second.

ON MIGRATION AND SETTLEMENT

The Yakurrwatchblog account places migration in the period around AD 1617 to 1670, and gives its causes as conflicts over burial rights, competition for land, and population growth. It describes the migration as occurring in phases, and gives the following dates:

• AD 1660 — Idomi and Ugep established settlements
• AD 1677–1707 — Ekori and Nko established
• AD 1707–1737 — Mkpani founded

A note on an inconsistency: the same article describes the phases of migration in an order that does not sit comfortably with the dates it gives — it lists Mkpani among the first to migrate, while dating its founding last. This has been left as found rather than tidied away. Resolving it is a task for the Preservation Team, and it is a good illustration of why a single web source is not sufficient.

ON EKOLI-YEDEN TODAY

The Wikipedia article states that Ekori lies in Yakurr Local Government Area of Cross River State, Nigeria, and gives its coordinates as 5°52′50″N 8°07′21″E. It identifies Lokaa as the native language, with English as the official language and Pidgin English also spoken.

It describes three major wards — Ajere, Ntan and Epenti — and names further communities including Lekpankom and Benini Ekori Epepe.

On livelihood, it states that over half the population are subsistence farmers growing cassava, maize, yam and vegetables, and that around 80% of cassava is processed into garri. On religion, it describes the community as mainly Christian, with about 2% identifying with traditional religions.

It refers to age-grade associations called Ekoh, and to the Ekori Progressive Elements League (EPEL), described as having primarily women members in Calabar, Lagos and Abuja.

It cites Daryll Forde (1964) for the claim that the community is the second largest in Yakurr Local Government Area. That original work has not been consulted for this compilation.

ON LEBOKU

The Wikipedia article describes Leboku as the New Yam festival or harvest thanksgiving, celebrated in Ekori during the month of September. It also refers to KEPU, described as a wrestling practice used when celebrating people of certain ages.

The Leboku section of this archive is the proper home for this material, and it should be built from the community''s own account of the festival rather than from these sources.

WHAT IS MISSING

Almost everything. There is no account here of Ekoli-Yeden''s traditional institutions, its leadership through time, its families and quarters, its own telling of its founding, the events its elders remember, or the meaning its people give to any of the above. None of that is in the sources consulted, and none of it has been invented to fill the gap.

If you hold documents, photographs, family records, or an account you were told by someone who knew — that is what completes this page. Please use the correction button below, or the contribution page.',
   'Compiled 2026 from sources dated 1964–2017',
   NULL,
   NULL,
   'Origins and settlement',
   'Ekori, Yakurr Local Government Area, Cross River State, Nigeria',
   'Compiled from Yakurrwatchblog (2017) and Wikipedia (accessed 2026). See Sources & References.',
   'Initial compilation for review',
   NULL,
   'History of Ekoli-Yeden — Initial Research Edition',
   'A first compilation of what published sources say about the history of Ekoli-Yeden, presented for verification by the Ekoli-Yeden Preservation Team.',
   NULL,
   'unverified',
   1,
   'published',
   1,
   '2026-01-01T00:00:00.000Z',
   '2026-01-01T00:00:00.000Z');

-- Attach the citations to the history entry.
INSERT OR IGNORE INTO content_sources
  (id, resource_type, resource_id, source_id, supports, page_reference, sort_order, created_at)
VALUES
  ('csrc_hist_1', 'history', 'hist_initial_research_edition', 'src_yakurrwatch_2017',
   'Clan names and earlier forms, proposed origins, migration period and phases, founding date ranges for Ekori and Nko',
   NULL, 1, '2026-01-01T00:00:00.000Z'),
  ('csrc_hist_2', 'history', 'hist_initial_research_edition', 'src_wikipedia_ekori',
   'Location, language, wards, livelihood, religion, age grades, EPEL, Leboku and KEPU',
   NULL, 2, '2026-01-01T00:00:00.000Z'),
  ('csrc_hist_3', 'history', 'hist_initial_research_edition', 'src_forde_1964',
   'Relative size of the community within Yakurr LGA — cited second-hand and not yet consulted directly',
   NULL, 3, '2026-01-01T00:00:00.000Z');
