import type { RequestContext } from '../types/api';
import { requireResource } from '../services/content-registry';
import { ContentService, PUBLIC_STATUSES } from '../services/content.service';
import { adminCreate, adminUpdate } from './content.controller';
import { DictionaryService } from '../services/dictionary.service';
import { DictionaryRepository, type DictionaryFilters } from '../repositories/dictionary.repository';
import { listRecords, findRecordBy } from '../repositories/base.repository';
import { ALL_CONTENT_STATUSES, CONTENT_STATUS, VERIFICATION_STATUS } from '../types/models';
import { NotFoundError } from '../utils/errors';
import { readJsonBody } from '../utils/validation';
import { json, paginated, publicCacheHeaders, NO_STORE_HEADERS } from '../utils/responses';
import { parsePagination } from '../utils/pagination';

/**
 * THE DICTIONARY
 *
 * A word record holds the headword, its variant forms, every part of speech it
 * belongs to, each of its senses, example sentences in both languages with
 * their pronunciation, and recordings of the word itself.
 *
 * Every one of those fields is supplied by a native speaker or a language
 * scholar. Nothing in this file — or anywhere else in the platform —
 * generates, guesses or completes the meaning of a word. An entry with no
 * meaning is returned with `english_meaning: null`, and the website shows it as
 * awaiting a speaker rather than filling the space with something plausible.
 */

const LANGUAGE_RESOURCE = requireResource('language');

/** Entry kinds the dictionary distinguishes. */
export const LANGUAGE_ENTRY_TYPES = [
  'word',
  'phrase',
  'greeting',
  'proverb',
  'idiom',
  'number',
  'name',
  'song',
  'riddle',
] as const;

/** Variant kinds, matching the CHECK constraint on `language_variants`. */
export const VARIANT_TYPES = [
  'alternate',
  'spelling',
  'dialect',
  'plural',
  'singular',
  'archaic',
  'diminutive',
  'honorific',
] as const;

/**
 * `GET /api/language`
 *
 * The dictionary, with the filters a dictionary actually needs:
 *
 *   ?q=                 searches headwords, variants, meanings, definitions
 *                       and example sentences, in either language at once
 *   ?letter=A           the A–Z index
 *   ?part_of_speech=    noun, verb, ideophone…
 *   ?entry_type=        word, proverb, greeting…
 *   ?category_id=
 *   ?verification_status=
 *   ?has_audio=true     only entries somebody has recorded
 *   ?has_example=true   only entries with a sentence showing the word in use
 *   ?sort=recent        newest first, instead of alphabetical
 */
export async function listWords(context: RequestContext): Promise<Response> {
  const { page, perPage, offset } = parsePagination(context.query);
  const service = new DictionaryService(context.env);

  const { items, total } = await service.search(
    buildFilters(context, { limit: perPage, offset, statuses: [...PUBLIC_STATUSES] }),
  );

  return paginated(items, page, perPage, total, publicCacheHeaders());
}

/** `GET /api/language/:id` — one entry in full. */
export async function showWord(context: RequestContext): Promise<Response> {
  const contentService = new ContentService(context.env.DB, LANGUAGE_RESOURCE);
  const record = await contentService.findOne(context.params['identifier'] ?? '', false);

  const [decorated] = await new DictionaryService(context.env).attachChildren(
    [record],
    [...PUBLIC_STATUSES],
  );

  return json(decorated ?? record, { headers: publicCacheHeaders() });
}

/**
 * `GET /api/language/index`
 *
 * The A–Z index with a count against each letter, plus the parts of speech and
 * entry types the dictionary can be filtered by, and how complete it is.
 *
 * One request rather than four, because the dictionary page needs all of it
 * before it can draw anything.
 */
export async function dictionaryIndex(context: RequestContext): Promise<Response> {
  const repository = new DictionaryRepository(context.env.DB);

  const [letters, partsOfSpeech, categories, coverage] = await Promise.all([
    repository.letterCounts([...PUBLIC_STATUSES]),
    repository.partsOfSpeech(),
    listRecords<Record<string, unknown>>(context.env.DB, 'language_categories', {
      status: PUBLIC_STATUSES,
      sortColumn: 'sort_order',
      sortDirection: 'ASC',
      limit: 100,
      offset: 0,
    }),
    repository.coverage(),
  ]);

  return json(
    {
      letters,
      partsOfSpeech,
      categories: categories.items,
      entryTypes: LANGUAGE_ENTRY_TYPES,
      variantTypes: VARIANT_TYPES,
      // Stated plainly so the page can say how much of the language is
      // recorded so far. An archive that hides how empty it is cannot ask the
      // community for help filling it.
      coverage,
    },
    { headers: publicCacheHeaders() },
  );
}

