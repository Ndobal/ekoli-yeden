import { DictionaryRepository } from '../repositories/dictionary.repository';
import { EditorialRepository } from '../repositories/editorial.repository';
import { AuditRepository } from '../repositories/audit.repository';
import { ContributionUploadService } from './contribution-upload.service';
import type { Env } from '../types/env';
import type { AuthenticatedUser } from '../types/auth';
import { CONTENT_STATUS } from '../types/models';
import { BadRequestError, NotFoundError } from '../utils/errors';
import { newId, nowIso, submissionReference } from '../utils/id';
import { Validator } from '../utils/validation';
import { LANGUAGE_ENTRY_TYPES, VARIANT_TYPES } from '../controllers/language.controller';

/**
 * CONTRIBUTING A WORD
 *
 * Contributing a word is not contributing a photograph, and the general
 * contribution form was the wrong shape for it. A word arrives with variants,
 * several parts of speech, more than one meaning and at least one sentence
 * showing it in use — none of which fit into "title" and "description".
 *
 * So this is a queue of its own, holding the whole proposed entry in the same
 * shape the dictionary stores. A language editor reviews something that
 * already reads like a dictionary entry, and promoting it is a copy rather
 * than a re-typing — which is the difference between a review queue that gets
 * worked through and one that does not.
 *
 * Nothing here is ever published directly. Promotion creates a `draft` word,
 * and publishing it is a separate, deliberate act by somebody with the
 * standing to say what a word means.
 */

export interface WordSubmissionRecord {
  id: string;
  reference_code: string;
  word: string;
  word_normalised: string | null;
  entry_type: string;
  parts_of_speech: string | null;
  variants: string | null;
  senses: string | null;
  examples: string | null;
  phonetic_respelling: string | null;
  tone_pattern: string | null;
  literal_translation: string | null;
  usage_notes: string | null;
  dialect_or_area: string | null;
  category_id: string | null;
  audio_upload_id: string | null;
  contributor_name: string | null;
  contributor_email: string | null;
  contributor_phone: string | null;
  speaker_credentials: string | null;
  status: string;
  review_notes: string | null;
  promoted_word_id: string | null;
  created_at: string;
  updated_at: string;
}

export class WordSubmissionService {
  private readonly dictionary: DictionaryRepository;

  constructor(private readonly env: Env) {
    this.dictionary = new DictionaryRepository(env.DB);
  }

