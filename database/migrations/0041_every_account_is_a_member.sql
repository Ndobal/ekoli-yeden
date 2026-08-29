-- ===========================================================================
-- 0041  AN ACCOUNT WITHOUT A MEMBERSHIP IS NOT A LESSER MEMBER — IT IS NONE
-- ===========================================================================
--
-- Two accounts exist with no `member_profiles` row. They can sign in and they
-- can do almost nothing: the forums, the directory, messaging, the
-- opportunities board and every contribution channel all read that row, so an
-- account without one is a member of nothing.
--
-- This is the residue of the old shape, where registering made a "contributor"
-- and joining was a second, separate act most people never completed. Migration
-- 0031 retired that idea and made every registered person a full member;
-- `ensureMembership` now creates the profile at registration and repairs it on
-- the next `/api/auth/me`.
--
-- These two predate all of it and have not signed in since. Rather than wait
-- for them to, they are made members here.
--
-- ---------------------------------------------------------------------------
-- WHY THIS DUPLICATES `ensureMembership` RATHER THAN CALLING IT
-- ---------------------------------------------------------------------------
--
-- It cannot call it: this is SQL and that is TypeScript running in a Worker.
-- So the numbering, the handle and the forum membership are written out again
-- here, and the risk of the two drifting is real.
--
-- What keeps it honest is that this migration is a ONE-OFF for accounts that
-- already exist. Nothing created from now on comes through here — registration
-- and the repair path both go through the service — so a drift would affect
-- these two rows and nothing else.
-- ===========================================================================

-- The membership number continues the same sequence: Okoli-<year>-<n>, counted
-- within the year, so these two take the next numbers rather than starting a
-- second scheme beside the first.
DROP TABLE IF EXISTS _new_members;
CREATE TABLE _new_members AS
SELECT
  u.id AS user_id,
  u.display_name,
  u.created_at,
  'Okoli-'
    || strftime('%Y', u.created_at)
    || '-'
    || substr(
         '0000' || CAST(
           (
             SELECT COUNT(*) FROM member_profiles p
             WHERE p.membership_number LIKE 'Okoli-' || strftime('%Y', u.created_at) || '-%'
           )
           + ROW_NUMBER() OVER (
               PARTITION BY strftime('%Y', u.created_at)
               ORDER BY u.created_at, u.id
             )
           AS TEXT
         ),
         -4
       ) AS membership_number,

  -- The handle, from the display name, in the same shape the service produces.
  -- A collision is made unique by appending the first six characters of the
  -- user id — the service uses a counter, and either is stable and readable.
  CASE
    WHEN EXISTS (
      SELECT 1 FROM member_profiles p
      WHERE p.handle = lower(replace(trim(u.display_name), ' ', '-'))
    )
    THEN lower(replace(trim(u.display_name), ' ', '-')) || '-' || substr(u.id, 1, 6)
    ELSE lower(replace(trim(u.display_name), ' ', '-'))
  END AS handle
FROM users u
WHERE u.status = 'active'
  AND NOT EXISTS (SELECT 1 FROM member_profiles p WHERE p.user_id = u.id);

INSERT INTO member_profiles
  (id, user_id, membership_number, handle, full_name, membership_status,
   joined_at, created_at, updated_at)
SELECT
  'mp_' || substr(n.user_id, 1, 26),
  n.user_id,
  n.membership_number,
  n.handle,
  n.display_name,
  'active',
  -- Dated from when the account was made. They have been part of this
  -- community since then; the row is what was missing.
  n.created_at,
  datetime('now'),
  datetime('now')
FROM _new_members n;

-- The role every registered person holds. Most already have it; this covers
-- any that do not.
INSERT OR IGNORE INTO user_roles (id, user_id, role_id, assigned_by, created_at)
SELECT
  'ur_' || substr(n.user_id, 1, 24) || '_om',
  n.user_id,
  (SELECT id FROM roles WHERE slug = 'okoli_member'),
  NULL,
  datetime('now')
FROM _new_members n
WHERE EXISTS (SELECT 1 FROM roles WHERE slug = 'okoli_member');

-- And the General Forum, which is what "full member" actually means in
-- practice: the room where the whole community can be reached.
INSERT OR IGNORE INTO forum_members
  (id, space_id, user_id, state, role, requested_at, decided_at, created_at, updated_at)
SELECT
  'fm_' || substr(n.user_id, 1, 24) || '_gen',
  (SELECT id FROM forum_spaces WHERE is_default = 1),
  n.user_id,
  'member',
  'member',
  n.created_at,
  n.created_at,
  datetime('now'),
  datetime('now')
FROM _new_members n
WHERE EXISTS (SELECT 1 FROM forum_spaces WHERE is_default = 1);

DROP TABLE _new_members;

-- Any account that somehow has a profile and no General Forum row — the state
-- every account registered between 0039 and the fix to `ensureMembership` was
-- left in.
INSERT OR IGNORE INTO forum_members
  (id, space_id, user_id, state, role, requested_at, decided_at, created_at, updated_at)
SELECT
  'fm_' || substr(p.user_id, 1, 24) || '_gen2',
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
  AND EXISTS (SELECT 1 FROM forum_spaces WHERE is_default = 1)
  AND NOT EXISTS (
    SELECT 1 FROM forum_members fm
    WHERE fm.user_id = p.user_id
      AND fm.space_id = (SELECT id FROM forum_spaces WHERE is_default = 1)
  );
