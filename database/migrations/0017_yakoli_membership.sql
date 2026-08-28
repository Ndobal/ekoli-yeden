-- ---------------------------------------------------------------------------
-- EKOLI YEDEN DIGITAL HOME — Migration 0017
-- YAKOLI MEMBERSHIP — one Okoli account for the whole platform.
--
-- THE ARCHITECTURAL DECISION THIS ENCODES
--
-- The forum, the opportunities board and the directory do not get user systems
-- of their own. There is one account — the row in `users` that already exists —
-- and this migration gives it the depth those features need: who somebody is,
-- what they can do, where they are, and what they are willing to show.
--
-- Everything added afterwards (mentorship, volunteering, events registration,
-- fundraising) attaches to the same account rather than rebuilding identity.
--
-- WHY A SEPARATE TABLE RATHER THAN THIRTY COLUMNS ON `users`
--
-- `users` is the authentication table: email, password hash, session state,
-- account status. It is read on every single authenticated request. Membership
-- is a different thing with a different lifetime — an Editorial Team volunteer
-- has an account and may never fill in a profession, and a member may leave the
-- community's directory without their account changing at all.
--
-- Keeping them apart also means the profile can carry personal data with its
-- own visibility rules, without those rules having to be reasoned about every
-- time somebody signs in.
--
-- THE PRIVACY RULE, ENFORCED IN THE SCHEMA
--
-- Sensitive fields default to private and members-only. Not "the interface does
-- not show them" — the columns that govern visibility default that way, so a
-- new field or a new screen cannot leak somebody's phone number by omission.
--
-- The platform never publicly labels anybody unemployed. `employment_status` is
-- governed by `show_employment`, which defaults to 0, and the directory query
-- in Module 7 filters on `listed_in_directory`, which also defaults to 0. Both
-- are choices a member makes, not defaults they have to discover and undo.
-- ---------------------------------------------------------------------------

-- ===========================================================================
-- VOCABULARIES
--
-- Professions, skills and interests are tables rather than free text. That is
-- the whole reason the opportunities system in Module 6 can match anybody to
-- anything: "Flutter" typed into a text box is not comparable with "flutter",
-- "Flutter dev" or "Flutter/Dart", and no amount of matching logic recovers
-- from that.
--
-- All three are extensible without a migration — a member may propose a skill
-- nobody has listed, and an administrator promotes it into the vocabulary.
-- ===========================================================================

