-- ---------------------------------------------------------------------------
-- EKOLI YEDEN DIGITAL HOME — Migration 0012
-- Password reset, and the contact details needed to deliver it.
--
-- THE PROBLEM THIS SOLVES
--
-- Until now the only way to recover an account was for a Super Admin to set a
-- new password directly. That works, but it means the administrator learns
-- every password they issue, and it leaves the community's volunteers unable to
-- help themselves at all.
--
-- This adds a proper reset flow: a single-use, time-limited token, delivered to
-- the account holder over email or WhatsApp, which lets them set their own
-- password without anybody else ever seeing it.
--
-- WHY THE TOKEN IS STORED AS A DIGEST
--
-- The same reasoning as refresh tokens. A reset token is, briefly, as good as
-- the password itself. Storing only its SHA-256 means a leaked database
-- snapshot cannot be used to take over accounts — the raw token exists only in
-- the message sent to the user.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS password_reset_tokens (
  id            TEXT PRIMARY KEY,
  user_id       TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,

  -- SHA-256 of the token. The raw value is never stored anywhere.
  token_hash    TEXT NOT NULL UNIQUE,

  -- How the link was sent, so the audit trail can answer "where did it go?".
  delivery      TEXT NOT NULL DEFAULT 'manual'
                  CHECK (delivery IN ('email', 'whatsapp', 'manual')),
  delivered_to  TEXT,

  -- Short-lived on purpose: long enough to reach somebody on a slow connection,
  -- short enough that an old message in a WhatsApp thread is not a way in.
  expires_at    TEXT NOT NULL,

  -- Single use. Set the moment the token is redeemed.
  used_at       TEXT,

  -- Who asked for it. A reset requested by an administrator on somebody's
  -- behalf is a different act from one the account holder requested themselves,
  -- and the difference belongs in the record.
  requested_by  TEXT REFERENCES users (id) ON DELETE SET NULL,
  ip_hash       TEXT,
  created_at    TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_reset_tokens_user ON password_reset_tokens (user_id);
CREATE INDEX IF NOT EXISTS idx_reset_tokens_expiry ON password_reset_tokens (expires_at);

-- --------------------------------------------------------------------------
-- Contact details for delivery.
--
-- `phone` already exists. A WhatsApp number is stored separately because it is
-- frequently not the same as the number somebody gives for calls, and sending a
-- reset link to the wrong one is a support problem nobody needs.
-- --------------------------------------------------------------------------
ALTER TABLE users ADD COLUMN whatsapp_number TEXT;

-- Where this person would rather be contacted. Many of the community's
-- volunteers will read WhatsApp long before they read email.
ALTER TABLE users ADD COLUMN preferred_contact TEXT NOT NULL DEFAULT 'email'
  CHECK (preferred_contact IN ('email', 'whatsapp'));

-- --------------------------------------------------------------------------
-- Settings governing the flow.
-- --------------------------------------------------------------------------
INSERT OR IGNORE INTO site_settings (key, value, value_type, group_name, is_public, description, updated_at)
VALUES
  ('password_reset_ttl_minutes', '60', 'number', 'security', 0,
   'How long a password reset link stays valid, in minutes.',
   '2026-08-12T00:00:00.000Z'),
  ('password_reset_self_service', 'true', 'boolean', 'security', 1,
   'Whether users may request their own password reset from the sign-in page.',
   '2026-08-12T00:00:00.000Z'),
  ('password_min_length', '12', 'number', 'security', 1,
   'Minimum password length. A short phrase is easier to remember than a short password.',
   '2026-08-12T00:00:00.000Z');