  /**
   * Accepts a proposed dictionary entry from anybody.
   *
   * No account required. The people who know the most words are rarely the
   * people most willing to register for a website.
   */
  async submit(
    payload: Record<string, unknown>,
    contributor: AuthenticatedUser | null,
    context: { requestId: string; ipHash: string | null },
  ): Promise<{
    id: string;
    referenceCode: string;
    alreadyRecorded: { id: string; word: string } | null;
  }> {
    const validated = new Validator(payload)
      .string('word', { required: true, min: 1, max: 200, label: 'The word' })
      .oneOf('entry_type', LANGUAGE_ENTRY_TYPES)
      .string('phonetic_respelling', { max: 300, label: 'How it is said' })
      .string('tone_pattern', { max: 100, label: 'Tone pattern' })
      .string('literal_translation', { max: 500, label: 'Literal translation' })
      .string('usage_notes', { max: 2000, label: 'Notes on use' })
      .string('dialect_or_area', { max: 200, label: 'Quarter or family' })
      .string('category_id', { max: 64 })
      .string('audio_upload_id', { max: 64 })
      .string('contributor_name', { max: 150, label: 'Your name' })
      .string('contributor_phone', { max: 40, label: 'Phone number' })
      .string('speaker_credentials', { max: 500, label: 'How you know this word' })
      .email('contributor_email')
      .boolean('consent_given', { required: true })
      .validated();

    if (validated['consent_given'] !== 1) {
      throw new BadRequestError(
        'Please confirm that this word may be recorded in the community dictionary.',
      );
    }

    const word = validated['word'] as string;
    const senses = normaliseSenses(payload['senses']);
    const examples = normaliseExamples(payload['examples']);

    // At least one meaning, or the entry is a word with nothing said about it.
    // The archive would rather have that than nothing — but it should be a
    // deliberate choice, so the contributor is told what is missing.
    if (senses.length === 0) {
      throw new BadRequestError(
        'Please give at least one meaning for this word, in English. If you know the word but not '
          + 'how to translate it, say so in the notes and give the sentence you have heard it in.',
      );
    }

    // A word already in the dictionary is not rejected — a second speaker
    // confirming a meaning, or giving a different one, is worth having. The
    // reviewer is simply told, so they merge rather than duplicate.
    const existing = await this.dictionary.findByNormalisedWord(word);

    const id = newId();
    const referenceCode = submissionReference();
    const timestamp = nowIso();

    await this.env.DB.prepare(
      `INSERT INTO "word_submissions"
         ("id", "reference_code", "word", "word_normalised", "entry_type",
          "parts_of_speech", "variants", "senses", "examples",
          "phonetic_respelling", "tone_pattern", "literal_translation", "usage_notes",
          "dialect_or_area", "category_id", "audio_upload_id",
          "contributor_name", "contributor_email", "contributor_phone", "speaker_credentials",
          "submitted_by", "consent_given", "status", "ip_hash", "created_at", "updated_at")
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    )
      .bind(
        id,
        referenceCode,
        word,
        DictionaryRepository.normalise(word),
        (validated['entry_type'] as string | undefined) ?? 'word',
        JSON.stringify(normaliseParts(payload['parts_of_speech'])),
        JSON.stringify(normaliseVariants(payload['variants'])),
        JSON.stringify(senses),
        JSON.stringify(examples),
        validated['phonetic_respelling'] ?? null,
        validated['tone_pattern'] ?? null,
        validated['literal_translation'] ?? null,
        validated['usage_notes'] ?? null,
        validated['dialect_or_area'] ?? null,
        validated['category_id'] ?? null,
        validated['audio_upload_id'] ?? null,
        validated['contributor_name'] ?? contributor?.displayName ?? null,
        validated['contributor_email'] ?? contributor?.email ?? null,
        validated['contributor_phone'] ?? null,
        validated['speaker_credentials'] ?? null,
        contributor?.id ?? null,
        1,
        'pending_review',
        context.ipHash,
        timestamp,
        timestamp,
      )
      .run();

    await new AuditRepository(this.env.DB).record({
      actorId: contributor?.id ?? null,
      actorEmail: contributor?.email ?? null,
      action: 'dictionary.word.submitted',
      resourceType: 'word_submission',
      resourceId: id,
      changes: { word, reference: referenceCode, senses: senses.length, examples: examples.length },
      ipHash: context.ipHash,
      requestId: context.requestId,
    });

    return {
      id,
      referenceCode,
      alreadyRecorded: existing ? { id: existing.id, word: existing.word } : null,
    };
  }

  /** The review queue. */
  async list(
    status: string,
    limit: number,
    offset: number,
  ): Promise<{ items: WordSubmissionRecord[]; total: number }> {
    const [countRow, rows] = await this.env.DB.batch<Record<string, unknown>>([
      this.env.DB.prepare('SELECT COUNT(*) AS total FROM "word_submissions" WHERE "status" = ?').bind(
        status,
      ),
      this.env.DB.prepare(
        'SELECT * FROM "word_submissions" WHERE "status" = ? ORDER BY "created_at" DESC LIMIT ? OFFSET ?',
      ).bind(status, limit, offset),
    ]);

    return {
      items: (rows?.results ?? []) as unknown as WordSubmissionRecord[],
      total: Number((countRow?.results?.[0]?.['total'] as number | undefined) ?? 0),
    };
  }

  async find(id: string): Promise<WordSubmissionRecord | null> {
    const row = await this.env.DB.prepare('SELECT * FROM "word_submissions" WHERE "id" = ? LIMIT 1')
      .bind(id)
      .first<WordSubmissionRecord>();
    return row ?? null;
  }

  /**
   * Turns an accepted submission into a dictionary entry.
   *
   * The new word is a `draft`. Approving a contribution says "this is worth
   * having"; publishing it says "this is what the word means", and only
   * somebody with the standing to make the second statement should make it.
   */
  async promote(
    id: string,
    reviewer: AuthenticatedUser,
    options: { notes: string | null; requestId: string },
  ): Promise<{ wordId: string }> {
    const submission = await this.find(id);
    if (!submission) throw new NotFoundError('That word submission was not found.');
    if (submission.status === 'promoted' && submission.promoted_word_id) {
      return { wordId: submission.promoted_word_id };
    }

    const wordId = newId();
    const timestamp = nowIso();
    const senses = parseJsonArray(submission.senses);
    const firstSense = senses[0] ?? {};

    await this.env.DB.prepare(
      `INSERT INTO "language_words"
         ("id", "word", "word_normalised", "initial_letter", "english_meaning", "definition",
          "category_id", "parts_of_speech", "part_of_speech", "phonetic_respelling", "tone_pattern",
          "literal_translation", "usage_notes", "dialect_or_variation", "entry_type", "speaker",
          "verification_status", "status", "created_at", "updated_at")
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    )
      .bind(
        wordId,
        submission.word,
        DictionaryRepository.normalise(submission.word),
        DictionaryRepository.initialLetter(submission.word),
        // The headword's own meaning mirrors sense 1, so anything still reading
        // the flat column sees the entry rather than an empty field.
        asText(firstSense['english_meaning']),
        asText(firstSense['definition']),
        submission.category_id,
        submission.parts_of_speech,
        firstPartOfSpeech(submission.parts_of_speech, firstSense),
        submission.phonetic_respelling,
        submission.tone_pattern,
        submission.literal_translation,
        submission.usage_notes,
        submission.dialect_or_area,
        submission.entry_type,
        submission.contributor_name,
        // Unverified, always. A contribution is a claim until the Verification
        // Team has checked it, however credible the contributor.
        'unverified',
        CONTENT_STATUS.DRAFT,
        timestamp,
        timestamp,
      )
      .run();

    await this.dictionary.replaceSenses(
      wordId,
      senses.map((sense) => ({
        part_of_speech: asText(sense['part_of_speech']),
        english_meaning: asText(sense['english_meaning']),
        definition: asText(sense['definition']),
        usage_note: asText(sense['usage_note']),
        register: null,
        domain: null,
      })),
      CONTENT_STATUS.DRAFT,
    );

    await this.dictionary.replaceVariants(
      wordId,
      parseJsonArray(submission.variants)
        .map((variant) => ({
          variant: asText(variant['variant']) ?? '',
          variant_type: asText(variant['variant_type']) ?? 'alternate',
          dialect_or_area: asText(variant['dialect_or_area']),
          speaker: null,
          notes: asText(variant['notes']),
        }))
        .filter((variant) => variant.variant !== ''),
      CONTENT_STATUS.DRAFT,
    );

    await this.dictionary.replaceExamples(
      wordId,
      parseJsonArray(submission.examples)
        .map((example) => ({
          sentence_ekoli: asText(example['sentence_ekoli']) ?? '',
          sentence_english: asText(example['sentence_english']),
          pronunciation: asText(example['pronunciation']),
          media_asset_id: null,
          speaker: submission.contributor_name,
          context_note: null,
        }))
        .filter((example) => example.sentence_ekoli !== ''),
      CONTENT_STATUS.DRAFT,
    );

    // The recording travels with the word.
    //
    // Without this the contributor's own voice would stay in the review queue
    // while the entry it belongs to went into the dictionary silent — which
    // loses the one part of a word that written text cannot carry, and is
    // exactly the part the form asks hardest for.
    if (submission.audio_upload_id) {
      await this.attachRecording(wordId, submission, reviewer, options.requestId);
    }

    // The contributor is credited now, into a table nothing in the editorial
    // flow ever writes to, so the credit survives every later edit of the entry.
    if (submission.contributor_name) {
      await new EditorialRepository(this.env.DB)
        .addContributor({
          resourceType: 'language',
          resourceId: wordId,
          userId: null,
          contributorName: submission.contributor_name,
          contributorType: 'individual',
          attributionPrefix: 'Word supplied by',
          // A word submission lives in its own table, not `submissions`, and
          // this column is a foreign key into that one.
          submissionId: null,
          submittedAt: submission.created_at,
          approvedBy: reviewer.id,
          usagePermission: 'public_display_with_credit',
          copyrightHolder: null,
          copyrightNotes: null,
        })
        // A failed credit must not lose the word. Who supplied it is still on
        // the submission row, so nothing here is unrecoverable.
        .catch(() => undefined);
    }

    await this.env.DB.prepare(
      `UPDATE "word_submissions"
       SET "status" = 'promoted', "promoted_word_id" = ?, "reviewed_by" = ?, "reviewed_at" = ?,
           "review_notes" = ?, "updated_at" = ?
       WHERE "id" = ?`,
    )
      .bind(wordId, reviewer.id, timestamp, options.notes, timestamp, id)
      .run();

    await new AuditRepository(this.env.DB).record({
      actorId: reviewer.id,
      actorEmail: reviewer.email,
      action: 'dictionary.word.promoted',
      resourceType: 'word_submission',
      resourceId: id,
      changes: { wordId, word: submission.word, contributor: submission.contributor_name },
      requestId: options.requestId,
    });

    return { wordId };
  }

