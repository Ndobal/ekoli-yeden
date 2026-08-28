-- ---------------------------------------------------------------------------
-- EKOLI YEDEN DIGITAL HOME — Migration 0020
-- KINSHIP, BIRTHDAYS AND REMEMBRANCE
--
-- Three things the community asked for, which turn out to be one thing: the
-- platform knowing who belongs to whom.
--
--   Kinship       members declare how they are related, and both sides agree
--   Birthdays     the community is prompted to wish somebody well, and the
--                 wishes are kept year by year
--   Remembrance   when somebody dies, their account is stilled rather than
--                 deleted, and they are remembered rather than removed
--
-- ---------------------------------------------------------------------------
-- THREE DECISIONS IN HERE THAT ARE NOT OBVIOUS
-- ---------------------------------------------------------------------------
--
-- 1. A MEMORIALISED ACCOUNT IS READ-ONLY, NOT LOCKED.
--
--    Marking a living person as dead is the most damaging thing anybody can do
--    on this platform. If memorialisation locked the account, it would also
--    take away the one thing the person needs — the ability to sign in and say
--    "I am not dead."
--
--    So the account stays reachable and stops being writable. The person sees
--    what has been recorded and can contest it in one action. A malicious or
--    mistaken report is embarrassing and reversible rather than permanent.
--
-- 2. A DEATH IS CONFIRMED BY SOMEBODY WHO WAS ALREADY FAMILY.
--
--    Not by anybody claiming to be. `death_confirmations` requires an
--    ACCEPTED relationship that existed before the report — otherwise two
--    accounts made this morning could bury somebody this afternoon.
--
-- 3. A PHONE NUMBER IS AN ADDRESS, NOT A DIRECTORY.
--
--    `phone_normalised` exists so that a member can connect to a relative by
--    the number they already have for them. It must never become a way to ask
--    "does this number have an account?" — the connection endpoint answers the
--    same way whether or not it found somebody, exactly as the password reset
--    flow already does, and it is rate limited.
-- ---------------------------------------------------------------------------

-- ===========================================================================
-- DATES OF BIRTH
--
-- Migration 0017 stored the year only, deliberately: it was all the age-grade
-- brackets needed, and a birth year identifies a person far less than a birth
-- date does.
--
-- Birthdays need the day and the month, so there is now a reason to hold them.
-- The day and month are what the community sees; the YEAR stays private, so a
-- member can be wished a happy birthday without publishing their age.
-- ===========================================================================
ALTER TABLE member_profiles ADD COLUMN birth_date TEXT;

-- Split out and indexed, because the daily question is "whose birthday is
-- today?" — and asking that with substr() over a text column would scan every
-- member of the community every time somebody opens their dashboard.
ALTER TABLE member_profiles ADD COLUMN birth_day INTEGER
  CHECK (birth_day IS NULL OR (birth_day >= 1 AND birth_day <= 31));
ALTER TABLE member_profiles ADD COLUMN birth_month INTEGER
  CHECK (birth_month IS NULL OR (birth_month >= 1 AND birth_month <= 12));

-- On by default: being wished a happy birthday by your community is the point.
-- Off is one switch away for somebody who would rather not.
ALTER TABLE member_profiles ADD COLUMN show_birthday INTEGER NOT NULL DEFAULT 1
  CHECK (show_birthday IN (0, 1));

-- Distinct from `show_birthday`. Somebody may be happy for their birthday to be
-- known without wanting a public wall of messages about it.
ALTER TABLE member_profiles ADD COLUMN birthday_wishes_enabled INTEGER NOT NULL DEFAULT 1
  CHECK (birthday_wishes_enabled IN (0, 1));

-- The age is never published. Stated as a column so the rule is visible to
-- anybody reading the schema rather than only to somebody reading the Worker.
ALTER TABLE member_profiles ADD COLUMN show_age INTEGER NOT NULL DEFAULT 0
  CHECK (show_age IN (0, 1));

CREATE INDEX IF NOT EXISTS idx_member_birthday
  ON member_profiles (birth_month, birth_day, show_birthday);

-- --------------------------------------------------------------------------
-- The phone number, normalised for lookup.
--
-- Digits only, with a leading country code where one was given. `+234 803 123
-- 4567`, `0803 123 4567` and `234-803-123-4567` are the same person, and a
-- connection that fails because of a space is a connection that never happens.
--
-- Not unique: two members legitimately share a number — a household phone, a
-- parent holding a child's account. Uniqueness would refuse the second one.
-- --------------------------------------------------------------------------
ALTER TABLE member_profiles ADD COLUMN phone_normalised TEXT;

