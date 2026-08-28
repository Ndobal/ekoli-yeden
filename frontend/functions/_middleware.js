/**
 * PER-PAGE SEO AT THE EDGE
 *
 * The problem this solves: Flutter Web renders into a canvas. Google's crawler
 * will eventually execute the app, but Facebook, WhatsApp, X, LinkedIn and
 * Slack will not — they fetch the HTML, read <head>, and stop. Without this,
 * every page of the archive shares one title and one description, and a link to
 * a history entry previews as though it were the homepage.
 *
 * What happens here: for any HTML request, the title, description, canonical
 * URL and Open Graph tags in index.html are rewritten to match the page that
 * was actually requested. For a content page — a history entry, a person, a
 * festival — the real record is fetched from the API so the preview carries its
 * actual title and summary.
 *
 * This runs on Cloudflare's edge as part of Pages, using HTMLRewriter, which
 * streams. Nothing is buffered and no build step is involved, so the SPA that
 * real visitors receive is untouched.
 */

const SITE = 'https://ekoli.pages.dev';
const API = 'https://ekoli-yeden-api.ndovera.workers.dev';
const DEFAULT_IMAGE = `${SITE}/social-card.png`;

const SITE_NAME = 'Ekoli Yeden Digital Home';
const TAGLINE = 'Preserving Our Past. Celebrating Our Present. Building Our Future.';

/**
 * Static metadata for the section pages.
 *
 * These are the descriptions a search result or a shared link shows, so they
 * are written to read as sentences rather than keyword lists.
 */
