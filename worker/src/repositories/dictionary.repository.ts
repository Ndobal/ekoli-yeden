import { newId, nowIso } from '../utils/id';
import { CONTENT_STATUS } from '../types/models';

/**
 * THE DICTIONARY
 *
 * A word is not a row. It is a headword with variants, several senses, several
 * parts of speech, example sentences in both languages, and recordings. This
 * repository assembles that, and does it in a fixed number of queries however
 * many words are on the page — the alternative, four lookups per word, turns a
 * page of fifty entries into two hundred round trips.
 */

export interface SenseRecord {
  id: string;
  word_id: string;
  sense_number: number;
  part_of_speech: string | null;
  english_meaning: string | null;
  definition: string | null;
  usage_note: string | null;
  register: string | null;
  domain: string | null;
  verification_status: string;
  status: string;
}

export interface ExampleRecord {
  id: string;
  word_id: string;
  sense_id: string | null;
  sentence_ekoli: string;
  sentence_english: string | null;
  pronunciation: string | null;
  media_asset_id: string | null;
  speaker: string | null;
  context_note: string | null;
  sort_order: number;
  status: string;
}

export interface VariantRecord {
  id: string;
  word_id: string;
  variant: string;
  variant_normalised: string | null;
  variant_type: string;
  dialect_or_area: string | null;
  speaker: string | null;
  notes: string | null;
  status: string;
}

export interface PartOfSpeechRecord {
  slug: string;
  label: string;
  abbreviation: string | null;
  description: string | null;
  sort_order: number;
}

/** What the dictionary can be narrowed by. */
export interface DictionaryFilters {
  search: string | null;
  letter: string | null;
  categoryId: string | null;
  entryType: string | null;
  partOfSpeech: string | null;
  verificationStatus: string | null;
  hasAudio: boolean;
  hasExample: boolean;
  sort: 'word' | 'recent';
  limit: number;
  offset: number;
  /** `null` for the public dictionary, which sees published entries only. */
  statuses: string[];
}

export class DictionaryRepository {
  constructor(private readonly db: D1Database) {}

  /**
   * Normalises a headword for searching and sorting.
   *
   * Lowercased and stripped of combining marks, so somebody typing on a phone
   * keyboard without tone marks still finds the word. Applied on every write,
   * which is why the search below can compare against a plain typed string.
   */
  static normalise(word: string): string {
    return word
      .normalize('NFKD')
      .replace(/[̀-ͯ]/g, '')
      .trim()
      .toLowerCase();
  }

  static initialLetter(word: string): string {
    const normalised = DictionaryRepository.normalise(word);
    const first = normalised.charAt(0).toUpperCase();
    return /[A-Z]/.test(first) ? first : '#';
  }

