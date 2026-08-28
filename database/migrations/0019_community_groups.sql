-- ---------------------------------------------------------------------------
-- EKOLI YEDEN DIGITAL HOME — Migration 0019
-- COMMUNITY GROUPS — age grades, cultural groups, and whatever comes next.
--
-- WHY THIS GENERALISES `age_grades`
--
-- Migration 0016 gave age grades their own table, their own administrators and
-- their own posts. The community now wants the same for cultural groups: a
-- space of their own, members who can find and join them, dues, and a way to
-- raise an issue.
--
-- Building that a second time for cultural groups — and a third time for
-- associations, and a fourth for whatever follows — would leave four copies of
-- the same membership logic to keep in step. So the shape becomes one table
-- with a `kind`, and everything that hangs off a group hangs off `group_id`.
--
-- The age grades created under 0016 are migrated across KEEPING THEIR IDS,
-- because `content_sources` and `content_contributors` reference them by
-- ('age_grades', id). The old tables are left in place rather than dropped: a
-- migration that destroys rows is one nobody can safely re-run.
--
-- WHAT IS NEW BEYOND THE GENERALISATION
--
--   Age brackets      A grade declares the birth years it covers, so the
--                     platform can tell a member which grades are theirs
--                     instead of making them guess.
--
--   Joining           A member asks to join; an officer of the group confirms.
--                     Not automatic — a grade decides who belongs to it, and
--                     the platform is not the authority on that.
--
--   Dues             What is owed, how often, and where to pay it.
--
--   Payments         A member says they paid; an officer confirms. The
--                     platform does NOT move money — see below.
--
--   Issues           A member raises something with the group's officers.
--
-- WHAT THE DUES SYSTEM DELIBERATELY IS NOT
--
-- It is not a payment processor. No card is taken, no money moves through this
-- platform, and no balance it shows is authoritative. A group publishes its
-- account details; a member pays by their own bank and then records that they
-- did; an officer confirms it against the group's own statement.
--
-- That is honest about what a community website can actually promise, and it
-- avoids holding funds — which would bring obligations this project is in no
-- position to meet. The one real risk it does carry is that published account
-- details are a target for tampering, so every change to them is recorded in
-- `group_account_changes` and the page tells members to verify before paying.
-- ---------------------------------------------------------------------------

