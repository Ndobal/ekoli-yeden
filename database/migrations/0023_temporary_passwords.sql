-- ---------------------------------------------------------------------------
-- 0023  Temporary passwords, and getting people back into their accounts
-- ---------------------------------------------------------------------------
--
-- Reset LINKS already exist (0012) and are the better mechanism: no
-- administrator ever learns anybody's password. They also assume the person can
-- receive and open a link, which is not always true here — an elder on a
-- borrowed phone, somebody whose email address stopped working years ago,
-- somebody standing in front of an administrator right now.
--
-- So a second route: the administrator sets a temporary password, reads it out,
-- and the account is required to replace it at the next sign-in. The temporary
-- one cannot be used for anything except choosing a real one.
--
-- `must_change_password` is what makes it temporary rather than just "a
-- password an administrator knows". Without it, the pragmatic route quietly
-- becomes a permanent shared credential, which is worse than the problem.
-- ---------------------------------------------------------------------------

ALTER TABLE users ADD COLUMN must_change_password INTEGER NOT NULL DEFAULT 0
  CHECK (must_change_password IN (0, 1));

-- When the password was last actually changed by its owner. Useful to an
-- administrator answering "did they ever set their own?" without having to
-- read the audit trail.
ALTER TABLE users ADD COLUMN password_changed_at TEXT;

-- Who issued the temporary password, and when. Kept on the row rather than only
-- in the audit log so it is visible in the one place somebody is looking when
-- they wonder why an account is being asked to change its password.
ALTER TABLE users ADD COLUMN temp_password_issued_by TEXT REFERENCES users (id) ON DELETE SET NULL;
ALTER TABLE users ADD COLUMN temp_password_issued_at TEXT;

CREATE INDEX IF NOT EXISTS idx_users_must_change ON users (must_change_password);

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------

INSERT OR IGNORE INTO site_settings (key, value, value_type, group_name, description, is_public, updated_at)
VALUES
  ('temp_password_ttl_hours', '72', 'number', 'security',
   'How long a temporary password remains usable before it must be reissued',
   0, datetime('now'));
