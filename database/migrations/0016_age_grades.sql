-- ---------------------------------------------------------------------------
-- EKOLI YEDEN DIGITAL HOME — Migration 0016
-- Age grades that the age grades themselves run.
--
-- WHAT CHANGES, AND WHY
--
-- Until now an age grade was an article in `content_items` that only the
-- Heritage Editor could write. That is the wrong shape for what an age grade
-- is. An age grade is a standing body with living members, its own officers
-- and its own news, and the people who know what it has been doing this year
-- are its own members — not a volunteer editor waiting to be told.
--
-- So an age grade becomes a record with:
--
--   * its own administrators, appointed from within the grade,
--   * its own roster of members,
--   * its own posts, which its administrators write and which appear on the
--     public page under that grade.
--
-- THE AUTHORISATION THIS INTRODUCES
--
-- A new and deliberately narrow axis: "administers this particular age grade".
-- It is not a platform role and it grants nothing anywhere else on the site.
-- A person who administers Ovat cannot touch Obam, cannot reach the media
-- library, cannot see a user list. The Worker checks membership of
-- `age_grade_admins` for the specific grade being written to, and that check
-- is the whole of the power granted.
--
-- WHAT STAYS UNDER THE PRESERVATION TEAM
--
-- Creating an age grade puts it in `pending_review`: a page claiming to speak
-- for a body of the community should be confirmed by somebody before it goes
-- live, and that is the one gate worth keeping. After that the grade runs
-- itself, and its posts carry its own name rather than the archive's — the
-- page says who is speaking, so a grade's own account of itself is never
-- mistaken for verified community history.
-- ---------------------------------------------------------------------------

