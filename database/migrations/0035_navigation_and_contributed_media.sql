-- ===========================================================================
-- 0035  THE NAVIGATION, AND THE MEDIA THAT NEVER APPEARED
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- THE TOP NAVIGATION
--
-- `navigation_items` is authoritative — the compiled-in list in
-- `app_routes.dart` is only a fallback for when the database cannot be read.
-- So the four sections finished in 0034 were built, routed, in the sitemap and
-- in the share previews, and reachable from nowhere on the site itself.
--
-- Videos and Community come out at the same time. Both still exist and both
-- keep their addresses: film sits in the Gallery beside the photographs, which
-- is where somebody asking "what did this look like" actually goes, and the
-- development projects sit inside News. Listing them again in the top
-- navigation advertised two doors into rooms the visitor was already in.
-- ---------------------------------------------------------------------------

-- `status` is the visibility switch on this table; 'archived' takes a row out
-- of the menu without losing the record of it having been there.
UPDATE navigation_items SET status = 'archived', updated_at = datetime('now')
WHERE id IN ('nav_videos', 'nav_community');

INSERT OR IGNORE INTO navigation_items
  (id, menu, label, path, description, is_cta, sort_order, status, created_at, updated_at)
VALUES
  ('nav_voices', 'primary', 'Voices', '/voices',
   'Elders and others, recorded in their own words', 0, 75, 'published',
   datetime('now'), datetime('now')),

  ('nav_stories', 'primary', 'Stories', '/stories',
   'Folktales and the long tellings', 0, 76, 'published',
   datetime('now'), datetime('now')),

  ('nav_discover', 'primary', 'Discover', '/discover',
   'The wards, quarters and landmarks of Ekori', 0, 77, 'published',
   datetime('now'), datetime('now')),

  ('nav_learn', 'primary', 'For children', '/learn',
   'Learn about Ekori — greetings, numbers and quizzes', 0, 78, 'published',
   datetime('now'), datetime('now'));


-- ---------------------------------------------------------------------------
-- A COVER IMAGE FOR A MEMBER
--
-- `avatar_media_id` has always existed. This is the band behind it.
-- ---------------------------------------------------------------------------
ALTER TABLE member_profiles ADD COLUMN cover_media_id TEXT
  REFERENCES media_assets (id) ON DELETE SET NULL;


-- ---------------------------------------------------------------------------
-- THE ALBUM THAT CONTRIBUTED FILES GO INTO
--
-- Approving a contributed file accessioned it and stopped. Filing it into an
-- album and publishing it were separate actions on a screen that did not offer
-- them, so thirteen photographs and a film were approved and appeared nowhere.
--
-- The Worker now files and publishes on approval, and it needs somewhere to
-- file to when the reviewer has not chosen an album. This is that album.
-- ---------------------------------------------------------------------------
INSERT OR IGNORE INTO galleries
  (id, slug, title, description, category, event_date, cover_media_id,
   seo_title, seo_description, sort_order, status, created_at, updated_at)
VALUES
  ('gal_community_contributions', 'community-contributions',
   'Sent in by the community',
   'Photographs and film given to the archive by people of Ekoli-Yeden. Every item here was '
   || 'sent in by somebody and checked before it was published.',
   'community', NULL, NULL,
   'Sent in by the community',
   'Photographs and film given to the archive by people of Ekoli-Yeden.',
   90, 'published', datetime('now'), datetime('now'));


-- ---------------------------------------------------------------------------
-- THE THIRTEEN THAT WERE ALREADY APPROVED
--
-- They have media assets and no album entry. Filing them by hand here rather
-- than asking somebody to re-approve thirteen files one at a time through a
-- screen that, until today, would not have published them anyway.
--
-- `taken_at`, `location` and the caption come back from the submission the file
-- arrived on, and the contributor's name becomes the credit — which is the
-- whole reason those columns were collected.
-- ---------------------------------------------------------------------------
INSERT INTO gallery_items
  (id, gallery_id, media_asset_id, caption, people_pictured, photographer,
   taken_at, location, sort_order, status, created_at, updated_at,
   contributed_by, submission_upload_id, added_by)
SELECT
  'gi_' || substr(su.id, 1, 26),
  'gal_community_contributions',
  su.media_asset_id,
  su.caption,
  su.people_pictured,
  su.contributor_name,
  su.taken_at,
  su.location,
  ROW_NUMBER() OVER (ORDER BY su.created_at),
  'published',
  datetime('now'),
  datetime('now'),
  su.uploaded_by,
  su.id,
  su.reviewed_by
FROM submission_uploads su
WHERE su.status = 'promoted'
  AND su.media_asset_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM gallery_items gi WHERE gi.media_asset_id = su.media_asset_id
  );

-- The assets themselves were left at 'approved', which is why they did not
-- appear even at their own address.
UPDATE media_assets SET status = 'published', updated_at = datetime('now')
WHERE id IN (
  SELECT media_asset_id FROM submission_uploads
  WHERE status = 'promoted' AND media_asset_id IS NOT NULL
) AND status <> 'published';
