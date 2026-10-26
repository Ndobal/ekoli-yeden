import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync, readdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { updateSettings } from '../src/controllers/settings.controller';
import { createSource, attachSource, listSources } from '../src/controllers/cms.controller';
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
