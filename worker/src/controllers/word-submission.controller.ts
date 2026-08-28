import type { RequestContext } from '../types/api';
import { WordSubmissionService } from '../services/word-submission.service';
import { DictionaryRepository } from '../repositories/dictionary.repository';
import { UnauthorizedError, NotFoundError } from '../utils/errors';
import { hashIp } from '../utils/crypto';
import { readJsonBody, Validator } from '../utils/validation';
import { json, paginated, NO_STORE_HEADERS, publicCacheHeaders } from '../utils/responses';
import { parsePagination } from '../utils/pagination';

/**
 * CONTRIBUTING TO THE DICTIONARY
 *
 * A separate route from `/api/contribute` because a word is a different kind of
 * thing from a photograph. What arrives here is a whole proposed entry —
 * variants, parts of speech, meanings, sentences — in the shape the dictionary
 * stores, so a language editor can accept it in one action.
 */

function clientIp(request: Request): string | null {
  return (
    request.headers.get('cf-connecting-ip') ??
    request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
    null
  );
}

/**
 * `GET /api/contribute/word/form`
 *
 * What the form needs to draw itself: the parts of speech, the entry types,
 * the variant kinds and the categories. Served from the database rather than
 * hard-coded in the client, so the community's language scholars can add a
 * grammatical category without a deployment.
 */
export async function wordFormOptions(context: RequestContext): Promise<Response> {
  const repository = new DictionaryRepository(context.env.DB);
  const [partsOfSpeech, categories] = await Promise.all([
    repository.partsOfSpeech(),
    context.env.DB.prepare(
      `SELECT "id", "name", "slug" FROM "language_categories"
       WHERE "status" = 'published' ORDER BY "sort_order" ASC`,
    ).all<{ id: string; name: string; slug: string }>(),
  ]);

  return json(
    {
      partsOfSpeech,
      categories: categories.results ?? [],
      variantTypes: [
        { value: 'dialect', label: 'How another quarter or family says it' },
        { value: 'spelling', label: 'A different spelling' },
        { value: 'plural', label: 'The plural form' },
        { value: 'singular', label: 'The singular form' },
        { value: 'alternate', label: 'Another form of the same word' },
        { value: 'archaic', label: 'An older form, not much used now' },
        { value: 'diminutive', label: 'The small or affectionate form' },
        { value: 'honorific', label: 'The respectful form' },
      ],
      guidance: [
        'Give the word as you say it, and the meaning in English.',
        'If the word means more than one thing, add a meaning for each.',
        'A sentence using the word is worth more than a definition — it shows how it is really used.',
        'If you can, record yourself saying it. That is the part written words preserve worst.',
        'A language editor checks every entry before it is published. Nothing here is invented.',
      ],
    },
    { headers: publicCacheHeaders(600) },
  );
}

/**
 * `POST /api/contribute/word`
 *
 * Open to anybody, rate limited. Lands at `pending_review`.
 */
