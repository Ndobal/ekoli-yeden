-- ===========================================================================
-- 0024  YAKOLI OPPORTUNITIES  (Module 6)
-- ===========================================================================
--
-- Jobs, scholarships, grants, training and apprenticeships, matched to members
-- by what they can do and where they are.
--
-- ---------------------------------------------------------------------------
-- THE ONE THING THIS MODULE MUST GET RIGHT
-- ---------------------------------------------------------------------------
--
-- A community jobs board is a gift to whoever wants to defraud that community.
-- Fake recruiters asking for a "processing fee" are among the most common
-- frauds people here meet, and a listing carrying the archive's name borrows
-- the archive's credibility to do it.
--
-- So three things are built in from the start rather than added after somebody
-- is hurt:
--
--   1. NOTHING IS PUBLIC UNTIL REVIEWED. `status` starts at pending_review, as
--      everywhere else in this archive.
--   2. EVERY LISTING SAYS WHETHER IT IS VOUCHED FOR. `verification_status` is
--      shown to the member, not just stored, so an unverified listing looks
--      unverified.
--   3. ANY MEMBER CAN REPORT ONE, and reporting is one press from the listing
--      itself. `opportunity_reports` exists for that.
--
-- And one thing the archive states plainly on every listing: no legitimate
-- employer asks a candidate for money.
-- ===========================================================================