CREATE INDEX IF NOT EXISTS idx_member_phone ON member_profiles (phone_normalised);

-- --------------------------------------------------------------------------
-- Whether this member is living, reported, or remembered.
--
-- On `member_profiles` rather than on `users.status`, because `users.status`
-- governs authentication and this must NOT: a memorialised account still
-- signs in. See decision 1 at the top of this file.
-- --------------------------------------------------------------------------
ALTER TABLE member_profiles ADD COLUMN memorial_state TEXT NOT NULL DEFAULT 'living'
  CHECK (memorial_state IN ('living', 'reported', 'memorialised', 'contested'));

CREATE INDEX IF NOT EXISTS idx_member_memorial ON member_profiles (memorial_state);

-- ===========================================================================
-- member_relationships
--
-- One row per pair, not two. `type` is what `to_user` is TO `from_user` — "B is
-- my father". `reverse_type` is the other side, chosen by the person accepting,
-- because only they can say whether they are the son or the daughter.
--
-- NOTHING IS A RELATIONSHIP UNTIL BOTH SIDES AGREE. A pending row is a claim.
-- Anybody can claim anybody is their brother; the platform records that as a
-- request and nothing more until the other person says yes.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS member_relationships (
  id             TEXT PRIMARY KEY,

  from_user_id   TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  to_user_id     TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,

  -- What `to_user` is to `from_user`.
  type           TEXT NOT NULL
                   CHECK (type IN (
                     'spouse', 'husband', 'wife',
                     'father', 'mother', 'parent',
                     'son', 'daughter', 'child',
                     'brother', 'sister', 'sibling',
                     'grandfather', 'grandmother', 'grandparent',
                     'grandson', 'granddaughter', 'grandchild',
                     'uncle', 'aunt', 'nephew', 'niece', 'cousin',
                     'father_in_law', 'mother_in_law', 'son_in_law', 'daughter_in_law',
                     'brother_in_law', 'sister_in_law',
                     'stepfather', 'stepmother', 'stepson', 'stepdaughter',
                     'stepbrother', 'stepsister',
                     'guardian', 'ward', 'godparent', 'godchild',
                     'kin', 'other')),

  -- What `from_user` is to `to_user`, set when the request is accepted.
  reverse_type   TEXT,

  state          TEXT NOT NULL DEFAULT 'pending'
                   CHECK (state IN ('pending', 'accepted', 'declined', 'withdrawn', 'removed')),

  -- Which of the two started it. Both may later remove it; either removing it
  -- ends it, because a relationship one side denies is not a relationship.
  requested_by   TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  note           TEXT,

  -- How the requester found them, kept for the audit trail: a connection made
  -- by typing somebody's phone number is a different act from one made by
  -- opening their profile.
  via            TEXT NOT NULL DEFAULT 'profile'
                   CHECK (via IN ('profile', 'phone', 'invitation', 'admin')),

  decided_at     TEXT,
  removed_by     TEXT REFERENCES users (id) ON DELETE SET NULL,
  removed_at     TEXT,

  created_at     TEXT NOT NULL,
  updated_at     TEXT NOT NULL,

  -- One relationship per pair, in one direction. The service refuses the
  -- mirror image as well, so A→B and B→A cannot both exist.
  UNIQUE (from_user_id, to_user_id)
);

CREATE INDEX IF NOT EXISTS idx_relationships_from
  ON member_relationships (from_user_id, state);
CREATE INDEX IF NOT EXISTS idx_relationships_to
  ON member_relationships (to_user_id, state);
-- "Who is waiting on me?" — the request inbox.
CREATE INDEX IF NOT EXISTS idx_relationships_pending
  ON member_relationships (to_user_id, state, created_at DESC);