export async function submitWord(context: RequestContext): Promise<Response> {
  const body = await readJsonBody(context.request);
  const secret = context.env.JWT_SECRET;

  const service = new WordSubmissionService(context.env);
  const result = await service.submit(body, context.user, {
    requestId: context.requestId,
    ipHash: secret ? await hashIp(clientIp(context.request), secret) : null,
  });

  return json(
    {
      id: result.id,
      referenceCode: result.referenceCode,
      status: 'pending_review',
      // Said plainly rather than treated as an error. A second speaker
      // confirming a meaning — or giving a different one — is worth having.
      alreadyRecorded: result.alreadyRecorded,
      message: result.alreadyRecorded
        ? 'Thank you. This word is already in the dictionary, so what you have sent will be read '
          + 'alongside the existing entry — a second speaker confirming a meaning, or giving '
          + 'another one, is exactly what the dictionary needs.'
        : 'Thank you. A language editor will check this entry before it is published. Keep your '
          + 'reference code if you would like to ask how it is progressing.',
    },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

/** `GET /api/contribute/word/:reference` — progress, by reference code. */
export async function wordSubmissionStatus(context: RequestContext): Promise<Response> {
  const service = new WordSubmissionService(context.env);
  const submission = await service.findByReference(context.params['reference'] ?? '');
  if (!submission) throw new NotFoundError('No contribution was found with that reference code.');

  // Deliberately narrow: the reference code is quotable over the phone, so the
  // response must not carry the contributor's own details back to whoever
  // happens to be holding it.
  return json(
    {
      reference_code: submission.reference_code,
      word: submission.word,
      status: submission.status,
      submitted_at: submission.created_at,
      published: submission.status === 'promoted',
    },
    { headers: NO_STORE_HEADERS },
  );
}

// ---------------------------------------------------------------------------
// The review queue
// ---------------------------------------------------------------------------

/** `GET /api/admin/word-submissions` */
export async function listWordSubmissions(context: RequestContext): Promise<Response> {
  const { page, perPage, offset } = parsePagination(context.query);
  const requested = context.query.get('status');
  const status = ['pending_review', 'approved', 'rejected', 'promoted', 'archived'].includes(
    requested ?? '',
  )
    ? (requested as string)
    : 'pending_review';

  const service = new WordSubmissionService(context.env);
  const dictionary = new DictionaryRepository(context.env.DB);
  const { items, total } = await service.list(status, perPage, offset);

  // Each row carries whether the dictionary already holds this word, so a
  // reviewer merges rather than creating a duplicate they have to find later.
  const decorated = await Promise.all(
    items.map(async (item) => ({
      ...item,
      parts_of_speech: safeParse(item.parts_of_speech),
      variants: safeParse(item.variants),
      senses: safeParse(item.senses),
      examples: safeParse(item.examples),
      existing_entry: await dictionary.findByNormalisedWord(item.word),
    })),
  );

  return paginated(decorated, page, perPage, total, NO_STORE_HEADERS);
}

/**
 * `POST /api/admin/word-submissions/:id/promote`
 *
 * Creates the dictionary entry. It arrives as a draft and unverified —
 * accepting a contribution says "this is worth having", not "this is what the
 * word means".
 */
export async function promoteWordSubmission(context: RequestContext): Promise<Response> {
  const reviewer = context.user;
  if (!reviewer) throw new UnauthorizedError('Please sign in to continue.');

  const body = await readJsonBody(context.request).catch(() => ({}) as Record<string, unknown>);
  const notes = new Validator(body)
    .string('review_notes', { max: 2000, label: 'Review notes' })
    .validated()['review_notes'] as string | null;

  const service = new WordSubmissionService(context.env);
  const result = await service.promote(context.params['id'] ?? '', reviewer, {
    notes: notes ?? null,
    requestId: context.requestId,
  });

  return json(
    {
      ...result,
      message:
        'Added to the dictionary as a draft, with the contributor credited. Check the meaning and '
        + 'publish it when you are satisfied.',
    },
    { headers: NO_STORE_HEADERS },
  );
}

/** `POST /api/admin/word-submissions/:id/reject` */
export async function rejectWordSubmission(context: RequestContext): Promise<Response> {
  const reviewer = context.user;
  if (!reviewer) throw new UnauthorizedError('Please sign in to continue.');

  const body = await readJsonBody(context.request).catch(() => ({}) as Record<string, unknown>);
  const notes = new Validator(body)
    .string('review_notes', { max: 2000, label: 'Review notes' })
    .validated()['review_notes'] as string | null;

  const service = new WordSubmissionService(context.env);
  await service.reject(context.params['id'] ?? '', reviewer, {
    notes: notes ?? null,
    requestId: context.requestId,
  });

  return json(
    {
      rejected: true,
      // Kept rather than deleted: a word somebody rejected may be a word
      // somebody else can confirm, and the community should be able to
      // revisit that.
      message: 'Marked as not accepted. The submission is kept, not deleted.',
    },
    { headers: NO_STORE_HEADERS },
  );
}

function safeParse(value: string | null): unknown[] {
  if (!value) return [];
  try {
    const parsed: unknown = JSON.parse(value);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}
