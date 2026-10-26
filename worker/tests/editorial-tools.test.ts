import { setPlaceCoordinates, editorialMapPlaces, mapPlaces } from '../src/controllers/discover.controller';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync, readdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { updateSettings } from '../src/controllers/settings.controller';
import { createSource, attachSource, listSources, updateHeroSlide, updateNavigationItem, layoutDraftAction, editorialHero, heroCarousel, editorialNavigation, bundle, listVersions, showVersion } from '../src/controllers/cms.controller';
import { adminCreate, adminUpdate, adminChangeStatus } from '../src/controllers/content.controller';
import { replaceQuestions, editorialQuestions, showQuiz } from '../src/controllers/learning.controller';
import { CONTENT_RESOURCES } from '../src/services/content-registry';
import { searchArchive } from '../src/services/search.service';
import { encodeSettingValue } from '../src/services/setting-value';
import type { RequestContext } from '../src/types/api';

// Real SQLite, with every migration applied. The adapter implements the D1
// statements used by these handlers and rolls back a failed batch as D1 does.
class Statement {
  values: any[] = [];
  constructor(readonly db: DatabaseSync, readonly sql: string) {}
  bind(...values: any[]) { this.values = values; return this; }
  execute() {
    const query = this.db.prepare(this.sql);
    if (/^\s*SELECT/i.test(this.sql)) return { results: query.all(...this.values), meta: {} };
    const result = query.run(...this.values);
    return { results: [], meta: { changes: Number(result.changes) } };
  }
  async all() { return this.execute(); }
  async run() { return this.execute(); }
  async first() { return this.execute().results[0] ?? null; }
}
let sqlite: DatabaseSync;
let db: D1Database;
const resource = (key: string) => CONTENT_RESOURCES[key]!;
const actor = { id: 'editor', displayName: 'Editor', email: 'editor@example.test', status: 'active', permissions: new Set(['*']) };
function context(body: unknown = {}, params: Record<string, string> = {}, query = ''): RequestContext {
  return {
    env: { DB: db, PUBLIC_MEDIA_BASE_URL: 'https://example.test/media' },
    user: actor, params, query: new URLSearchParams(query), requestId: 'test',
    request: new Request('https://example.test/api', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) }),
  } as unknown as RequestContext;
}
async function data(response: Response) { return (await response.json() as any).data; }
async function create(key: string, body: unknown) { return data(await adminCreate(resource(key))(context(body))); }
const questions = [
  { prompt: 'First question', explanation: 'Why', options: [{ label: 'One', is_correct: true }, { label: 'Two', is_correct: false }] },
  { prompt: 'Second question', options: [{ label: 'Three', is_correct: false }, { label: 'Four', is_correct: true }] },
];
beforeEach(() => {
  sqlite = new DatabaseSync(':memory:');
  const migrations = resolve(import.meta.dirname, '../../database/migrations');
  for (const path of readdirSync(migrations).sort()) sqlite.exec(readFileSync(resolve(migrations, path), 'utf8'));
  sqlite.exec(`INSERT INTO users (id,email,display_name,created_at,updated_at) VALUES ('editor','editor@example.test','Editor','2026-01-01','2026-01-01')`);
  db = {
    prepare: (sql: string) => new Statement(sqlite, sql),
    batch: async (statements: Statement[]) => {
      sqlite.exec('BEGIN');
      try { const result = statements.map(s => s.execute()); sqlite.exec('COMMIT'); return result; }
      catch (error) { sqlite.exec('ROLLBACK'); throw error; }
    },
  } as unknown as D1Database;
});
afterEach(() => sqlite.close());

