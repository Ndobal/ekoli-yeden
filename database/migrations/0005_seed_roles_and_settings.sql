-- ---------------------------------------------------------------------------
-- EKOLI YEDEN DIGITAL HOME — Migration 0005
-- Seeds the role definitions and the site setting keys.
--
-- This migration seeds STRUCTURE ONLY.
--
-- It creates no history, no leaders, no people, no language entries, no
-- festival records and no news. Those are supplied by the Ekoli-Yeden
-- Preservation Team through the admin system once the community has verified
-- them. Every content table is intentionally left empty.
--
-- Permission strings are "<resource>:<action>" and are kept in step with
-- worker/src/services/content-registry.ts. Super Admin holds the wildcard "*".
-- ---------------------------------------------------------------------------

INSERT OR IGNORE INTO roles (id, slug, name, description, permissions, is_system, created_at, updated_at)
VALUES
  (
    'role_super_admin',
    'super_admin',
    'Super Admin',
    'Complete control of the platform, including users, roles and settings.',
    '["*"]',
    1,
    '2026-01-01T00:00:00.000Z',
    '2026-01-01T00:00:00.000Z'
  ),
  (
    'role_content_administrator',
    'content_administrator',
    'Content Administrator',
    'Manages all published content across the archive, but not user accounts or roles.',
    '["audit:read","businesses:create","businesses:delete","businesses:publish","businesses:read","businesses:update","community:create","community:delete","community:publish","community:read","community:update","events:create","events:delete","events:publish","events:read","events:update","festivals:create","festivals:delete","festivals:publish","festivals:read","festivals:update","galleries:create","galleries:delete","galleries:publish","galleries:read","galleries:update","history:create","history:delete","history:publish","history:read","history:update","language-categories:create","language-categories:delete","language-categories:publish","language-categories:read","language-categories:update","language:create","language:delete","language:publish","language:read","language:update","leaders:create","leaders:delete","leaders:publish","leaders:read","leaders:update","media:create","media:delete","media:read","media:update","news:create","news:delete","news:publish","news:read","news:update","organizations:create","organizations:delete","organizations:publish","organizations:read","organizations:update","pages:create","pages:delete","pages:publish","pages:read","pages:update","people:create","people:delete","people:publish","people:read","people:update","submissions:read","submissions:review","users:read","videos:create","videos:delete","videos:publish","videos:read","videos:update"]',
    1,
    '2026-01-01T00:00:00.000Z',
    '2026-01-01T00:00:00.000Z'
  ),
  (
    'role_heritage_editor',
    'heritage_editor',
    'Heritage Editor',
    'Ekoli-Yeden history, traditional leadership and notable people.',
    '["history:create","history:delete","history:publish","history:read","history:update","leaders:create","leaders:delete","leaders:publish","leaders:read","leaders:update","media:create","media:read","media:update","people:create","people:delete","people:publish","people:read","people:update","submissions:read"]',
    1,
    '2026-01-01T00:00:00.000Z',
    '2026-01-01T00:00:00.000Z'
  ),
  (
    'role_language_editor',
    'language_editor',
    'Language Editor',
    'The Ekoli language dictionary, proverbs and pronunciation recordings.',
    '["language-categories:create","language-categories:delete","language-categories:publish","language-categories:read","language-categories:update","language:create","language:delete","language:publish","language:read","language:update","media:create","media:read","media:update","submissions:read"]',
    1,
    '2026-01-01T00:00:00.000Z',
    '2026-01-01T00:00:00.000Z'
  ),
  (
    'role_media_manager',
    'media_manager',
    'Media Manager',
    'Photographs, audio, galleries and the YouTube video archive.',
    '["galleries:create","galleries:delete","galleries:publish","galleries:read","galleries:update","media:create","media:delete","media:read","media:update","submissions:read","videos:create","videos:delete","videos:publish","videos:read","videos:update"]',
    1,
    '2026-01-01T00:00:00.000Z',
    '2026-01-01T00:00:00.000Z'
  ),
  (
    'role_leboku_manager',
    'leboku_manager',
    'Leboku Manager',
    'Festival editions, programmes, announcements and festival events.',
    '["events:create","events:publish","events:read","events:update","festivals:create","festivals:delete","festivals:publish","festivals:read","festivals:update","galleries:read","media:create","media:read","media:update","videos:read"]',
    1,
    '2026-01-01T00:00:00.000Z',
    '2026-01-01T00:00:00.000Z'
  ),
  (
    'role_moderator',
    'moderator',
    'Moderator',
    'Reviews community contributions and decides what enters the archive.',
    '["events:read","galleries:read","history:read","language:read","leaders:read","media:read","media:update","news:read","people:read","submissions:read","submissions:review","videos:read"]',
    1,
    '2026-01-01T00:00:00.000Z',
    '2026-01-01T00:00:00.000Z'
  ),
  (
    'role_contributor',
    'contributor',
    'Contributor',
    'Submits photographs, documents, stories and recordings for review. Holds no publishing permission.',
    '[]',
    1,
    '2026-01-01T00:00:00.000Z',
    '2026-01-01T00:00:00.000Z'
  ),
  (
    'role_public_visitor',
    'public_visitor',
    'Public Visitor',
    'Reads published content. This is the default for anyone who is not signed in; it is never assigned to an account.',
    '[]',
    1,
    '2026-01-01T00:00:00.000Z',
    '2026-01-01T00:00:00.000Z'
  );

