-- ---------------------------------------------------------------------------
-- 0021  Make membership findable
-- ---------------------------------------------------------------------------
--
-- The Join page has existed since Module 4, routed at /join and working. Nobody
-- could find it, and not one person had joined.
--
-- The navigation is CMS-driven so the Editorial Team can reorder it, and the
-- Dart constants in `app_routes.dart` are only a fallback for before the CMS
-- has loaded. `navigation_items` was seeded in 0009, before membership existed,
-- so the live menu carried no Join item — and the fallback list that did carry
-- one was therefore never used.
--
-- Adding a route to the router and a NavItem to the fallback list is two thirds
-- of shipping a page. This is the third.
--
-- The existing primary menu is numbered 1..12 with no gaps, so making room for
-- Join means moving Contribute along by one rather than picking a large number
-- and landing at the end.
-- ---------------------------------------------------------------------------

-- Contribute steps aside to make room. Done first so the two never share a
-- sort order, which would leave their relative order down to the tie-break.
UPDATE navigation_items
   SET sort_order = 13, updated_at = datetime('now')
 WHERE path = '/contribute';

-- Join sits immediately before Contribute, which is deliberate: contributing
-- now requires a membership, so somebody reading the menu left to right meets
-- the thing they need before the thing that needs it.
INSERT OR IGNORE INTO navigation_items
  (id, menu, label, path, description, is_cta, sort_order, status, created_at, updated_at)
VALUES
  ('nav_join', 'primary', 'Join', '/join',
   'One Okoli account — your membership and the community',
   0, 12, 'published', datetime('now'), datetime('now'));

-- A member's own affairs, kept out of the primary menu: that menu is for the
-- archive, not for one reader's account.
INSERT OR IGNORE INTO navigation_items
  (id, menu, label, path, description, is_cta, sort_order, status, created_at, updated_at)
VALUES
  ('nav_account', 'utility', 'My account', '/account',
   'Your membership, your profile and your notifications',
   0, 100, 'published', datetime('now'), datetime('now'));

-- Contribute is re-worded rather than left as seeded: 0009 invited anybody to
-- send material, which is no longer true.
UPDATE navigation_items
   SET description = 'Share photographs, recordings and stories — members only',
       updated_at  = datetime('now')
 WHERE path = '/contribute';

-- ---------------------------------------------------------------------------
-- The wording that explains the change to a visitor
-- ---------------------------------------------------------------------------
--
-- Held as CMS strings rather than baked into the Dart, so the community can
-- soften or sharpen it without a deployment.
INSERT OR IGNORE INTO content_strings
  (key, value, group_name, page, label, help_text, value_type, status, created_at, updated_at)
VALUES
  ('page.contribute.members_only',
   'Contributing is for members of Ekoli-Yeden. Reading is for everybody, always.',
   'contribute', 'contribute',
   'Contribute — members-only notice',
   'Shown in place of the contribution form to somebody who has not yet joined',
   'text', 'published', datetime('now'), datetime('now')),

  ('page.join.why_contribute',
   'A photograph is worth what is known about it. When we cannot tell who is pictured or when, '
   || 'the only way to find out is to ask whoever sent it — so a contribution is tied to a member '
   || 'we can reach. It costs a name, an email and a moment. There is no fee.',
   'join', 'join',
   'Join — why membership is required to contribute',
   'The reason given for requiring membership before contributing',
   'text', 'published', datetime('now'), datetime('now'));
