import type { Handler, RequestContext } from '../types/api';
import { json, publicCacheHeaders } from '../utils/responses';
import { publicMediaUrl } from '../utils/files';

/**
 * THE COMMUNITY HUB.
 *
 * ---------------------------------------------------------------------------
 * WHY AN ACTIVITY FEED IS ASSEMBLED RATHER THAN STORED
 * ---------------------------------------------------------------------------
 *
 * The obvious design is an `activity` table that every other module writes a
 * row to. It is also the design that goes wrong quietly: the day somebody adds
 * a feature and forgets the write, that feature becomes invisible to the whole
 * community and nobody notices, because a missing row looks exactly like
 * nothing having happened.
 *
 * So the feed is assembled from the things themselves — the photographs, the
 * conversations, the people who joined. A new section appears in it by being
 * added here, in one place, and until then its absence is a visible gap rather
 * than a silent one.
 *
 * At this size the cost is five small indexed queries behind a five-minute
 * edge cache. If the archive ever outgrows that, the fix is a materialised
 * table fed from these same queries — not a write scattered through twenty
 * controllers.
 *
 * ---------------------------------------------------------------------------
 * WHAT THE FEED WILL NOT CARRY
 * ---------------------------------------------------------------------------
 *
 * Forum posts, as opposed to the fact that a conversation was started. Two of
 * the three spaces may hold minors and the server refuses their contents to an
 * anonymous caller; quoting a reply into a public feed would route around that
 * for no gain. The feed says a conversation exists and where; reading it still
 * asks the same questions of the same reader.
 */

interface FeedRow extends Record<string, unknown> {
  kind: string;
  at: string | null;
}