/** `GET /api/language/categories` — the categories words are grouped under. */
export async function listCategories(context: RequestContext): Promise<Response> {
  const { page, perPage, offset } = parsePagination(context.query);
  const { items, total } = await listRecords<Record<string, unknown>>(
    context.env.DB,
    'language_categories',
    {
      status: PUBLIC_STATUSES,
      sortColumn: 'sort_order',
      sortDirection: 'ASC',
      limit: perPage,
      offset,
    },
  );
  return paginated(items, page, perPage, total, publicCacheHeaders());
}

/** `GET /api/language/categories/:slug` — a category and its published words. */
export async function showCategory(context: RequestContext): Promise<Response> {
  const slug = context.params['slug'] ?? '';
  const category = await findRecordBy<Record<string, unknown>>(
    context.env.DB,
    'language_categories',
    'slug',
    slug,
    { status: PUBLIC_STATUSES },
  );
  if (!category) throw new NotFoundError('That language category was not found.');

  const service = new DictionaryService(context.env);
  const { items, total } = await service.search({
    search: null,
    letter: null,
    categoryId: String(category['id']),
    entryType: null,
    partOfSpeech: null,
    verificationStatus: null,
    hasAudio: false,
    hasExample: false,
    sort: 'word',
    limit: 200,
    offset: 0,
    statuses: [...PUBLIC_STATUSES],
  });

  return json({ category, words: items, total }, { headers: publicCacheHeaders() });
}

// ---------------------------------------------------------------------------
// Editing an entry
// ---------------------------------------------------------------------------

/**
 * `GET /api/admin/language/:id/entry`
 *
 * The whole entry as an editor needs to see it: drafts included, so somebody
 * working on sense 3 can see sense 3.
 */
export async function adminShowEntry(context: RequestContext): Promise<Response> {
  const contentService = new ContentService(context.env.DB, LANGUAGE_RESOURCE);
  const record = await contentService.findOne(context.params['id'] ?? '', true);

  const [decorated] = await new DictionaryService(context.env).attachChildren(
    [record],
    [...ALL_CONTENT_STATUSES],
  );

  return json(decorated ?? record, { headers: NO_STORE_HEADERS });
}

/**
 * `PUT /api/admin/language/:id/entry`
 *
 * Saves the parts of an entry that are not columns on the word row: its
 * senses, its variants and its example sentences.
 *
 * Each list is replaced wholesale rather than merged. A language editor works
 * on the whole entry at once, and reconciling a partial list against what is
 * stored is how an orphaned sense 3 survives somebody deleting it.
 */
export async function adminSaveEntryParts(context: RequestContext): Promise<Response> {
  const body = await readJsonBody(context.request);
  const wordId = context.params['id'] ?? '';

  const contentService = new ContentService(context.env.DB, LANGUAGE_RESOURCE);
  const word = await contentService.findOne(wordId, true);
  const status = String(word['status'] ?? CONTENT_STATUS.DRAFT);

  const repository = new DictionaryRepository(context.env.DB);
  const service = new DictionaryService(context.env);

  if (Array.isArray(body['senses'])) {
    await repository.replaceSenses(wordId, parseSenses(body['senses']), status);
  }
  if (Array.isArray(body['variants'])) {
    await repository.replaceVariants(wordId, parseVariants(body['variants']), status);
  }
  if (Array.isArray(body['examples'])) {
    await repository.replaceExamples(wordId, parseExamples(body['examples']), status);
  }

  // The searchable form is derived, never sent by the client, so it cannot
  // drift out of step with the headword it belongs to.
  await repository.refreshNormalisedForm(wordId, String(word['word'] ?? ''));

  const [decorated] = await service.attachChildren([word], [...ALL_CONTENT_STATUSES]);
  return json(decorated ?? word, { headers: NO_STORE_HEADERS });
}

/**
 * `GET /api/admin/language/gaps`
 *
 * The entries that are not finished: no meaning, no recording, no example.
 * A working list for the Language Preservation Team rather than a statistic —
 * "these forty words need a speaker" is actionable in a way that "63% complete"
 * is not.
 */