-- ---------------------------------------------------------------------------
-- Site settings.
--
-- Keys are defined here so the Flutter client always knows what it may
-- receive. Values marked "to be supplied" are left empty on purpose — the
-- platform does not invent contact details, social accounts or facts about
-- Ekoli-Yeden. An administrator fills them in through /admin/settings.
-- ---------------------------------------------------------------------------
INSERT OR IGNORE INTO site_settings (key, value, value_type, group_name, is_public, description, updated_at)
VALUES
  -- Identity
  ('site_name', 'Ekoli Yeden Digital Home', 'string', 'identity', 1, 'The name shown in the header and browser tab.', '2026-01-01T00:00:00.000Z'),
  ('site_tagline', 'Preserving Our Past. Celebrating Our Present. Building Our Future.', 'string', 'identity', 1, 'The tagline shown beneath the site name.', '2026-01-01T00:00:00.000Z'),
  ('community_name', 'Ekoli-Yeden', 'string', 'identity', 1, 'The name of the community this archive belongs to.', '2026-01-01T00:00:00.000Z'),
  ('festival_name', 'Leboku', 'string', 'identity', 1, 'The name of the community festival.', '2026-01-01T00:00:00.000Z'),
  ('site_description', NULL, 'string', 'identity', 1, 'Default meta description. To be supplied.', '2026-01-01T00:00:00.000Z'),
  ('logo_media_id', NULL, 'string', 'identity', 1, 'Media asset id of the site logo.', '2026-01-01T00:00:00.000Z'),
  ('social_share_image_media_id', NULL, 'string', 'identity', 1, 'Default Open Graph image. To be supplied.', '2026-01-01T00:00:00.000Z'),

  -- Contact — deliberately empty until the community supplies verified details.
  ('contact_email', NULL, 'string', 'contact', 1, 'Official contact email. To be supplied.', '2026-01-01T00:00:00.000Z'),
  ('contact_phone', NULL, 'string', 'contact', 1, 'Official contact phone number. To be supplied.', '2026-01-01T00:00:00.000Z'),
  ('contact_address', NULL, 'string', 'contact', 1, 'Postal or physical address. To be supplied.', '2026-01-01T00:00:00.000Z'),

  -- Social — the website is the permanent archive; social media distributes it.
  ('facebook_url', NULL, 'string', 'social', 1, 'Official Facebook page. To be supplied.', '2026-01-01T00:00:00.000Z'),
  ('youtube_url', NULL, 'string', 'social', 1, 'Official YouTube channel. To be supplied.', '2026-01-01T00:00:00.000Z'),
  ('instagram_url', NULL, 'string', 'social', 1, 'Official Instagram account. To be supplied.', '2026-01-01T00:00:00.000Z'),
  ('whatsapp_url', NULL, 'string', 'social', 1, 'Community WhatsApp link. To be supplied.', '2026-01-01T00:00:00.000Z'),

  -- Feature switches — sections stay hidden until there is verified material.
  ('feature_contributions_open', 'true', 'boolean', 'features', 1, 'Whether the public may submit contributions.', '2026-01-01T00:00:00.000Z'),
  ('feature_language_academy', 'true', 'boolean', 'features', 1, 'Show the Ekoli language section.', '2026-01-01T00:00:00.000Z'),
  ('feature_business_directory', 'true', 'boolean', 'features', 1, 'Show the business and professional directory.', '2026-01-01T00:00:00.000Z'),
  ('feature_hall_of_fame', 'false', 'boolean', 'features', 1, 'Show the Hall of Fame section.', '2026-01-01T00:00:00.000Z'),
  ('feature_public_registration', 'true', 'boolean', 'features', 1, 'Whether visitors may create a contributor account.', '2026-01-01T00:00:00.000Z'),

  -- Festival
  ('current_festival_year', NULL, 'number', 'festival', 1, 'The festival edition featured on the homepage. To be supplied.', '2026-01-01T00:00:00.000Z'),
  ('festival_countdown_enabled', 'false', 'boolean', 'festival', 1, 'Show a countdown to the next festival.', '2026-01-01T00:00:00.000Z'),

  -- Editorial policy, applied by the moderation workflow.
  ('moderation_requires_verification', 'true', 'boolean', 'editorial', 0, 'Historical and language entries must be verified before publication.', '2026-01-01T00:00:00.000Z'),
  ('submissions_notify_email', NULL, 'string', 'editorial', 0, 'Where new contribution notices are sent. To be supplied.', '2026-01-01T00:00:00.000Z');
