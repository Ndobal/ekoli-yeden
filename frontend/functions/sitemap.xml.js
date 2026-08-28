/**
 * THE SITEMAP
 *
 * Generated at request time from the API rather than written by hand, so that
 * every history entry, culture article, person, festival and gallery the
 * Preservation Team publishes becomes discoverable without anybody remembering
 * to update a file.
 *
 * That matters for an archive that is meant to grow for years: a hand-written
 * sitemap is accurate on the day it is written and wrong from then on.
 */

const SITE = 'https://ekoli.pages.dev';
const API = 'https://ekoli-yeden-api.ndovera.workers.dev';

/** The fixed section pages, with how strongly each should be weighted. */
const STATIC_PAGES = [
  { path: '/', priority: '1.0', changefreq: 'weekly' },
  { path: '/about', priority: '0.8', changefreq: 'monthly' },
  { path: '/history', priority: '0.9', changefreq: 'weekly' },
  { path: '/culture', priority: '0.9', changefreq: 'weekly' },
  { path: '/language', priority: '0.9', changefreq: 'weekly' },
  { path: '/festivals', priority: '0.9', changefreq: 'weekly' },
  { path: '/leaders', priority: '0.8', changefreq: 'monthly' },
  { path: '/people', priority: '0.8', changefreq: 'weekly' },
  { path: '/age-grades', priority: '0.7', changefreq: 'monthly' },
  { path: '/cultural-groups', priority: '0.7', changefreq: 'monthly' },
  { path: '/music', priority: '0.7', changefreq: 'monthly' },
  { path: '/news', priority: '0.8', changefreq: 'daily' },
  { path: '/events', priority: '0.7', changefreq: 'weekly' },
  { path: '/gallery', priority: '0.8', changefreq: 'weekly' },
  { path: '/videos', priority: '0.8', changefreq: 'weekly' },
  { path: '/community', priority: '0.7', changefreq: 'weekly' },
  { path: '/voices', priority: '0.8', changefreq: 'weekly' },
  { path: '/stories', priority: '0.7', changefreq: 'weekly' },
  { path: '/discover', priority: '0.6', changefreq: 'monthly' },
  { path: '/learn', priority: '0.6', changefreq: 'monthly' },
  { path: '/businesses', priority: '0.6', changefreq: 'weekly' },
  { path: '/organizations', priority: '0.6', changefreq: 'monthly' },
  { path: '/contribute', priority: '0.8', changefreq: 'monthly' },
  { path: '/language/contribute', priority: '0.7', changefreq: 'monthly' },
  { path: '/age-grades/register', priority: '0.6', changefreq: 'monthly' },
  { path: '/gallery/photographs', priority: '0.7', changefreq: 'weekly' },
  { path: '/ancestry', priority: '0.8', changefreq: 'weekly' },
  { path: '/places', priority: '0.7', changefreq: 'monthly' },
  // The forum index only. A conversation is not offered to a crawler — see the
  // note in `_middleware.js`.
  { path: '/community/forums', priority: '0.6', changefreq: 'daily' },
  { path: '/news/submit', priority: '0.5', changefreq: 'monthly' },
  { path: '/preservation-team', priority: '0.7', changefreq: 'monthly' },
  { path: '/contact', priority: '0.5', changefreq: 'monthly' },
  { path: '/terms', priority: '0.4', changefreq: 'yearly' },
  { path: '/privacy', priority: '0.4', changefreq: 'yearly' },
  { path: '/cookies', priority: '0.3', changefreq: 'yearly' },
];

/**
 * The areas of the cultural archive.
 *
 * Listed explicitly because they are defined in the Flutter client rather than
 * in the database — they are the shape of the section, not records in it. Each
 * is a real address a search engine should know about, and each is where
 * somebody searching for "Ekoli-Yeden food" should land.
 *
 * Keep in step with `cultureAreas` in
 * `frontend/lib/features/culture/culture_pages.dart`.
 */
const CULTURE_AREAS = [
  'language',
  'leboku',
  'traditional-practices',
  'wrestling',
  'dances',
  'food',
  'clothing',
  'agriculture',
  'proverbs',
  'folklore',
  'oral-history',
  'traditional-institutions',
  'community-life',
];

