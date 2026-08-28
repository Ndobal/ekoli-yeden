import { describe, expect, it } from 'vitest';

import { can } from '../src/services/permissions';
import { discoverRoutes } from '../src/routes/discover.routes';
import { CONTENT_RESOURCES } from '../src/services/content-registry';
import { publicRoutes } from '../src/routes/public.routes';

/**
 * THE LAST SECTIONS OF THE PROPOSAL.
 *
 * Voices of Ekori, the map, the children's area, the Hall of Fame and the
 * stories. Each of these carries a rule that is easy to undo by accident, so
 * each has a test that fails loudly when somebody does.
 */

type Actor = Parameters<typeof can>[0];

const actor = (permissions: string[], status = 'active'): Actor =>
  ({ id: 'u', status, permissions: new Set(permissions) }) as unknown as Actor;

const anonymous = null;
const member = actor([
  'members.profile', 'forum.read', 'submissions:create', 'messages.send',
]);
const heritageEditor = actor(['content.create', 'content.edit', 'content.read', 'content.submit']);
const superAdmin = actor(['*']);

// ---------------------------------------------------------------------------
// The registry
// ---------------------------------------------------------------------------

describe('the three new content types are registered properly', () => {
  it('stories share content_items and are discriminated, so they cannot see culture', () => {
    const stories = CONTENT_RESOURCES['stories'];
    expect(stories).toBeDefined();
    expect(stories!.table).toBe('content_items');
    expect(stories!.fixedFilters).toEqual({ content_type: 'story' });
  });

  it('a story cannot overwrite a culture article', () => {
    // The discriminator is what keeps two resources in one table apart. If it
    // is ever dropped, `/api/stories/:slug` starts serving culture.
    const stories = CONTENT_RESOURCES['stories'];
    const culture = CONTENT_RESOURCES['culture'];
    expect(stories!.fixedFilters!['content_type'])
      .not.toBe(culture!.fixedFilters!['content_type']);
  });

  it('recordings keep consent and the interpretation as writable fields', () => {
    const recordings = CONTENT_RESOURCES['recordings'];
    expect(recordings).toBeDefined();
    for (const column of [
      'consent_reference',
      'transcript',
      'english_interpretation',
      'interpreted_by',
      'audio_media_id',
      'youtube_video_id',
    ]) {
      expect(recordings!.writableColumns, `recordings must allow ${column}`).toContain(column);
    }
  });

  it('a recording is searchable by what was said, not only by its title', () => {
    // An oral history archive whose search does not reach the transcripts is a
    // list of filenames.
    const recordings = CONTENT_RESOURCES['recordings'];
    expect(recordings!.searchableColumns).toContain('transcript');
    expect(recordings!.searchableColumns).toContain('english_interpretation');
  });

  it('quizzes are registered without a verification workflow', () => {
    // A quiz is not a claim about history; it does not need verifying, it needs
    // publishing. Marking it verifiable would put it in the wrong queue.
    const quizzes = CONTENT_RESOURCES['quizzes'];
    expect(quizzes).toBeDefined();
    expect(quizzes!.hasVerification).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// The routes
// ---------------------------------------------------------------------------

describe('what the world may reach', () => {
  const open = discoverRoutes
    .filter((route) => (route.middleware ?? []).length === 0)
    .map((route) => `${route.method} ${route.path}`)
    .sort();

  it('the map, the Hall of Fame and one quiz are public; nothing else here is', () => {
    expect(open).toEqual([
      'GET /api/hall-of-fame',
      'GET /api/learn/quizzes/:identifier',
      'GET /api/map/places',
    ]);
  });

  it('every editorial route in this file is guarded', () => {
    const unguarded = discoverRoutes
      .filter((route) => route.path.startsWith('/api/editorial/'))
      .filter((route) => (route.middleware ?? []).length === 0);
    expect(unguarded.map((route) => route.path)).toEqual([]);
  });

  it('the new content types got their generated public read routes', () => {
    const paths = publicRoutes.map((route) => `${route.method} ${route.path}`);
    for (const key of ['stories', 'recordings', 'quizzes']) {
      expect(paths, `${key} needs a public list`).toContain(`GET /api/${key}`);
      expect(paths, `${key} needs a public show`).toContain(`GET /api/${key}/:identifier`);
    }
  });
});

describe('the editorial doors of the new sections', () => {
  async function callAs(door: string, who: Actor): Promise<'ok' | 'refused'> {
    const route = discoverRoutes.find((r) => `${r.method} ${r.path}` === door);
    expect(route, `${door} should exist`).toBeDefined();

    const reached = async () => new Response('reached');
    const chain = (route!.middleware ?? []).reduceRight<typeof reached>(
      (next, middleware) => middleware(next) as typeof reached,
      reached,
    );

    try {
      await chain({ user: who } as never);
      return 'ok';
    } catch {
      return 'refused';
    }
  }

  const doors = [
    'POST /api/editorial/places/:id/coordinates',
    'PUT /api/editorial/quizzes/:id/questions',
    'GET /api/editorial/quizzes/:id/questions',
  ];

  for (const door of doors) {
    it(`${door} refuses an anonymous caller`, async () => {
      expect(await callAs(door, anonymous)).toBe('refused');
    });

    it(`${door} refuses an ordinary member`, async () => {
      // Every registered person is a contributor. That does not make them an
      // editor, and moving a place on the map or rewriting a child's quiz are
      // editorial acts.
      expect(await callAs(door, member)).toBe('refused');
    });

    it(`${door} admits an editor`, async () => {
      expect(await callAs(door, heritageEditor)).toBe('ok');
    });

    it(`${door} admits the Super Admin`, async () => {
      expect(await callAs(door, superAdmin)).toBe('ok');
    });
  }
});

// ---------------------------------------------------------------------------
// The two promises that are easiest to break by accident
// ---------------------------------------------------------------------------

describe('the children’s area keeps no record of any child', () => {
  it('there is no route that accepts a quiz answer', () => {
    // The whole privacy promise of §17 is that nothing a child does is stored.
    // Any endpoint that takes an answer, a score or an attempt breaks it, so
    // this test names the shapes such a route would have.
    const suspicious = discoverRoutes.filter((route) => {
      const path = route.path.toLowerCase();
      const writes = route.method !== 'GET';
      return writes && (
        path.includes('answer') ||
        path.includes('score') ||
        path.includes('attempt') ||
        path.includes('result') ||
        /\/learn\//.test(path)
      );
    });

    expect(
      suspicious.map((route) => `${route.method} ${route.path}`),
      'a child’s answers must never be sent anywhere',
    ).toEqual([]);
  });

  it('the only learning route is a read', () => {
    const learn = discoverRoutes.filter((route) => route.path.startsWith('/api/learn'));
    expect(learn).toHaveLength(1);
    expect(learn[0]!.method).toBe('GET');
  });
});

describe('a suspended editor loses the new sections too', () => {
  const suspended = actor(['content.create', 'content.edit', 'content.read'], 'suspended');

  it('cannot update history, and so cannot move a place on the map', () => {
    expect(can(suspended, 'history:update' as never)).toBe(false);
  });

  it('cannot rewrite a quiz', () => {
    expect(can(suspended, 'language:update' as never)).toBe(false);
  });

  it('cannot touch the oral history archive', () => {
    expect(can(suspended, 'recordings:update' as never)).toBe(false);
  });
});
