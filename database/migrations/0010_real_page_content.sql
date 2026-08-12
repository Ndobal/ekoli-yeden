-- ---------------------------------------------------------------------------
-- EKOLI YEDEN DIGITAL HOME — Migration 0010
-- Substantive content for every public page.
--
-- WHAT THIS DOES AND DOES NOT DO
--
-- It replaces thin placeholder copy with real, professional text so the site
-- reads as a finished archive rather than an empty shell, and so the Editorial
-- Team has something concrete to correct rather than a blank box.
--
-- Two kinds of text are seeded, and they are kept strictly apart:
--
--   PLATFORM TEXT — what this archive is, why it exists, how to contribute,
--   what each section will hold. This is project description, not a claim about
--   Ekoli-Yeden, and it is safe to state plainly.
--
--   SOURCED FACTS — anything asserting something about Ekoli-Yeden itself.
--   Every one of these is drawn from the two research sources recorded in
--   migration 0009, attributed inline in the text, and carried on records
--   flagged `research_edition = 1` and `verification_status = 'unverified'`
--   so they render beneath the Initial Research Edition notice.
--
-- Still nothing invented: no chief is named, no date is asserted that a source
-- did not give, no Ekoli word is assigned a meaning, and no festival programme
-- or committee is fabricated.
--
-- Every string below is editable by the Editorial Team without touching code.
-- ---------------------------------------------------------------------------

-- ===========================================================================
-- PAGE INTRODUCTIONS — replacing the thin placeholders from 0009
-- ===========================================================================

UPDATE content_strings SET value =
  'Ekoli-Yeden is a community with a history, a language, a leadership, families, achievements and a way of life. Most of what is known about it has never been written down. This archive is where that changes.',
  updated_at = '2026-08-12T00:00:00.000Z'
WHERE key = 'page.about.intro';

UPDATE content_strings SET value =
  'The recorded history of Ekoli-Yeden — its origins, migrations, institutions and the events its elders remember. Every entry names where it came from and shows whether the Preservation Team has verified it, because an archive that cannot answer "how do you know?" is not an archive.',
  updated_at = '2026-08-12T00:00:00.000Z'
WHERE key = 'page.history.intro';

UPDATE content_strings SET value =
  'The festivals, practices, food, dress, farming, proverbs and community life of Ekoli-Yeden. Some of what follows is drawn from published sources and clearly marked as unverified; most of it is still to be written by the people who live it.',
  updated_at = '2026-08-12T00:00:00.000Z'
WHERE key = 'page.culture.intro';

UPDATE content_strings SET value =
  'Published sources identify Lokaa as the language of the Yakurr communities, of which Ekori is one. This section will hold its words, expressions, greetings, numbers and proverbs, with pronunciation recorded by native speakers — so that what survives is not only the spelling of the language but its sound.',
  updated_at = '2026-08-12T00:00:00.000Z'
WHERE key = 'page.language.intro';

UPDATE content_strings SET value =
  'Old photographs, documents, stories, oral accounts, language recordings, information about notable people — all of it is welcome, and none of it is published without being checked first. You do not need an account, and you will be given a reference code so you can follow what happens to what you sent.',
  updated_at = '2026-08-12T00:00:00.000Z'
WHERE key = 'page.contribute.intro';

UPDATE content_strings SET value =
  'The volunteer organisation that collects, checks and preserves the material in this archive. Its work is the difference between a verified community record and a collection of unchecked claims — and it is the reason anything here can be trusted.',
  updated_at = '2026-08-12T00:00:00.000Z'
WHERE key = 'page.preservation_team.intro';

UPDATE content_strings SET value =
  'How to reach the people who maintain this archive, and how to send material that belongs in it.',
  updated_at = '2026-08-12T00:00:00.000Z'
WHERE key = 'page.contact.intro';

-- ===========================================================================
-- HOMEPAGE — fuller, more confident copy
-- ===========================================================================

UPDATE content_strings SET value =
  'EKOLI YEDEN DIGITAL HOME is the permanent digital home and heritage archive of Ekoli-Yeden. It brings together in one place the history, language, culture, leadership, people, festivals and community life that have until now lived scattered across personal phones, WhatsApp groups, family albums and the memories of elders.

It is built to last, to be searched, and to be added to for generations. Everything in it is contributed by the community, checked before it is published, and recorded with its source.',
  updated_at = '2026-08-12T00:00:00.000Z'
WHERE key = 'home.welcome.body';

