-- ---------------------------------------------------------------------------
-- EKOLI YEDEN DIGITAL HOME — Migration 0008
-- Editorial Team roles.
--
-- THE DISTINCTION THIS MIGRATION ENFORCES:
--
--   The Editorial Team is not the Super Admin.
--
-- Editorial roles can write, edit, review and publish the content of the
-- archive. None of them can create a Super Admin, change a role, alter a
-- security setting, read the audit log, delete content, or reach anything
-- to do with Cloudflare. Those permissions are simply absent from the arrays
-- below, and the Worker denies by default — a permission that is not granted
-- does not exist.
--
-- The team is split into four positions so that writing and publishing are
-- separate acts:
--
--   Writer   → drafts and submits
--   Editor   → edits, and shapes pages, navigation and the homepage
--   Reviewer → approves or rejects
--   Publisher→ makes approved content live
--
-- A Super Admin assigns whichever combination a volunteer needs. Nobody gets
-- `content.publish` merely by being on the Editorial Team.
--
-- Permission naming: these dotted capabilities sit above the resource-scoped
-- permissions seeded in 0005 (`history:create`, `videos:publish`, …). The
-- Worker's authorisation layer treats `content.create` as satisfying
-- `<any content resource>:create`, so both vocabularies work together and a
-- role can be granted broadly or narrowly.
-- ---------------------------------------------------------------------------

INSERT OR IGNORE INTO roles (id, slug, name, description, permissions, is_system, created_at, updated_at)
VALUES
  (
    'role_editorial_writer',
    'editorial_writer',
    'Editorial Team — Writer',
    'Writes and edits drafts, and submits them for review. Cannot approve or publish anything.',
    '["content.create","content.edit","content.read","content.submit","media.metadata.edit","sources.read"]',
    1,
    '2026-01-01T00:00:00.000Z',
    '2026-01-01T00:00:00.000Z'
  ),
  (
    'role_editorial_editor',
    'editorial_editor',
    'Editorial Team — Editor',
    'Edits all editorial content, and manages page text, navigation labels, homepage sections, SEO fields and sources. Cannot approve or publish.',
    '["content.create","content.edit","content.read","content.submit","pages.edit","navigation.edit","homepage.edit","seo.edit","media.metadata.edit","sources.manage","sources.read"]',
    1,
    '2026-01-01T00:00:00.000Z',
    '2026-01-01T00:00:00.000Z'
  ),
  (
    'role_editorial_reviewer',
    'editorial_reviewer',
    'Editorial Team — Reviewer',
    'Reviews submitted content and approves or rejects it. Approval is not publication.',
    '["content.read","content.review","sources.read","submissions:read","submissions:review"]',
    1,
    '2026-01-01T00:00:00.000Z',
    '2026-01-01T00:00:00.000Z'
  ),
  (
    'role_editorial_publisher',
    'editorial_publisher',
    'Editorial Team — Publisher',
    'Publishes approved content to the public site, and can withdraw it again. Granted separately from editing.',
    '["content.read","content.publish","content.unpublish","sources.read"]',
    1,
    '2026-01-01T00:00:00.000Z',
    '2026-01-01T00:00:00.000Z'
  );

-- --------------------------------------------------------------------------
-- Super Admin capabilities, named explicitly.
--
-- The role already holds the "*" wildcard, so this changes nothing at runtime.
-- It is written out so that the permission vocabulary is documented in the
-- database itself and an administrator reading the roles table can see exactly
-- what the wildcard covers.
-- --------------------------------------------------------------------------
UPDATE roles
SET description =
      'Complete control of the platform: system.manage, users.manage, roles.manage, '
      || 'permissions.manage, security.manage, settings.manage, content.manage, content.publish, '
      || 'content.delete, media.manage, submissions.manage, audit.view. Held by the Technology Team.',
    updated_at = '2026-01-01T00:00:00.000Z'
WHERE slug = 'super_admin';

-- --------------------------------------------------------------------------
-- Site settings introduced by the editorial system.
-- --------------------------------------------------------------------------
INSERT OR IGNORE INTO site_settings (key, value, value_type, group_name, is_public, description, updated_at)
VALUES
  ('editorial_requires_review', 'true', 'boolean', 'editorial', 0,
   'Content must pass review before it can be published. Turning this off is a Super Admin decision.',
   '2026-01-01T00:00:00.000Z'),
  ('editorial_requires_separate_publisher', 'true', 'boolean', 'editorial', 0,
   'The person who approves content may not also publish it.',
   '2026-01-01T00:00:00.000Z'),
  ('show_contributor_attribution', 'true', 'boolean', 'editorial', 1,
   'Show "Contributed by …" on published material.',
   '2026-01-01T00:00:00.000Z'),
  ('show_research_edition_notice', 'true', 'boolean', 'editorial', 1,
   'Show the "Initial Research Edition" notice on history drawn from unverified secondary sources.',
   '2026-01-01T00:00:00.000Z'),
  ('hero_autoplay_seconds', '7', 'number', 'appearance', 1,
   'Seconds each homepage hero slide is shown. Set to 0 to disable autoplay.',
   '2026-01-01T00:00:00.000Z');
