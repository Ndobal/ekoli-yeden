-- ===========================================================================
-- 0039  A MEMBER BELONGS TO FORUMS, NOT TO "THE FORUMS"
-- ===========================================================================
--
-- Access was binary. `forum.service.ts` asked one question — is this person an
-- active member of the community — and answered it for every members-only
-- space at once. So there was no such thing as belonging to the Youth Forum:
-- you either had all of them or none of them.
--
-- That makes several things impossible rather than merely unbuilt. A forum
-- cannot have its own membership, so it cannot have its own admin, so nobody
-- can be approved, rejected, removed or suspended from one forum while staying
-- in another. It also means a space "for the youth" is readable by everybody,
-- which is not what calling it that promises.
--
-- ---------------------------------------------------------------------------
-- MANY TO MANY, WITH ONE MEMBERSHIP NOBODY CHOOSES
-- ---------------------------------------------------------------------------
--
--   Williams
--    ├── General Forum      automatic, and cannot be left
--    ├── Youth Forum        approved
--    ├── Students Forum     approved
--    └── Sports Forum       not a member
--
-- The General Forum is the one every registered person is in from the moment
-- they register. It is marked `is_default` rather than named in code, so the
-- community can move that role to a different space without a deployment —
-- and `join_policy = 'automatic'` is what actually grants it, so the two
-- cannot drift.
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- HOW A SPACE IS JOINED
-- ---------------------------------------------------------------------------
ALTER TABLE forum_spaces ADD COLUMN join_policy TEXT NOT NULL DEFAULT 'request'
  CHECK (join_policy IN (
    -- Everybody is a member from registration and cannot leave. The General
    -- Forum, and only ever one space.
    'automatic',
    -- Ask, and a forum admin decides.
    'request',
    -- Nobody may ask. Membership is granted by an admin or not at all — for a
    -- space like a council or a committee.
    'closed'
  ));

-- Exactly one space carries the automatic membership. Enforced by a partial
-- unique index rather than by hoping: two default forums would mean every new
-- account silently joining both.
ALTER TABLE forum_spaces ADD COLUMN is_default INTEGER NOT NULL DEFAULT 0
  CHECK (is_default IN (0, 1));

CREATE UNIQUE INDEX IF NOT EXISTS idx_forum_spaces_one_default
  ON forum_spaces (is_default) WHERE is_default = 1;


-- ---------------------------------------------------------------------------
-- WHO BELONGS TO WHAT
--
-- One row per person per space, holding both their standing and their
-- authority there. Two columns rather than one status, because they answer
-- different questions and change independently: a forum admin who is suspended
-- is still the admin, and restoring them must not have to remember that.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS forum_members (
  id            TEXT PRIMARY KEY,
  space_id      TEXT NOT NULL REFERENCES forum_spaces (id) ON DELETE CASCADE,
  user_id       TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,

  -- Where they stand.
  --
  -- `pending` is a request waiting on an admin. `rejected` and `removed` are
  -- kept rather than deleted: a forum admin looking at a request needs to know
  -- whether this person has been turned away before, and deleting the row
  -- would make every reapplication look like a first one.
  state         TEXT NOT NULL DEFAULT 'pending'
                  CHECK (state IN ('pending', 'member', 'rejected', 'removed', 'suspended')),

  -- What they may do there. Separate from `state` on purpose — see above.
  role          TEXT NOT NULL DEFAULT 'member'
                  CHECK (role IN ('member', 'moderator', 'admin')),

  -- Why they want in, in their own words. What an admin actually decides on.
  request_note  TEXT,

  -- Why they were turned away or removed. Shown to them, because a refusal
  -- somebody cannot understand is one they will simply repeat.
  decision_note TEXT,

  -- A suspension that ends by itself. Null means it does not.
  suspended_until TEXT,

  requested_at  TEXT NOT NULL,
  decided_at    TEXT,
  decided_by    TEXT REFERENCES users (id) ON DELETE SET NULL,
  created_at    TEXT NOT NULL,
  updated_at    TEXT NOT NULL,

  -- One standing per person per space. A second request is an update to the
  -- row that exists, which is what keeps the history of it.
  UNIQUE (space_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_forum_members_user  ON forum_members (user_id, state);
CREATE INDEX IF NOT EXISTS idx_forum_members_space ON forum_members (space_id, state);
CREATE INDEX IF NOT EXISTS idx_forum_members_queue ON forum_members (space_id, state, requested_at);


-- ---------------------------------------------------------------------------
-- THE GENERAL FORUM
--
-- The existing public "community" space becomes it: renaming and re-pointing a
-- space nobody has posted in is better than creating a fourth and leaving an
-- orphan behind.
-- ---------------------------------------------------------------------------
UPDATE forum_spaces
SET name        = 'General Forum',
    tagline     = 'Where the whole of Ekoli-Yeden talks',
    description = 'The community''s own room. Every registered member is here from the day they '
                  || 'register, and nobody has to ask. Anything that concerns Ekoli-Yeden as a '
                  || 'whole belongs in it — questions, announcements, arrangements, and the '
                  || 'ordinary business of a community.',
    visibility  = 'public',
    join_policy = 'automatic',
    is_default  = 1,
    sort_order  = 0,
    updated_at  = datetime('now')
WHERE slug = 'community';

-- The others are asked for.
UPDATE forum_spaces
SET join_policy = 'request', updated_at = datetime('now')
WHERE is_default = 0;


-- ---------------------------------------------------------------------------
-- EVERYBODY WHO IS ALREADY HERE
--
-- Every active member joins the General Forum, dated from when they joined the
-- community rather than from today — they have been entitled to it all along;
-- the row is what was missing.
-- ---------------------------------------------------------------------------
INSERT OR IGNORE INTO forum_members
  (id, space_id, user_id, state, role, requested_at, decided_at, created_at, updated_at)
SELECT
  'fm_' || substr(p.id, 1, 24) || '_gen',
  (SELECT id FROM forum_spaces WHERE is_default = 1),
  p.user_id,
  'member',
  'member',
  COALESCE(p.joined_at, p.created_at),
  COALESCE(p.joined_at, p.created_at),
  datetime('now'),
  datetime('now')
FROM member_profiles p
WHERE p.membership_status = 'active'
  AND EXISTS (SELECT 1 FROM forum_spaces WHERE is_default = 1);

-- Anybody already moderating a space is its admin. The table existed and was
-- the only per-space authority there was.
INSERT OR IGNORE INTO forum_members
  (id, space_id, user_id, state, role, requested_at, decided_at, decided_by, created_at, updated_at)
SELECT
  'fm_' || substr(m.id, 1, 24) || '_mod',
  m.space_id,
  m.user_id,
  'member',
  'admin',
  m.created_at,
  m.created_at,
  m.appointed_by,
  datetime('now'),
  datetime('now')
FROM forum_moderators m;

-- And where somebody is both, the moderator row wins: they were already
-- running the space and the backfill above would otherwise have left them an
-- ordinary member of it.
UPDATE forum_members
SET role = 'admin', updated_at = datetime('now')
WHERE EXISTS (
  SELECT 1 FROM forum_moderators m
  WHERE m.space_id = forum_members.space_id AND m.user_id = forum_members.user_id
);