UPDATE content_strings SET value =
  'Four ways into the archive — where we came from, how we live, who we are, and the language that carries all of it.',
  updated_at = '2026-08-12T00:00:00.000Z'
WHERE key = 'home.s1.description';

UPDATE content_strings SET value =
  'Origins, migrations, traditional institutions and the events that shaped this community — each entry recorded with its source and its verification status.',
  updated_at = '2026-08-12T00:00:00.000Z'
WHERE key = 'home.s1.card1.description';

UPDATE content_strings SET value =
  'Leboku and the harvest, traditional practices, wrestling, dances, food, dress, farming, proverbs and folklore.',
  updated_at = '2026-08-12T00:00:00.000Z'
WHERE key = 'home.s1.card2.description';

UPDATE content_strings SET value =
  'Traditional leadership, scholars, professionals, artists, farmers and community builders — at home and across the world.',
  updated_at = '2026-08-12T00:00:00.000Z'
WHERE key = 'home.s1.card3.description';

UPDATE content_strings SET value =
  'Words, meanings, expressions and proverbs, with pronunciation recorded by native speakers so the voice of the language survives too.',
  updated_at = '2026-08-12T00:00:00.000Z'
WHERE key = 'home.s1.card4.description';

UPDATE content_strings SET value =
  'Published sources describe Leboku as the New Yam festival — a harvest thanksgiving of the Yakurr communities, celebrated in Ekori in September. This archive gives each year its own permanent page: its programme, its announcements, its photographs and its videos. When a festival ends, the year is not lost.',
  updated_at = '2026-08-12T00:00:00.000Z'
WHERE key = 'home.s2.description';

UPDATE content_strings SET value =
  'The community as it is now — its news and announcements, its development projects, the businesses and professions its people run, the organizations that serve it, and the achievements worth recording.',
  updated_at = '2026-08-12T00:00:00.000Z'
WHERE key = 'home.s3.description';

UPDATE content_strings SET value =
  'Photographs labelled with what they show, videos organised by subject, and documents held with their provenance — catalogued so that somebody who was not there can still understand them in fifty years.',
  updated_at = '2026-08-12T00:00:00.000Z'
WHERE key = 'home.s4.description';

UPDATE content_strings SET value =
  'Every year that passes, something is lost. Elders who carry what nobody wrote down grow older. Photographs fade in drawers. Recordings disappear with the phones they were made on.

Help preserve the stories, images, language and memories of Ekoli-Yeden while they can still be preserved. Every contribution is reviewed by the Preservation Team before publication, and every contributor is credited.',
  updated_at = '2026-08-12T00:00:00.000Z'
WHERE key = 'home.s5.description';

-- ===========================================================================
-- NEW STRINGS — the About page and section explanations
-- ===========================================================================

INSERT OR IGNORE INTO content_strings
  (key, value, draft_value, group_name, page, label, help_text, value_type, max_length, status, is_locked, sort_order, created_at, updated_at)