describe('typed settings', () => {
  it('persists switches, numbers, cleared text and an audit record', async () => {
    const result = await data(await updateSettings(context({ feature_hall_of_fame: true, current_festival_year: '2027', contact_phone: null })));
    expect(result.values.feature_hall_of_fame).toBe(true);
    expect(result.values.current_festival_year).toBe(2027);
    expect(result.values.contact_phone).toBeNull();
    expect(sqlite.prepare("SELECT COUNT(*) n FROM audit_logs WHERE action = 'settings.updated'").get()?.n).toBe(1);
  });
  it('rejects an invalid value before changing any settings', async () => {
    await expect(updateSettings(context({ site_name: 'Changed', feature_hall_of_fame: 'perhaps' }))).rejects.toMatchObject({ status: 422 });
    expect(sqlite.prepare("SELECT value FROM site_settings WHERE key = 'site_name'").get()?.value).not.toBe('Changed');
  });
  it('validates JSON rather than double-encoding it', () => {
    expect(encodeSettingValue('test', 'json', '{"a":1}')).toBe('{"a":1}');
    expect(() => encodeSettingValue('test', 'json', '{')).toThrow();
    expect(() => encodeSettingValue('test', 'number', 'Infinity')).toThrow();
  });
});

describe('sources', () => {
  it('creates and attaches a source to an existing archive record', async () => {
    const history = await create('history', { title: 'Historical record' });
    const source = await data(await createSource(context({ title: 'Interview', source_type: 'oral_interview', reliability: 'primary' })));
    await attachSource(context({ source_id: source.id, resource_type: 'history', resource_id: history.id, supports: 'The date', page_reference: '3' }));
    const citation = sqlite.prepare('SELECT * FROM content_sources WHERE resource_id = ?').get(history.id);
    expect(citation?.resource_id).toBe(history.id);
    expect(citation?.supports).toBe('The date');
  });
  it('refuses nonexistent records and invalid resource types', async () => {
    await expect(attachSource(context({ source_id: 'missing', resource_type: 'history', resource_id: 'missing' }))).rejects.toMatchObject({ status: 404 });
    await expect(attachSource(context({ source_id: 'missing', resource_type: 'users', resource_id: 'editor' }))).rejects.toMatchObject({ status: 400 });
  });
  it('paginates the source library', async () => {
    for (const title of ['A source', 'B source', 'C source']) await createSource(context({ title }));
    const first = await data(await listSources(context({}, {}, 'perPage=1&page=1&q=source')));
    const second = await data(await listSources(context({}, {}, 'perPage=1&page=2&q=source')));
    expect(first.sources).toHaveLength(1);
    expect(second.sources).toHaveLength(1);
    expect(first.sources[0].id).not.toBe(second.sources[0].id);
    expect(second.total).toBe(3);
  });
});

describe('quizzes', () => {
  it('creates a draft, saves ordered questions, publishes and serves them', async () => {
    const quiz = await create('quizzes', { title: 'Practice', subject: 'general', level: 'starter' });
    await replaceQuestions(context({ questions }, { id: quiz.id }));
    const editorial = await data(await editorialQuestions(context({}, { id: quiz.id })));
    expect(editorial.items.map((q: any) => q.prompt)).toEqual(['First question', 'Second question']);
    await adminChangeStatus(resource('quizzes'))(context({ status: 'published' }, { id: quiz.id }));
    const published = await data(await showQuiz(context({}, { identifier: quiz.id })));
    expect(published.questions[0].options.map((o: any) => o.is_correct)).toEqual([true, false]);
  });
  it('refuses an empty quiz at publication', async () => {
    const quiz = await create('quizzes', { title: 'Empty quiz' });
    await expect(adminChangeStatus(resource('quizzes'))(context({ status: 'published' }, { id: quiz.id }))).rejects.toMatchObject({ status: 422 });
  });
  it.each([[], [null], [{ prompt: 'Bad', options: [null, null] }], [{ prompt: 'Bad', options: [{ label: 'A', is_correct: true }, { label: 'B', is_correct: true }] }]].map(questions => ({ questions })))('rejects invalid questions and preserves the saved set: %j', async ({ questions: invalid }) => {
    const quiz = await create('quizzes', { title: 'Practice' });
    await replaceQuestions(context({ questions }, { id: quiz.id }));
    await expect(replaceQuestions(context({ questions: invalid }, { id: quiz.id }))).rejects.toMatchObject({ status: 422 });
    expect(sqlite.prepare('SELECT COUNT(*) n FROM quiz_questions WHERE quiz_id = ?').get(quiz.id)?.n).toBe(2);
  });
});

