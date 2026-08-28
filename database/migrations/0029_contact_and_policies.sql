-- ===========================================================================
-- 0029  MESSAGES FROM THE PUBLIC, AND THE POLICIES THAT GOVERN THEM
-- ===========================================================================
--
-- Until now the contact page listed an email address and stopped there. That
-- works only for somebody who has an email client set up, remembers to include
-- what they are writing about, and never wonders whether it arrived. For a
-- community reached mostly on a phone, it is close to no contact page at all.
--
-- ---------------------------------------------------------------------------
-- WHY A MESSAGE IS A RECORD AND NOT AN EMAIL
-- ---------------------------------------------------------------------------
--
-- An email lands in one person's inbox. When they are travelling, or their
-- phone breaks, or they simply do not see it, nobody else knows it existed.
-- A row here is seen by every administrator, keeps its own state, and can be
-- answered by whoever is available.
--
-- It also gives the sender something an email cannot: a reference they can
-- quote, and a page that tells them what happened to what they wrote.
--
-- ---------------------------------------------------------------------------
-- TOPIC IS THE ONE FIELD THAT DOES REAL WORK
-- ---------------------------------------------------------------------------
--
-- "A correction to something on the site" and "please take my photograph down"
-- are not the same message and should not sit in the same queue in the same
-- order. The topic routes it and sets how urgently it should be read — a
-- privacy request has a deadline in law; a general greeting does not.
-- ===========================================================================

CREATE TABLE IF NOT EXISTS contact_messages (
  id              TEXT PRIMARY KEY,

  -- Quoted back to the sender so they can ask what happened to it without an
  -- account. The same shape as every other reference this platform issues.
  reference_code  TEXT NOT NULL UNIQUE,

  name            TEXT NOT NULL,
  email           TEXT,
  phone           TEXT,

  -- How they would rather be answered. Asked because email is not how most of
  -- this community actually communicates.
  preferred_reply TEXT NOT NULL DEFAULT 'email'
                    CHECK (preferred_reply IN ('email', 'phone', 'whatsapp', 'none')),

  topic           TEXT NOT NULL DEFAULT 'general'
                    CHECK (topic IN ('general', 'correction', 'contribution', 'privacy',
                                     'takedown', 'membership', 'technical', 'press',
                                     'complaint', 'other')),

  subject         TEXT,
  message         TEXT NOT NULL,

  -- Set when the sender was signed in. Never required: somebody asking for
  -- their own data to be removed must not have to create an account first.
  submitted_by    TEXT REFERENCES users (id) ON DELETE SET NULL,

  status          TEXT NOT NULL DEFAULT 'new'
                    CHECK (status IN ('new', 'reading', 'answered', 'closed', 'spam')),

  -- Who picked it up. One row, so two administrators do not both answer it and
  -- neither knows the other did.
  assigned_to     TEXT REFERENCES users (id) ON DELETE SET NULL,
  answered_by     TEXT REFERENCES users (id) ON DELETE SET NULL,
  answered_at     TEXT,

  -- What was done about it, for whoever reads the queue next.
  handling_notes  TEXT,

  -- Salted, like everywhere else in this platform. Enough to recognise a flood
  -- from one source; not enough to be a log of who visited.
  ip_hash         TEXT,

  created_at      TEXT NOT NULL,
  updated_at      TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_contact_status
  ON contact_messages (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_contact_topic
  ON contact_messages (topic, status);

-- ---------------------------------------------------------------------------
-- The policy pages.
--
-- Seeded into `content_strings` like the rest of the website's text, so the
-- Preservation Team can correct a detail — a name, an address, a retention
-- period — without a deployment. Each page renders from a compiled-in fallback
-- if the row is missing, so the site is never legally silent because a seed
-- did not run.
--
-- Only the details that genuinely change live here. The body of each policy is
-- in the Dart pages, where it can be reviewed in a diff alongside the code that
-- makes the claims true.
-- ---------------------------------------------------------------------------
INSERT OR IGNORE INTO content_strings
  (key, value, draft_value, group_name, page, label, help_text,
   value_type, max_length, status, is_locked, sort_order, created_at, updated_at)
VALUES
  ('policy.effective_date', '28 August 2026', NULL, 'policies', 'legal',
   'The date the current terms and privacy policy took effect', NULL, 'text', 60,
   'published', 0, 10, datetime('now'), datetime('now')),

  ('policy.custodian', 'The Ekoli-Yeden Preservation Team', NULL, 'policies', 'legal',
   'Who is responsible for this archive and its data', NULL, 'text', 200,
   'published', 0, 20, datetime('now'), datetime('now')),

  ('policy.contact_email', 'privacy@ekoliyeden.org', NULL, 'policies', 'legal',
   'The address privacy and takedown requests should reach', NULL, 'text', 200,
   'published', 0, 30, datetime('now'), datetime('now')),

  ('policy.retention', 'For as long as the archive exists, unless you ask us to remove it',
   NULL, 'policies', 'legal',
   'How long contributed material is kept', NULL, 'text', 300,
   'published', 0, 40, datetime('now'), datetime('now')),

  ('page.terms.title', 'Terms of Use', NULL, 'pages', 'legal',
   'The terms page title', NULL, 'text', 120,
   'published', 0, 50, datetime('now'), datetime('now')),

  ('page.privacy.title', 'Privacy Policy', NULL, 'pages', 'legal',
   'The privacy page title', NULL, 'text', 120,
   'published', 0, 60, datetime('now'), datetime('now')),

  ('page.cookies.title', 'Cookies', NULL, 'pages', 'legal',
   'The cookies page title', NULL, 'text', 120,
   'published', 0, 70, datetime('now'), datetime('now')),

  ('page.contact.form_intro',
   'Write to the Preservation Team. Every message reaches all of the administrators rather than '
   || 'one inbox, and you are given a reference you can quote if you need to follow it up.',
   NULL, 'pages', 'contact',
   'The line above the contact form', NULL, 'text', 500,
   'published', 0, 80, datetime('now'), datetime('now'));