const PAGES = {
  '/': {
    title: `${SITE_NAME} — ${TAGLINE}`,
    description:
      'The permanent digital home and heritage archive of Ekoli-Yeden: its history, culture, ' +
      'language, leadership, people, festivals and community life — preserved, verified and open to all.',
  },
  '/about': {
    title: 'About Ekoli-Yeden',
    description:
      'Why this archive exists, how material reaches it, and the promise it makes: nothing is ' +
      'invented, and every claim names its source.',
  },
  '/history': {
    title: 'Our History',
    description:
      'The recorded history of Ekoli-Yeden — its origins, migrations and institutions. Each entry ' +
      'names where it came from and shows whether it has been verified.',
  },
  '/culture': {
    title: 'Culture & Heritage',
    description:
      'Traditions, festivals, wrestling, dances, food, dress, farming, proverbs and folklore of ' +
      'Ekoli-Yeden, documented and verified by the Preservation Team.',
  },
  '/language': {
    title: 'The Lokaa Dictionary',
    description:
      'Words of Ekoli-Yeden with their meanings, variant forms, example sentences and ' +
      'pronunciation, recorded by native speakers. Published sources identify Lokaa as the ' +
      'language of the Yakurr communities.',
  },
  '/language/contribute': {
    title: 'Contribute a word',
    description:
      'Add a word to the Ekoli-Yeden dictionary: what it means, how it is said, and a sentence ' +
      'using it. A language editor checks every entry before it is published.',
  },
  '/festivals': {
    title: 'Festivals',
    description:
      'The festivals of Ekoli-Yeden, including the Lekoli Boku New Yam Festival — Celebrating Our ' +
      'Heritage, Yam and Unity. Programmes, events, photographs and videos, preserved year by year.',
  },
  '/leaders': {
    title: 'Traditional Leadership',
    description:
      'The traditional institution and community leadership of Ekoli-Yeden, past and present, ' +
      'maintained with the traditional institution and verified before publication.',
  },
  '/people': {
    title: 'People of Ekoli-Yeden',
    description:
      'Scholars, professionals, farmers, artists, entrepreneurs and community builders from ' +
      'Ekoli-Yeden and its diaspora.',
  },
  '/age-grades': {
    title: 'Age Grades',
    description:
      'The age grades of Ekoli-Yeden — groupings of people of a similar age who take on ' +
      'responsibilities together, and one of the structures by which the community organises itself.',
  },
  '/cultural-groups': {
    title: 'Cultural Groups',
    description:
      'The cultural groups of Ekoli-Yeden, among them Obam and Igban — each with its own practice, ' +
      'occasions and membership.',
  },
  '/music': {
    title: 'Cultural Music',
    description:
      'The musical forms of Ekoli-Yeden, among them Onene. Recordings by the people who play them ' +
      'are what preserve a musical tradition.',
  },
  '/news': {
    title: 'News & Announcements',
    description:
      'Community news, announcements, appointments and achievements from Ekoli-Yeden — recorded ' +
      'permanently rather than lost to a social media feed.',
  },
  '/events': {
    title: 'Events',
    description: 'Community meetings, ceremonies, cultural activities and gatherings in Ekoli-Yeden.',
  },
  '/gallery/photographs': {
    title: 'Every photograph',
    description:
      'Every photograph in the Ekoli Yeden archive, from every album and every festival year, ' +
      'newest first.',
  },
  '/age-grades/register': {
    title: 'Register your age grade',
    description:
      'Register an age grade of Ekoli-Yeden and keep its page yourself — its members, its ' +
      'photographs and its news.',
  },
  '/gallery': {
    title: 'Photo Gallery',
    description:
      'Photographs of Ekoli-Yeden — its people, leadership, ceremonies and everyday life — labelled ' +
      'with what they show so they remain understandable for generations.',
  },
  '/videos': {
    title: 'Video Archive',
    description:
      'Documentaries, interviews, oral history, festival performances and music from Ekoli-Yeden, ' +
      'organised by subject with transcripts where they exist.',
  },
  '/community': {
    title: 'Community Projects',
    description:
      'Development projects in Ekoli-Yeden: what is planned, what is underway, and how each is progressing.',
  },
  '/businesses': {
    title: 'Businesses & Professionals',
    description:
      'Businesses, trades and professional services run by people of Ekoli-Yeden, at home and abroad.',
  },
  '/organizations': {
    title: 'Organizations',
    description:
      'Unions, associations, societies, schools, churches and other bodies serving the Ekoli-Yeden community.',
  },
  '/contribute': {
    title: 'Contribute to Ekoli-Yeden',
    description:
      'Share old photographs, documents, stories, oral history and language recordings with the ' +
      'archive. Every contribution is reviewed before publication, and every contributor is credited.',
  },
  '/ancestry': {
    title: 'Ancestry Records',
    description:
      'The people Ekoli-Yeden came from. Nobody is removed from this archive when they die — ' +
      'their account is stilled, what they made public stays public, and they are remembered here.',
  },
  '/places': {
    title: 'The Places of Ekori',
    description:
      'Ajere, Ntan, Epenti and Afrekpe, the quarters inside them and the compounds inside ' +
      'those — how Ekori fits together, and who is from each part of it.',
  },
  '/community/forums': {
    title: 'Community Forums',
    description:
      'Where the community talks to itself: questions, answers and announcements, kept where ' +
      'the next person can find them instead of scrolling away in a group chat.',
  },
  '/news/submit': {
    title: 'Send in news',
    description:
      'Tell the community what has happened. Anybody may write it; an administrator reads ' +
      'everything that arrives and decides what is published.',
  },
  '/terms': {
    title: 'Terms of Use',
    description:
      'What this archive is, what you can expect of it, and what it asks of you. Plain terms ' +
      'for a community heritage archive — no advertising, nothing for sale.',
  },
  '/privacy': {
    title: 'Privacy Policy',
    description:
      'What this archive collects, what it does with it, and what you can ask for. No ' +
      'advertising, no trackers, and nothing about you is ever sold.',
  },
  '/cookies': {
    title: 'Cookies',
    description:
      'What this site stores on your device: a sign-in session, and nothing else. No ' +
      'advertising or analytics cookies, which is why there is no banner.',
  },
  '/preservation-team': {
    title: 'The Ekoli-Yeden Preservation Team',
    description:
      'The volunteer organisation that collects, verifies and preserves the material in this archive.',
  },
  '/contact': {
    title: 'Contact',
    description: 'How to reach the people who maintain the Ekoli Yeden Digital Home.',
  },
  '/search': {
    title: 'Search the Archive',
    description:
      'Search the history, people, language, photographs and videos of Ekoli-Yeden in one place.',
  },
};