  /**
   * Searches headwords, meanings, definitions, example sentences and variants
   * in one statement.
   *
   * Variants are searched because a visitor usually knows the form their own
   * family says, not the form an editor chose as the headword. A dictionary
   * that only matches its headwords fails exactly the person it exists for.
   */
  async search(filters: DictionaryFilters): Promise<{ items: Record<string, unknown>[]; total: number }> {
    const conditions: string[] = [];
    const bindings: unknown[] = [];

    // Fails closed. An empty status list would otherwise produce no status
    // condition at all and return every draft in the dictionary — the one
    // mistake in this file that would matter, so it cannot be made.
    const statuses = filters.statuses.length > 0 ? filters.statuses : [CONTENT_STATUS.PUBLISHED];
    conditions.push(`w."status" IN (${statuses.map(() => '?').join(', ')})`);
    bindings.push(...statuses);

    if (filters.letter) {
      conditions.push('w."initial_letter" = ?');
      bindings.push(filters.letter.toUpperCase());
    }
    if (filters.categoryId) {
      conditions.push('w."category_id" = ?');
      bindings.push(filters.categoryId);
    }
    if (filters.entryType) {
      conditions.push('w."entry_type" = ?');
      bindings.push(filters.entryType);
    }
    if (filters.verificationStatus) {
      conditions.push('w."verification_status" = ?');
      bindings.push(filters.verificationStatus);
    }

    // A word is "a noun" if any of its senses is, or if the headword itself
    // lists it. Both are checked, because an entry may carry its parts of
    // speech on the headword before anybody has broken it into senses.
    if (filters.partOfSpeech) {
      conditions.push(
        `(w."parts_of_speech" LIKE ? ESCAPE '\\'
          OR EXISTS (SELECT 1 FROM "language_senses" s
                     WHERE s."word_id" = w."id" AND s."part_of_speech" = ?))`,
      );
      bindings.push(`%"${escapeLike(filters.partOfSpeech)}"%`, filters.partOfSpeech);
    }

    if (filters.hasAudio) {
      conditions.push(
        `EXISTS (SELECT 1 FROM "language_audio" a
                 WHERE a."word_id" = w."id" AND a."status" = 'published')`,
      );
    }
    if (filters.hasExample) {
      conditions.push(`EXISTS (SELECT 1 FROM "language_examples" e WHERE e."word_id" = w."id")`);
    }

    const term = filters.search?.trim();
    if (term) {
      const pattern = `%${escapeLike(term)}%`;
      conditions.push(
        `(w."word" LIKE ? ESCAPE '\\'
          OR w."word_normalised" LIKE ? ESCAPE '\\'
          OR w."english_meaning" LIKE ? ESCAPE '\\'
          OR w."definition" LIKE ? ESCAPE '\\'
          OR EXISTS (SELECT 1 FROM "language_variants" v
                     WHERE v."word_id" = w."id"
                       AND (v."variant" LIKE ? ESCAPE '\\' OR v."variant_normalised" LIKE ? ESCAPE '\\'))
          OR EXISTS (SELECT 1 FROM "language_senses" s
                     WHERE s."word_id" = w."id"
                       AND (s."english_meaning" LIKE ? ESCAPE '\\' OR s."definition" LIKE ? ESCAPE '\\'))
          OR EXISTS (SELECT 1 FROM "language_examples" e
                     WHERE e."word_id" = w."id"
                       AND (e."sentence_ekoli" LIKE ? ESCAPE '\\' OR e."sentence_english" LIKE ? ESCAPE '\\')))`,
      );
      for (let i = 0; i < 10; i += 1) bindings.push(pattern);
    }

    const where = conditions.length > 0 ? ` WHERE ${conditions.join(' AND ')}` : '';
    const order =
      filters.sort === 'recent'
        ? 'w."created_at" DESC, w."id" ASC'
        : 'COALESCE(w."word_normalised", lower(w."word")) ASC, w."id" ASC';

    const [countResult, rowsResult] = await this.db.batch<Record<string, unknown>>([
      this.db.prepare(`SELECT COUNT(*) AS total FROM "language_words" w${where}`).bind(...bindings),
      this.db
        .prepare(`SELECT w.* FROM "language_words" w${where} ORDER BY ${order} LIMIT ? OFFSET ?`)
        .bind(...bindings, filters.limit, filters.offset),
    ]);

    return {
      items: (rowsResult?.results ?? []) as Record<string, unknown>[],
      total: Number((countResult?.results?.[0]?.['total'] as number | undefined) ?? 0),
    };
  }

  /**
   * The A–Z index, with a count against each letter.
   *
   * Letters with nothing behind them are returned with a zero rather than
   * omitted, so the index does not silently shrink and re-flow as the
   * dictionary grows.
   */
  async letterCounts(statuses: string[]): Promise<{ letter: string; total: number }[]> {
    const placeholders = statuses.map(() => '?').join(', ');
    const result = await this.db
      .prepare(
        `SELECT COALESCE("initial_letter", '#') AS letter, COUNT(*) AS total
         FROM "language_words"
         WHERE "status" IN (${placeholders})
         GROUP BY letter
         ORDER BY letter ASC`,
      )
      .bind(...statuses)
      .all<{ letter: string; total: number }>();

    const counts = new Map<string, number>();
    for (const row of result.results ?? []) counts.set(row.letter, Number(row.total));

    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');
    const letters = alphabet.map((letter) => ({ letter, total: counts.get(letter) ?? 0 }));
    if ((counts.get('#') ?? 0) > 0) letters.push({ letter: '#', total: counts.get('#') ?? 0 });
    return letters;
  }

  async partsOfSpeech(): Promise<PartOfSpeechRecord[]> {
    const result = await this.db
      .prepare('SELECT * FROM "language_parts_of_speech" ORDER BY "sort_order" ASC, "label" ASC')
      .all<PartOfSpeechRecord>();
    return result.results ?? [];
  }

  // -------------------------------------------------------------------------
  // Attaching the parts of an entry
  // -------------------------------------------------------------------------

  async sensesFor(wordIds: string[], statuses: string[]): Promise<SenseRecord[]> {
    return this.childrenOf<SenseRecord>(
      'language_senses',
      wordIds,
      statuses,
      '"sense_number" ASC',
    );
  }