-- ===========================================================================
-- community_groups
-- ===========================================================================
CREATE TABLE IF NOT EXISTS community_groups (
  id                     TEXT PRIMARY KEY,
  slug                   TEXT NOT NULL UNIQUE,

  kind                   TEXT NOT NULL DEFAULT 'age_grade'
                           CHECK (kind IN ('age_grade', 'cultural_group', 'association',
                                           'union', 'society', 'other')),

  title                  TEXT NOT NULL,
  subtitle               TEXT,
  motto                  TEXT,
  excerpt                TEXT,
  body                   TEXT,
  category               TEXT,

  formed_year            INTEGER,

  -- --- Who this group is for ---------------------------------------------
  --
  -- Age grades are defined by birth years, so the bracket is stored as two
  -- years rather than as an age range: an age range would need re-entering
  -- every year, and would be wrong in between.
  --
  -- Both nullable. A cultural group is not defined by age at all, and an older
  -- age grade may not know its exact years.
  birth_year_from        INTEGER CHECK (birth_year_from IS NULL OR (birth_year_from >= 1900 AND birth_year_from <= 2100)),
  birth_year_to          INTEGER CHECK (birth_year_to IS NULL OR (birth_year_to >= 1900 AND birth_year_to <= 2100)),

  -- What the group writes for people to read, where the bracket is fuzzier
  -- than two numbers — "those born around the war years".
  birth_years            TEXT,

  -- How somebody joins.
  --
  --   by_age      the platform suggests it to members inside the bracket, and
  --               they ask to join
  --   by_request  anybody may ask; the group decides
  --   open        anybody may join without being confirmed
  --   closed      not accepting members at present
  join_policy            TEXT NOT NULL DEFAULT 'by_request'
                           CHECK (join_policy IN ('open', 'by_age', 'by_request', 'closed')),

  -- --- Dues ---------------------------------------------------------------
  dues_amount            REAL CHECK (dues_amount IS NULL OR dues_amount >= 0),
  dues_currency          TEXT NOT NULL DEFAULT 'NGN',
  dues_period            TEXT NOT NULL DEFAULT 'annual'
                           CHECK (dues_period IN ('annual', 'quarterly', 'monthly', 'one_off', 'other')),
  dues_notes             TEXT,
  dues_updated_at        TEXT,

  -- --- Presentation --------------------------------------------------------
  cover_media_id         TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  gallery_id             TEXT REFERENCES galleries (id) ON DELETE SET NULL,

  contact_name           TEXT,
  contact_phone          TEXT,
  contact_email          TEXT,

  member_count           INTEGER NOT NULL DEFAULT 0,
  sort_order             INTEGER NOT NULL DEFAULT 0,

  seo_title              TEXT,
  seo_description        TEXT,
  seo_image_media_id     TEXT REFERENCES media_assets (id) ON DELETE SET NULL,

  created_by             TEXT REFERENCES users (id) ON DELETE SET NULL,
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

CREATE INDEX IF NOT EXISTS idx_groups_kind ON community_groups (kind, status, sort_order);
-- The query that powers "which grades are mine?": every published group whose
-- bracket contains a given birth year.
CREATE INDEX IF NOT EXISTS idx_groups_bracket
  ON community_groups (kind, status, birth_year_from, birth_year_to);

-- ===========================================================================
-- group_admins — who may speak for a group.
--
-- The same narrow authority as `age_grade_admins`: one row, one group, nothing
-- anywhere else. `lead` may appoint and remove; `admin` may write.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS group_admins (
  id            TEXT PRIMARY KEY,
  group_id      TEXT NOT NULL REFERENCES community_groups (id) ON DELETE CASCADE,
  user_id       TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  admin_role    TEXT NOT NULL DEFAULT 'admin' CHECK (admin_role IN ('lead', 'admin', 'treasurer')),

  -- The office they hold inside the group, which is a different thing from
  -- what they may do on this website.
  office        TEXT,
  appointed_by  TEXT REFERENCES users (id) ON DELETE SET NULL,
  created_at    TEXT NOT NULL,
  UNIQUE (group_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_group_admins_group ON group_admins (group_id);
CREATE INDEX IF NOT EXISTS idx_group_admins_user ON group_admins (user_id);

-- ===========================================================================
-- group_members
--
-- Two kinds of row live here, and the difference matters:
--
--   `user_id` set     a member of this platform who asked to join
--   `user_id` null    somebody the group listed by name, who may never hold
--                     an account here — most of a grade's roster
--
-- `membership_state` is the group's decision, not the platform's. A member
-- asks; an officer confirms. The platform does not decide who belongs to an
-- age grade.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS group_members (
  id               TEXT PRIMARY KEY,
  group_id         TEXT NOT NULL REFERENCES community_groups (id) ON DELETE CASCADE,

  user_id          TEXT REFERENCES users (id) ON DELETE SET NULL,
  person_id        TEXT REFERENCES people (id) ON DELETE SET NULL,
  full_name        TEXT NOT NULL,

  membership_state TEXT NOT NULL DEFAULT 'requested'
                     CHECK (membership_state IN ('requested', 'active', 'declined', 'left', 'removed')),

  office           TEXT,
  joined_year      INTEGER,
  birth_year       INTEGER,
  notes            TEXT,

  -- What the person said when they asked to join.
  request_note     TEXT,
  decided_by       TEXT REFERENCES users (id) ON DELETE SET NULL,
  decided_at       TEXT,

  photo_media_id   TEXT REFERENCES media_assets (id) ON DELETE SET NULL,

  is_deceased      INTEGER NOT NULL DEFAULT 0 CHECK (is_deceased IN (0, 1)),
  deceased_year    INTEGER,

  sort_order       INTEGER NOT NULL DEFAULT 0,

  -- Whether the NAME may appear on the public roster. Separate from
  -- `membership_state`: an active member may not want their name on a public
  -- page, and being in a grade is not consent to be listed on the internet.
  status           TEXT NOT NULL DEFAULT 'pending_review'
                     CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),

  added_by         TEXT REFERENCES users (id) ON DELETE SET NULL,
  created_at       TEXT NOT NULL,
  updated_at       TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_group_members_group
  ON group_members (group_id, membership_state, sort_order);
CREATE INDEX IF NOT EXISTS idx_group_members_user ON group_members (user_id);
-- "Which groups am I in?" and "is this person already a member?" both need this.
CREATE UNIQUE INDEX IF NOT EXISTS idx_group_members_unique_user
  ON group_members (group_id, user_id) WHERE user_id IS NOT NULL;

-- ===========================================================================
-- group_posts — what the group says about itself.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS group_posts (
  id               TEXT PRIMARY KEY,
  group_id         TEXT NOT NULL REFERENCES community_groups (id) ON DELETE CASCADE,
  slug             TEXT NOT NULL,

  title            TEXT NOT NULL,
  excerpt          TEXT,
  body             TEXT,

  post_type        TEXT NOT NULL DEFAULT 'update'
                     CHECK (post_type IN ('update', 'announcement', 'meeting', 'project',
                                          'obituary', 'report', 'history', 'dues')),

  cover_media_id   TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  gallery_id       TEXT REFERENCES galleries (id) ON DELETE SET NULL,

  author_id        TEXT REFERENCES users (id) ON DELETE SET NULL,
  author_name      TEXT,

  -- Some notices are the group's own business rather than the community's.
  audience         TEXT NOT NULL DEFAULT 'public'
                     CHECK (audience IN ('public', 'members')),

  event_date       TEXT,
  published_at     TEXT,

  status           TEXT NOT NULL DEFAULT 'draft'
                     CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  review_notes     TEXT,
  reviewed_by      TEXT REFERENCES users (id) ON DELETE SET NULL,

  created_at       TEXT NOT NULL,
  updated_at       TEXT NOT NULL,
  UNIQUE (group_id, slug)
);

CREATE INDEX IF NOT EXISTS idx_group_posts_group
  ON group_posts (group_id, status, published_at DESC);

-- ===========================================================================
-- group_payment_accounts
--
-- Where members pay their dues.
--
-- THIS IS THE MOST SENSITIVE TABLE ON THE PLATFORM. Published account details
-- are a target: change the number and every member's dues go somewhere else.
-- Three things guard it, and none of them alone would be enough:
--
--   1. Only a `lead` or `treasurer` of the group may write it.
--   2. Every change is recorded in `group_account_changes`, with the old value
--      kept, so a substitution is visible afterwards.
--   3. The page shows members the last-changed date and tells them to confirm
--      with an officer they know before sending money.
--
-- The platform never handles the money itself.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS group_payment_accounts (
  id             TEXT PRIMARY KEY,
  group_id       TEXT NOT NULL REFERENCES community_groups (id) ON DELETE CASCADE,

  label          TEXT,
  bank_name      TEXT NOT NULL,
  account_name   TEXT NOT NULL,
  account_number TEXT NOT NULL,

  -- For groups whose members send money from abroad.
  swift_code     TEXT,
  sort_code      TEXT,
  instructions   TEXT,

  -- Account details are shown to members, never to the public. A community's
  -- bank details on an indexable page is an invitation.
  visibility     TEXT NOT NULL DEFAULT 'members'
                   CHECK (visibility IN ('members', 'admins')),

  is_primary     INTEGER NOT NULL DEFAULT 1 CHECK (is_primary IN (0, 1)),
  is_active      INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),

  added_by       TEXT REFERENCES users (id) ON DELETE SET NULL,
  last_changed_by TEXT REFERENCES users (id) ON DELETE SET NULL,
  created_at     TEXT NOT NULL,
  updated_at     TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_group_accounts_group
  ON group_payment_accounts (group_id, is_active, is_primary DESC);

-- --------------------------------------------------------------------------
-- group_account_changes — append-only.
--
-- The old value is kept deliberately. If somebody changes an account number,
-- the group can see exactly what it was before and when it changed, without
-- having to take anybody's word for it.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS group_account_changes (
  id                 TEXT PRIMARY KEY,
  account_id         TEXT NOT NULL REFERENCES group_payment_accounts (id) ON DELETE CASCADE,
  group_id           TEXT NOT NULL REFERENCES community_groups (id) ON DELETE CASCADE,

  changed_by         TEXT REFERENCES users (id) ON DELETE SET NULL,
  changed_by_name    TEXT,

  field              TEXT NOT NULL,
  old_value          TEXT,
  new_value          TEXT,

  ip_hash            TEXT,
  created_at         TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_group_account_changes_group
  ON group_account_changes (group_id, created_at DESC);

-- ===========================================================================
-- group_dues_payments
--
-- A member says they paid; an officer confirms it. Nothing here is a receipt,
-- and the platform says so on the page: it is the group's own record, kept
-- somewhere both sides can see it.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS group_dues_payments (
  id               TEXT PRIMARY KEY,
  group_id         TEXT NOT NULL REFERENCES community_groups (id) ON DELETE CASCADE,
  member_id        TEXT REFERENCES group_members (id) ON DELETE SET NULL,
  user_id          TEXT REFERENCES users (id) ON DELETE SET NULL,

  -- Held as text as well, so a record still reads correctly after an account
  -- is deleted.
  payer_name       TEXT,

  amount           REAL NOT NULL CHECK (amount >= 0),
  currency         TEXT NOT NULL DEFAULT 'NGN',

  -- What the dues were for: "2026", "Q1 2026", "building fund".
  period_label     TEXT,
  paid_on          TEXT,

  method           TEXT NOT NULL DEFAULT 'bank_transfer'
                     CHECK (method IN ('bank_transfer', 'cash', 'mobile_money', 'cheque', 'other')),

  -- The member's own reference — a transfer reference, a receipt number.
  reference        TEXT,
  note             TEXT,

  -- A photograph of the transfer slip, in the contribution bucket.
  proof_media_id   TEXT REFERENCES media_assets (id) ON DELETE SET NULL,

  state            TEXT NOT NULL DEFAULT 'declared'
                     CHECK (state IN ('declared', 'confirmed', 'disputed', 'cancelled')),

  confirmed_by     TEXT REFERENCES users (id) ON DELETE SET NULL,
  confirmed_at     TEXT,
  officer_note     TEXT,

  created_at       TEXT NOT NULL,
  updated_at       TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_dues_group
  ON group_dues_payments (group_id, state, paid_on DESC);
CREATE INDEX IF NOT EXISTS idx_dues_user ON group_dues_payments (user_id, group_id);

-- ===========================================================================
-- group_issues
--
-- A member raising something with the group's officers: a dispute, a
-- correction, a concern about money, a complaint.
--
-- Kept apart from the forums because it is not a discussion — it is addressed
-- to the group's officers, and some of it is nobody else's business.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS group_issues (
  id             TEXT PRIMARY KEY,
  group_id       TEXT NOT NULL REFERENCES community_groups (id) ON DELETE CASCADE,

  raised_by      TEXT REFERENCES users (id) ON DELETE SET NULL,
  raised_by_name TEXT,

  kind           TEXT NOT NULL DEFAULT 'other'
                   CHECK (kind IN ('dues', 'membership', 'conduct', 'correction',
                                   'finance', 'leadership', 'other')),

  subject        TEXT NOT NULL,
  detail         TEXT,

  -- Some things a member needs to raise without the rest of the group reading
  -- it. Visible to the group's officers only, and to nobody else.
  is_private     INTEGER NOT NULL DEFAULT 1 CHECK (is_private IN (0, 1)),

  state          TEXT NOT NULL DEFAULT 'open'
                   CHECK (state IN ('open', 'acknowledged', 'resolved', 'closed')),

  handled_by     TEXT REFERENCES users (id) ON DELETE SET NULL,
  handled_at     TEXT,
  resolution     TEXT,

  created_at     TEXT NOT NULL,
  updated_at     TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_group_issues_group
  ON group_issues (group_id, state, created_at DESC);

-- ===========================================================================
-- MIGRATING THE AGE GRADES CREATED UNDER 0016
--
-- Ids are preserved. `content_sources` and `content_contributors` reference
-- these rows by ('age_grades', id), and changing the id would orphan every
-- citation attached to them.
-- ===========================================================================
INSERT OR IGNORE INTO community_groups (
  id, slug, kind, title, subtitle, motto, excerpt, body, category,
  formed_year, birth_years, join_policy, cover_media_id, gallery_id,
  contact_name, contact_phone, contact_email, sort_order,
  seo_title, seo_description, seo_image_media_id, created_by,
  verification_status, author_id, editor_id, reviewer_id, published_by,
  submitted_at, published_at_workflow, review_notes, status, created_at, updated_at
)
SELECT
  g.id, g.slug, 'age_grade', g.title, g.subtitle, g.motto, g.excerpt, g.body, g.category,
  g.formed_year, g.birth_years, 'by_request', g.cover_media_id, g.gallery_id,
  g.contact_name, g.contact_phone, g.contact_email, g.sort_order,
  g.seo_title, g.seo_description, g.seo_image_media_id, g.created_by,
  g.verification_status, g.author_id, g.editor_id, g.reviewer_id, g.published_by,
  g.submitted_at, g.published_at_workflow, g.review_notes, g.status, g.created_at, g.updated_at
FROM age_grades g;

INSERT OR IGNORE INTO group_admins (id, group_id, user_id, admin_role, office, appointed_by, created_at)
SELECT a.id, a.age_grade_id, a.user_id, a.admin_role, a.office, a.appointed_by, a.created_at
FROM age_grade_admins a;

INSERT OR IGNORE INTO group_members (
  id, group_id, user_id, person_id, full_name, membership_state, office, joined_year,
  notes, photo_media_id, is_deceased, deceased_year, sort_order, status, added_by,
  created_at, updated_at
)
SELECT
  m.id, m.age_grade_id, m.user_id, m.person_id, m.full_name,
  -- A name a grade listed is an established member, not somebody waiting on a
  -- decision. Their public visibility is still governed by `status`.
  'active',
  m.office, m.joined_year, m.notes, m.photo_media_id, m.is_deceased, m.deceased_year,
  m.sort_order, m.status, m.added_by, m.created_at, m.updated_at
FROM age_grade_members m;

INSERT OR IGNORE INTO group_posts (
  id, group_id, slug, title, excerpt, body, post_type, cover_media_id, gallery_id,
  author_id, author_name, audience, event_date, published_at, status, review_notes,
  reviewed_by, created_at, updated_at
)
SELECT
  p.id, p.age_grade_id, p.slug, p.title, p.excerpt, p.body, p.post_type,
  p.cover_media_id, p.gallery_id, p.author_id, p.author_name, 'public',
  p.event_date, p.published_at, p.status, p.review_notes, p.reviewed_by,
  p.created_at, p.updated_at
FROM age_grade_posts p;

UPDATE community_groups
SET member_count = (
  SELECT COUNT(*) FROM group_members m
  WHERE m.group_id = community_groups.id AND m.membership_state = 'active'
);

-- The 0016 tables are left in place, holding the same rows. Nothing writes to
-- them from here on; they are kept so this migration can be re-run and so that
-- anything still pointing at them keeps resolving.

-- ===========================================================================
-- Settings.
-- ===========================================================================
INSERT OR IGNORE INTO site_settings (key, value, value_type, group_name, is_public, description, updated_at)
VALUES
  ('groups_self_registration', 'true', 'boolean', 'groups', 1,
   'Whether a member may register their age grade or cultural group. It still waits for the '
   || 'Preservation Team to confirm it before appearing publicly.',
   '2026-08-27T00:00:00.000Z'),
  ('groups_suggest_by_age', 'true', 'boolean', 'groups', 1,
   'Whether a member is shown the age grades their birth year falls inside.',
   '2026-08-27T00:00:00.000Z'),
  ('groups_dues_enabled', 'true', 'boolean', 'groups', 1,
   'Whether groups may publish dues and account details, and members record payments.',
   '2026-08-27T00:00:00.000Z'),
  ('groups_payment_disclaimer',
   'Ekoli Yeden does not handle this money. The account details below are published by the group '
   || 'itself, and a payment recorded here is the group''s own record rather than a receipt. '
   || 'Before sending money, confirm the account with an officer of the group you know personally.',
   'string', 'groups', 1,
   'Shown above every set of published account details. It is the honest statement of what this '
   || 'platform can and cannot promise about money.',
   '2026-08-27T00:00:00.000Z'),
  ('groups_member_birth_year_required', 'true', 'boolean', 'groups', 1,
   'Whether a member must record their birth year before joining an age grade. Required, because '
   || 'an age grade is defined by birth years and cannot check a claim without one.',
   '2026-08-27T00:00:00.000Z');

INSERT OR IGNORE INTO content_strings
  (key, value, draft_value, group_name, page, label, help_text, value_type,
   max_length, status, is_locked, sort_order, created_at, updated_at)
VALUES
  ('page.groups.dues_note',
   'Dues are set and collected by the group itself. This page records what the group has told us '
   || 'is owed and what members have said they paid — it is not a receipt, and no money passes '
   || 'through Ekoli Yeden.',
   NULL, 'pages', 'groups',
   'The note above a group''s dues', NULL, 'text', 600, 'published', 0, 600,
   '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('page.groups.join_note',
   'Asking to join sends a request to the group''s officers. They decide — being inside the birth '
   || 'years of an age grade does not by itself make somebody a member of it.',
   NULL, 'pages', 'groups',
   'The note on the join button', NULL, 'text', 400, 'published', 0, 610,
   '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('page.account.age_prompt',
   'Add the year you were born and we can show you which age grades are yours.',
   NULL, 'pages', 'account',
   'The dashboard prompt asking for a birth year', NULL, 'text', 300, 'published', 0, 620,
   '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z');