/**
 * Detail routes, mapped to the API resource that backs them.
 *
 * `/history/some-entry` becomes a lookup against `/api/history/some-entry`, so
 * the shared link carries the entry's own title rather than the section's.
 */
const DETAIL_ROUTES = {
  history: { resource: 'history', section: 'History' },
  culture: { resource: 'culture', section: 'Culture' },
  leaders: { resource: 'leaders', section: 'Leadership' },
  people: { resource: 'people', section: 'People' },
  news: { resource: 'news', section: 'News' },
  events: { resource: 'events', section: 'Events' },
  gallery: { resource: 'galleries', section: 'Gallery' },
  videos: { resource: 'videos', section: 'Videos' },
  businesses: { resource: 'businesses', section: 'Businesses' },
  organizations: { resource: 'organizations', section: 'Organizations' },
  community: { resource: 'community', section: 'Community Projects' },
  'age-grades': { resource: 'age-grades', section: 'Age Grades' },
  'cultural-groups': { resource: 'cultural-groups', section: 'Cultural Groups' },
  music: { resource: 'music', section: 'Cultural Music' },
  language: { resource: 'language', section: 'Language' },
  ancestry: { resource: 'ancestry', section: 'Ancestry Records' },
  places: { resource: 'places', section: 'The Places of Ekori' },
};

/**
 * Paths that must never be indexed.
 *
 * `/my/` covers the workspace screens that belong to one person rather than to
 * the archive — the age grades somebody administers. They are behind a
 * permission on the server either way; this is so they never turn up in a
 * search result that then asks the reader to sign in.
 */
const PRIVATE_PREFIXES = [
  '/admin',
  '/editorial',
  '/sign-in',
  '/register',
  '/my/',
  '/account',
  // The member directory is the community's list of itself, not a public
  // register. The API refuses it without a session; this keeps a crawler from
  // holding on to a page of real people's names and professions regardless.
  '/directory',
  // Signed-in and matched to the reader. There is nothing to index and nothing
  // useful to show somebody the archive knows nothing about.
  '/opportunities',
  // Private conversations between two people. Never indexed, never previewed,
  // and never fetched for metadata.
  '/messages',
];

export async function onRequest(context) {
  const { request, next } = context;
  const url = new URL(request.url);

  const response = await next();

  // Only HTML documents carry metadata; assets and JSON pass straight through.
  const contentType = response.headers.get('content-type') || '';
  if (!contentType.includes('text/html')) return response;

  const meta = await resolveMetadata(url);

  const rewritten = new HTMLRewriter()
    .on('title#page-title', new TextSetter(meta.title))
    .on('meta#page-description', new AttributeSetter('content', meta.description))
    .on('link#page-canonical', new AttributeSetter('href', meta.canonical))
    .on('meta#og-type', new AttributeSetter('content', meta.type))
    .on('meta#og-title', new AttributeSetter('content', meta.title))
    .on('meta#og-description', new AttributeSetter('content', meta.description))
    .on('meta#og-url', new AttributeSetter('content', meta.canonical))
    .on('meta#og-image', new AttributeSetter('content', meta.image))
    .on('meta#twitter-title', new AttributeSetter('content', meta.title))
    .on('meta#twitter-description', new AttributeSetter('content', meta.description))
    .on('meta#twitter-image', new AttributeSetter('content', meta.image))
    // The no-JavaScript summary is replaced with this page's own content, so a
    // crawler that never executes Flutter still reads something meaningful.
    .on('div#seo-content', new ContentSetter(meta.body))
    .transform(response);

  const headers = new Headers(rewritten.headers);
  if (meta.noIndex || PRIVATE_PREFIXES.some((prefix) => url.pathname.startsWith(prefix))) {
    headers.set('x-robots-tag', 'noindex, nofollow');
  }
  // A short edge cache keeps the API lookup off the critical path for repeat
  // crawls without letting an edited title go stale for long.
  headers.set('cache-control', 'public, max-age=0, s-maxage=300');

  return new Response(rewritten.body, {
    status: rewritten.status,
    statusText: rewritten.statusText,
    headers,
  });
}