-- ===========================================================================
-- BIRTHDAY WISHES
--
-- Kept in their own table rather than as forum posts, because they are asked a
-- question forum posts cannot answer: "what did people say to me in 2027?"
-- The year is stored on the row, so each year is its own chapter and the
-- previous ones do not scroll away.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS birthday_wishes (
  id                TEXT PRIMARY KEY,

  recipient_user_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  sender_user_id    TEXT REFERENCES users (id) ON DELETE SET NULL,

  -- Held as text too, so a wish still reads correctly years later after the
  -- sender has closed their account. The same reasoning as contributor
  -- attribution in the archive: the message was still sent by somebody.
  sender_name       TEXT,

  -- The birthday this belongs to. The whole point of the feature: 2026's
  -- wishes are a different page from 2027's.
  year              INTEGER NOT NULL,

  message           TEXT NOT NULL,

  -- The community asked for wishes AND prayers, and they are not the same
  -- thing. Marked so the page can group them.
  is_prayer         INTEGER NOT NULL DEFAULT 0 CHECK (is_prayer IN (0, 1)),

  -- Where it was sent from, so a wish can say "from your age grade".
  group_id          TEXT REFERENCES community_groups (id) ON DELETE SET NULL,

  visibility        TEXT NOT NULL DEFAULT 'members'
                      CHECK (visibility IN ('public', 'members', 'private')),

  -- A wish is not moderated on the way in — the community should not need
  -- permission to be kind — but it can be hidden if it turns out not to be.
  status            TEXT NOT NULL DEFAULT 'published'
                      CHECK (status IN ('published', 'hidden', 'removed')),

  created_at        TEXT NOT NULL,

  -- One wish per person per birthday. A second attempt edits the first rather
  -- than filling the page with duplicates.
  UNIQUE (recipient_user_id, sender_user_id, year)
);