  async variantsFor(wordIds: string[], statuses: string[]): Promise<VariantRecord[]> {
    return this.childrenOf<VariantRecord>('language_variants', wordIds, statuses, '"variant" ASC');
  }

  /**
   * Example sentences, joined to the recording of the sentence where there is
   * one. The recording is the part a learner needs most and the part a written
   * archive preserves worst, so it travels with the sentence rather than being
   * fetched separately.
   */
  async examplesFor(
    wordIds: string[],
    statuses: string[],
  ): Promise<(ExampleRecord & { storage_key: string | null; audio_status: string | null })[]> {
    if (wordIds.length === 0 || statuses.length === 0) return [];

    const wordPlaceholders = wordIds.map(() => '?').join(', ');
    const statusPlaceholders = statuses.map(() => '?').join(', ');

    const result = await this.db
      .prepare(
        `SELECT e.*, ma."storage_key", ma."status" AS audio_status
         FROM "language_examples" e
         LEFT JOIN "media_assets" ma ON ma."id" = e."media_asset_id"
         WHERE e."word_id" IN (${wordPlaceholders})
           AND e."status" IN (${statusPlaceholders})
         ORDER BY e."sort_order" ASC, e."created_at" ASC`,
      )
      .bind(...wordIds, ...statuses)
      .all<ExampleRecord & { storage_key: string | null; audio_status: string | null }>();

    return result.results ?? [];
  }

  private async childrenOf<T>(
    table: 'language_senses' | 'language_variants',
    wordIds: string[],
    statuses: string[],
    orderBy: string,
  ): Promise<T[]> {
    if (wordIds.length === 0 || statuses.length === 0) return [];

    const wordPlaceholders = wordIds.map(() => '?').join(', ');
    const statusPlaceholders = statuses.map(() => '?').join(', ');

    const result = await this.db
      .prepare(
        `SELECT * FROM "${table}"
         WHERE "word_id" IN (${wordPlaceholders})
           AND "status" IN (${statusPlaceholders})
         ORDER BY ${orderBy}`,
      )
      .bind(...wordIds, ...statuses)
      .all<T>();

    return result.results ?? [];
  }

  // -------------------------------------------------------------------------
  // Writing
  // -------------------------------------------------------------------------

  /**
   * Replaces a word's senses with the supplied list.
   *
   * Replace rather than merge: a language editor works on the whole entry at
   * once, and reconciling a partial list against what is already stored is a
   * good way to leave an orphaned sense 3 behind after somebody removes it.
   */
  async replaceSenses(
    wordId: string,
    senses: {
      part_of_speech?: string | null;
      english_meaning?: string | null;
      definition?: string | null;
      usage_note?: string | null;
      register?: string | null;
      domain?: string | null;
    }[],
    status: string,
  ): Promise<void> {
    await this.db.prepare('DELETE FROM "language_senses" WHERE "word_id" = ?').bind(wordId).run();
    if (senses.length === 0) return;

    const timestamp = nowIso();
    const statements = senses.map((sense, index) =>
      this.db
        .prepare(
          `INSERT INTO "language_senses"
             ("id", "word_id", "sense_number", "part_of_speech", "english_meaning", "definition",
              "usage_note", "register", "domain", "verification_status", "status", "created_at", "updated_at")
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        )
        .bind(
          newId(),
          wordId,
          index + 1,
          sense.part_of_speech ?? null,
          sense.english_meaning ?? null,
          sense.definition ?? null,
          sense.usage_note ?? null,
          sense.register ?? null,
          sense.domain ?? null,
          'unverified',
          status,
          timestamp,
          timestamp,
        ),
    );

    await this.db.batch(statements);
  }

  async replaceVariants(
    wordId: string,
    variants: {
      variant: string;
      variant_type?: string | null;
      dialect_or_area?: string | null;
      speaker?: string | null;
      notes?: string | null;
    }[],
    status: string,
  ): Promise<void> {
    await this.db.prepare('DELETE FROM "language_variants" WHERE "word_id" = ?').bind(wordId).run();
    if (variants.length === 0) return;

    const timestamp = nowIso();
    // De-duplicated before insert: the table has a UNIQUE (word_id, variant),
    // and one repeated form in an editor's list should not fail the save.
    const seen = new Set<string>();
    const statements = [];

    for (const variant of variants) {
      const form = variant.variant.trim();
      if (form === '' || seen.has(form)) continue;
      seen.add(form);

      statements.push(
        this.db
          .prepare(
            `INSERT INTO "language_variants"
               ("id", "word_id", "variant", "variant_normalised", "variant_type",
                "dialect_or_area", "speaker", "notes", "status", "created_at", "updated_at")
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          )
          .bind(
            newId(),
            wordId,
            form,
            DictionaryRepository.normalise(form),
            variant.variant_type ?? 'alternate',
            variant.dialect_or_area ?? null,
            variant.speaker ?? null,
            variant.notes ?? null,
            status,
            timestamp,
            timestamp,
          ),
      );
    }