async function resolveMetadata(url) {
  const path = url.pathname.replace(/\/+$/, '') || '/';
  const canonical = `${SITE}${path === '/' ? '/' : path}`;

  if (PRIVATE_PREFIXES.some((prefix) => path.startsWith(prefix))) {
    return {
      title: `${SITE_NAME}`,
      description: TAGLINE,
      canonical,
      image: DEFAULT_IMAGE,
      type: 'website',
      body: `<h1>${escapeHtml(SITE_NAME)}</h1>`,
    };
  }

  const segments = path.split('/').filter(Boolean);

  // An age grade's own workspace belongs to its administrators, not to the
  // archive. Matched here rather than by prefix because the grade's public page
  // sits one segment above it and must stay indexable.
  if (segments[0] === 'age-grades' && segments[2] === 'manage') {
    return {
      title: SITE_NAME,
      description: TAGLINE,
      canonical,
      image: DEFAULT_IMAGE,
      type: 'website',
      body: `<h1>${escapeHtml(SITE_NAME)}</h1>`,
      noIndex: true,
    };
  }

  // A conversation, or the moderators' queue.
  //
  // The forum index and each space are indexable; a topic is not. Two of the
  // three spaces may contain minors, the server refuses their contents to an
  // anonymous caller, and a crawler must not be handed a title from the one
  // space that is public either — a question somebody asked in 2026 should not
  // be the first search result for their name in 2036.
  if (segments[0] === 'community' && segments[1] === 'forums' && segments.length >= 3) {
    return {
      title: `Community Forums | ${SITE_NAME}`,
      description: PAGES['/community/forums'].description,
      canonical,
      image: DEFAULT_IMAGE,
      type: 'website',
      body: `<h1>Community Forums</h1><p>${escapeHtml(PAGES['/community/forums'].description)}</p>`,
      noIndex: true,
    };
  }

  // One area of the cultural archive — /culture/area/food. A shelf rather than
  // an article, so it takes its description from the section list rather than
  // from a record lookup that would find nothing.
  if (segments.length === 3 && segments[0] === 'culture' && segments[1] === 'area') {
    const label = titleCase(segments[2].replace(/-/g, ' '));
    const description =
      `What the Ekoli Yeden archive holds on ${label.toLowerCase()}, and how to add to it. ` +
      'Each area is filled by the Preservation Team as material is collected and verified.';

    return {
      title: `${label} — Culture & Heritage | ${SITE_NAME}`,
      description,
      canonical,
      image: DEFAULT_IMAGE,
      type: 'website',
      body: `<h1>${escapeHtml(label)}</h1><p>${escapeHtml(description)}</p>`,
    };
  }

  // A post by an age grade — /age-grades/<grade>/posts/<post>.
  if (segments.length === 4 && segments[0] === 'age-grades' && segments[2] === 'posts') {
    const post = await fetchJson(`${API}/api/age-grades/${segments[1]}/posts/${segments[3]}`);
    if (post) {
      const description =
        truncate(post.excerpt || post.body || '', 280) ||
        `Posted by ${post.author_name || 'an age grade'} of Ekoli-Yeden.`;

      return {
        title: `${post.title} — ${post.author_name || 'Age Grades'} | ${SITE_NAME}`,
        description,
        canonical,
        image: DEFAULT_IMAGE,
        type: 'article',
        body:
          `<h1>${escapeHtml(post.title)}</h1>` +
          `<p>${escapeHtml(description)}</p>` +
          (post.body ? `<div>${escapeHtml(truncate(post.body, 4000))}</div>` : ''),
      };
    }
  }

  // A detail page: fetch the record so the preview is about the record.
  if (segments.length === 2 && DETAIL_ROUTES[segments[0]]) {
    const record = await fetchRecord(DETAIL_ROUTES[segments[0]].resource, segments[1]);
    if (record) {
      const section = DETAIL_ROUTES[segments[0]].section;
      const title = record.title || record.name || record.full_name || record.word || section;
      const description =
        truncate(
          record.summary || record.excerpt || record.description || record.english_meaning ||
            record.headline || record.biography || record.body || '',
          280,
        ) || `${title} — part of the ${SITE_NAME}.`;

      return {
        title: `${title} — ${section} | ${SITE_NAME}`,
        description,
        canonical,
        image: DEFAULT_IMAGE,
        type: 'article',
        body:
          `<h1>${escapeHtml(title)}</h1>` +
          `<p>${escapeHtml(description)}</p>` +
          (record.body ? `<div>${escapeHtml(truncate(record.body, 4000))}</div>` : ''),
      };
    }
  }

  // A festival page, which has its own shape.
  if (segments[0] === 'festivals' && segments[1]) {
    const festival = await fetchFestival(segments[1]);
    if (festival) {
      const name = festival.full_name || `${festival.name} ${festival.year}`;
      const description =
        festival.tagline || truncate(festival.description || '', 280) ||
        `${name}, a festival of Ekoli-Yeden.`;
      return {
        title: `${name} | ${SITE_NAME}`,
        description,
        canonical,
        image: festival.logo_url || DEFAULT_IMAGE,
        type: 'article',
        body: `<h1>${escapeHtml(name)}</h1><p>${escapeHtml(description)}</p>`,
      };
    }
  }

  const page = PAGES[path];
  if (page) {
    return {
      title: path === '/' ? page.title : `${page.title} | ${SITE_NAME}`,
      description: page.description,
      canonical,
      image: DEFAULT_IMAGE,
      type: 'website',
      body: `<h1>${escapeHtml(page.title)}</h1><p>${escapeHtml(page.description)}</p>`,
    };
  }

  return {
    title: SITE_NAME,
    description: PAGES['/'].description,
    canonical,
    image: DEFAULT_IMAGE,
    type: 'website',
    body: `<h1>${escapeHtml(SITE_NAME)}</h1><p>${escapeHtml(TAGLINE)}</p>`,
  };
}