CREATE INDEX IF NOT EXISTS idx_wishes_recipient_year
  ON birthday_wishes (recipient_user_id, year, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wishes_sender ON birthday_wishes (sender_user_id);

-- --------------------------------------------------------------------------
-- birthday_prompts
--
-- What each member has already been asked, and what they did about it.
--
-- Exists so that "Not now" means not now. Without it the same prompt would
-- reappear on every page load, which turns a kindness into a nuisance and
-- teaches people to dismiss the notification without reading it.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS birthday_prompts (
  id                TEXT PRIMARY KEY,
  user_id           TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  recipient_user_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  year              INTEGER NOT NULL,
  action            TEXT NOT NULL DEFAULT 'shown'
                      CHECK (action IN ('shown', 'wished', 'skipped')),
  created_at        TEXT NOT NULL,
  UNIQUE (user_id, recipient_user_id, year)
);

CREATE INDEX IF NOT EXISTS idx_birthday_prompts
  ON birthday_prompts (user_id, year, action);

-- ===========================================================================
-- DEATH REPORTS
--
-- A report is a claim. It changes nothing on its own.
--
-- The path is: reported → confirmed by somebody who was already family →
-- the account holder is notified and given time to contest → memorialised.
-- The Preservation Team can stop or reverse it at any point in that sequence.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS death_reports (
  id                  TEXT PRIMARY KEY,

  -- The account, where the person had one. Null for somebody remembered who
  -- never used this platform — most of the community's dead.
  subject_user_id     TEXT REFERENCES users (id) ON DELETE SET NULL,
  subject_name        TEXT NOT NULL,

  reported_by         TEXT REFERENCES users (id) ON DELETE SET NULL,
  reporter_name       TEXT,

  -- How the reporter says they are related. A claim at this stage; the
  -- confirmation step requires a relationship that was already accepted.
  reporter_relationship TEXT,

  -- Which group raised it, where an age grade or a family reported one of
  -- their own.
  group_id            TEXT REFERENCES community_groups (id) ON DELETE SET NULL,

  date_of_death       TEXT,
  place_of_death      TEXT,
  detail              TEXT,

  state               TEXT NOT NULL DEFAULT 'reported'
                        CHECK (state IN ('reported', 'family_confirmed', 'memorialised',
                                         'contested', 'rejected', 'withdrawn')),

  confirmations       INTEGER NOT NULL DEFAULT 0,

  -- When the subject was told, and by when they could contest it. Both null
  -- where there was no account to tell.
  subject_notified_at TEXT,
  contest_closes_at   TEXT,
  contested_at        TEXT,
  contest_note        TEXT,

  reviewed_by         TEXT REFERENCES users (id) ON DELETE SET NULL,
  reviewed_at         TEXT,
  review_notes        TEXT,

  ancestry_record_id  TEXT,

  created_at          TEXT NOT NULL,
  updated_at          TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_death_reports_state
  ON death_reports (state, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_death_reports_subject
  ON death_reports (subject_user_id);

-- --------------------------------------------------------------------------
-- death_confirmations
--
-- The safeguard. A confirmation is only counted when the confirmer holds an
-- ACCEPTED relationship with the subject that existed before the report — the
-- service checks `member_relationships` and stores which row it relied on.
--
-- Without that, two accounts registered this morning could bury somebody this
-- afternoon.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS death_confirmations (
  id              TEXT PRIMARY KEY,
  report_id       TEXT NOT NULL REFERENCES death_reports (id) ON DELETE CASCADE,

  confirmed_by    TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  confirmer_name  TEXT,

  -- The accepted relationship this confirmation rested on. Recorded so the
  -- basis for a memorialisation is answerable afterwards.
  relationship_id TEXT REFERENCES member_relationships (id) ON DELETE SET NULL,
  relationship    TEXT,

  -- A Preservation Team member may confirm without being family, and that is a
  -- different kind of confirmation.
  is_official     INTEGER NOT NULL DEFAULT 0 CHECK (is_official IN (0, 1)),

  note            TEXT,
  created_at      TEXT NOT NULL,
  UNIQUE (report_id, confirmed_by)
);

CREATE INDEX IF NOT EXISTS idx_death_confirmations_report
  ON death_confirmations (report_id);

-- ===========================================================================
-- ANCESTRY RECORDS
--
-- The commemorating page. Not a deletion and not an archive of accounts — a
-- record of the people the community came from.
--
-- Most rows here will never have had an account. An elder who died in 1974 is
-- exactly who this is for, and the platform should be able to hold them
-- without pretending they were a member of a website.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS ancestry_records (
  id                 TEXT PRIMARY KEY,
  slug               TEXT NOT NULL UNIQUE,

  user_id            TEXT REFERENCES users (id) ON DELETE SET NULL,
  person_id          TEXT REFERENCES people (id) ON DELETE SET NULL,

  full_name          TEXT NOT NULL,
  also_known_as      TEXT,

  -- Both free of NOT NULL. For the older dead nobody now living may be
  -- certain, and a guessed date in a memorial is worse than an empty field.
  birth_date         TEXT,
  birth_year         INTEGER,
  death_date         TEXT,
  death_year         INTEGER,

  place_of_origin    TEXT,
  quarter            TEXT,

  biography          TEXT,
  contribution       TEXT,
  survived_by        TEXT,

  portrait_media_id  TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  gallery_id         TEXT REFERENCES galleries (id) ON DELETE SET NULL,

  -- Which age grade, family or cultural group they belonged to.
  group_id           TEXT REFERENCES community_groups (id) ON DELETE SET NULL,

  recorded_by        TEXT REFERENCES users (id) ON DELETE SET NULL,
  death_report_id    TEXT REFERENCES death_reports (id) ON DELETE SET NULL,

  verification_status TEXT NOT NULL DEFAULT 'unverified'
                        CHECK (verification_status IN ('unverified', 'in_review', 'verified', 'disputed')),

  -- The editorial workflow columns, so this behaves like every other content
  -- type and can be reached through the registry.
  author_id              TEXT REFERENCES users (id) ON DELETE SET NULL,
  editor_id              TEXT REFERENCES users (id) ON DELETE SET NULL,
  reviewer_id            TEXT REFERENCES users (id) ON DELETE SET NULL,
  published_by           TEXT REFERENCES users (id) ON DELETE SET NULL,
  submitted_at           TEXT,
  published_at_workflow  TEXT,
  review_notes           TEXT,

  seo_title          TEXT,
  seo_description    TEXT,
  sort_order         INTEGER NOT NULL DEFAULT 0,

  status             TEXT NOT NULL DEFAULT 'pending_review'
                       CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'archived', 'rejected')),
  created_at         TEXT NOT NULL,
  updated_at         TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ancestry_status
  ON ancestry_records (status, death_year DESC);
CREATE INDEX IF NOT EXISTS idx_ancestry_user ON ancestry_records (user_id);
CREATE INDEX IF NOT EXISTS idx_ancestry_group ON ancestry_records (group_id);

-- --------------------------------------------------------------------------
-- ancestry_tributes — what people leave on a memorial.
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ancestry_tributes (
  id            TEXT PRIMARY KEY,
  record_id     TEXT NOT NULL REFERENCES ancestry_records (id) ON DELETE CASCADE,

  author_id     TEXT REFERENCES users (id) ON DELETE SET NULL,
  author_name   TEXT,
  relationship  TEXT,

  message       TEXT NOT NULL,

  status        TEXT NOT NULL DEFAULT 'published'
                  CHECK (status IN ('pending_review', 'published', 'hidden', 'removed')),
  created_at    TEXT NOT NULL,
  updated_at    TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_tributes_record
  ON ancestry_tributes (record_id, status, created_at DESC);

-- ===========================================================================
-- Settings.
--
-- Every threshold in the death flow is here rather than in code, because the
-- right values depend on how this community actually works and that is not
-- something a schema should decide once and for all.
-- ===========================================================================
INSERT OR IGNORE INTO site_settings (key, value, value_type, group_name, is_public, description, updated_at)
VALUES
  ('birthdays_enabled', 'true', 'boolean', 'birthdays', 1,
   'Whether the platform prompts members to wish each other a happy birthday.',
   '2026-08-27T00:00:00.000Z'),
  ('birthday_prompt_scope', 'connections_and_groups', 'string', 'birthdays', 1,
   'Who is prompted about a birthday: everybody (all_members), only people connected to them '
   || '(connections), or connections plus every group they belong to (connections_and_groups).',
   '2026-08-27T00:00:00.000Z'),
  ('birthday_show_age', 'false', 'boolean', 'birthdays', 1,
   'Whether a birthday shows the member''s age. Off: the community can wish somebody well '
   || 'without publishing how old they are.',
   '2026-08-27T00:00:00.000Z'),

  ('relationships_require_acceptance', 'true', 'boolean', 'kinship', 0,
   'Whether both people must agree before a relationship is recorded. Locked on in practice — a '
   || 'relationship one side has not agreed to is a claim, not a fact.',
   '2026-08-27T00:00:00.000Z'),
  ('relationship_requests_per_day', '25', 'number', 'kinship', 0,
   'How many connection requests one member may send in a day. A brake on somebody working '
   || 'through the membership list.',
   '2026-08-27T00:00:00.000Z'),

  ('death_confirmations_required', '1', 'number', 'remembrance', 0,
   'How many confirmations from ALREADY-ACCEPTED relatives are needed before an account is '
   || 'memorialised. One by default; raise it if reports prove unreliable.',
   '2026-08-27T00:00:00.000Z'),
  ('death_contest_window_hours', '72', 'number', 'remembrance', 0,
   'How long the account holder has to contest before memorialisation takes effect. They are '
   || 'notified when the report is confirmed, and can contest in one action.',
   '2026-08-27T00:00:00.000Z'),
  ('death_requires_team_review', 'true', 'boolean', 'remembrance', 0,
   'Whether the Preservation Team must approve before a memorial page is published. The account '
   || 'is stilled on family confirmation either way; this governs the public page.',
   '2026-08-27T00:00:00.000Z'),
  ('memorialised_accounts_readonly', 'true', 'boolean', 'remembrance', 0,
   'Whether a memorialised account can still sign in, read-only. On, and it should stay on: an '
   || 'account locked out of contesting its own death has no way to correct a mistake.',
   '2026-08-27T00:00:00.000Z');

INSERT OR IGNORE INTO content_strings
  (key, value, draft_value, group_name, page, label, help_text, value_type,
   max_length, status, is_locked, sort_order, created_at, updated_at)
VALUES
  ('birthday.prompt.title', 'Congratulations {name}, on your birthday!', NULL, 'birthdays', 'account',
   'The birthday card heading. {name} is replaced with the member''s name', NULL, 'text', 200,
   'published', 0, 700, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('birthday.prompt.wish', 'Wish them a happy birthday', NULL, 'birthdays', 'account',
   'The button that opens the message box', NULL, 'text', 60,
   'published', 0, 710, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('birthday.prompt.skip', 'Not now', NULL, 'birthdays', 'account',
   'The button that dismisses the prompt until next year', NULL, 'text', 60,
   'published', 0, 720, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('birthday.greeting.default',
   'Happy birthday from all of us at Ekoli-Yeden. May the year ahead bring you health, peace and '
   || 'the company of your people.',
   NULL, 'birthdays', 'account',
   'What the platform itself says to a member on their birthday', NULL, 'text', 400,
   'published', 0, 730, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),

  ('page.ancestry.title', 'Ancestry Records', NULL, 'pages', 'ancestry',
   'The memorial section title', NULL, 'text', 120,
   'published', 0, 740, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('page.ancestry.intro',
   'The people Ekoli-Yeden came from. Nobody is removed from this archive when they die — their '
   || 'account is stilled, what they made public stays public, and they are remembered here. If '
   || 'you can tell us about somebody who is not yet recorded, please do.',
   NULL, 'pages', 'ancestry',
   'The memorial section introduction', NULL, 'text', 800,
   'published', 0, 750, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('page.memorial.contest_note',
   'This account has been recorded as belonging to somebody who has died. If that is wrong, press '
   || 'the button below and the Preservation Team will be told at once. Nothing has been deleted.',
   NULL, 'pages', 'account',
   'Shown to a memorialised account when its holder signs in', NULL, 'text', 500,
   'published', 0, 760, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z');
