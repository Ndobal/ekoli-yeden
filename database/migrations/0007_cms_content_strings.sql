-- ---------------------------------------------------------------------------
-- EKOLI YEDEN DIGITAL HOME — Migration 0007
-- The CMS text system, and the homepage hero.
--
-- THE RULE THIS TABLE EXISTS TO ENFORCE:
--
--   If a visitor can read it, the Editorial Team can change it without
--   touching code.
--
-- Every navigation label, heading, paragraph, button label, caption, empty
-- state, notice and SEO field on the public site is a row in `content_strings`.
-- The Flutter client ships a fallback for each key so the site still renders
-- correctly before the CMS is seeded, or if the API is briefly unreachable —
-- but the moment a row exists, the row wins.
--
-- The one category deliberately excluded is security and system-generated
-- messages: a sign-in failure or a permission denial must say what it means,
-- and must not be editable into something misleading.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS content_strings (
  -- Dotted key, e.g. 'home.hero.slide1.title', 'nav.history', 'footer.copyright'.
  key            TEXT PRIMARY KEY,

  -- The live value the public site serves.
  value          TEXT,

  -- The Editorial Team's work in progress. Editing writes here, never to
  -- `value`, so a half-finished edit is never visible to a visitor.
  draft_value    TEXT,

  -- Grouping for the editorial interface: 'navigation', 'home', 'footer',
  -- 'system', 'contribute', 'seo', and one group per page.
  group_name     TEXT NOT NULL DEFAULT 'general',
  page           TEXT,

  -- Shown to the editor in the CMS so they know what they are changing and
  -- where it appears.
  label          TEXT NOT NULL,
  help_text      TEXT,

  value_type     TEXT NOT NULL DEFAULT 'text'
                   CHECK (value_type IN ('text', 'richtext', 'url', 'image_media_id', 'number')),
  max_length     INTEGER,

  -- The workflow applies to text as much as to articles: an editor drafts, a
  -- reviewer approves, a publisher makes it live.
  status         TEXT NOT NULL DEFAULT 'published'
                   CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),

  -- A locked string may not be edited through the CMS. Reserved for the very
  -- small set of legally or structurally fixed strings.
  is_locked      INTEGER NOT NULL DEFAULT 0 CHECK (is_locked IN (0, 1)),

  sort_order     INTEGER NOT NULL DEFAULT 0,
  updated_by     TEXT REFERENCES users (id) ON DELETE SET NULL,
  reviewed_by    TEXT REFERENCES users (id) ON DELETE SET NULL,
  created_at     TEXT NOT NULL,
  updated_at     TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_content_strings_group ON content_strings (group_name, sort_order);
CREATE INDEX IF NOT EXISTS idx_content_strings_page ON content_strings (page);
CREATE INDEX IF NOT EXISTS idx_content_strings_status ON content_strings (status);

-- --------------------------------------------------------------------------
-- hero_slides — the homepage carousel.
--
-- Exactly five slides are seeded. Each carries its own image, heading,
-- description and buttons, all editable through the CMS. The image slot is
-- left empty until an approved photograph exists: the carousel renders a
-- branded gradient panel rather than a broken image, so the homepage is
-- presentable on day one and improves as real photographs arrive.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hero_slides (
  id                     TEXT PRIMARY KEY,
  slide_number           INTEGER NOT NULL UNIQUE CHECK (slide_number BETWEEN 1 AND 5),
  eyebrow                TEXT,
  title                  TEXT NOT NULL,
  description            TEXT,
  -- NULL until the Media Team attaches an approved photograph.
  image_media_id         TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  image_alt_text         TEXT,
  primary_button_label   TEXT,
  primary_button_path    TEXT,
  secondary_button_label TEXT,
  secondary_button_path  TEXT,
  status                 TEXT NOT NULL DEFAULT 'published'
                           CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  updated_by             TEXT REFERENCES users (id) ON DELETE SET NULL,
  created_at             TEXT NOT NULL,
  updated_at             TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_hero_slides_order ON hero_slides (slide_number);

-- --------------------------------------------------------------------------
-- navigation_items — the menus, editable without a deployment.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS navigation_items (
  id           TEXT PRIMARY KEY,
  menu         TEXT NOT NULL DEFAULT 'primary'
                 CHECK (menu IN ('primary', 'footer', 'utility')),
  label        TEXT NOT NULL,
  path         TEXT NOT NULL,
  description  TEXT,
  -- Draws the item as a call-to-action button rather than a plain link.
  is_cta       INTEGER NOT NULL DEFAULT 0 CHECK (is_cta IN (0, 1)),
  sort_order   INTEGER NOT NULL DEFAULT 0,
  status       TEXT NOT NULL DEFAULT 'published'
                 CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_navigation_menu ON navigation_items (menu, sort_order);