export const communityOverview: Handler = async (context: RequestContext) => {
  const db = context.env.DB;
  const base = context.env.PUBLIC_MEDIA_BASE_URL;

  const [stats, members, groups, grades, photographs, conversations, news, joins] =
    await db.batch<Record<string, unknown>>([
      db.prepare(
        `SELECT
           (SELECT COUNT(*) FROM "member_profiles" WHERE "membership_status" = 'active') AS members,
           (SELECT COUNT(*) FROM "community_groups" WHERE "status" = 'published') AS groups,
           (SELECT COUNT(*) FROM "age_grades" WHERE "status" = 'published') AS age_grades,
           (SELECT COUNT(*) FROM "forum_spaces" WHERE "status" = 'published') AS forums,
           (SELECT COUNT(*) FROM "forum_topics") AS topics,
           (SELECT COUNT(*) FROM "forum_posts") AS posts,
           (SELECT COUNT(*) FROM "gallery_items" WHERE "status" = 'published') AS photographs,
           (SELECT COUNT(*) FROM "news" WHERE "status" = 'published') AS news,
           (SELECT COUNT(*) FROM "history_entries" WHERE "status" = 'published') AS history,
           (SELECT COUNT(*) FROM "language_words" WHERE "status" = 'published') AS words,
           (SELECT COUNT(*) FROM "people" WHERE "status" = 'published') AS people,
           (SELECT COUNT(*) FROM "recordings" WHERE "status" = 'published') AS recordings`,
      ),

      // The people, newest first. Only those who asked to be listed.
      db.prepare(
        `SELECT p."handle", p."full_name", p."headline", p."joined_at", p."place_text",
                p."open_to_mentoring", m."storage_key" AS avatar_key
         FROM "member_profiles" p
         LEFT JOIN "media_assets" m ON m."id" = p."avatar_media_id"
         WHERE p."membership_status" = 'active' AND p."listed_in_directory" = 1
           AND COALESCE(p."memorial_state", 'living') = 'living'
         ORDER BY p."joined_at" DESC
         LIMIT 8`,
      ),

      db.prepare(
        `SELECT g."slug", g."title" AS name, g."kind", g."member_count", m."storage_key" AS cover_key
         FROM "community_groups" g
         LEFT JOIN "media_assets" m ON m."id" = g."cover_media_id"
         WHERE g."status" = 'published'
         ORDER BY g."member_count" DESC, g."title"
         LIMIT 6`,
      ),

      db.prepare(
        `SELECT "slug", "title", "birth_years"
         FROM "age_grades" WHERE "status" = 'published'
         ORDER BY "formed_year" DESC LIMIT 6`,
      ),

      // --- The feed -------------------------------------------------------
      db.prepare(
        `SELECT 'photograph' AS kind, gi."created_at" AS at, gi."caption" AS title,
                gi."photographer" AS actor, g."slug" AS parent_slug, g."title" AS parent_title,
                ma."storage_key" AS image_key
         FROM "gallery_items" gi
         INNER JOIN "galleries" g ON g."id" = gi."gallery_id"
         LEFT JOIN "media_assets" ma ON ma."id" = gi."media_asset_id"
         WHERE gi."status" = 'published' AND g."status" = 'published'
         ORDER BY gi."created_at" DESC LIMIT 8`,
      ),

      db.prepare(
        `SELECT 'conversation' AS kind, t."created_at" AS at, t."title" AS title,
                NULL AS actor, s."slug" AS parent_slug, s."name" AS parent_title,
                NULL AS image_key
         FROM "forum_topics" t
         INNER JOIN "forum_spaces" s ON s."id" = t."space_id"
         WHERE s."visibility" = 'public' AND s."status" = 'published'
         ORDER BY t."created_at" DESC LIMIT 6`,
      ),

      db.prepare(
        `SELECT 'news' AS kind, n."published_at" AS at, n."title" AS title,
                n."author_name" AS actor, n."slug" AS parent_slug,
                c."name" AS parent_title, NULL AS image_key
         FROM "news" n
         LEFT JOIN "news_categories" c ON c."id" = n."category_id"
         WHERE n."status" = 'published'
         ORDER BY n."published_at" DESC LIMIT 6`,
      ),

      db.prepare(
        `SELECT 'member' AS kind, p."joined_at" AS at, p."full_name" AS title,
                p."handle" AS actor, NULL AS parent_slug, p."place_text" AS parent_title,
                m."storage_key" AS image_key
         FROM "member_profiles" p
         LEFT JOIN "media_assets" m ON m."id" = p."avatar_media_id"
         WHERE p."membership_status" = 'active' AND p."listed_in_directory" = 1
         ORDER BY p."joined_at" DESC LIMIT 6`,
      ),
    ]);

  const url = (key: unknown): string | null =>
    typeof key === 'string' && key !== '' ? publicMediaUrl(base, key) : null;

  const feed: FeedRow[] = [
    ...((photographs?.results ?? []) as FeedRow[]),
    ...((conversations?.results ?? []) as FeedRow[]),
    ...((news?.results ?? []) as FeedRow[]),
    ...((joins?.results ?? []) as FeedRow[]),
  ]
    .filter((row) => typeof row.at === 'string' && row.at !== '')
    .sort((a, b) => String(b.at).localeCompare(String(a.at)))
    .slice(0, 20);

  return json(
    {
      stats: stats?.results?.[0] ?? {},

      members: (members?.results ?? []).map((row) => ({
        handle: row['handle'],
        name: row['full_name'],
        headline: row['headline'],
        place: row['place_text'],
        joined_at: row['joined_at'],
        open_to_mentoring: Number(row['open_to_mentoring'] ?? 0) === 1,
        avatar_url: url(row['avatar_key']),
      })),

      groups: [
        ...(groups?.results ?? []).map((row) => ({
          slug: row['slug'],
          name: row['name'],
          kind: row['kind'],
          member_count: Number(row['member_count'] ?? 0),
          cover_url: url(row['cover_key']),
        })),
        // Age grades are groups too, and a community hub that lists one kind
        // and not the other tells half the story of how Ekori organises itself.
        ...(grades?.results ?? []).map((row) => ({
          slug: row['slug'],
          name: row['title'],
          kind: 'age_grade',
          member_count: 0,
          detail: row['birth_years'],
          cover_url: null,
        })),
      ],

      activity: feed.map((row) => ({
        kind: row['kind'],
        at: row['at'],
        title: row['title'],
        actor: row['actor'],
        parent_slug: row['parent_slug'],
        parent_title: row['parent_title'],
        image_url: url(row['image_key']),
      })),
    },
    { headers: publicCacheHeaders(300) },
  );
};
