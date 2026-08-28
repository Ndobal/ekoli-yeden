-- ---------------------------------------------------------------------------
-- EKOLI YEDEN DIGITAL HOME — Migration 0018
-- YAKOLI COMMUNITY — the forums.
--
-- THE SHAPE, AND WHY IT IS A FORUM RATHER THAN A FEED
--
-- This archive exists because WhatsApp loses things. A feed sorted by what is
-- newest — or worse, by what gets reactions — would recreate exactly the
-- problem the platform was built to solve: the loudest thing wins and the
-- elder's account sinks.
--
-- So: topics, in categories, in spaces. A question asked in 2026 is still
-- findable in 2036, still has its answers attached, and still sits under a
-- heading that says what it is about. The "Community Wall" a member sees is a
-- view over these same tables, not a second system.
--
-- THREE SPACES, NOT THREE CATEGORIES
--
-- The Youth and Student spaces are separate spaces rather than categories in
-- the general forum, because they need different rules — not just a different
-- heading. The student space in particular may contain minors, and that has to
-- be a property of the space enforced by the schema, not a convention.
--
-- MODERATION IS NOT AN AFTERTHOUGHT
--
-- Every post can be reported. Every moderator action is recorded in
-- `forum_moderation_actions`, which has no update or delete path — the same
-- discipline as `audit_logs`. A community platform where moderation is
-- invisible is a community platform where moderation becomes suspect.
-- ---------------------------------------------------------------------------