describe('oral history and publication rules', () => {
  it('normalises the video, requires consent, then publishes', async () => {
    const interview = await create('recordings', { title: 'An interview', youtube_video_id: 'https://youtu.be/abcdefghijk', transcript: 'Recorded words', english_interpretation: 'Interpretation' });
    expect(interview.youtube_video_id).toBe('abcdefghijk');
    await expect(adminChangeStatus(resource('recordings'))(context({ status: 'published' }, { id: interview.id }))).rejects.toMatchObject({ status: 422 });
    await adminUpdate(resource('recordings'))(context({ consent_reference: 'Speaker agreed on record' }, { id: interview.id }));
    await adminChangeStatus(resource('recordings'))(context({ status: 'published' }, { id: interview.id }));
    expect(sqlite.prepare('SELECT status FROM recordings WHERE id = ?').get(interview.id)?.status).toBe('published');
    await expect(adminUpdate(resource('recordings'))(context({ consent_reference: null }, { id: interview.id }))).rejects.toMatchObject({ status: 422 });
  });
  it('rejects recordings without media and disallows publication through a draft write', async () => {
    await expect(create('recordings', { title: 'No media' })).rejects.toMatchObject({ status: 422 });
    await expect(create('recordings', { title: 'Bypass', youtube_video_id: 'abcdefghijk', status: 'published' })).rejects.toMatchObject({ status: 422 });
    const quiz = await create('quizzes', { title: 'Draft' });
    await expect(adminUpdate(resource('quizzes'))(context({ status: 'published' }, { id: quiz.id }))).rejects.toMatchObject({ status: 422 });
  });
});

it('keeps stories out of culture search results', async () => {
  await create('stories', { title: 'Distinctive story' });
  sqlite.exec("UPDATE content_items SET status = 'published' WHERE content_type = 'story'");
  const result = await searchArchive(db, 'Distinctive', { resources: ['culture', 'stories'] });
  expect(result.groups.map(g => g.resource)).toEqual(['stories']);
});

it('preserves direct festival publication for authorised publishers', async () => {
  const festival = await create('festivals', { name: 'A festival', status: 'published' });
  expect(festival.status).toBe('published');
});

it('refuses inline publication by an editor without publishing authority', async () => {
  const request = context({ title: 'Draft', status: 'published' });
  request.user = { ...actor, permissions: new Set(['history:create', 'content.edit']) } as any;
  await expect(adminCreate(resource('history'))(request)).rejects.toMatchObject({ status: 403 });
});

const heroId = '1';
async function heroDraft(values: Record<string, unknown> = {}, revision = 0) {
  return data(await updateHeroSlide(context({ title: 'Proposed heading', status: 'published', ...values, expected_revision: revision }, { slide: heroId })));
}
async function layoutAction(kind: string, id: string, action: string, revision: number) {
  return layoutDraftAction(context({ expected_revision: revision }, { kind, id, action }));
}

