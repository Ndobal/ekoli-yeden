-- ---------------------------------------------------------------------------
-- 0025  Membership belongs in the dashboard, not the public menu
-- ---------------------------------------------------------------------------
--
-- 0021 put "Join" in the primary navigation, because nobody could find the
-- membership page at all. That fixed the discovery problem and created a
-- smaller one: the primary menu is for reading about Ekoli-Yeden, and it had
-- started to carry a member's own affairs.
--
-- Now that registering signs somebody straight in and lands them on their
-- dashboard, the dashboard is where membership is completed and where every
-- member feature lives — opportunities, groups, family, dues, the directory.
-- A visitor has no use for any of it.
--
-- WHAT IS NOT REMOVED, AND WHY THAT MATTERS
--
-- "Join" leaves the PRIMARY menu and moves to the UTILITY menu, which sits
-- beside Sign in. It is not deleted. Somebody who has never been here still has
-- to be able to become a member without an account first, and a menu with no
-- way in at all would be the same mistake as 0009 made, in the other direction.
-- ---------------------------------------------------------------------------

UPDATE navigation_items
   SET menu        = 'utility',
       sort_order  = 20,
       description = 'Become a member of the Yakoli community',
       updated_at  = datetime('now')
 WHERE path = '/join';

-- Contribute stays in the primary menu. It is a request to the whole community
-- rather than a member's own affair, and the page itself explains that
-- contributing needs a membership.
UPDATE navigation_items
   SET sort_order = 12,
       updated_at = datetime('now')
 WHERE path = '/contribute';

-- The member's own entrance, beside Join.
INSERT OR IGNORE INTO navigation_items
  (id, menu, label, path, description, is_cta, sort_order, status, created_at, updated_at)
VALUES
  ('nav_dashboard', 'utility', 'My dashboard', '/account',
   'Your membership, your groups, opportunities and your family',
   0, 10, 'published', datetime('now'), datetime('now'));

-- The old utility entry is superseded by the one above.
DELETE FROM navigation_items WHERE id = 'nav_account';

-- ---------------------------------------------------------------------------
-- Footer: the member sections people may look for directly
-- ---------------------------------------------------------------------------
--
-- Reachable, but not competing with the archive itself for attention in the
-- main menu. Somebody who knows the directory exists can find it; somebody
-- reading about Leboku is not interrupted by it.
-- ---------------------------------------------------------------------------

INSERT OR IGNORE INTO navigation_items
  (id, menu, label, path, description, is_cta, sort_order, status, created_at, updated_at)
VALUES
  ('nav_directory', 'footer', 'Member directory', '/directory',
   'Find members by what they do and where they are',
   0, 220, 'published', datetime('now'), datetime('now')),

  ('nav_opportunities', 'footer', 'Opportunities', '/opportunities',
   'Jobs, scholarships and training for members',
   0, 230, 'published', datetime('now'), datetime('now')),

  ('nav_groups', 'footer', 'Groups and age grades', '/groups',
   'Age grades, cultural groups, associations and unions',
   0, 205, 'published', datetime('now'), datetime('now'));

-- The footer already carries "Age grades" and "Cultural groups" separately.
-- Both now render the same section with a filter, so the standalone entries are
-- kept — they are useful doors — but described honestly.
UPDATE navigation_items
   SET description = 'The age grades of Ekoli-Yeden, by generation',
       updated_at  = datetime('now')
 WHERE path = '/age-grades';
