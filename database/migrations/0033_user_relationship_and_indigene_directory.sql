-- ===========================================================================
-- 0033  USER → RELATIONSHIP → ROLE
-- ===========================================================================
--
-- "Member" was the wrong word and it was doing two jobs at once.
--
-- It sounded like somebody who had joined an organisation and paid a
-- subscription, which is not what this is. And it was carrying both halves of
-- an identity that are genuinely separate: WHAT SOMEBODY IS TO EKOLI-YEDEN, and
-- WHAT THEY DO ON THIS PLATFORM.
--
-- Those do not vary together. An indigene may be an ordinary user, an editor,
-- or the Super Admin. A researcher from a university may be a contributor. A
-- friend of the community may run the media library. Folding the two into one
-- word means every one of those people has to be described as something they
-- are not.
--
-- ---------------------------------------------------------------------------
-- SO: TWO AXES
-- ---------------------------------------------------------------------------
--
--   USER
--    ├── relationship to Ekoli-Yeden   indigene · resident · friend ·
--    │                                 researcher · organisation · other
--    └── platform role                 user · contributor · editorial · admin
--
-- The relationship is this migration. The role axis already exists as `roles`
-- and `user_roles`, and 0031 made every registered person a user of the
-- platform rather than a "contributor account".
--
-- ---------------------------------------------------------------------------
-- WHY A NEW COLUMN RATHER THAN A REBUILT ONE
-- ---------------------------------------------------------------------------
--
-- `connection` carries a CHECK constraint, and SQLite cannot alter one in
-- place. Rebuilding `member_profiles` — the table holding every living
-- person's personal data — to change a word would be a real risk taken for a
-- cosmetic reason.
--
-- So `relationship` is added beside it and becomes the canonical field, and
-- `connection` is backfilled from and left alone. Nothing is lost, nothing is
-- rewritten, and the old column stays readable for anybody checking what a
-- profile said before today.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- WHAT SOMEBODY IS TO EKOLI-YEDEN.
--
-- Six answers, and `married_in` kept as a seventh.
--
-- The recommendation was six. `married_in` survives because the community
-- already distinguishes it and because collapsing it into either "indigene" or
-- "resident" would tell a woman who married into Ekori that the archive has
-- decided which of those she is. It is not the platform's place to decide that.
-- ---------------------------------------------------------------------------
ALTER TABLE member_profiles ADD COLUMN relationship TEXT
  CHECK (relationship IS NULL OR relationship IN (
    'indigene', 'resident', 'married_in', 'friend',
    'researcher', 'organisation', 'other'));

-- Everybody whose answer already said they are of Ekori.
--
-- Born here, family from here, a descendant, or returned: all four are ways of
-- saying indigene, and all four were separate options because the old field was
-- trying to be a relationship and a story at the same time. The story is kept
-- in `connection` and in `connection_note`.
UPDATE member_profiles
SET relationship = CASE connection
  WHEN 'born_here'        THEN 'indigene'
  WHEN 'family_from_here' THEN 'indigene'
  WHEN 'descendant'       THEN 'indigene'
  WHEN 'returned'         THEN 'indigene'
  WHEN 'married_into'     THEN 'married_in'
  WHEN 'resident'         THEN 'resident'
  WHEN 'researcher'       THEN 'researcher'
  WHEN 'friend'           THEN 'friend'
  WHEN 'other'            THEN 'other'
  ELSE NULL
END
WHERE connection IS NOT NULL AND relationship IS NULL;

CREATE INDEX IF NOT EXISTS idx_member_profiles_relationship
  ON member_profiles (relationship, listed_in_directory);

-- ---------------------------------------------------------------------------
-- The role that every registered person holds.
--
-- Renamed from "Okoli Member" to say what it is: a user of this platform. The
-- slug is untouched — it is referenced by `user_roles`, by the permission
-- checks, and by the audit log, and renaming a slug to improve a label is how
-- an authorisation system quietly breaks.
-- ---------------------------------------------------------------------------
UPDATE roles
SET name        = 'Ekoli-Yeden User',
    description = 'Every registered person. May keep a profile, contribute material to the '
                  || 'archive, write to other users, take part in the forums, see and apply for '
                  || 'opportunities, and appear in the Indigene Directory if they choose. What '
                  || 'somebody is TO Ekoli-Yeden — indigene, resident, friend, researcher — is '
                  || 'recorded separately on their profile and grants nothing by itself.',
    updated_at  = datetime('now')
WHERE slug = 'okoli_member';

-- ---------------------------------------------------------------------------
-- The wording.
-- ---------------------------------------------------------------------------
INSERT OR IGNORE INTO content_strings
  (key, value, draft_value, group_name, page, label, help_text,
   value_type, max_length, status, is_locked, sort_order, created_at, updated_at)
VALUES
  ('page.directory.title', 'Indigene Directory', NULL, 'pages', 'directory',
   'The directory page title', NULL, 'text', 120,
   'published', 0, 10, datetime('now'), datetime('now')),

  ('page.directory.intro',
   'People of Ekoli-Yeden who have chosen to be findable — at home and in the diaspora. Search '
   || 'by what somebody does, or by where they are. Nobody appears here unless they switched it '
   || 'on themselves, and no phone number or email address is shown unless they shared it.',
   NULL, 'pages', 'directory', 'The line under the directory heading', NULL, 'text', 600,
   'published', 0, 20, datetime('now'), datetime('now')),

  ('profile.relationship.question', 'What is your relationship to Ekoli-Yeden?',
   NULL, 'membership', 'account',
   'The question asked when somebody fills in their profile', NULL, 'text', 200,
   'published', 0, 30, datetime('now'), datetime('now'));
