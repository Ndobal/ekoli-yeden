import type { RequestContext } from '../types/api';
import { requireResource } from '../services/content-registry';
import { ContentService, PUBLIC_STATUSES } from '../services/content.service';
import { listRecords, findRecordBy } from '../repositories/base.repository';
import { CONTENT_STATUS, VERIFICATION_STATUS } from '../types/models';
import { NotFoundError } from '../utils/errors';
import { json, paginated, publicCacheHeaders } from '../utils/responses';
import { parsePagination } from '../utils/pagination';
import { publicMediaUrl } from '../utils/files';

/**
 * THE EKOLI LANGUAGE SYSTEM
 *
 * A word record holds the word, its meaning, a definition, an example, a
 * dialect note, a speaker, a pronunciation recording and a verification status.
 *
 * Every one of those fields is supplied by a native speaker or a language
 * scholar through the admin system. Nothing in this file — or anywhere else in
 * the platform — generates, guesses or completes the meaning of an Ekoli word.
 * An entry with no meaning yet is returned with `english_meaning: null`, and
 * the website shows it as awaiting verification.
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

/**
 * `GET /api/language`
 *
 * Supports `?q=` (Ekoli → English or English → Ekoli, since both columns are
 * searchable), `?category_id=`, `?entry_type=` and `?verification_status=`.
 */
export async function listWords(context: RequestContext): Promise<Response> {
  const service = new ContentService(context.env.DB, LANGUAGE_RESOURCE);
  const query = service.buildQuery(context.query, false);

  const entryType = context.query.get('entry_type');
  if (entryType && (LANGUAGE_ENTRY_TYPES as readonly string[]).includes(entryType)) {
    query.filters['entry_type'] = entryType;
  }
  const verification = context.query.get('verification_status');
  if (verification && Object.values(VERIFICATION_STATUS).includes(verification as never)) {
    query.filters['verification_status'] = verification;
  }

  const { items, total } = await service.list(query);
  const withAudio = await attachAudio(context, items);

  return paginated(withAudio, query.page, query.perPage, total, publicCacheHeaders());
}

/** `GET /api/language/:id` — one entry with all of its recordings. */
export async function showWord(context: RequestContext): Promise<Response> {
  const service = new ContentService(context.env.DB, LANGUAGE_RESOURCE);
  const record = await service.findOne(context.params['identifier'] ?? '', false);
  const [decorated] = await attachAudio(context, [record]);

  return json(decorated ?? record, { headers: publicCacheHeaders() });
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

/**
 * `GET /api/language/categories/:slug` — a category and its published words.
 */
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

  const { items, total } = await listRecords<Record<string, unknown>>(context.env.DB, 'language_words', {
    status: PUBLIC_STATUSES,
    filters: { category_id: String(category['id']) },
    sortColumn: 'word',
    sortDirection: 'ASC',
    limit: 200,
    offset: 0,
  });

  return json(
    { category, words: await attachAudio(context, items), total },
    { headers: publicCacheHeaders() },
  );
}

/**
 * Joins pronunciation recordings onto word records.
 *
 * A word may have several recordings — different speakers, different dialect
 * variations — which is exactly what a language archive needs to capture.
 */
async function attachAudio(
  context: RequestContext,
  words: Record<string, unknown>[],
): Promise<Record<string, unknown>[]> {
  if (words.length === 0) return words;

  const ids = words.map((word) => String(word['id'])).filter((id) => id !== '');
  if (ids.length === 0) return words;

  const placeholders = ids.map(() => '?').join(', ');
  const result = await context.env.DB.prepare(
    `SELECT la."id", la."word_id", la."speaker", la."dialect_or_variation", la."notes",
            ma."storage_key", ma."mime_type"
     FROM "language_audio" la
     INNER JOIN "media_assets" ma ON ma."id" = la."media_asset_id"
     WHERE la."word_id" IN (${placeholders})
       AND la."status" = ?
       AND ma."status" = ?
     ORDER BY la."created_at" ASC`,
  )
    .bind(...ids, CONTENT_STATUS.PUBLISHED, CONTENT_STATUS.PUBLISHED)
    .all<{
      id: string;
      word_id: string;
      speaker: string | null;
      dialect_or_variation: string | null;
      notes: string | null;
      storage_key: string;
      mime_type: string;
    }>();

  const byWord = new Map<string, Record<string, unknown>[]>();
  for (const row of result.results ?? []) {
    const list = byWord.get(row.word_id) ?? [];
    list.push({
      id: row.id,
      speaker: row.speaker,
      dialect_or_variation: row.dialect_or_variation,
      notes: row.notes,
      mime_type: row.mime_type,
      audio_url: publicMediaUrl(context.env.PUBLIC_MEDIA_BASE_URL, row.storage_key),
    });
    byWord.set(row.word_id, list);
  }

  return words.map((word) => ({
    ...word,
    pronunciations: byWord.get(String(word['id'])) ?? [],
  }));
}
