-- ===========================================================================
-- 0031  THERE IS NO CONTRIBUTOR ACCOUNT. EVERY MEMBER IS A CONTRIBUTOR.
-- ===========================================================================
--
-- Registering created an account holding the `contributor` role, whose
-- permission array was literally empty. Joining the Yakoli community was a
-- second, separate act that created the member profile and granted
-- `okoli_member`.
--
-- ---------------------------------------------------------------------------
-- THE SPLIT DID NOT SURVIVE CONTACT WITH THE CODE
-- ---------------------------------------------------------------------------
--
-- `requireMembership` — the middleware guarding every contribution route —
-- refuses anybody without a member profile. So a "Contributor" account, the
-- thing named for contributing, could not contribute. It could sign in, read
-- what an anonymous visitor could already read, and nothing else. Somebody who
-- registered in order to send in their grandmother's photographs met a wall
-- and a second form.
--
-- ---------------------------------------------------------------------------
-- SO THE TWO BECOME ONE
-- ---------------------------------------------------------------------------
--
-- Registering IS joining. Everybody who registers gets a member profile, the
-- member dashboard, and `okoli_member` — which now carries the permission to
-- contribute. Everything beyond that is a role a Super Admin assigns.
--
-- The `contributor` row is kept rather than deleted. It is referenced by audit
-- entries recording who was granted what and when, and an audit trail with
-- dangling references is worse than a retired row nobody assigns.
-- ===========================================================================

-- Everything the old Contributor role was supposed to allow, now held by the
-- role every member actually has.
UPDATE roles
SET permissions = '["members.profile","members.directory.read","forum.read","forum.post",'
                  || '"forum.reply","forum.react","forum.report","opportunities.read",'
                  || '"opportunities.apply","opportunities.save","notifications.read",'
                  || '"submissions:create","messages.send","messages.read"]',
    description  = 'Every registered member of Ekoli-Yeden. May keep a profile, contribute '
                   || 'material to the archive, write to other members, take part in the forums, '
                   || 'see and apply for opportunities, and appear in the directory if they '
                   || 'choose. Holds nothing over the archive''s own content — that stays with '
                   || 'the Editorial and Preservation Teams.',
    updated_at   = datetime('now')
WHERE slug = 'okoli_member';

-- Retired, and said to be, so nobody assigns it from the roles screen wondering
-- what it does.
UPDATE roles
SET name        = 'Contributor (retired)',
    description = 'RETIRED. Every registered member is a contributor — see the Member role. '
                  || 'This row is kept because the audit log references it; it is no longer '
                  || 'assigned to anybody.',
    updated_at  = datetime('now')
WHERE slug = 'contributor';

-- ---------------------------------------------------------------------------
-- Move everybody who holds it.
--
-- `INSERT OR IGNORE` first so that somebody who already holds both comes
-- through with one row rather than colliding, and only then remove the old
-- grant. Done in that order because the reverse would briefly leave an account
-- holding neither.
-- ---------------------------------------------------------------------------
INSERT OR IGNORE INTO user_roles (id, user_id, role_id, assigned_by, created_at)
SELECT lower(hex(randomblob(16))), ur.user_id, 'role_okoli_member', NULL, datetime('now')
FROM user_roles ur
WHERE ur.role_id = 'role_contributor';

DELETE FROM user_roles WHERE role_id = 'role_contributor';

-- ---------------------------------------------------------------------------
-- The profiles for accounts that never joined.
--
-- A membership number and a handle are generated in the application for new
-- registrations, where names are available and handles can be made readable.
-- Doing it here would produce `member-a3f9` for people who have perfectly good
-- names, so this migration deliberately does NOT backfill.
--
-- Instead `MembershipService.ensureMembership` creates the profile the first
-- time an existing account opens its dashboard, using its display name. Every
-- account self-heals on next sign-in, with a handle somebody would recognise.
-- ---------------------------------------------------------------------------
