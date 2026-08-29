-- ===========================================================================
-- 0040  THE COMMUNITY HUB IN THE MENU
-- ===========================================================================
--
-- `navigation_items` is authoritative and the compiled-in list is only a
-- fallback, so a section added to `app_routes.dart` alone is built, routed, in
-- the sitemap, in the share previews — and linked from nowhere on the site.
--
-- That has now caught the same set of pages twice. The lesson is written into
-- 0035 and repeated here: a new public section is not finished until it has a
-- row in this table.
--
-- `nav_community` was archived in 0035 because it pointed at /community, which
-- is the development projects inside News. This is a different page — who is
-- here, the forums, and what has happened lately — and takes an address of its
-- own rather than fighting for that one.
-- ===========================================================================

INSERT OR IGNORE INTO navigation_items
  (id, menu, label, path, description, is_cta, sort_order, status, created_at, updated_at)
VALUES
  ('nav_community_hub', 'primary', 'Community', '/the-community',
   'Who is here, the forums, and what has happened lately', 0, 74, 'published',
   datetime('now'), datetime('now'));