describe('carousel drafts', () => {
  it('keeps changes out of public responses until reviewed and published', async () => {
    const old = sqlite.prepare('SELECT title FROM hero_slides WHERE slide_number = 1').get()?.title;
    await heroDraft();
    const publicData = await data(await heroCarousel(context()));
    expect(publicData.slides.find((s: any) => s.slideNumber === 1).title).toBe(old);
    const editorial = await data(await editorialHero(context()));
    expect(editorial.slides[0].draft.values.title).toBe('Proposed heading');
    expect(editorial.slides[0].draft.state).toBe('draft');
    await layoutAction('hero', heroId, 'submit', 1);
    await layoutAction('hero', heroId, 'approve', 2);
    await layoutAction('hero', heroId, 'publish', 3);
    expect(sqlite.prepare('SELECT title FROM hero_slides WHERE slide_number = 1').get()?.title).toBe('Proposed heading');
    const history = await data(await listVersions(context({}, { resourceType: 'hero_slide', resourceId: heroId })));
    expect(history.versions).toHaveLength(1);
    const snapshot = await data(await showVersion(context({}, { resourceType: 'hero_slide', resourceId: heroId, version: '1' })));
    expect(snapshot.snapshot.title).toBe(old);
    expect(snapshot.changedFields.title.to).toBe('Proposed heading');
  });
  it('rejects stale saves and requires a revision number', async () => {
    await heroDraft();
    await expect(heroDraft({ title: 'Lost change' }, 0)).rejects.toMatchObject({ status: 409 });
    await expect(updateHeroSlide(context({ title: 'No revision' }, { slide: heroId }))).rejects.toMatchObject({ status: 422 });
  });
  it('requires approval again after an approved draft is edited', async () => {
    await heroDraft();
    await layoutAction('hero', heroId, 'submit', 1);
    await layoutAction('hero', heroId, 'approve', 2);
    await heroDraft({ title: 'Changed after approval' }, 3);
    await expect(layoutAction('hero', heroId, 'publish', 4)).rejects.toMatchObject({ status: 409 });
  });
  it('does not grant publication or review authority to a homepage editor', async () => {
    await heroDraft();
    const request = context({ expected_revision: 1 }, { kind: 'hero', id: heroId, action: 'publish' });
    request.user = { ...actor, permissions: new Set(['homepage.edit']) } as any;
    await expect(layoutDraftAction(request)).rejects.toMatchObject({ status: 403 });
    const review = context({ expected_revision: 1 }, { kind: 'hero', id: heroId, action: 'approve' });
    review.user = request.user;
    await expect(layoutDraftAction(review)).rejects.toMatchObject({ status: 403 });
  });
  it('discards only the draft and keeps the live carousel', async () => {
    const old = sqlite.prepare('SELECT title FROM hero_slides WHERE slide_number = 1').get()?.title;
    await heroDraft();
    await layoutAction('hero', heroId, 'discard', 1);
    expect(sqlite.prepare('SELECT title FROM hero_slides WHERE slide_number = 1').get()?.title).toBe(old);
    await expect(heroDraft({}, 0)).rejects.toMatchObject({ status: 409 });
    await heroDraft({}, 2);
  });
  it('rejects incomplete buttons and nonexistent image attachments', async () => {
    await expect(heroDraft({ primary_button_label: 'Open', primary_button_path: '' })).rejects.toMatchObject({ status: 422 });
    await expect(heroDraft({ image_media_id: 'missing', image_alt_text: 'Description' })).rejects.toMatchObject({ status: 422 });
  });
  it('hides a slide only after its visibility change is published', async () => {
    await heroDraft({ status: 'archived' });
    expect((await data(await heroCarousel(context()))).slides.some((s: any) => s.slideNumber === 1)).toBe(true);
    await layoutAction('hero', heroId, 'submit', 1);
    await layoutAction('hero', heroId, 'approve', 2);
    await layoutAction('hero', heroId, 'publish', 3);
    expect((await data(await heroCarousel(context()))).slides.some((s: any) => s.slideNumber === 1)).toBe(false);
  });
});

describe('navigation drafts', () => {
  it('stages labels, destinations, emphasis, order and visibility', async () => {
    const row = sqlite.prepare("SELECT * FROM navigation_items WHERE menu = 'primary' LIMIT 1").get()!;
    await updateNavigationItem(context({ label: 'Changed menu', path: '/history', sort_order: 7, is_cta: true, status: 'published', expected_revision: 0 }, { id: String(row.id) }));
    expect(sqlite.prepare('SELECT label FROM navigation_items WHERE id = ?').get(row.id!)?.label).toBe(row.label);
    const staged = await data(await editorialNavigation(context()));
    expect(staged.items.find((n: any) => n.id === row.id).draft.values.path).toBe('/history');
    await layoutAction('navigation', String(row.id), 'submit', 1);
    await layoutAction('navigation', String(row.id), 'approve', 2);
    await layoutAction('navigation', String(row.id), 'publish', 3);
    const publicNav = await data(await bundle(context()));
    const updated = publicNav.navigation.primary.find((n: any) => n.id === row.id);
    expect(updated).toMatchObject({ label: 'Changed menu', path: '/history', isCta: true });
    expect(sqlite.prepare('SELECT sort_order FROM navigation_items WHERE id = ?').get(row.id!)?.sort_order).toBe(7);
  });
  it.each(['//outside.test', 'javascript:alert(1)', '/\\outside.test', '/invalid path'])('rejects unsafe destination %s', async path => {
    const row = sqlite.prepare('SELECT id FROM navigation_items LIMIT 1').get()!;
    await expect(updateNavigationItem(context({ path, expected_revision: 0 }, { id: String(row.id) }))).rejects.toMatchObject({ status: 422 });
  });
  it('restricts menu editing to the right permission', async () => {
    const row = sqlite.prepare('SELECT id FROM navigation_items LIMIT 1').get()!;
    const request = context({ path: '/history', expected_revision: 0 }, { id: String(row.id) });
    request.user = { ...actor, permissions: new Set(['homepage.edit']) } as any;
    await expect(updateNavigationItem(request)).rejects.toMatchObject({ status: 403 });
  });
});