/** Content types to enumerate, and the public path each lives under. */
const CONTENT = [
  { resource: 'history', path: '/history', priority: '0.8' },
  { resource: 'culture', path: '/culture', priority: '0.8' },
  { resource: 'leaders', path: '/leaders', priority: '0.7' },
  { resource: 'people', path: '/people', priority: '0.7' },
  { resource: 'news', path: '/news', priority: '0.7' },
  { resource: 'events', path: '/events', priority: '0.6' },
  { resource: 'galleries', path: '/gallery', priority: '0.7' },
  { resource: 'videos', path: '/videos', priority: '0.7' },
  { resource: 'recordings', path: '/voices', priority: '0.7' },
  { resource: 'stories', path: '/stories', priority: '0.6' },
  { resource: 'quizzes', path: '/learn', priority: '0.5' },
  { resource: 'businesses', path: '/businesses', priority: '0.5' },
  { resource: 'organizations', path: '/organizations', priority: '0.5' },
  { resource: 'community', path: '/community', priority: '0.6' },
  { resource: 'age-grades', path: '/age-grades', priority: '0.6' },
  { resource: 'cultural-groups', path: '/cultural-groups', priority: '0.6' },
  { resource: 'music', path: '/music', priority: '0.6' },
  // The people the community came from, and the places it is made of. Both are
  // published records like any other section, and both are what somebody
  // searching a family name should find.
  { resource: 'ancestry', path: '/ancestry', priority: '0.7' },
  { resource: 'places', path: '/places', priority: '0.6' },
];

export async function onRequest() {
  const entries = STATIC_PAGES.map((page) => ({
    loc: `${SITE}${page.path}`,
    priority: page.priority,
    changefreq: page.changefreq,
    lastmod: null,
  }));

  // Everything published, fetched in parallel. A failure on one resource must
  // not empty the whole sitemap, so each is caught individually.
  const collected = await Promise.all(
    CONTENT.map(async ({ resource, path, priority }) => {
      try {
        const response = await fetch(`${API}/api/${resource}?perPage=100`, {
          cf: { cacheTtl: 600, cacheEverything: true },
        });
        if (!response.ok) return [];
        const payload = await response.json();
        if (!payload.success) return [];
        return (payload.data.items || []).map((item) => ({
          loc: `${SITE}${path}/${item.slug || item.id}`,
          priority,
          changefreq: 'monthly',
          lastmod: (item.updated_at || '').slice(0, 10) || null,
        }));
      } catch {
        return [];
      }
    }),
  );

  for (const group of collected) entries.push(...group);

  for (const area of CULTURE_AREAS) {
    entries.push({
      loc: `${SITE}/culture/area/${area}`,
      priority: '0.7',
      changefreq: 'monthly',
      lastmod: null,
    });
  }

  // Festivals sit at their own path.
  try {
    const response = await fetch(`${API}/api/festivals`, {
      cf: { cacheTtl: 600, cacheEverything: true },
    });
    if (response.ok) {
      const payload = await response.json();
      if (payload.success) {
        for (const festival of payload.data.items || []) {
          entries.push({
            loc: `${SITE}/festivals/${festival.slug}`,
            priority: '0.8',
            changefreq: 'weekly',
            lastmod: (festival.updated_at || '').slice(0, 10) || null,
          });
        }
      }
    }
  } catch {
    // Fall through — the static pages are still listed.
  }

  const xml =
    '<?xml version="1.0" encoding="UTF-8"?>\n' +
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' +
    entries
      .map(
        (entry) =>
          '  <url>\n' +
          `    <loc>${escapeXml(entry.loc)}</loc>\n` +
          (entry.lastmod ? `    <lastmod>${entry.lastmod}</lastmod>\n` : '') +
          `    <changefreq>${entry.changefreq}</changefreq>\n` +
          `    <priority>${entry.priority}</priority>\n` +
          '  </url>',
      )
      .join('\n') +
    '\n</urlset>\n';

  return new Response(xml, {
    headers: {
      'content-type': 'application/xml; charset=utf-8',
      'cache-control': 'public, max-age=0, s-maxage=3600',
    },
  });
}

function escapeXml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}