VALUES
  ('page.about.why.title', 'Why this archive exists', NULL, 'pages', 'about', 'About — first heading', NULL, 'text', 120, 'published', 0, 130, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),
  ('page.about.why.body',
   'A photograph is lost when a phone breaks. A message disappears when a group is cleared. A Facebook post from today is almost impossible to find in five years. Knowledge that is never recorded goes with the person who held it.

None of the places our history currently lives were built to keep it. Social media was designed to circulate things quickly, not to preserve them — and it was never meant to serve as the official record of a community.

This archive is the alternative: one permanent, organised, searchable place where the history, language, culture, leadership and people of Ekoli-Yeden are collected, checked, labelled and kept.',
   NULL, 'pages', 'about', 'About — why this exists', NULL, 'richtext', 2000, 'published', 0, 131, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),

  ('page.about.promise.title', 'What this archive will not do', NULL, 'pages', 'about', 'About — second heading', NULL, 'text', 120, 'published', 0, 132, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),
  ('page.about.promise.body',
   'It will not invent anything.

No history, no chief, no leader, no date, no cultural claim, no statistic and no meaning of an Ekoli word appears on this site because software produced it. Where the community has not supplied something, the page says so plainly rather than filling the space with a plausible guess.

Material drawn from outside sources is labelled with where it came from, and marked unverified until the Preservation Team has checked it. An entry can be published and still unverified — that is the honest state for something the archive holds but has not yet confirmed.',
   NULL, 'pages', 'about', 'About — the editorial promise', NULL, 'richtext', 2000, 'published', 0, 133, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),

  ('page.gallery.intro',
   'Photographs of Ekoli-Yeden — its people, its leadership, its ceremonies, its festivals and its everyday life. Each is labelled with what it shows, so that a face in a crowd can still be named by somebody who recognises it years from now.',
   NULL, 'pages', 'gallery', 'Gallery introduction', NULL, 'richtext', 800, 'published', 0, 134, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),

  ('page.videos.intro',
   'Documentaries, interviews, oral history, festival performances, ceremonies and music. Videos are hosted on YouTube and organised here by subject — with a written transcript wherever one exists, because a transcript is what makes a recording searchable.',
   NULL, 'pages', 'videos', 'Videos introduction', NULL, 'richtext', 800, 'published', 0, 135, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),

  ('page.leaders.intro',
   'The traditional institution and community leadership of Ekoli-Yeden, past and present. This record is maintained together with the traditional institution and verified before publication — no name appears here that the community has not supplied and confirmed.',
   NULL, 'pages', 'leaders', 'Leadership introduction', NULL, 'richtext', 800, 'published', 0, 136, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),

  ('page.people.intro',
   'Scholars, professionals, farmers, artists, entrepreneurs, athletes, clergy and community builders from Ekoli-Yeden and its diaspora. A profile is published only once the person, or their family, has agreed to be listed.',
   NULL, 'pages', 'people', 'People introduction', NULL, 'richtext', 800, 'published', 0, 137, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),

  ('page.news.intro',
   'Community news, announcements, appointments, achievements and notices. Social media remains how news is spread; this is where it is permanently recorded, so that it can still be found years later.',
   NULL, 'pages', 'news', 'News introduction', NULL, 'richtext', 800, 'published', 0, 138, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),

  ('page.leboku.intro',
   'Published sources describe Leboku as the New Yam festival of the Yakurr communities — a harvest thanksgiving celebrated in Ekori in September. Each edition keeps its own permanent page here: its programme, announcements, photographs and videos, preserved year after year.',
   NULL, 'pages', 'leboku', 'Leboku introduction', NULL, 'richtext', 800, 'published', 0, 139, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),

  ('page.community.intro',
   'Development projects, organizations and businesses. Where a project reports funding, those figures come from the project committee''s own records — the archive does not estimate them.',
   NULL, 'pages', 'community', 'Community introduction', NULL, 'richtext', 800, 'published', 0, 140, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),

  ('page.businesses.intro',
   'Businesses, trades and professional services run by people of Ekoli-Yeden, at home and abroad — so that the community can find and support its own.',
   NULL, 'pages', 'businesses', 'Businesses introduction', NULL, 'richtext', 800, 'published', 0, 141, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),

  ('page.events.intro',
   'Community meetings, ceremonies, cultural activities and gatherings — those coming up, and those already held and now part of the record.',
   NULL, 'pages', 'events', 'Events introduction', NULL, 'richtext', 800, 'published', 0, 142, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),

  ('page.organizations.intro',
   'Unions, associations, societies, schools, churches and other bodies serving the Ekoli-Yeden community.',
   NULL, 'pages', 'organizations', 'Organizations introduction', NULL, 'richtext', 800, 'published', 0, 143, '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z');

-- ===========================================================================
-- CULTURE — articles built strictly from the recorded sources.
--
-- Each is flagged research_edition = 1 and verification_status = 'unverified',
-- so the page renders it beneath the Initial Research Edition notice with its
-- citations. Each says explicitly what is NOT known, which is the larger part.
-- ===========================================================================

INSERT OR IGNORE INTO content_items
  (id, content_type, slug, title, subtitle, excerpt, body, category,
   verification_status, research_edition, sort_order, status, created_at, updated_at)