CREATE TABLE IF NOT EXISTS professions (
  id           TEXT PRIMARY KEY,
  slug         TEXT NOT NULL UNIQUE,
  name         TEXT NOT NULL,
  industry     TEXT,
  description  TEXT,

  -- Proposed by a member and not yet confirmed. Usable immediately — refusing
  -- somebody's own profession because it is not on a list is how a profile
  -- gets abandoned half-finished — but flagged for an administrator to tidy.
  is_approved  INTEGER NOT NULL DEFAULT 1 CHECK (is_approved IN (0, 1)),
  proposed_by  TEXT REFERENCES users (id) ON DELETE SET NULL,

  sort_order   INTEGER NOT NULL DEFAULT 0,
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_professions_industry ON professions (industry, name);

CREATE TABLE IF NOT EXISTS skills (
  id           TEXT PRIMARY KEY,
  slug         TEXT NOT NULL UNIQUE,
  name         TEXT NOT NULL,

  -- Groups a skill so the directory can offer "Construction" rather than four
  -- hundred ungrouped checkboxes.
  category     TEXT,
  description  TEXT,

  is_approved  INTEGER NOT NULL DEFAULT 1 CHECK (is_approved IN (0, 1)),
  proposed_by  TEXT REFERENCES users (id) ON DELETE SET NULL,

  -- Maintained as members attach themselves, so the directory can show the
  -- skills the community actually has rather than the ones somebody seeded.
  member_count INTEGER NOT NULL DEFAULT 0,

  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_skills_category ON skills (category, name);
CREATE INDEX IF NOT EXISTS idx_skills_popular ON skills (member_count DESC);

CREATE TABLE IF NOT EXISTS interests (
  id           TEXT PRIMARY KEY,
  slug         TEXT NOT NULL UNIQUE,
  name         TEXT NOT NULL,
  description  TEXT,
  sort_order   INTEGER NOT NULL DEFAULT 0,
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL
);

-- ===========================================================================
-- member_profiles
--
-- One row per Okoli. Created when somebody joins, not when they register — an
-- Editorial Team volunteer has an account without being a member of the Yakoli
-- community, and the two should not be forced together.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS member_profiles (
  id                    TEXT PRIMARY KEY,
  user_id               TEXT NOT NULL UNIQUE REFERENCES users (id) ON DELETE CASCADE,

  -- The quotable membership number, in the same shape as a contribution
  -- reference: YK-XXXXXX. Members will read it down a phone line.
  membership_number     TEXT NOT NULL UNIQUE,

  -- The public address of the profile. Derived from the display name, and
  -- separate from it so that changing your name does not break a link
  -- somebody shared.
  handle                TEXT NOT NULL UNIQUE,

  membership_status     TEXT NOT NULL DEFAULT 'active'
                          CHECK (membership_status IN ('pending', 'active', 'suspended', 'left')),
  joined_at             TEXT NOT NULL,

  -- --- Identity ----------------------------------------------------------
  full_name             TEXT,
  avatar_media_id       TEXT REFERENCES media_assets (id) ON DELETE SET NULL,
  headline              TEXT,
  bio                   TEXT,

  -- Contact. Never public by default — see `show_contact` below.
  phone                 TEXT,
  whatsapp_number       TEXT,

  -- --- Where ------------------------------------------------------------
  -- Held as separate fields rather than one address string, because Module 6
  -- matches opportunities by proximity: Ekoli-Yeden, then Yakurr, then Cross
  -- River, then Nigeria, then remote, then international. That ordering is
  -- impossible over a free-text address.
  country               TEXT,
  state_region          TEXT,
  lga                   TEXT,
  community_area        TEXT,
  city                  TEXT,

  -- True where the member is in Ekoli-Yeden itself, set from `community_area`
  -- on write. Denormalised on purpose: it is the first tier of the proximity
  -- sort and would otherwise be a string comparison on every opportunity.
  is_in_ekoli_yeden     INTEGER NOT NULL DEFAULT 0 CHECK (is_in_ekoli_yeden IN (0, 1)),
  is_diaspora           INTEGER NOT NULL DEFAULT 0 CHECK (is_diaspora IN (0, 1)),

  -- How this person belongs to Ekoli-Yeden. An enum with an "other" escape,
  -- because the common answers are few and the uncommon ones matter.
  connection            TEXT
                          CHECK (connection IS NULL OR connection IN (
                            'born_here', 'family_from_here', 'married_into', 'resident',
                            'descendant', 'returned', 'researcher', 'friend', 'other')),
  connection_note       TEXT,

  -- --- Professional -------------------------------------------------------
  profession_id         TEXT REFERENCES professions (id) ON DELETE SET NULL,
  profession_other      TEXT,
  industry              TEXT,
  employer              TEXT,
  years_experience      INTEGER CHECK (years_experience IS NULL OR (years_experience >= 0 AND years_experience <= 80)),

  education_level       TEXT
                          CHECK (education_level IS NULL OR education_level IN (
                            'primary', 'secondary', 'vocational', 'diploma', 'bachelors',
                            'masters', 'doctorate', 'other')),
  education_field       TEXT,
  institution           TEXT,

  -- --- Work situation -----------------------------------------------------
  --
  -- Asked as "what best describes your current work situation?" rather than
  -- "are you unemployed?". The grouping into working / seeking / student /
  -- retired / not-seeking is derived in the Worker rather than stored, so the
  -- two can never disagree.
  employment_status     TEXT
                          CHECK (employment_status IS NULL OR employment_status IN (
                            'employed_full_time', 'employed_part_time', 'self_employed',
                            'business_owner', 'freelancer', 'student',
                            'seeking_work', 'not_seeking', 'retired', 'other')),
  employment_updated_at TEXT,

  -- Whether they want to hear about opportunities. Distinct from employment
  -- status: somebody in full-time work may still want to know about a
  -- scholarship, and somebody seeking work may not want notifications.
  open_to_opportunities INTEGER NOT NULL DEFAULT 0 CHECK (open_to_opportunities IN (0, 1)),

  -- --- Age band -----------------------------------------------------------
  --
  -- The year only, never the full date. It is enough to tell a youth member
  -- from a student from an elder, which is all the platform needs it for, and
  -- a birth year is far less identifying than a birth date. Never public.
  birth_year            INTEGER CHECK (birth_year IS NULL OR (birth_year >= 1900 AND birth_year <= 2100)),

  -- --- Privacy ------------------------------------------------------------
  --
  -- `members` rather than `public` is the default for the profile itself, and
  -- everything sensitive is off. A member turns things on; nobody has to
  -- discover a default and undo it.
  profile_visibility    TEXT NOT NULL DEFAULT 'members'
                          CHECK (profile_visibility IN ('public', 'members', 'private')),
  show_contact          INTEGER NOT NULL DEFAULT 0 CHECK (show_contact IN (0, 1)),
  show_employment       INTEGER NOT NULL DEFAULT 0 CHECK (show_employment IN (0, 1)),
  show_location         INTEGER NOT NULL DEFAULT 1 CHECK (show_location IN (0, 1)),
  show_education        INTEGER NOT NULL DEFAULT 1 CHECK (show_education IN (0, 1)),

  -- Off by default, and the only thing the directory in Module 7 will look at.
  -- Being findable by profession is a decision, not a consequence of joining.
  listed_in_directory   INTEGER NOT NULL DEFAULT 0 CHECK (listed_in_directory IN (0, 1)),

  -- --- Notification preferences -------------------------------------------
  notify_opportunities  INTEGER NOT NULL DEFAULT 1 CHECK (notify_opportunities IN (0, 1)),
  notify_forum          INTEGER NOT NULL DEFAULT 1 CHECK (notify_forum IN (0, 1)),
  notify_community      INTEGER NOT NULL DEFAULT 1 CHECK (notify_community IN (0, 1)),

  -- --- Housekeeping -------------------------------------------------------
  -- How much of the profile is filled in, recalculated on write. Stored so the
  -- dashboard can nudge without recomputing across a dozen columns per view.
  completion_percent    INTEGER NOT NULL DEFAULT 0
                          CHECK (completion_percent >= 0 AND completion_percent <= 100),
  last_active_at        TEXT,
  created_at            TEXT NOT NULL,
  updated_at            TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_member_profiles_user ON member_profiles (user_id);
CREATE INDEX IF NOT EXISTS idx_member_profiles_handle ON member_profiles (handle);
CREATE INDEX IF NOT EXISTS idx_member_profiles_directory
  ON member_profiles (listed_in_directory, membership_status);
CREATE INDEX IF NOT EXISTS idx_member_profiles_profession
  ON member_profiles (profession_id, listed_in_directory);
CREATE INDEX IF NOT EXISTS idx_member_profiles_location
  ON member_profiles (country, state_region, lga);
-- The statistics query in the admin snapshot groups on this.
CREATE INDEX IF NOT EXISTS idx_member_profiles_employment
  ON member_profiles (employment_status);

-- ===========================================================================
-- What a member can do, and what they care about.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS member_skills (
  id          TEXT PRIMARY KEY,
  profile_id  TEXT NOT NULL REFERENCES member_profiles (id) ON DELETE CASCADE,
  skill_id    TEXT NOT NULL REFERENCES skills (id) ON DELETE CASCADE,

  -- Self-assessed, and labelled as such wherever it is shown. Useful for
  -- ordering a match; not a qualification the platform vouches for.
  proficiency TEXT NOT NULL DEFAULT 'unspecified'
                CHECK (proficiency IN ('unspecified', 'beginner', 'intermediate', 'advanced', 'expert')),
  years       INTEGER CHECK (years IS NULL OR (years >= 0 AND years <= 80)),
  created_at  TEXT NOT NULL,
  UNIQUE (profile_id, skill_id)
);

CREATE INDEX IF NOT EXISTS idx_member_skills_profile ON member_skills (profile_id);
-- Module 6 matches from this direction: "who has this skill?"
CREATE INDEX IF NOT EXISTS idx_member_skills_skill ON member_skills (skill_id);

CREATE TABLE IF NOT EXISTS member_interests (
  id          TEXT PRIMARY KEY,
  profile_id  TEXT NOT NULL REFERENCES member_profiles (id) ON DELETE CASCADE,
  interest_id TEXT NOT NULL REFERENCES interests (id) ON DELETE CASCADE,
  created_at  TEXT NOT NULL,
  UNIQUE (profile_id, interest_id)
);

CREATE INDEX IF NOT EXISTS idx_member_interests_profile ON member_interests (profile_id);
CREATE INDEX IF NOT EXISTS idx_member_interests_interest ON member_interests (interest_id);

-- ===========================================================================
-- notifications
--
-- Created in Module 4 because the account dashboard needs it, and written to by
-- Modules 5 and 6. Deliberately generic: a notification is a line of text, a
-- link, and a kind — not a foreign key into whichever feature raised it, which
-- would mean altering this table every time a feature is added.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS notifications (
  id             TEXT PRIMARY KEY,
  user_id        TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,

  kind           TEXT NOT NULL DEFAULT 'general'
                   CHECK (kind IN ('general', 'forum_reply', 'forum_mention', 'forum_moderation',
                                   'opportunity_match', 'opportunity_deadline', 'application_status',
                                   'membership', 'contribution', 'age_grade')),

  title          TEXT NOT NULL,
  body           TEXT,

  -- Where clicking it goes. A path on this site, never an external URL: a
  -- notification is not a delivery mechanism for somebody else's link.
  link_path      TEXT,

  -- What raised it, for de-duplication and for cleaning up when the thing it
  -- points at is deleted.
  resource_type  TEXT,
  resource_id    TEXT,

  read_at        TEXT,
  created_at     TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_notifications_user
  ON notifications (user_id, read_at, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_resource
  ON notifications (resource_type, resource_id);

-- ===========================================================================
-- The Okoli Member role.
--
-- Narrow on purpose. Membership grants a profile, the forums, the
-- opportunities board and the directory — and nothing that touches the
-- archive's content, which stays with the Editorial and Preservation Teams.
--
-- The permissions for Modules 5, 6 and 7 are listed here so the role does not
-- have to be rewritten three more times; the routes that honour them arrive
-- with those modules.
-- ===========================================================================
INSERT OR IGNORE INTO roles (id, slug, name, description, permissions, is_system, created_at, updated_at)
VALUES
  (
    'role_okoli_member',
    'okoli_member',
    'Okoli Member',
    'A member of the Yakoli community. May keep a profile, take part in the forums, see and apply '
    || 'for opportunities, and appear in the directory if they choose. Holds nothing over the '
    || 'archive''s own content.',
    '["members.profile","members.directory.read","forum.read","forum.post","forum.reply","forum.react","forum.report","opportunities.read","opportunities.apply","opportunities.save","notifications.read"]',
    1,
    '2026-08-27T00:00:00.000Z',
    '2026-08-27T00:00:00.000Z'
  );

-- ===========================================================================
-- Interests — the ten areas an Okoli can say they care about.
-- ===========================================================================
INSERT OR IGNORE INTO interests (id, slug, name, description, sort_order, created_at, updated_at)
VALUES
  ('int_education',      'education',             'Education',             'Schools, teaching, scholarships and learning.', 10, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('int_culture',        'culture',               'Culture',               'Traditions, festivals, music, dress and practice.', 20, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('int_heritage',       'heritage',              'Heritage',              'History, language, oral history and the archive itself.', 30, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('int_youth',          'youth-development',     'Youth development',     'Work with and for young people of Ekoli-Yeden.', 40, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('int_business',       'business',              'Business',              'Trade, enterprise and professional work.', 50, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('int_agriculture',    'agriculture',           'Agriculture',           'Farming, the seasons and the crops the community lives by.', 60, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('int_technology',     'technology',            'Technology',            'Software, engineering, digital skills and infrastructure.', 70, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('int_sports',         'sports',                'Sports',                'Wrestling, football and community sport.', 80, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('int_community_dev',  'community-development', 'Community development', 'Projects, infrastructure and the common good.', 90, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('int_volunteering',   'volunteering',          'Volunteering',          'Giving time to the community and to this archive.', 100, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z');

-- ===========================================================================
-- A starting vocabulary of professions and skills.
--
-- These are structural, not a claim about who lives in Ekoli-Yeden. They exist
-- so that the first member to join has something to pick from instead of an
-- empty list — and every one of them is extensible by the members themselves.
-- ===========================================================================
INSERT OR IGNORE INTO professions (id, slug, name, industry, sort_order, created_at, updated_at)
VALUES
  ('prof_teacher',        'teacher',                'Teacher',                       'Education',        10,  '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_lecturer',       'lecturer',               'Lecturer',                      'Education',        20,  '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_farmer',         'farmer',                 'Farmer',                        'Agriculture',      30,  '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_agronomist',     'agronomist',             'Agronomist',                    'Agriculture',      40,  '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_trader',         'trader',                 'Trader',                        'Business',         50,  '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_entrepreneur',   'entrepreneur',           'Entrepreneur',                  'Business',         60,  '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_accountant',     'accountant',             'Accountant',                    'Finance',          70,  '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_civil_engineer', 'civil-engineer',         'Civil Engineer',                'Engineering',      80,  '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_engineer',       'engineer',               'Engineer',                      'Engineering',      90,  '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_software_dev',   'software-developer',     'Software Developer',            'Technology',       100, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_data_analyst',   'data-analyst',           'Data Analyst',                  'Technology',       110, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_nurse',          'nurse',                  'Nurse',                         'Healthcare',       120, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_doctor',         'doctor',                 'Doctor',                        'Healthcare',       130, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_pharmacist',     'pharmacist',             'Pharmacist',                    'Healthcare',       140, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_lawyer',         'lawyer',                 'Lawyer',                        'Law',              150, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_civil_servant',  'civil-servant',          'Civil Servant',                 'Public service',   160, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_caterer',        'caterer',                'Caterer',                       'Hospitality',      170, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_tailor',         'tailor',                 'Tailor',                        'Craft and trade',  180, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_carpenter',      'carpenter',              'Carpenter',                     'Craft and trade',  190, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_mechanic',       'mechanic',               'Mechanic',                      'Craft and trade',  200, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_electrician',    'electrician',            'Electrician',                   'Craft and trade',  210, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_driver',         'driver',                 'Driver',                        'Transport',        220, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_journalist',     'journalist',             'Journalist',                    'Media',            230, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_designer',       'designer',               'Designer',                      'Media',            240, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_student',        'student',                'Student',                       'Education',        250, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_clergy',         'clergy',                 'Clergy',                        'Religious',        260, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_security',       'security-officer',       'Security Officer',              'Public service',   270, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('prof_other',          'other',                  'Other',                         NULL,               999, '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z');

INSERT OR IGNORE INTO skills (id, slug, name, category, created_at, updated_at)
VALUES
  ('skill_teaching',          'teaching',              'Teaching',               'Education',       '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_curriculum',        'curriculum-design',     'Curriculum Design',      'Education',       '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_mentoring',         'mentoring',             'Mentoring',              'Education',       '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_crop_farming',      'crop-farming',          'Crop Farming',           'Agriculture',     '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_livestock',         'livestock',             'Livestock',              'Agriculture',     '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_irrigation',        'irrigation',            'Irrigation',             'Agriculture',     '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_project_mgmt',      'project-management',    'Project Management',     'Business',        '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_bookkeeping',       'bookkeeping',           'Bookkeeping',            'Business',        '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_sales',             'sales',                 'Sales',                  'Business',        '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_marketing',         'marketing',             'Marketing',              'Business',        '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_structural',        'structural-design',     'Structural Design',      'Engineering',     '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_autocad',           'autocad',               'AutoCAD',                'Engineering',     '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_construction',      'construction-mgmt',     'Construction Management','Engineering',     '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_surveying',         'surveying',             'Surveying',              'Engineering',     '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_software_dev',      'software-development',  'Software Development',   'Technology',      '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_flutter',           'flutter',               'Flutter',                'Technology',      '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_dart',              'dart',                  'Dart',                   'Technology',      '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_javascript',        'javascript',            'JavaScript',             'Technology',      '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_python',            'python',                'Python',                 'Technology',      '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_data_analysis',     'data-analysis',         'Data Analysis',          'Technology',      '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_networking_it',     'it-networking',         'IT & Networking',        'Technology',      '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_graphic_design',    'graphic-design',        'Graphic Design',         'Media',           '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_photography',       'photography',           'Photography',            'Media',           '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_videography',       'videography',           'Videography',            'Media',           '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_writing',           'writing',               'Writing',                'Media',           '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_translation',       'translation',           'Translation',            'Media',           '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_nursing',           'nursing',               'Nursing',                'Healthcare',      '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_first_aid',         'first-aid',             'First Aid',              'Healthcare',      '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_community_health',  'community-health',      'Community Health',       'Healthcare',      '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_baking',            'baking',                'Baking',                 'Hospitality',     '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_event_catering',    'event-catering',        'Event Catering',         'Hospitality',     '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_food_prep',         'food-preparation',      'Food Preparation',       'Hospitality',     '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_tailoring',         'tailoring',             'Tailoring',              'Craft and trade', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_carpentry',         'carpentry',             'Carpentry',              'Craft and trade', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_masonry',           'masonry',               'Masonry',                'Craft and trade', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_welding',           'welding',               'Welding',                'Craft and trade', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_auto_repair',       'auto-repair',           'Auto Repair',            'Craft and trade', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_electrical',        'electrical-work',       'Electrical Work',        'Craft and trade', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_public_speaking',   'public-speaking',       'Public Speaking',        'General',         '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_leadership',        'leadership',            'Leadership',             'General',         '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_fundraising',       'fundraising',           'Fundraising',            'General',         '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_lokaa',             'lokaa-language',        'Lokaa Language',         'Heritage',        '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_oral_history',      'oral-history',          'Oral History',           'Heritage',        '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('skill_traditional_music', 'traditional-music',     'Traditional Music',      'Heritage',        '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z');

-- ===========================================================================
-- Settings.
-- ===========================================================================
INSERT OR IGNORE INTO site_settings (key, value, value_type, group_name, is_public, description, updated_at)
VALUES
  ('membership_open', 'true', 'boolean', 'membership', 1,
   'Whether the public may join the Yakoli community.',
   '2026-08-27T00:00:00.000Z'),
  ('membership_requires_approval', 'false', 'boolean', 'membership', 0,
   'Whether a new member waits for approval before their membership becomes active. Off by '
   || 'default: a barrier at the door is how a community platform stays empty.',
   '2026-08-27T00:00:00.000Z'),
  ('membership_minimum_age', '13', 'number', 'membership', 1,
   'The youngest age at which somebody may hold an account of their own.',
   '2026-08-27T00:00:00.000Z'),
  ('directory_open_to_public', 'false', 'boolean', 'membership', 1,
   'Whether the Yakoli directory can be searched by anybody, or only by signed-in members. Off by '
   || 'default: a directory of a community''s professionals is exactly the kind of list that '
   || 'should not be scrapeable.',
   '2026-08-27T00:00:00.000Z');

INSERT OR IGNORE INTO content_strings
  (key, value, draft_value, group_name, page, label, help_text, value_type,
   max_length, status, is_locked, sort_order, created_at, updated_at)
VALUES
  ('page.join.title', 'Join the Yakoli community', NULL, 'pages', 'join',
   'Membership page title', NULL, 'text', 120, 'published', 0, 500,
   '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('page.join.intro',
   'One account for the whole of Ekoli Yeden. Being a member means you can take part in the '
   || 'community forums, see opportunities meant for Ekoli-Yeden people, and be found by others '
   || 'who need what you can do — if you choose to be. You decide what appears on your profile, '
   || 'and nothing sensitive is shown by default.',
   NULL, 'pages', 'join',
   'Membership page introduction', NULL, 'text', 900, 'published', 0, 510,
   '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('page.join.privacy_note',
   'Your phone number, your email and your work situation are never shown publicly unless you '
   || 'turn them on. The platform does not label anybody unemployed, anywhere, to anyone.',
   NULL, 'pages', 'join',
   'The privacy promise on the membership form', NULL, 'text', 500, 'published', 0, 520,
   '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z');
