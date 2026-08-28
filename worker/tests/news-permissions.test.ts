import { describe, expect, it } from 'vitest';

import { can } from '../src/services/permissions';
import { newsRoutes } from '../src/routes/news.routes';

/**
 * WHO MAY DO WHAT TO THE NEWS.
 *
 * ---------------------------------------------------------------------------
 * WHY THIS FILE EXISTS
 * ---------------------------------------------------------------------------
 *
 * The Editorial Team's four roles were written in an older permission
 * vocabulary — `content.edit`, `content.publish` — and the news module is
 * written in the newer one, `news:update`, `news:publish`. A bridge in
 * `acceptedPermissionsFor` translates between them.
 *
 * That bridge is not total, and the gap it left was invisible: the Publisher
 * held `news:publish` and was refused at a door guarded by `news:update`, so
 * the role named for publishing could not publish, and the check that would
 * have allowed it was never reached. Nothing failed loudly. The button simply
 * returned 403 for the one person meant to press it.
 *
 * So the matrix below is written out in full rather than derived, and the role
 * permissions are copied verbatim from the seeded rows. If somebody edits a
 * role, or re-guards a route, a line here turns red and names the person who
 * just lost — or gained — the ability to publish under the community's name.
 */

// ---------------------------------------------------------------------------
// The roles, exactly as they are seeded in the database.
// ---------------------------------------------------------------------------

const ROLE_PERMISSIONS: Record<string, string[]> = {
  super_admin: ['*'],

  content_administrator: [
    'news:create', 'news:delete', 'news:publish', 'news:read', 'news:update',
    'submissions:read', 'submissions:review', 'media:create', 'media:read',
  ],

  editorial_writer: [
    'content.create', 'content.edit', 'content.read', 'content.submit',
    'media.metadata.edit', 'sources.read',
  ],

  editorial_reviewer: [
    'content.read', 'content.review', 'sources.read',
    'submissions:read', 'submissions:review',
  ],

  editorial_editor: [
    'content.create', 'content.edit', 'content.read', 'content.submit',
    'pages.edit', 'navigation.edit', 'homepage.edit', 'seo.edit',
    'media.metadata.edit', 'sources.manage', 'sources.read',
  ],

  editorial_publisher: [
    'content.read', 'content.publish', 'content.unpublish', 'sources.read',
  ],

  // Every registered person. Holds no content capability at all.
  okoli_member: [
    'members.profile', 'members.directory.read', 'forum.read', 'forum.post',
    'forum.reply', 'forum.react', 'forum.report', 'opportunities.read',
    'opportunities.apply', 'opportunities.save', 'notifications.read',
    'submissions:create', 'messages.send', 'messages.read',
  ],

  public_visitor: [],
};

type Actor = Parameters<typeof can>[0];

function actorFor(slug: string, status = 'active'): Actor {
  return {
    id: `user_${slug}`,
    status,
    permissions: new Set(ROLE_PERMISSIONS[slug]),
  } as unknown as Actor;
}

// ---------------------------------------------------------------------------
// The matrix.
// ---------------------------------------------------------------------------

/** `true` means the role may do it; `false` means it must be refused. */
const MATRIX: Record<string, Record<string, boolean>> = {
  //                       read   update  publish  delete
  super_admin:           { read: true,  update: true,  publish: true,  delete: true },
  content_administrator: { read: true,  update: true,  publish: true,  delete: true },
  editorial_editor:      { read: true,  update: true,  publish: false, delete: false },
  editorial_writer:      { read: true,  update: true,  publish: false, delete: false },
  editorial_reviewer:    { read: true,  update: false, publish: false, delete: false },
  editorial_publisher:   { read: true,  update: false, publish: true,  delete: false },
  okoli_member:          { read: false, update: false, publish: false, delete: false },
  public_visitor:        { read: false, update: false, publish: false, delete: false },
};

describe('news permissions, role by role', () => {
  for (const [slug, expected] of Object.entries(MATRIX)) {
    describe(slug, () => {
      const actor = actorFor(slug);

      for (const [action, allowed] of Object.entries(expected)) {
        it(`${allowed ? 'may' : 'may NOT'} news:${action}`, () => {
          expect(can(actor, `news:${action}` as never)).toBe(allowed);
        });
      }
    });
  }
});