  async reject(
    id: string,
    reviewer: AuthenticatedUser,
    options: { notes: string | null; requestId: string },
  ): Promise<void> {
    const submission = await this.find(id);
    if (!submission) throw new NotFoundError('That word submission was not found.');

    await this.env.DB.prepare(
      `UPDATE "word_submissions"
       SET "status" = 'rejected', "reviewed_by" = ?, "reviewed_at" = ?, "review_notes" = ?, "updated_at" = ?
       WHERE "id" = ?`,
    )
      .bind(reviewer.id, nowIso(), options.notes, nowIso(), id)
      .run();

    await new AuditRepository(this.env.DB).record({
      actorId: reviewer.id,
      actorEmail: reviewer.email,
      action: 'dictionary.word.rejected',
      resourceType: 'word_submission',
      resourceId: id,
      changes: { word: submission.word, notes: options.notes },
      requestId: options.requestId,
    });
  }

  /**
   * Moves a contributed recording into the archive and hangs it on the word.
   *
   * Reuses the contribution approval path rather than copying the file itself,
   * so the recording is promoted exactly the way a contributed photograph is —
   * same provenance chain, same credit, one implementation.
   *
   * The `language_audio` row starts at `pending_review`: the entry is a draft,
   * and a recording that played on a page before anybody had listened to it
   * would be the one part of this flow that skipped review.
   */
  private async attachRecording(
    wordId: string,
    submission: WordSubmissionRecord,
    reviewer: AuthenticatedUser,
    requestId: string,
  ): Promise<void> {
    if (!submission.audio_upload_id) return;

    try {
      const { mediaAssetId } = await new ContributionUploadService(this.env).approve(
        submission.audio_upload_id,
        reviewer,
        { notes: `Pronunciation of "${submission.word}"`, requestId },
      );

      const timestamp = nowIso();
      await this.env.DB.prepare(
        `INSERT INTO "language_audio"
           ("id", "word_id", "media_asset_id", "speaker", "dialect_or_variation", "notes",
            "status", "created_at", "updated_at")
         VALUES (?, ?, ?, ?, ?, NULL, ?, ?, ?)`,
      )
        .bind(
          newId(),
          wordId,
          mediaAssetId,
          submission.contributor_name,
          submission.dialect_or_area,
          CONTENT_STATUS.PENDING_REVIEW,
          timestamp,
          timestamp,
        )
        .run();
    } catch {
      // A recording that cannot be promoted must not lose the word. It stays in
      // the contribution queue, where it can be approved and attached by hand.
    }
  }