CREATE TABLE IF NOT EXISTS opportunities (
  id                  TEXT PRIMARY KEY,
  slug                TEXT NOT NULL UNIQUE,

  kind                TEXT NOT NULL DEFAULT 'job'
                        CHECK (kind IN ('job', 'internship', 'apprenticeship', 'scholarship',
                                        'grant', 'training', 'volunteer', 'tender', 'other')),

  title               TEXT NOT NULL,
  organisation        TEXT NOT NULL,
  summary             TEXT,
  description         TEXT,
  requirements        TEXT,
  benefits            TEXT,

  -- --- Where -------------------------------------------------------------
  -- The tier is what the sort uses; the text is what a person reads. Both,
  -- because "Ekori" and "ekoli_yeden" serve different purposes.
  location_tier       TEXT NOT NULL DEFAULT 'nigeria'
                        CHECK (location_tier IN ('ekoli_yeden', 'yakurr', 'cross_river',
                                                 'nigeria', 'remote', 'international')),
  location_text       TEXT,
  is_remote           INTEGER NOT NULL DEFAULT 0 CHECK (is_remote IN (0, 1)),

  -- --- Terms --------------------------------------------------------------
  employment_type     TEXT
                        CHECK (employment_type IS NULL OR employment_type IN
                               ('full_time', 'part_time', 'contract', 'temporary',
                                'casual', 'self_employed')),

  -- Held as a range, because "what does it pay?" is the question most listings
  -- dodge and the one members most need answered.
  pay_min             REAL,
  pay_max             REAL,
  pay_currency        TEXT NOT NULL DEFAULT 'NGN',
  pay_period          TEXT
                        CHECK (pay_period IS NULL OR pay_period IN
                               ('hour', 'day', 'week', 'month', 'year', 'once')),
  pay_note            TEXT,

  -- --- Applying -----------------------------------------------------------
  application_url     TEXT,
  application_email   TEXT,
  application_phone   TEXT,
  application_note    TEXT,
  closes_at           TEXT,

  -- --- Provenance ---------------------------------------------------------
  -- Who put it here matters more than usual on this table: a listing posted by
  -- a known member of the community carries different weight from one sent in
  -- by a stranger, and a member deciding whether to trust it should be able to
  -- see which it is.
  posted_by           TEXT REFERENCES users (id) ON DELETE SET NULL,
  poster_name         TEXT,
  poster_relationship TEXT,
  source_url          TEXT,

  verification_status TEXT NOT NULL DEFAULT 'unverified'
                        CHECK (verification_status IN ('unverified', 'in_review', 'verified', 'disputed')),
  verified_by         TEXT REFERENCES users (id) ON DELETE SET NULL,
  verified_at         TEXT,

  -- Set when the Preservation Team has decided a listing is a fraud. Kept
  -- rather than deleted so the same one cannot simply be posted again without
  -- anybody remembering.
  is_flagged          INTEGER NOT NULL DEFAULT 0 CHECK (is_flagged IN (0, 1)),
  flag_reason         TEXT,

  view_count          INTEGER NOT NULL DEFAULT 0,

  status              TEXT NOT NULL DEFAULT 'pending_review'
                        CHECK (status IN ('draft', 'pending_review', 'approved', 'published',
                                          'archived', 'rejected')),
  created_at          TEXT NOT NULL,
  updated_at          TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_opportunities_live
  ON opportunities (status, closes_at);
CREATE INDEX IF NOT EXISTS idx_opportunities_kind
  ON opportunities (kind, status);
CREATE INDEX IF NOT EXISTS idx_opportunities_location
  ON opportunities (location_tier, status);
CREATE INDEX IF NOT EXISTS idx_opportunities_poster
  ON opportunities (posted_by);

-- ---------------------------------------------------------------------------
-- What a listing needs somebody to be able to do
--
-- The join that makes matching possible. A member's `member_skills` meeting an
-- opportunity's `opportunity_skills` is the whole mechanism — which is why the
-- dashboard nags about adding skills: a member with none cannot be matched to
-- anything, however much they might suit it.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS opportunity_skills (
  id              TEXT PRIMARY KEY,
  opportunity_id  TEXT NOT NULL REFERENCES opportunities (id) ON DELETE CASCADE,
  skill_id        TEXT NOT NULL REFERENCES skills (id) ON DELETE CASCADE,

  -- Essential versus welcome. A member missing an essential skill is shown the
  -- listing anyway, with the gap named — being told what to learn is more use
  -- than being quietly filtered out.
  is_required     INTEGER NOT NULL DEFAULT 1 CHECK (is_required IN (0, 1)),

  created_at      TEXT NOT NULL,
  UNIQUE (opportunity_id, skill_id)
);

CREATE INDEX IF NOT EXISTS idx_opportunity_skills_skill
  ON opportunity_skills (skill_id, is_required);

-- ---------------------------------------------------------------------------
-- Saved for later
--
-- Deliberately not "applied". The archive does not sit between a member and an
-- employer, and pretending to track applications it cannot see would be a lie
-- the interface tells every time it showed a status.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS opportunity_saves (
  id              TEXT PRIMARY KEY,
  opportunity_id  TEXT NOT NULL REFERENCES opportunities (id) ON DELETE CASCADE,
  user_id         TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  note            TEXT,
  created_at      TEXT NOT NULL,
  UNIQUE (opportunity_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_opportunity_saves_user
  ON opportunity_saves (user_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- "This is a scam"
--
-- One press from the listing. The count is what matters most: several
-- independent reports on one listing is the signal that reaches the
-- Preservation Team fastest, and it is the community protecting itself rather
-- than waiting to be protected.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS opportunity_reports (
  id              TEXT PRIMARY KEY,
  opportunity_id  TEXT NOT NULL REFERENCES opportunities (id) ON DELETE CASCADE,
  reported_by     TEXT REFERENCES users (id) ON DELETE SET NULL,
  reporter_name   TEXT,

  reason          TEXT NOT NULL DEFAULT 'other'
                    CHECK (reason IN ('asks_for_money', 'not_genuine', 'expired',
                                      'misleading', 'offensive', 'duplicate', 'other')),
  detail          TEXT,

  state           TEXT NOT NULL DEFAULT 'open'
                    CHECK (state IN ('open', 'upheld', 'dismissed')),
  reviewed_by     TEXT REFERENCES users (id) ON DELETE SET NULL,
  reviewed_at     TEXT,
  review_note     TEXT,

  created_at      TEXT NOT NULL,
  UNIQUE (opportunity_id, reported_by)
);

CREATE INDEX IF NOT EXISTS idx_opportunity_reports_open
  ON opportunity_reports (state, created_at DESC);

-- ---------------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------------

INSERT OR IGNORE INTO roles (id, slug, name, description, permissions, is_system, created_at, updated_at)
VALUES (
  'role_opportunities_editor',
  'opportunities_editor',
  'Opportunities Editor',
  'Reviews and publishes jobs, scholarships and training, and acts on reports of fraudulent listings.',
  '["opportunities:read","opportunities:create","opportunities:update","opportunities:publish","opportunities:delete"]',
  0,
  datetime('now'),
  datetime('now')
);

-- ---------------------------------------------------------------------------
-- The words the page says
-- ---------------------------------------------------------------------------

INSERT OR IGNORE INTO content_strings
  (key, value, group_name, page, label, help_text, value_type, status, created_at, updated_at)
VALUES
  ('page.opportunities.intro',
   'Jobs, scholarships, training and grants, shown to you in the order they suit you — what you '
   || 'can do, and how near it is. Add your skills to your profile and this page starts working '
   || 'for you.',
   'opportunities', 'opportunities',
   'Opportunities — introduction',
   'The paragraph under the heading on the opportunities page',
   'text', 'published', datetime('now'), datetime('now')),

  ('page.opportunities.fraud_warning',
   'No genuine employer, school or training provider will ever ask you to pay a fee to apply, to '
   || 'be interviewed, or to be given a job. If a listing here asks you for money, do not pay it '
   || '— report the listing instead. It takes one press and it protects everybody after you.',
   'opportunities', 'opportunities',
   'Opportunities — fraud warning',
   'Shown on every opportunity listing. Please do not soften this.',
   'text', 'published', datetime('now'), datetime('now'));