async function fetchRecord(resource, identifier) {
  try {
    const response = await fetch(`${API}/api/${resource}/${encodeURIComponent(identifier)}`, {
      cf: { cacheTtl: 300, cacheEverything: true },
    });
    if (!response.ok) return null;
    const payload = await response.json();
    return payload.success ? payload.data : null;
  } catch {
    // A metadata lookup must never break the page. The defaults still apply.
    return null;
  }
}

/** A GET returning the API's `data` envelope, or null on any failure. */
async function fetchJson(url) {
  try {
    const response = await fetch(url, { cf: { cacheTtl: 300, cacheEverything: true } });
    if (!response.ok) return null;
    const payload = await response.json();
    return payload.success ? payload.data : null;
  } catch {
    // A metadata lookup must never break the page. The defaults still apply.
    return null;
  }
}

/** "oral history" -> "Oral history". Sentence case, not title case: the areas
 *  are named the way the culture page names them. */
function titleCase(value) {
  const clean = String(value || '').trim();
  return clean.charAt(0).toUpperCase() + clean.slice(1);
}

async function fetchFestival(slug) {
  try {
    const response = await fetch(`${API}/api/festivals/${encodeURIComponent(slug)}`, {
      cf: { cacheTtl: 300, cacheEverything: true },
    });
    if (!response.ok) return null;
    const payload = await response.json();
    return payload.success ? payload.data.festival : null;
  } catch {
    return null;
  }
}

function truncate(value, max) {
  const clean = String(value || '').replace(/\s+/g, ' ').trim();
  if (clean.length <= max) return clean;
  const cut = clean.lastIndexOf(' ', max);
  return `${clean.slice(0, cut > 0 ? cut : max)}…`;
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/** Replaces the text of an element. */
class TextSetter {
  constructor(value) {
    this.value = value;
    this.first = true;
  }
  text(chunk) {
    // The original text arrives in chunks; the first is replaced and the rest
    // removed, otherwise the old title would be appended to the new one.
    chunk.replace(this.first ? this.value : '');
    this.first = false;
  }
}

/** Replaces one attribute of an element. */
class AttributeSetter {
  constructor(name, value) {
    this.name = name;
    this.value = value;
  }
  element(element) {
    element.setAttribute(this.name, this.value);
  }
}

/** Replaces the inner HTML of an element. */
class ContentSetter {
  constructor(html) {
    this.html = html;
  }
  element(element) {
    element.setInnerContent(this.html, { html: true });
  }
}