  /** What a contributor sees when they quote their reference code. */
  async findByReference(referenceCode: string): Promise<WordSubmissionRecord | null> {
    const row = await this.env.DB.prepare(
      'SELECT * FROM "word_submissions" WHERE "reference_code" = ? LIMIT 1',
    )
      .bind(referenceCode.trim().toUpperCase())
      .first<WordSubmissionRecord>();
    return row ?? null;
  }
}

// ---------------------------------------------------------------------------
// Shaping what arrives from the form
// ---------------------------------------------------------------------------

function normaliseParts(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((item): item is string => typeof item === 'string')
    .map((item) => item.trim())
    .filter((item) => item !== '')
    .slice(0, 8);
}

function normaliseSenses(raw: unknown): Record<string, string | null>[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter(isRecord)
    .map((sense) => ({
      part_of_speech: asText(sense['part_of_speech'], 60),
      english_meaning: asText(sense['english_meaning'], 500),
      definition: asText(sense['definition'], 2000),
      usage_note: asText(sense['usage_note'], 1000),
    }))
    // A sense with neither a meaning nor a definition says nothing.
    .filter((sense) => sense.english_meaning !== null || sense.definition !== null)
    .slice(0, 10);
}

function normaliseVariants(raw: unknown): Record<string, string | null>[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter(isRecord)
    .map((variant) => ({
      variant: asText(variant['variant'], 200),
      variant_type: (VARIANT_TYPES as readonly string[]).includes(String(variant['variant_type']))
        ? String(variant['variant_type'])
        : 'alternate',
      dialect_or_area: asText(variant['dialect_or_area'], 200),
      notes: asText(variant['notes'], 500),
    }))
    .filter((variant) => variant.variant !== null)
    .slice(0, 12);
}

function normaliseExamples(raw: unknown): Record<string, string | null>[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter(isRecord)
    .map((example) => ({
      sentence_ekoli: asText(example['sentence_ekoli'], 1000),
      sentence_english: asText(example['sentence_english'], 1000),
      pronunciation: asText(example['pronunciation'], 1000),
    }))
    .filter((example) => example.sentence_ekoli !== null)
    .slice(0, 10);
}

function parseJsonArray(value: string | null): Record<string, unknown>[] {
  if (!value) return [];
  try {
    const parsed: unknown = JSON.parse(value);
    return Array.isArray(parsed) ? parsed.filter(isRecord) : [];
  } catch {
    return [];
  }
}

/** The part of speech stored on the headword, for anything reading it flat. */
function firstPartOfSpeech(parts: string | null, firstSense: Record<string, unknown>): string | null {
  const fromSense = asText(firstSense['part_of_speech'], 60);
  if (fromSense) return fromSense;

  if (!parts) return null;
  try {
    const parsed: unknown = JSON.parse(parts);
    if (Array.isArray(parsed) && typeof parsed[0] === 'string') return parsed[0];
  } catch {
    // Not JSON — nothing to take from it.
  }
  return null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function asText(value: unknown, max = 2000): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed === '' ? null : trimmed.slice(0, max);
}
