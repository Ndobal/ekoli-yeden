-- ===========================================================================
-- 0030  MESSAGES BETWEEN MEMBERS, AND ASKING FOR SOMEBODY'S NUMBER
-- ===========================================================================
--
-- Until now, one member could reach another only by already knowing how to.
-- The archive could tell you that a nurse in Lagos is from Ajere and could not
-- give you any way to say hello to her — which meant, in practice, that the
-- directory sent people back to WhatsApp to find each other, and the platform
-- became a lookup table rather than a place.
--
-- ---------------------------------------------------------------------------
-- THE RULE THIS WHOLE MIGRATION EXISTS TO ENFORCE
-- ---------------------------------------------------------------------------
--
-- YOU CAN REACH SOMEBODY WITHOUT BEING GIVEN THEIR NUMBER.
--
-- A message goes through this platform. The sender never learns the recipient's
-- phone number or email address by sending it, and the recipient never has to
-- publish either in order to be reachable. That is the entire point: the thing
-- people actually want from a directory is contact, and the thing they are
-- rightly unwilling to publish is contact DETAILS. Those are separable, and
-- everything below separates them.
--
-- If somebody does want the number — to call about a funeral, to send a
-- document — they ask, and the person decides. `contact_grants` records that
-- decision, and `visibleProfile` in `membership.ts` reads it. Nothing is
-- released because an interface forgot to hide it.
--
-- ---------------------------------------------------------------------------
-- WHY CONVERSATIONS AND NOT A FLAT MESSAGE TABLE
-- ---------------------------------------------------------------------------
--
-- A flat `messages(from, to, body)` table cannot answer "has this person read
-- it", cannot hold a group thread later, and makes the commonest query — the
-- list of my conversations with the last line of each — a self-join over
-- everything anybody has ever written. One row per conversation, one per
-- participant, one per message.
-- ===========================================================================