    if (statements.length > 0) await this.db.batch(statements);
  }

  async replaceExamples(
    wordId: string,
    examples: {
      sentence_ekoli: string;
      sentence_english?: string | null;
      pronunciation?: string | null;
      media_asset_id?: string | null;
      speaker?: string | null;
      context_note?: string | null;
    }[],
    status: string,
  ): Promise<void> {
    await this.db.prepare('DELETE FROM "language_examples" WHERE "word_id" = ?').bind(wordId).run();
    if (examples.length === 0) return;

    const timestamp = nowIso();
    const statements = examples
      .filter((example) => example.sentence_ekoli.trim() !== '')
      .map((example, index) =>
        this.db
          .prepare(
            `INSERT INTO "language_examples"
               ("id", "word_id", "sense_id", "sentence_ekoli", "sentence_english", "pronunciation",
                "media_asset_id", "speaker", "context_note", "sort_order", "status", "created_at", "updated_at")
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          )
          .bind(
            newId(),
            wordId,
            null,
            example.sentence_ekoli.trim(),
            example.sentence_english ?? null,
            example.pronunciation ?? null,
            example.media_asset_id ?? null,
            example.speaker ?? null,
            example.context_note ?? null,
            index,
            status,
            timestamp,
            timestamp,
          ),
      );

    if (statements.length > 0) await this.db.batch(statements);
  }

  /** Keeps the searchable form in step whenever a headword changes. */
  async refreshNormalisedForm(wordId: string, word: string): Promise<void> {
    await this.db
      .prepare(
        'UPDATE "language_words" SET "word_normalised" = ?, "initial_letter" = ?, "updated_at" = ? WHERE "id" = ?',
      )
      .bind(
        DictionaryRepository.normalise(word),
        DictionaryRepository.initialLetter(word),
        nowIso(),
        wordId,
      )
      .run();
  }

  /**
   * Whether a headword is already in the dictionary.
   *
   * Compared on the normalised form, so a submission that differs only in tone
   * marks or capitalisation is caught before it reaches a reviewer as an
   * apparent new word.
   */
  async findByNormalisedWord(word: string): Promise<{ id: string; word: string; status: string } | null> {
    const row = await this.db
      .prepare('SELECT "id", "word", "status" FROM "language_words" WHERE "word_normalised" = ? LIMIT 1')
      .bind(DictionaryRepository.normalise(word))
      .first<{ id: string; word: string; status: string }>();
    return row ?? null;
  }

  /** How much of the dictionary is actually finished. */
  async coverage(): Promise<Record<string, number>> {
    const row = await this.db
      .prepare(
        `SELECT
           COUNT(*) AS total,
           SUM(CASE WHEN "status" = 'published' THEN 1 ELSE 0 END) AS published,
           SUM(CASE WHEN "verification_status" = 'verified' THEN 1 ELSE 0 END) AS verified,
           SUM(CASE WHEN "english_meaning" IS NULL OR trim("english_meaning") = '' THEN 1 ELSE 0 END) AS without_meaning,
           (SELECT COUNT(DISTINCT "word_id") FROM "language_audio" WHERE "status" = ?) AS with_audio,
           (SELECT COUNT(DISTINCT "word_id") FROM "language_examples") AS with_example
         FROM "language_words"`,
      )
      .bind(CONTENT_STATUS.PUBLISHED)
      .first<Record<string, number>>();

    return {
      total: Number(row?.['total'] ?? 0),
      published: Number(row?.['published'] ?? 0),
      verified: Number(row?.['verified'] ?? 0),
      withoutMeaning: Number(row?.['without_meaning'] ?? 0),
      withAudio: Number(row?.['with_audio'] ?? 0),
      withExample: Number(row?.['with_example'] ?? 0),
    };
  }
}

/** Escapes the wildcards so a visitor typing `%` searches for a percent sign. */
function escapeLike(value: string): string {
  return value.replace(/[\\%_]/g, (char) => `\\${char}`);
}