-- ===========================================================================
-- age_grades
--
-- A table of its own rather than another shelf in `content_items`, because
-- unlike a culture article this record has people attached to it, and rows
-- that own other rows do not belong in a shared-discriminator table.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS age_grades (
  id                     TEXT PRIMARY KEY,
  slug                   TEXT NOT NULL UNIQUE,

  -- What the grade calls itself, and any other name it is known by.
  title                  TEXT NOT NULL,
  subtitle               TEXT,

  -- The year the grade was formed, and the birth years it covers. Both free of
  -- a NOT NULL, because for the older grades nobody now living may be certain,
  -- and a guessed year in an archive is worse than an empty field.
  formed_year            INTEGER,
  birth_years            TEXT,

  excerpt                TEXT,
  body                   TEXT,
  motto                  TEXT,
  category               TEXT,

  -- Where the grade fits in the sequence of grades. Ordering by name would be
  -- meaningless; ordering by formed_year fails for the ones with no year.
  sort_order             INTEGER NOT NULL DEFAULT 0,

  cover_media_id         TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  gallery_id             TEXT REFERENCES galleries (id) ON DELETE SET NULL,

  -- Who registered the grade on the platform. Not the same as who leads it —
  -- that is `age_grade_admins`.
  created_by             TEXT REFERENCES users (id) ON DELETE SET NULL,
  contact_name           TEXT,
  contact_phone          TEXT,
  contact_email          TEXT,

  seo_title              TEXT,
  seo_description        TEXT,
  seo_image_media_id     TEXT REFERENCES media_assets (id) ON DELETE SET NULL,

  verification_status    TEXT NOT NULL DEFAULT 'unverified'
                           CHECK (verification_status IN ('unverified', 'in_review', 'verified', 'disputed')),

  -- The editorial workflow columns every registry resource carries.
  author_id              TEXT REFERENCES users (id) ON DELETE SET NULL,
  editor_id              TEXT REFERENCES users (id) ON DELETE SET NULL,
  reviewer_id            TEXT REFERENCES users (id) ON DELETE SET NULL,
  published_by           TEXT REFERENCES users (id) ON DELETE SET NULL,
  submitted_at           TEXT,
  published_at_workflow  TEXT,
  review_notes           TEXT,

  status                 TEXT NOT NULL DEFAULT 'draft'
                           CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at             TEXT NOT NULL,
  updated_at             TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_age_grades_status ON age_grades (status, sort_order);
CREATE INDEX IF NOT EXISTS idx_age_grades_formed ON age_grades (formed_year);

-- --------------------------------------------------------------------------
-- Carry across the age grade articles already written, keeping their ids.
--
-- The ids are preserved because `content_sources` and `content_contributors`
-- reference them by ('age_grades', id). Changing the id would orphan every
-- citation and every acknowledgement attached to those records, which is
-- exactly the kind of quiet loss this archive exists to prevent.
-- --------------------------------------------------------------------------
INSERT OR IGNORE INTO age_grades (
  id, slug, title, subtitle, excerpt, body, category, sort_order,
  cover_media_id, seo_title, seo_description, seo_image_media_id,
  verification_status, author_id, editor_id, reviewer_id, published_by,
  submitted_at, published_at_workflow, review_notes, status, created_at, updated_at
)
SELECT
  ci.id, ci.slug, ci.title, ci.subtitle, ci.excerpt, ci.body, ci.category, ci.sort_order,
  ci.cover_media_id, ci.seo_title, ci.seo_description, ci.seo_image_media_id,
  ci.verification_status, ci.author_id, ci.editor_id, ci.reviewer_id, ci.published_by,
  ci.submitted_at, ci.published_at_workflow, ci.review_notes, ci.status, ci.created_at, ci.updated_at
FROM content_items ci
WHERE ci.content_type = 'age_grades';

-- Archived rather than deleted: the originals stay readable in `content_items`
-- if anything turns out to reference them, and a migration that destroys rows
-- is a migration nobody can safely re-run.
UPDATE content_items SET content_type = 'age_grades_migrated', updated_at = datetime('now')
WHERE content_type = 'age_grades';

-- ===========================================================================
-- age_grade_admins
--
-- Who may speak for this grade. `lead` is the person who registered it or was
-- handed it; only a lead may appoint or remove another administrator, which
-- keeps the grade in charge of its own membership without letting any single
-- admin quietly take it over.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS age_grade_admins (
  id             TEXT PRIMARY KEY,
  age_grade_id   TEXT NOT NULL REFERENCES age_grades (id) ON DELETE CASCADE,
  user_id        TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,

  admin_role     TEXT NOT NULL DEFAULT 'admin'
                   CHECK (admin_role IN ('lead', 'admin')),

  -- The office they hold inside the grade, which is not the same thing as
  -- their permission on the platform. "Secretary" is a fact about the grade;
  -- `admin_role` is a fact about this website.
  office         TEXT,

  appointed_by   TEXT REFERENCES users (id) ON DELETE SET NULL,
  created_at     TEXT NOT NULL,
  UNIQUE (age_grade_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_age_grade_admins_grade ON age_grade_admins (age_grade_id);
CREATE INDEX IF NOT EXISTS idx_age_grade_admins_user ON age_grade_admins (user_id);

-- ===========================================================================
-- age_grade_members
--
-- The roster. `user_id` is nullable and usually null: most members of most
-- grades will never hold an account here, and a roster that only lists the
-- ones who do is not a roster.
--
-- `is_deceased` and `deceased_year` exist because an age grade's record of its
-- own dead is part of what the grade is for.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS age_grade_members (
  id             TEXT PRIMARY KEY,
  age_grade_id   TEXT NOT NULL REFERENCES age_grades (id) ON DELETE CASCADE,

  full_name      TEXT NOT NULL,
  user_id        TEXT REFERENCES users (id) ON DELETE SET NULL,
  person_id      TEXT REFERENCES people (id) ON DELETE SET NULL,

  office         TEXT,
  joined_year    INTEGER,
  notes          TEXT,
  photo_media_id TEXT REFERENCES media_assets (id) ON DELETE SET NULL,

  is_deceased    INTEGER NOT NULL DEFAULT 0 CHECK (is_deceased IN (0, 1)),
  deceased_year  INTEGER,

  sort_order     INTEGER NOT NULL DEFAULT 0,

  -- A living person's name on a public page is personal data. A member row is
  -- not visible until somebody has confirmed it belongs there.
  status         TEXT NOT NULL DEFAULT 'pending_review'
                   CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  added_by       TEXT REFERENCES users (id) ON DELETE SET NULL,
  created_at     TEXT NOT NULL,
  updated_at     TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_age_grade_members_grade
  ON age_grade_members (age_grade_id, sort_order);

-- ===========================================================================
-- age_grade_posts
--
-- What the grade has to say: a meeting notice, a project, a death announced, a
-- report of what was done at the last festival.
--
-- These are published under the grade's own name. `author_name` holds the
-- grade's attribution rather than the archive's, because a post is the grade
-- speaking about itself — useful, and a different kind of statement from a
-- verified history entry. The public page labels it as such.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS age_grade_posts (
  id               TEXT PRIMARY KEY,
  age_grade_id     TEXT NOT NULL REFERENCES age_grades (id) ON DELETE CASCADE,
  slug             TEXT NOT NULL,

  title            TEXT NOT NULL,
  excerpt          TEXT,
  body             TEXT,

  post_type        TEXT NOT NULL DEFAULT 'update'
                     CHECK (post_type IN ('update', 'announcement', 'meeting', 'project',
                                          'obituary', 'report', 'history')),

  cover_media_id   TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  gallery_id       TEXT REFERENCES galleries (id) ON DELETE SET NULL,

  -- Who wrote it, and the name it is published under.
  author_id        TEXT REFERENCES users (id) ON DELETE SET NULL,
  author_name      TEXT,

  event_date       TEXT,
  published_at     TEXT,

  status           TEXT NOT NULL DEFAULT 'draft'
                     CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  review_notes     TEXT,
  reviewed_by      TEXT REFERENCES users (id) ON DELETE SET NULL,

  created_at       TEXT NOT NULL,
  updated_at       TEXT NOT NULL,
  UNIQUE (age_grade_id, slug)
);

CREATE INDEX IF NOT EXISTS idx_age_grade_posts_grade
  ON age_grade_posts (age_grade_id, status, published_at DESC);

-- ===========================================================================
-- Settings that govern how much the grades run themselves.
--
-- The defaults hand the grades real autonomy — a post goes live when its
-- administrator publishes it — because an update that has to wait a week for a
-- volunteer editor is an update that stops being written. Both switches exist
-- so the community can tighten this if it ever needs to, without a deployment.
-- ===========================================================================
INSERT OR IGNORE INTO site_settings (key, value, value_type, group_name, is_public, description, updated_at)
VALUES
  ('age_grades_self_registration', 'true', 'boolean', 'age_grades', 1,
   'Whether a signed-in member of the community may register their age grade. The grade still '
   || 'waits for the Preservation Team to confirm it before it appears publicly.',
   '2026-08-26T00:00:00.000Z'),
  ('age_grade_posts_require_review', 'false', 'boolean', 'age_grades', 0,
   'Whether a post by an age grade administrator must be reviewed before it appears. Off by '
   || 'default: a grade speaks for itself, and the page says so.',
   '2026-08-26T00:00:00.000Z'),
  ('age_grade_members_require_review', 'true', 'boolean', 'age_grades', 0,
   'Whether a member added to a roster must be confirmed before their name appears publicly. On '
   || 'by default, because a living person''s name is personal data.',
   '2026-08-26T00:00:00.000Z');

INSERT OR IGNORE INTO content_strings
  (key, value, draft_value, group_name, page, label, help_text, value_type,
   max_length, status, is_locked, sort_order, created_at, updated_at)
VALUES
  ('page.age_grades.register.title', 'Register your age grade', NULL, 'pages', 'age-grades',
   'Age grade registration form title', NULL, 'text', 120, 'published', 0, 400,
   '2026-08-26T00:00:00.000Z', '2026-08-26T00:00:00.000Z'),
  ('page.age_grades.register.intro',
   'If you belong to an age grade of Ekoli-Yeden, you can register it here and keep its page '
   || 'yourself. Give its name and the year it was formed. Once the Preservation Team has '
   || 'confirmed it, you and anybody you appoint can add its members, its photographs and its news.',
   NULL, 'pages', 'age-grades',
   'Age grade registration form introduction', NULL, 'text', 800, 'published', 0, 410,
   '2026-08-26T00:00:00.000Z', '2026-08-26T00:00:00.000Z'),
  ('page.age_grades.self_published_note',
   'Posted by the age grade itself. The Ekoli-Yeden Preservation Team has not verified this as '
   || 'community history.',
   NULL, 'pages', 'age-grades',
   'Label shown on a post written by an age grade', NULL, 'text', 300, 'published', 0, 420,
   '2026-08-26T00:00:00.000Z', '2026-08-26T00:00:00.000Z');