describe('the two roles that the guard used to lock out', () => {
  it('the Reviewer can reach the newsroom, though they may not rewrite a story', () => {
    const reviewer = actorFor('editorial_reviewer');
    expect(can(reviewer, 'news:review' as never)).toBe(true);
    expect(can(reviewer, 'news:update' as never)).toBe(false);
  });

  it('the Publisher can publish, which is the whole point of the role', () => {
    const publisher = actorFor('editorial_publisher');
    expect(can(publisher, 'news:publish' as never)).toBe(true);
  });

  it('neither of them can delete a story', () => {
    expect(can(actorFor('editorial_reviewer'), 'news:delete' as never)).toBe(false);
    expect(can(actorFor('editorial_publisher'), 'news:delete' as never)).toBe(false);
  });
});

describe('a suspended account keeps its roles and loses its authority', () => {
  for (const slug of ['super_admin', 'content_administrator', 'editorial_publisher']) {
    it(`${slug}, once suspended, may not publish`, () => {
      expect(can(actorFor(slug, 'suspended'), 'news:publish' as never)).toBe(false);
    });
  }

  it('an anonymous caller may do nothing', () => {
    expect(can(null, 'news:read' as never)).toBe(false);
    expect(can(null, 'news:publish' as never)).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// The routes themselves.
// ---------------------------------------------------------------------------

describe('the shape of the news routes', () => {
  const publicPaths = newsRoutes
    .filter((route) => (route.middleware ?? []).length === 0)
    .map((route) => `${route.method} ${route.path}`);

  it('only the portal is reachable without a token', () => {
    expect(publicPaths.sort()).toEqual([
      'GET /api/news-portal',
      'GET /api/news-portal/:identifier',
      'GET /api/news-portal/categories',
      'GET /api/news-portal/overview',
      'GET /api/news-portal/tags',
    ]);
  });

  it('every editorial route is guarded', () => {
    const unguarded = newsRoutes
      .filter((route) => route.path.startsWith('/api/editorial/'))
      .filter((route) => (route.middleware ?? []).length === 0);

    expect(unguarded.map((route) => route.path)).toEqual([]);
  });

  /**
   * Runs a route's real middleware chain against a real actor.
   *
   * The matrix above tests `can`, and `can` was never the thing that was
   * broken — the guard chosen in the route table was. So this drives the
   * closures themselves and reports what the caller would actually receive.
   */
  async function callAs(door: string, slug: string): Promise<'ok' | 'refused'> {
    const route = newsRoutes.find((r) => `${r.method} ${r.path}` === door);
    expect(route, `${door} should exist`).toBeDefined();

    const reached = async () => new Response('reached');
    const chain = (route!.middleware ?? []).reduceRight<typeof reached>(
      (next, middleware) => middleware(next) as typeof reached,
      reached,
    );

    try {
      await chain({ user: actorFor(slug) } as never);
      return 'ok';
    } catch {
      return 'refused';
    }
  }

  const DOORS = [
    'GET /api/editorial/news-list',
    'GET /api/editorial/news/:identifier',
    'POST /api/editorial/news/:id/state',
  ];

  for (const door of DOORS) {
    describe(door, () => {
      for (const slug of [
        'super_admin',
        'content_administrator',
        'editorial_editor',
        'editorial_writer',
        'editorial_reviewer',
        'editorial_publisher',
      ]) {
        it(`admits ${slug}`, async () => {
          expect(await callAs(door, slug)).toBe('ok');
        });
      }

      for (const slug of ['okoli_member', 'public_visitor']) {
        it(`refuses ${slug}`, async () => {
          expect(await callAs(door, slug)).toBe('refused');
        });
      }
    });
  }

  it('publishing itself stays behind news:publish, whoever opened the door', () => {
    // `setNewsState` admits the Reviewer, then refuses them the one transition
    // that makes a story public. Both halves matter.
    expect(can(actorFor('editorial_reviewer'), 'news:publish' as never)).toBe(false);
    expect(can(actorFor('editorial_writer'), 'news:publish' as never)).toBe(false);
    expect(can(actorFor('editorial_editor'), 'news:publish' as never)).toBe(false);
    expect(can(actorFor('editorial_publisher'), 'news:publish' as never)).toBe(true);
  });
});