export async function dictionaryGaps(context: RequestContext): Promise<Response> {
  const { page, perPage, offset } = parsePagination(context.query);
  const kind = context.query.get('missing') ?? 'meaning';

  const condition =
    kind === 'audio'
      ? `NOT EXISTS (SELECT 1 FROM "language_audio" a WHERE a."word_id" = w."id")`
      : kind === 'example'
        ? `NOT EXISTS (SELECT 1 FROM "language_examples" e WHERE e."word_id" = w."id")`
        : `(w."english_meaning" IS NULL OR trim(w."english_meaning") = '')`;

  const [countRow, rows] = await context.env.DB.batch<Record<string, unknown>>([
    context.env.DB.prepare(`SELECT COUNT(*) AS total FROM "language_words" w WHERE ${condition}`),
    context.env.DB.prepare(
      `SELECT w."id", w."word", w."english_meaning", w."entry_type", w."status", w."verification_status"
       FROM "language_words" w WHERE ${condition}
       ORDER BY COALESCE(w."word_normalised", lower(w."word")) ASC LIMIT ? OFFSET ?`,
    ).bind(perPage, offset),
  ]);

  return paginated(
    (rows?.results ?? []) as Record<string, unknown>[],
    page,
    perPage,
    Number((countRow?.results?.[0]?.['total'] as number | undefined) ?? 0),
    NO_STORE_HEADERS,
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Reads the dictionary filters off the query string, ignoring anything else. */
function buildFilters(
  context: RequestContext,
  page: { limit: number; offset: number; statuses: string[] },
): DictionaryFilters {
  const query = context.query;

  const entryType = query.get('entry_type');
  const verification = query.get('verification_status');
  const letter = query.get('letter');

  return {
    search: query.get('q') ?? query.get('search'),
    // A single letter or `#`; anything else is discarded rather than passed to
    // the database as a filter nobody meant.
    letter: letter && /^([A-Za-z]|#)$/.test(letter) ? letter : null,
    categoryId: query.get('category_id'),
    entryType:
      entryType && (LANGUAGE_ENTRY_TYPES as readonly string[]).includes(entryType) ? entryType : null,
    partOfSpeech: query.get('part_of_speech'),
    verificationStatus:
      verification && Object.values(VERIFICATION_STATUS).includes(verification as never)
        ? verification
        : null,
    hasAudio: query.get('has_audio') === 'true',
    hasExample: query.get('has_example') === 'true',
    sort: query.get('sort') === 'recent' ? 'recent' : 'word',
    limit: page.limit,
    offset: page.offset,
    statuses: page.statuses,
  };
}

function parseSenses(raw: unknown[]): {
  part_of_speech?: string | null;
  english_meaning?: string | null;
  definition?: string | null;
  usage_note?: string | null;
  register?: string | null;
  domain?: string | null;
}[] {
  return raw.filter(isRecord).map((sense) => ({
    part_of_speech: text(sense['part_of_speech'], 60),
    english_meaning: text(sense['english_meaning'], 500),
    definition: text(sense['definition'], 4000),
    usage_note: text(sense['usage_note'], 1000),
    register: text(sense['register'], 100),
    domain: text(sense['domain'], 100),
  }));
}

function parseVariants(raw: unknown[]): {
  variant: string;
  variant_type?: string | null;
  dialect_or_area?: string | null;
  speaker?: string | null;
  notes?: string | null;
}[] {
  return raw
    .filter(isRecord)
    .map((variant) => ({
      variant: text(variant['variant'], 200) ?? '',
      variant_type: (VARIANT_TYPES as readonly string[]).includes(String(variant['variant_type']))
        ? String(variant['variant_type'])
        : 'alternate',
      dialect_or_area: text(variant['dialect_or_area'], 200),
      speaker: text(variant['speaker'], 200),
      notes: text(variant['notes'], 1000),
    }))
    .filter((variant) => variant.variant !== '');
}

function parseExamples(raw: unknown[]): {
  sentence_ekoli: string;
  sentence_english?: string | null;
  pronunciation?: string | null;
  media_asset_id?: string | null;
  speaker?: string | null;
  context_note?: string | null;
}[] {
  return raw
    .filter(isRecord)
    .map((example) => ({
      sentence_ekoli: text(example['sentence_ekoli'], 1000) ?? '',
      sentence_english: text(example['sentence_english'], 1000),
      pronunciation: text(example['pronunciation'], 1000),
      media_asset_id: text(example['media_asset_id'], 64),
      speaker: text(example['speaker'], 200),
      context_note: text(example['context_note'], 1000),
    }))
    .filter((example) => example.sentence_ekoli !== '');
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

/** Trims, length-caps and normalises empty to null. */
function text(value: unknown, max: number): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed === '' ? null : trimmed.slice(0, max);
}

/**
 * `POST /api/admin/language` and `PUT|PATCH /api/admin/language/:id`
 *
 * Wraps the generated handlers so that the searchable form of the headword is
 * rebuilt whenever the headword changes.
 *
 * `word_normalised` and `initial_letter` are derived, never sent by a client —
 * which is exactly why they are not writable columns, and why this has to
 * happen here rather than in the payload. Getting it wrong would leave a word
 * findable under its old spelling and nowhere else.
 */
export async function adminCreateWord(context: RequestContext): Promise<Response> {
  return withRefreshedSearchForm(context, await adminCreate(LANGUAGE_RESOURCE)(context));
}

export async function adminUpdateWord(context: RequestContext): Promise<Response> {
  return withRefreshedSearchForm(context, await adminUpdate(LANGUAGE_RESOURCE)(context));
}

async function withRefreshedSearchForm(
  context: RequestContext,
  response: Response,
): Promise<Response> {
  if (!response.ok) return response;

  const payload = (await response.clone().json().catch(() => null)) as
    | { data?: Record<string, unknown> }
    | null;
  const word = payload?.data;
  if (!word || typeof word['id'] !== 'string' || typeof word['word'] !== 'string') return response;

  await new DictionaryRepository(context.env.DB).refreshNormalisedForm(word['id'], word['word']);
  return response;
}