-- ===========================================================================
-- forum_spaces
--
-- Three to begin with. A space owns its own visibility, its own moderators and
-- its own rules about who may post.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS forum_spaces (
  id             TEXT PRIMARY KEY,
  slug           TEXT NOT NULL UNIQUE,
  name           TEXT NOT NULL,
  tagline        TEXT,
  description    TEXT,

  kind           TEXT NOT NULL DEFAULT 'community'
                   CHECK (kind IN ('community', 'youth', 'students')),

  -- Who may READ the space.
  --
  --   public   anybody, signed in or not
  --   members  Yakoli members only
  --
  -- The student space is `members` and stays that way: a space that may
  -- contain minors should not be readable by an anonymous visitor, and should
  -- certainly not be indexable.
  visibility     TEXT NOT NULL DEFAULT 'members'
                   CHECK (visibility IN ('public', 'members')),

  -- Whether search engines may index it. Separate from `visibility` because a
  -- space could be publicly readable and still not something to surface in a
  -- search result — and because getting this wrong for the student space is
  -- the single worst mistake this module could make.
  is_indexable   INTEGER NOT NULL DEFAULT 0 CHECK (is_indexable IN (0, 1)),

  -- Whether a new topic waits for a moderator before anybody sees it.
  requires_approval INTEGER NOT NULL DEFAULT 0 CHECK (requires_approval IN (0, 1)),

  -- Extra care for spaces that may contain minors: contact details and precise
  -- locations are suppressed on author cards, and reports are prioritised.
  is_youth_space INTEGER NOT NULL DEFAULT 0 CHECK (is_youth_space IN (0, 1)),

  icon           TEXT,
  accent         TEXT,
  sort_order     INTEGER NOT NULL DEFAULT 0,
  topic_count    INTEGER NOT NULL DEFAULT 0,

  status         TEXT NOT NULL DEFAULT 'published'
                   CHECK (status IN ('draft', 'published', 'archived')),
  created_at     TEXT NOT NULL,
  updated_at     TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_forum_spaces_status ON forum_spaces (status, sort_order);

-- ===========================================================================
-- forum_categories
-- ===========================================================================
CREATE TABLE IF NOT EXISTS forum_categories (
  id           TEXT PRIMARY KEY,
  space_id     TEXT NOT NULL REFERENCES forum_spaces (id) ON DELETE CASCADE,
  slug         TEXT NOT NULL,
  name         TEXT NOT NULL,
  description  TEXT,

  -- Grouping within a space — "Community", "Heritage", "Development", "Social"
  -- in the general forum. A heading above the categories rather than a level of
  -- nesting, because two levels is enough for any forum a community this size
  -- will ever need.
  section      TEXT,

  icon         TEXT,
  sort_order   INTEGER NOT NULL DEFAULT 0,
  topic_count  INTEGER NOT NULL DEFAULT 0,

  -- Announcements should be readable by everybody and writable by few.
  post_permission TEXT NOT NULL DEFAULT 'members'
                    CHECK (post_permission IN ('members', 'moderators')),

  status       TEXT NOT NULL DEFAULT 'published'
                 CHECK (status IN ('draft', 'published', 'archived')),
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL,
  UNIQUE (space_id, slug)
);

CREATE INDEX IF NOT EXISTS idx_forum_categories_space
  ON forum_categories (space_id, status, sort_order);

-- ===========================================================================
-- forum_topics
--
-- `space_id` is denormalised onto the topic. It could be reached through the
-- category every time, but every listing, every permission check and every
-- moderation query needs it, and a join per check is a join too many.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS forum_topics (
  id             TEXT PRIMARY KEY,
  space_id       TEXT NOT NULL REFERENCES forum_spaces (id) ON DELETE CASCADE,
  category_id    TEXT NOT NULL REFERENCES forum_categories (id) ON DELETE CASCADE,
  slug           TEXT NOT NULL,

  title          TEXT NOT NULL,
  body           TEXT NOT NULL,

  author_id      TEXT REFERENCES users (id) ON DELETE SET NULL,
  -- Kept as text as well, so a topic still reads correctly after an account is
  -- deleted. The same reasoning as contributor attribution in the archive.
  author_name    TEXT,

  is_pinned      INTEGER NOT NULL DEFAULT 0 CHECK (is_pinned IN (0, 1)),
  is_locked      INTEGER NOT NULL DEFAULT 0 CHECK (is_locked IN (0, 1)),

  reply_count    INTEGER NOT NULL DEFAULT 0,
  reaction_count INTEGER NOT NULL DEFAULT 0,
  last_reply_at  TEXT,
  last_reply_by  TEXT,

  -- `hidden` is a moderator's decision that something should not be seen but
  -- should still exist; `removed` is the same with the content cleared. Neither
  -- deletes the row, because a moderation decision that leaves no trace is a
  -- moderation decision nobody can review.
  status         TEXT NOT NULL DEFAULT 'published'
                   CHECK (status IN ('pending_review', 'published', 'hidden', 'removed')),

  created_at     TEXT NOT NULL,
  updated_at     TEXT NOT NULL,
  UNIQUE (space_id, slug)
);

CREATE INDEX IF NOT EXISTS idx_forum_topics_category
  ON forum_topics (category_id, status, is_pinned DESC, last_reply_at DESC);
CREATE INDEX IF NOT EXISTS idx_forum_topics_space
  ON forum_topics (space_id, status, last_reply_at DESC);
CREATE INDEX IF NOT EXISTS idx_forum_topics_author ON forum_topics (author_id);

-- ===========================================================================
-- forum_posts — the replies.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS forum_posts (
  id             TEXT PRIMARY KEY,
  topic_id       TEXT NOT NULL REFERENCES forum_topics (id) ON DELETE CASCADE,

  -- One level of threading. Replying to a reply is useful; replying to a reply
  -- to a reply produces a shape nobody can read on a phone.
  parent_post_id TEXT REFERENCES forum_posts (id) ON DELETE SET NULL,

  body           TEXT NOT NULL,
  author_id      TEXT REFERENCES users (id) ON DELETE SET NULL,
  author_name    TEXT,

  reaction_count INTEGER NOT NULL DEFAULT 0,
  is_answer      INTEGER NOT NULL DEFAULT 0 CHECK (is_answer IN (0, 1)),

  status         TEXT NOT NULL DEFAULT 'published'
                   CHECK (status IN ('pending_review', 'published', 'hidden', 'removed')),

  edited_at      TEXT,
  created_at     TEXT NOT NULL,
  updated_at     TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_forum_posts_topic
  ON forum_posts (topic_id, status, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_forum_posts_author ON forum_posts (author_id);

-- ===========================================================================
-- forum_reactions
--
-- Deliberately few kinds, and deliberately not used for ranking anything.
-- Sorting a community's conversation by what gets the most reactions is how
-- the loudest thing wins; the count is shown, and it orders nothing.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS forum_reactions (
  id           TEXT PRIMARY KEY,
  target_type  TEXT NOT NULL CHECK (target_type IN ('topic', 'post')),
  target_id    TEXT NOT NULL,
  user_id      TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  kind         TEXT NOT NULL DEFAULT 'appreciate'
                 CHECK (kind IN ('appreciate', 'agree', 'helpful', 'celebrate')),
  created_at   TEXT NOT NULL,
  UNIQUE (target_type, target_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_forum_reactions_target
  ON forum_reactions (target_type, target_id);

-- ===========================================================================
-- forum_follows — "tell me when somebody replies to this".
-- ===========================================================================
CREATE TABLE IF NOT EXISTS forum_follows (
  id          TEXT PRIMARY KEY,
  topic_id    TEXT NOT NULL REFERENCES forum_topics (id) ON DELETE CASCADE,
  user_id     TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  created_at  TEXT NOT NULL,
  UNIQUE (topic_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_forum_follows_topic ON forum_follows (topic_id);
CREATE INDEX IF NOT EXISTS idx_forum_follows_user ON forum_follows (user_id);

-- ===========================================================================
-- forum_reports
--
-- Every post carries a Report. The queue is what stops the forums becoming an
-- uncontrolled comment section — and it only works if reporting is one tap and
-- the reporter never has to explain themselves at length.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS forum_reports (
  id            TEXT PRIMARY KEY,
  target_type   TEXT NOT NULL CHECK (target_type IN ('topic', 'post')),
  target_id     TEXT NOT NULL,

  reporter_id   TEXT REFERENCES users (id) ON DELETE SET NULL,

  reason        TEXT NOT NULL
                  CHECK (reason IN ('abuse', 'harassment', 'spam', 'misinformation',
                                    'inappropriate', 'off_topic', 'personal_information',
                                    'child_safety', 'other')),
  detail        TEXT,

  status        TEXT NOT NULL DEFAULT 'open'
                  CHECK (status IN ('open', 'reviewing', 'actioned', 'dismissed')),

  reviewed_by   TEXT REFERENCES users (id) ON DELETE SET NULL,
  reviewed_at   TEXT,
  review_notes  TEXT,

  ip_hash       TEXT,
  created_at    TEXT NOT NULL,
  updated_at    TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_forum_reports_status
  ON forum_reports (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_forum_reports_target
  ON forum_reports (target_type, target_id);

-- ===========================================================================
-- forum_moderation_actions
--
-- Append-only, like `audit_logs`. There is deliberately no update or delete
-- path in the application.
--
-- A community platform where moderation is invisible is a community platform
-- where moderation becomes suspect — "who removed my post, and why?" has to
-- have an answer, and the answer has to be one somebody else can check.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS forum_moderation_actions (
  id            TEXT PRIMARY KEY,

  moderator_id  TEXT REFERENCES users (id) ON DELETE SET NULL,
  moderator_name TEXT,

  action        TEXT NOT NULL
                  CHECK (action IN ('hide', 'remove', 'restore', 'lock', 'unlock',
                                    'pin', 'unpin', 'warn', 'suspend', 'unsuspend',
                                    'ban', 'unban', 'approve', 'dismiss_report', 'move')),

  target_type   TEXT NOT NULL CHECK (target_type IN ('topic', 'post', 'member', 'report')),
  target_id     TEXT NOT NULL,

  -- The person affected, where the action was about a person rather than a
  -- piece of content.
  subject_id    TEXT REFERENCES users (id) ON DELETE SET NULL,

  reason        TEXT,
  notes         TEXT,

  -- For a suspension: when it lifts. NULL on a ban, which does not.
  expires_at    TEXT,

  report_id     TEXT REFERENCES forum_reports (id) ON DELETE SET NULL,
  created_at    TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_forum_moderation_created
  ON forum_moderation_actions (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_forum_moderation_target
  ON forum_moderation_actions (target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_forum_moderation_subject
  ON forum_moderation_actions (subject_id);

-- ===========================================================================
-- forum_moderators
--
-- The same narrow pattern as `age_grade_admins`: an authority scoped to one
-- thing, held as a row rather than as a platform role.
--
-- `space_id` NULL means every space. A member who moderates the Youth space
-- has no authority in the general forum, which is the point — moderating
-- sports should not come with the power to remove somebody's post about a
-- funeral.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS forum_moderators (
  id           TEXT PRIMARY KEY,
  space_id     TEXT REFERENCES forum_spaces (id) ON DELETE CASCADE,
  user_id      TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  appointed_by TEXT REFERENCES users (id) ON DELETE SET NULL,
  created_at   TEXT NOT NULL,
  UNIQUE (space_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_forum_moderators_user ON forum_moderators (user_id);
CREATE INDEX IF NOT EXISTS idx_forum_moderators_space ON forum_moderators (space_id);

-- ===========================================================================
-- forum_sanctions
--
-- A warning, a suspension or a ban, held separately from the action log so
-- that "is this member currently suspended?" is one indexed read rather than a
-- scan back through history.
-- ===========================================================================
CREATE TABLE IF NOT EXISTS forum_sanctions (
  id            TEXT PRIMARY KEY,
  user_id       TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,

  kind          TEXT NOT NULL CHECK (kind IN ('warning', 'suspension', 'ban')),

  -- NULL means every space.
  space_id      TEXT REFERENCES forum_spaces (id) ON DELETE CASCADE,

  reason        TEXT,
  issued_by     TEXT REFERENCES users (id) ON DELETE SET NULL,

  -- NULL on a warning (nothing to expire) and on a ban (nothing expires).
  expires_at    TEXT,
  lifted_at     TEXT,
  lifted_by     TEXT REFERENCES users (id) ON DELETE SET NULL,

  created_at    TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_forum_sanctions_active
  ON forum_sanctions (user_id, kind, lifted_at, expires_at);

-- ===========================================================================
-- The Community Moderator role.
--
-- Separate from Super Admin, the Editorial Team and the Preservation Team. A
-- moderator manages conduct in the forums and holds nothing over the archive's
-- content, its users, its settings or its security.
-- ===========================================================================
INSERT OR IGNORE INTO roles (id, slug, name, description, permissions, is_system, created_at, updated_at)
VALUES
  (
    'role_community_moderator',
    'community_moderator',
    'Community Moderator',
    'Manages the Yakoli forums: reviews reports, hides or removes posts, warns, suspends and bans. '
    || 'Holds nothing over the archive''s content, the user list, the settings or the audit log. '
    || 'Every action they take is recorded.',
    '["forum.read","forum.post","forum.reply","forum.react","forum.report","forum.moderate","forum.reports.read","forum.reports.review","forum.sanction","forum.pin","forum.lock","members.directory.read","opportunities.read","notifications.read"]',
    1,
    '2026-08-27T00:00:00.000Z',
    '2026-08-27T00:00:00.000Z'
  );

-- ===========================================================================
-- The three spaces.
-- ===========================================================================
INSERT OR IGNORE INTO forum_spaces
  (id, slug, name, tagline, description, kind, visibility, is_indexable,
   requires_approval, is_youth_space, icon, accent, sort_order, status, created_at, updated_at)
VALUES
  (
    'space_community', 'community', 'Yakoli Community Forum',
    'Where Ekoli-Yeden talks to itself',
    'General discussion for the whole community — development, heritage, announcements and the '
    || 'ordinary business of a place. Topics stay findable: a question asked here in 2026 still '
    || 'has its answers attached in 2036.',
    'community', 'public', 1, 0, 0, 'forum', 'green', 10, 'published',
    '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'
  ),
  (
    'space_youth', 'youth', 'Yakoli Youth',
    'Careers, enterprise, technology and leadership',
    'A space of its own for the young people of Ekoli-Yeden — not a category in the general forum. '
    || 'Careers, entrepreneurship, technology, skills and the opportunities that come with them.',
    'youth', 'members', 0, 0, 1, 'rocket', 'gold', 20, 'published',
    '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'
  ),
  (
    'space_students', 'students', 'Yakoli Students',
    'Scholarships, study and the way through',
    'For students of Ekoli-Yeden, at every level. Scholarships, academic questions, career guidance '
    || 'and mentorship. Members only and never indexed: this space may include young people, and '
    || 'it is not a place a stranger reads.',
    'students', 'members', 0, 0, 1, 'school', 'navy', 30, 'published',
    '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'
  );

-- ===========================================================================
-- Categories.
--
-- The community named these. They are headings for conversations that have not
-- happened yet, not claims about what the community thinks.
-- ===========================================================================
INSERT OR IGNORE INTO forum_categories
  (id, space_id, slug, name, description, section, sort_order, post_permission, status, created_at, updated_at)
VALUES
  -- The general forum
  ('cat_general',       'space_community', 'general-discussion',    'General Discussion',    'Anything about Ekoli-Yeden that does not belong under another heading.', 'Community',   10,  'members',    'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_development',   'space_community', 'community-development', 'Community Development', 'Projects, infrastructure and the common good.', 'Community',   20,  'members',    'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_announcements', 'space_community', 'announcements',         'Announcements',         'Notices from the Preservation Team and community leadership.', 'Community',   30,  'moderators', 'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_ideas',         'space_community', 'ideas',                 'Ideas & Suggestions',   'Proposals for the community, and for this platform.', 'Community',   40,  'members',    'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_history',       'space_community', 'history',               'History',               'Questions and discussion about the history of Ekoli-Yeden. Settled material belongs in the archive; this is where it gets worked out.', 'Heritage',    50,  'members',    'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_culture',       'space_community', 'culture',               'Culture',               'Traditions, festivals, practice and what they mean.', 'Heritage',    60,  'members',    'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_language',      'space_community', 'language',              'Language',              'Lokaa — words, meanings, and how things are said.', 'Heritage',    70,  'members',    'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_leboku',        'space_community', 'leboku',                'Leboku',                'The festival: planning it, remembering it, keeping it.', 'Heritage',    80,  'members',    'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_education',     'space_community', 'education',             'Education',             'Schools, teaching and learning in and from Ekoli-Yeden.', 'Development', 90,  'members',    'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_business',      'space_community', 'business',              'Business',              'Trade, enterprise and professional work.', 'Development', 100, 'members',    'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_agriculture',   'space_community', 'agriculture',           'Agriculture',           'Farming, the seasons and the crops the community lives by.', 'Development', 110, 'members',    'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_technology',    'space_community', 'technology',            'Technology',            'Digital skills, connectivity and what technology can do here.', 'Development', 120, 'members',    'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_infrastructure','space_community', 'infrastructure',        'Infrastructure',        'Roads, water, power and the physical fabric of the community.', 'Development', 130, 'members',    'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_events',        'space_community', 'events',                'Events',                'What is happening, and what happened.', 'Social',      140, 'members',    'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_achievements',  'space_community', 'achievements',          'Achievements',          'Recognition for people of Ekoli-Yeden, at home and abroad.', 'Social',      150, 'members',    'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_sports',        'space_community', 'sports',                'Sports',                'Wrestling, football and community sport.', 'Social',      160, 'members',    'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),

  -- Youth
  ('cat_y_careers',     'space_youth', 'careers',           'Careers',                'Finding work, changing direction, and what a career actually looks like.', NULL, 10, 'members', 'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_y_enterprise',  'space_youth', 'entrepreneurship',  'Entrepreneurship',       'Starting something, and keeping it going.', NULL, 20, 'members', 'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_y_technology',  'space_youth', 'technology',        'Technology',             'Learning it, using it, building with it.', NULL, 30, 'members', 'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_y_leadership',  'space_youth', 'leadership',        'Leadership',             'Taking responsibility in the community.', NULL, 40, 'members', 'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_y_skills',      'space_youth', 'skills',            'Skills & Training',      'Trades, qualifications and where to learn them.', NULL, 50, 'members', 'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_y_innovation',  'space_youth', 'innovation',        'Innovation',             'Ideas for Ekoli-Yeden, and for the people in it.', NULL, 60, 'members', 'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_y_sports',      'space_youth', 'sports',            'Sports',                 'Playing, training and competing.', NULL, 70, 'members', 'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_y_opps',        'space_youth', 'opportunities',     'Opportunities',          'Discussing what is on the opportunities board.', NULL, 80, 'members', 'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_y_community',   'space_youth', 'community',         'Community Development',  'What young people can do for Ekoli-Yeden.', NULL, 90, 'members', 'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),

  -- Students
  ('cat_s_scholarships','space_students', 'scholarships',   'Scholarships',           'What is available, and how to apply for it.', NULL, 10, 'members', 'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_s_academic',    'space_students', 'academic',       'Academic Discussion',    'Coursework, subjects and study.', NULL, 20, 'members', 'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_s_career',      'space_students', 'career-guidance','Career Guidance',        'Choosing a direction, and asking people who took it.', NULL, 30, 'members', 'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_s_competitions','space_students', 'competitions',   'Competitions',           'Contests, olympiads and prizes worth entering.', NULL, 40, 'members', 'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_s_resources',   'space_students', 'study-resources','Study Resources',        'Books, notes and where to find them.', NULL, 50, 'members', 'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_s_university',  'space_students', 'university',     'University',             'Admissions, courses and life there.', NULL, 60, 'members', 'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_s_mentorship',  'space_students', 'mentorship',     'Mentorship',             'Asking somebody who has been where you are going.', NULL, 70, 'members', 'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z'),
  ('cat_s_news',        'space_students', 'education-news', 'Education News',         'What is changing in education, and what it means here.', NULL, 80, 'members', 'published', '2026-08-27T00:00:00.000Z', '2026-08-27T00:00:00.000Z');

UPDATE forum_spaces SET topic_count = 0 WHERE topic_count IS NULL;

-- ===========================================================================
-- Settings.
-- ===========================================================================
INSERT OR IGNORE INTO site_settings (key, value, value_type, group_name, is_public, description, updated_at)
VALUES
  ('forum_open', 'true', 'boolean', 'forum', 1,
   'Whether members may post in the forums.',
   '2026-08-27T00:00:00.000Z'),
  ('forum_topics_per_hour', '10', 'number', 'forum', 0,
   'How many topics one member may start in an hour. A brake on a runaway argument, not a quota.',
   '2026-08-27T00:00:00.000Z'),
  ('forum_replies_per_hour', '40', 'number', 'forum', 0,
   'How many replies one member may post in an hour.',
   '2026-08-27T00:00:00.000Z'),
  ('forum_edit_window_minutes', '30', 'number', 'forum', 1,
   'How long after posting a member may edit their own words. After that the post stands, because '
   || 'a conversation whose earlier half can be rewritten is not a record of anything.',
   '2026-08-27T00:00:00.000Z'),
  ('forum_youth_hides_contact', 'true', 'boolean', 'forum', 0,
   'In the Youth and Student spaces, suppress contact details and precise locations on author '
   || 'cards regardless of what a member has made public elsewhere. These spaces may include '
   || 'minors.',
   '2026-08-27T00:00:00.000Z');