VALUES
  ('cult_leboku', 'culture', 'leboku-the-new-yam-festival',
   'Leboku — the New Yam Festival',
   'Harvest thanksgiving of the Yakurr communities',
   'What published sources say about Leboku, and the much larger part that only the community can supply.',
   'WHAT THE SOURCES SAY

The Wikipedia article on Ekori describes Leboku as the New Yam festival, or harvest thanksgiving, and states that it is celebrated in Ekori during the month of September.

The Yakurrwatchblog account of Yakurr history refers to a festival of the Yakurr communities as one of the largest in Africa, without giving further detail.

That is the whole of what those two sources establish. Both are secondary web sources, and one of them carries Wikipedia''s own notice that it cites no sources at all.

WHAT THIS PAGE STILL NEEDS

Almost everything that matters about Leboku is not above.

The meaning of the festival, and what the new yam signifies. How the date is set each year, and by whom. The rites that open and close it. Who has which role, and how those roles are held. What is cooked, worn, danced and sung. Which age grades take part, and how. What the festival looked like in previous generations, and what has changed. What elders remember of it from their childhood.

None of that has been recorded here, because none of it should be written from a web page. It belongs to the people who keep the festival.

If you can describe any part of it — from your own knowledge, from what you were told, from photographs or recordings you hold — the archive would welcome it. Use the correction button below, or the contribution page.',
   'Leboku',
   'unverified', 1, 1, 'published', '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),

  ('cult_kepu', 'culture', 'kepu-wrestling', 'KEPU — Wrestling',
   'A wrestling practice associated with age celebrations',
   'A single sourced sentence, and an open invitation to the people who know the practice.',
   'WHAT THE SOURCES SAY

The Wikipedia article on Ekori refers to KEPU as a wrestling practice used when celebrating people of certain ages.

That is the entirety of what the available sources say about it.

WHAT THIS PAGE STILL NEEDS

The meaning of the name. Which ages are marked, and why. How a bout is conducted, and what governs it. Who may take part. What is worn. What is won. What role the age grades play. How the practice has changed within living memory, and whether it is still kept.

A photograph or a recording of KEPU would be a significant addition to this archive, as would an account from anybody who has taken part in it.',
   'Traditional practices',
   'unverified', 1, 2, 'published', '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),

  ('cult_agriculture', 'culture', 'farming-and-food', 'Farming and Food',
   'What is grown, and what is made of it',
   'Sourced figures on farming in Ekori, and the practices behind them still to be recorded.',
   'WHAT THE SOURCES SAY

The Wikipedia article on Ekori states that over half the population are subsistence farmers, growing cassava, maize, yam and vegetables, and that around 80% of the cassava grown is processed into garri.

The same article describes Leboku as a harvest thanksgiving, which places the yam at the centre of the community''s year.

These figures are recorded here as they were found. Neither their source nor their date is established, and they have not been checked against any local record.

WHAT THIS PAGE STILL NEEDS

The farming year itself: when land is cleared, when planting happens, when harvest comes, and what marks each stage. How land is held and passed on. Which varieties are grown and what they are called in the language. How garri is made, step by step, and by whom. What is cooked for ordinary days and what is cooked for occasions. What is planted now that was not planted a generation ago, and what has been lost.

This is knowledge held by people who farm, and it is exactly the kind that disappears without being noticed.',
   'Agriculture',
   'unverified', 1, 3, 'published', '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),

  ('cult_community_life', 'culture', 'community-life-and-age-grades',
   'Community Life and Age Grades',
   'How the community organises itself',
   'Age grades, associations and the wards of Ekori, as far as published sources record them.',
   'WHAT THE SOURCES SAY

The Wikipedia article on Ekori refers to age-grade associations called Ekoh.

It names three major wards — Ajere, Ntan and Epenti — and lists further communities including Lekpankom and Benini Ekori Epepe.

It also describes the Ekori Progressive Elements League (EPEL), an association it says has primarily women members based in Calabar, Lagos and Abuja.

On religion, it describes the community as mainly Christian, with about 2% identifying with traditional religions.

It cites Daryll Forde (1964) for the statement that the community is the second largest in Yakurr Local Government Area. That work has not been consulted directly for this archive, and doing so is a task for the Research Team.

WHAT THIS PAGE STILL NEEDS

How the age grades work: how one is formed, what it is called, what it is responsible for, and what marks entry into it. How the wards relate to one another and to the traditional institution. Which associations exist, when they were founded, and what they do. How decisions are taken, and by whom.

This is the structure of the community''s own daily life, and almost none of it is recorded anywhere.',
   'Community life',
   'unverified', 1, 4, 'published', '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),

  ('cult_language_overview', 'culture', 'the-language', 'The Language',
   'Lokaa, and the work of recording it',
   'What sources say about the language of the Yakurr communities, and why recording it matters now.',
   'WHAT THE SOURCES SAY

The Wikipedia article on Ekori identifies Lokaa as the native language, with English as the official language and Pidgin English also spoken.

The Yakurrwatchblog account of Yakurr history states that the names of several settlements changed from earlier forms — it lists "Umor, Ekoli, Iloli and Yakurr Ibe" among them — attributing the change to difficulty of pronunciation by Europeans. The relationship between the names Ekoli and Ekori is a question this archive exists to settle properly, from the community''s own knowledge rather than from a blog post.

WHY THIS MATTERS NOW

Many Ekoli-Yeden children are growing up outside the community. Some know their heritage without being fluent in the language of it. A language that is spoken but never recorded survives only as long as its last fluent speaker.

WHAT THE ARCHIVE IS BUILDING

A dictionary of words and their meanings, with pronunciation recorded by native speakers — so that what is preserved is the sound of the language and not only its spelling. Greetings, numbers, family terms, proverbs, idioms, riddles and songs. Dialect and family variation recorded rather than flattened, because the variation is part of the language.

Not one word has been entered into that dictionary by this software, and none ever will be. Every entry must come from a native speaker or a recognised language scholar. A guessed meaning would be worse than an empty page, because it would look finished.

If you speak the language and can contribute words, meanings, examples or recordings, that is the single most valuable thing you can give this archive.',
   'Language',
   'unverified', 1, 5, 'published', '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z');

-- Cite the sources on each culture article.
INSERT OR IGNORE INTO content_sources
  (id, resource_type, resource_id, source_id, supports, page_reference, sort_order, created_at)
VALUES
  ('csrc_cult_1', 'culture', 'cult_leboku', 'src_wikipedia_ekori', 'Leboku as the New Yam festival, celebrated in September', NULL, 1, '2026-08-12T00:00:00.000Z'),
  ('csrc_cult_2', 'culture', 'cult_leboku', 'src_yakurrwatch_2017', 'Reference to a major Yakurr festival', NULL, 2, '2026-08-12T00:00:00.000Z'),
  ('csrc_cult_3', 'culture', 'cult_kepu', 'src_wikipedia_ekori', 'KEPU as a wrestling practice used in age celebrations', NULL, 1, '2026-08-12T00:00:00.000Z'),
  ('csrc_cult_4', 'culture', 'cult_agriculture', 'src_wikipedia_ekori', 'Subsistence farming, crops grown, and cassava processed into garri', NULL, 1, '2026-08-12T00:00:00.000Z'),
  ('csrc_cult_5', 'culture', 'cult_community_life', 'src_wikipedia_ekori', 'Age grades, wards, EPEL and religious composition', NULL, 1, '2026-08-12T00:00:00.000Z'),
  ('csrc_cult_6', 'culture', 'cult_community_life', 'src_forde_1964', 'Relative size of the community — cited second-hand, not consulted directly', NULL, 2, '2026-08-12T00:00:00.000Z'),
  ('csrc_cult_7', 'culture', 'cult_language_overview', 'src_wikipedia_ekori', 'Lokaa as the native language', NULL, 1, '2026-08-12T00:00:00.000Z'),
  ('csrc_cult_8', 'culture', 'cult_language_overview', 'src_yakurrwatch_2017', 'Earlier settlement names including Ekoli', NULL, 2, '2026-08-12T00:00:00.000Z');

-- ===========================================================================
-- LANGUAGE CATEGORIES — structure only. Not one word is seeded.
-- ===========================================================================

INSERT OR IGNORE INTO language_categories
  (id, slug, name, description, sort_order, status, created_at, updated_at)
VALUES
  ('lang_cat_greetings', 'greetings', 'Greetings', 'How people greet one another, and the replies that belong to each.', 1, 'published', '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),
  ('lang_cat_family', 'family', 'Family and relationships', 'Terms for kin, and how people are addressed within a family.', 2, 'published', '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),
  ('lang_cat_numbers', 'numbers', 'Numbers', 'Counting, and how numbers are used in speech.', 3, 'published', '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),
  ('lang_cat_everyday', 'everyday', 'Everyday words', 'The vocabulary of ordinary life — home, work, food, weather, the body.', 4, 'published', '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),
  ('lang_cat_farming', 'farming', 'Farming and the land', 'Crops, tools, seasons and the words that describe working the land.', 5, 'published', '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),
  ('lang_cat_proverbs', 'proverbs', 'Proverbs and sayings', 'Proverbs, and what they are used to mean.', 6, 'published', '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),
  ('lang_cat_ceremony', 'ceremony', 'Ceremony and tradition', 'The vocabulary of festivals, rites and traditional occasions.', 7, 'published', '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),
  ('lang_cat_names', 'names', 'Names and praise names', 'Personal names, their meanings, and praise names.', 8, 'published', '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z');

-- ===========================================================================
-- LEBOKU — a festival record, with nothing invented.
--
-- No dates, programme, committee or sponsors are seeded: none is known. The
-- record exists so the section resolves and so the Leboku Manager has
-- somewhere to enter the real information.
-- ===========================================================================

INSERT OR IGNORE INTO festivals
  (id, slug, name, year, theme, description, start_date, end_date, location,
   programme, sponsors, announcements, committee, is_archived,
   seo_title, seo_description, status, created_at, updated_at)
VALUES
  ('fest_leboku_2026', 'leboku-2026', 'Leboku', 2026, NULL,
   'Published sources describe Leboku as the New Yam festival, or harvest thanksgiving, of the Yakurr communities, and record that it is celebrated in Ekori during the month of September.

The dates, programme, committee and announcements for this edition have not been published here. They will be added by the Leboku Manager once the community has confirmed them — nothing about the festival has been assumed or filled in from elsewhere.

Photographs and videos from this and previous editions are welcome. If you have material from any year of Leboku, the archive would be glad to receive it, and this page will keep it permanently.',
   NULL, NULL, 'Ekori, Yakurr Local Government Area, Cross River State, Nigeria',
   NULL, NULL, NULL, NULL, 0,
   'Leboku 2026 — Ekoli Yeden Digital Home',
   'The Leboku New Yam festival of Ekoli-Yeden: programme, announcements, photographs and videos, preserved year by year.',
   'published', '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z');

INSERT OR IGNORE INTO content_sources
  (id, resource_type, resource_id, source_id, supports, page_reference, sort_order, created_at)
VALUES
  ('csrc_fest_1', 'festivals', 'fest_leboku_2026', 'src_wikipedia_ekori',
   'Leboku as the New Yam festival celebrated in Ekori in September', NULL, 1, '2026-08-12T00:00:00.000Z');

-- ===========================================================================
-- GALLERY — a home for the leadership photographs.
--
-- The gallery is created here; the photographs themselves are uploaded through
-- the media library, which is where their contributor, permission and
-- moderation state are recorded.
--
-- The individual leaders are deliberately NOT named. The community supplied the
-- photographs, not the names, and captioning a portrait with a guess would be
-- exactly the kind of invention this archive refuses.
-- ===========================================================================

INSERT OR IGNORE INTO galleries
  (id, slug, title, description, category, event_date, location,
   sort_order, seo_title, seo_description, status, created_at, updated_at)
VALUES
  ('gal_leadership', 'traditional-leadership', 'Traditional Leadership and Elders',
   'Photographs of the traditional leadership and elders of Ekoli-Yeden, contributed by the community.

The individuals in these photographs have not been named here. The archive holds the images; it does not yet hold the names, titles and dates that belong with them — and it will not guess at them. If you can identify anyone pictured, or supply the occasion and date, please use the contribution page. That information is what turns a photograph into a record.',
   'Leadership', NULL, 'Ekori, Cross River State, Nigeria',
   1, 'Traditional Leadership and Elders — Ekoli Yeden Digital Home',
   'Photographs of the traditional leadership and elders of Ekoli-Yeden, held in the community archive.',
   'published', '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),

  ('gal_community', 'community-life', 'Community Life',
   'Photographs of everyday life, gatherings, ceremonies and work in Ekoli-Yeden. This gallery grows as the community contributes to it.',
   'Community', NULL, NULL,
   2, 'Community Life — Ekoli Yeden Digital Home',
   'Photographs of everyday life, gatherings and ceremonies in Ekoli-Yeden.',
   'published', '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z'),

  ('gal_leboku', 'leboku-festival', 'Leboku Festival',
   'Photographs from the Leboku New Yam festival. Each year''s images are kept permanently, so that the festival''s own history accumulates here.',
   'Leboku', NULL, NULL,
   3, 'Leboku Festival Photographs — Ekoli Yeden Digital Home',
   'Photographs from the Leboku New Yam festival of Ekoli-Yeden.',
   'published', '2026-08-12T00:00:00.000Z', '2026-08-12T00:00:00.000Z');

-- ===========================================================================
-- SITE SETTINGS
-- ===========================================================================

UPDATE site_settings SET value =
  'The permanent digital home and heritage archive of Ekoli-Yeden: its history, culture, language, leadership, people, festivals and community life — preserved, verified and open to all.',
  updated_at = '2026-08-12T00:00:00.000Z'
WHERE key = 'site_description';

UPDATE site_settings SET value = '2026', updated_at = '2026-08-12T00:00:00.000Z'
WHERE key = 'current_festival_year';