describe('map editor', () => {
  it('saves and clears coordinates, preserving snapshots', async () => {
    const place = sqlite.prepare('SELECT id FROM places LIMIT 1').get()!;
    await setPlaceCoordinates(context({ latitude: 5.5, longitude: 8.3 }, { id: String(place.id) }));
    expect(sqlite.prepare('SELECT latitude FROM places WHERE id = ?').get(place.id!)?.latitude).toBe(5.5);
    await setPlaceCoordinates(context({ latitude: null, longitude: null, previous_latitude: 5.5, previous_longitude: 8.3 }, { id: String(place.id) }));
    expect(sqlite.prepare('SELECT latitude FROM places WHERE id = ?').get(place.id!)?.latitude).toBeNull();
    const versions = await data(await listVersions(context({}, { resourceType: 'places', resourceId: String(place.id) })));
    expect(versions.versions).toHaveLength(2);
    const previous = await data(await showVersion(context({}, { resourceType: 'places', resourceId: String(place.id), version: '2' })));
    expect(previous.snapshot.latitude).toBe(5.5);
  });
  it('rejects invalid, incomplete and stale coordinates', async () => {
    const place = sqlite.prepare('SELECT id FROM places LIMIT 1').get()!;
    await expect(setPlaceCoordinates(context({ latitude: 91, longitude: 1 }, { id: String(place.id) }))).rejects.toMatchObject({ status: 422 });
    await expect(setPlaceCoordinates(context({ latitude: 5 }, { id: String(place.id) }))).rejects.toMatchObject({ status: 422 });
    await setPlaceCoordinates(context({ latitude: 5, longitude: 8 }, { id: String(place.id) }));
    await expect(setPlaceCoordinates(context({ latitude: 6, longitude: 8, previous_latitude: null, previous_longitude: null }, { id: String(place.id) }))).rejects.toMatchObject({ status: 409 });
  });
  it('includes unpublished places only in the protected editorial map', async () => {
    const place = sqlite.prepare('SELECT id FROM places LIMIT 1').get()!;
    sqlite.prepare("UPDATE places SET status = 'draft' WHERE id = ?").run(place.id!);
    const editorial = await data(await editorialMapPlaces(context()));
    const publicMap = await data(await mapPlaces(context()));
    expect(editorial.items.some((p: any) => p.id === place.id)).toBe(true);
    expect(publicMap.items.some((p: any) => p.id === place.id)).toBe(false);
  });
});

describe('project funding', () => {
  it('saves decimal amounts, currency and completion date, and permits clearing amounts', async () => {
    const project = await create('community', { title: 'Project', funding_target: 500000.5, funds_raised: 125000.25, currency: 'NGN', progress_percent: 25, completion_date: '2027-01-01' });
    expect(project.funding_target).toBe(500000.5);
    expect(project.funds_raised).toBe(125000.25);
    const updated = await data(await adminUpdate(resource('community'))(context({ funds_raised: null, currency: 'USD' }, { id: project.id })));
    expect(updated.funds_raised).toBeNull();
    expect(updated.currency).toBe('USD');
  });
  it.each([{ funding_target: -1 }, { funds_raised: '100' }, { currency: 'naira' }, { progress_percent: 101 }, { completion_date: 'not a date' }])('rejects invalid funding values %j', async invalid => {
    await expect(create('community', { title: 'Project', ...invalid })).rejects.toMatchObject({ status: 422 });
  });
});