CREATE TABLE IF NOT EXISTS conversations (
  id             TEXT PRIMARY KEY,

  -- 'direct' is two people. Group threads are not built yet; the column exists
  -- so adding them later is a feature rather than a migration of every row.
  kind           TEXT NOT NULL DEFAULT 'direct'
                   CHECK (kind IN ('direct', 'group')),

  -- Set for a group thread. A direct conversation is titled by whoever you are
  -- talking to, which depends on which side you are reading from, so it is not
  -- stored.
  title          TEXT,

  -- For a direct conversation: the two participant ids, sorted and joined.
  -- UNIQUE, which is what stops two people who message each other at the same
  -- moment ending up in two separate threads that each think they are the one.
  pair_key       TEXT UNIQUE,

  last_message_at   TEXT,
  last_message_text TEXT,
  last_message_by   TEXT REFERENCES users (id) ON DELETE SET NULL,

  created_by     TEXT REFERENCES users (id) ON DELETE SET NULL,
  created_at     TEXT NOT NULL,
  updated_at     TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_conversations_recent
  ON conversations (last_message_at DESC);

-- ---------------------------------------------------------------------------
-- Who is in a conversation, and what they have seen of it.
--
-- `last_read_at` rather than a per-message read receipt: the unread count is
-- then one comparison instead of a row per message per person, and "seen at
-- 10:42" is all any of these screens needs to know.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS conversation_participants (
  id              TEXT PRIMARY KEY,
  conversation_id TEXT NOT NULL REFERENCES conversations (id) ON DELETE CASCADE,
  user_id         TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,

  last_read_at    TEXT,

  -- Their own copy of the thread. Leaving hides it for them and for nobody
  -- else; the other person's record of the conversation is not theirs to
  -- delete.
  is_archived     INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),

  -- One person muting or blocking the thread. `is_blocked` stops new messages
  -- arriving from the other side and is checked on send.
  is_muted        INTEGER NOT NULL DEFAULT 0 CHECK (is_muted IN (0, 1)),
  is_blocked      INTEGER NOT NULL DEFAULT 0 CHECK (is_blocked IN (0, 1)),

  joined_at       TEXT NOT NULL,
  UNIQUE (conversation_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_participants_user
  ON conversation_participants (user_id, is_archived);

-- ---------------------------------------------------------------------------
-- The messages themselves.
--
-- Never hard-deleted. `status` moves to 'deleted' and the body is cleared, so
-- the conversation keeps its shape and a moderator reviewing a report can still
-- see that something was there.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS direct_messages (
  id              TEXT PRIMARY KEY,
  conversation_id TEXT NOT NULL REFERENCES conversations (id) ON DELETE CASCADE,

  sender_id       TEXT REFERENCES users (id) ON DELETE SET NULL,
  -- Kept beside the id so a conversation still reads correctly after an account
  -- is closed.
  sender_name     TEXT,

  body            TEXT NOT NULL,

  -- An attachment already in the media library. Files are not uploaded through
  -- this path: everything in R2 goes through the media service, which checks
  -- the type and the size.
  media_id        TEXT REFERENCES media_assets (id) ON DELETE SET NULL,

  status          TEXT NOT NULL DEFAULT 'sent'
                    CHECK (status IN ('sent', 'deleted', 'hidden')),

  edited_at       TEXT,
  created_at      TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_messages_conversation
  ON direct_messages (conversation_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- ASKING FOR SOMEBODY'S CONTACT DETAILS
--
-- The request carries a reason, and the reason is shown to the person deciding.
-- "I am your cousin in Calabar and there is a funeral" and "hi" are different
-- requests, and somebody deciding whether to hand over their phone number
-- deserves to be told which one this is.
--
-- Nothing here is automatic. An unanswered request stays unanswered; there is
-- no timeout that grants it, because a request nobody replied to is not
-- consent.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS contact_requests (
  id            TEXT PRIMARY KEY,

  requester_id  TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  subject_id    TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,

  -- What they are asking to see. Asked for separately because they are not the
  -- same ask: a number is how you reach somebody today, an email is a durable
  -- identifier that follows them around.
  wants_phone   INTEGER NOT NULL DEFAULT 1 CHECK (wants_phone IN (0, 1)),
  wants_email   INTEGER NOT NULL DEFAULT 0 CHECK (wants_email IN (0, 1)),

  reason        TEXT,

  state         TEXT NOT NULL DEFAULT 'pending'
                  CHECK (state IN ('pending', 'approved', 'declined', 'withdrawn', 'revoked')),

  decided_at    TEXT,
  decided_note  TEXT,

  created_at    TEXT NOT NULL,
  updated_at    TEXT NOT NULL,

  -- One outstanding request per pair. Somebody who has been declined cannot
  -- ask again by pressing the button forty times.
  UNIQUE (requester_id, subject_id)
);

CREATE INDEX IF NOT EXISTS idx_contact_requests_subject
  ON contact_requests (subject_id, state);

-- ---------------------------------------------------------------------------
-- WHAT WAS ACTUALLY GRANTED
--
-- Separate from the request, deliberately. The request is a conversation about
-- permission; this row IS the permission, and it is the only thing
-- `visibleProfile` consults. Revoking is deleting the grant, which takes effect
-- on the next request — there is no cached copy anywhere that could keep
-- working after somebody changed their mind.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS contact_grants (
  id            TEXT PRIMARY KEY,

  -- Who may see. Who they may see.
  viewer_id     TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  subject_id    TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,

  can_see_phone INTEGER NOT NULL DEFAULT 0 CHECK (can_see_phone IN (0, 1)),
  can_see_email INTEGER NOT NULL DEFAULT 0 CHECK (can_see_email IN (0, 1)),

  request_id    TEXT REFERENCES contact_requests (id) ON DELETE SET NULL,
  granted_at    TEXT NOT NULL,

  UNIQUE (viewer_id, subject_id)
);

CREATE INDEX IF NOT EXISTS idx_contact_grants_viewer
  ON contact_grants (viewer_id, subject_id);

-- ---------------------------------------------------------------------------
-- Who may write to a member at all.
--
-- Defaults to 'members', not to 'everyone'. Being reachable is the point of
-- this feature, and being reachable by anybody who can type is how people stop
-- using it.
-- ---------------------------------------------------------------------------
ALTER TABLE member_profiles ADD COLUMN messages_from TEXT NOT NULL DEFAULT 'members'
  CHECK (messages_from IN ('members', 'nobody'));

-- Whether a member appears when somebody searches for a name to message.
--
-- Separate from `listed_in_directory` on purpose: "do not put me in the
-- community's published list of people" and "do not let my own cousin find me
-- to say hello" are different wishes, and a great many people hold the first
-- without holding the second.
ALTER TABLE member_profiles ADD COLUMN findable_for_messages INTEGER NOT NULL DEFAULT 1
  CHECK (findable_for_messages IN (0, 1));

-- ---------------------------------------------------------------------------
-- The wording, in the CMS with the rest of the site's text.
-- ---------------------------------------------------------------------------
INSERT OR IGNORE INTO content_strings
  (key, value, draft_value, group_name, page, label, help_text,
   value_type, max_length, status, is_locked, sort_order, created_at, updated_at)
VALUES
  ('page.messages.title', 'Messages', NULL, 'pages', 'messages',
   'The messages page title', NULL, 'text', 120,
   'published', 0, 10, datetime('now'), datetime('now')),

  ('page.messages.intro',
   'Write to anybody in the community without needing their phone number. They can reply here, '
   || 'and neither of you has to publish a number or an email address to be reachable.',
   NULL, 'pages', 'messages',
   'The line under the messages heading', NULL, 'text', 400,
   'published', 0, 20, datetime('now'), datetime('now')),

  ('messages.contact_request.explainer',
   'Asking to see somebody''s phone number or email sends them a request. They decide, and they '
   || 'can change their mind later. Nothing is shared until they say yes.',
   NULL, 'messages', 'messages',
   'Shown above the form for requesting somebody''s contact details', NULL, 'text', 400,
   'published', 0, 30, datetime('now'), datetime('now'));
