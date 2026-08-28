import {
  DictionaryRepository,
  type DictionaryFilters,
  type ExampleRecord,
  type SenseRecord,
  type VariantRecord,
} from '../repositories/dictionary.repository';
import type { Env } from '../types/env';
import { CONTENT_STATUS } from '../types/models';
import { publicMediaUrl } from '../utils/files';

/**
 * ASSEMBLING A DICTIONARY ENTRY
 *
 * An entry is a headword plus four sets of children: its senses, its example
 * sentences, its variant forms and its pronunciation recordings. Loading those
 * per word would cost four queries per row; this loads them once for the whole
 * page and stitches them together in memory, so a page of fifty entries costs
 * five queries rather than two hundred.
 *
 * The rule the whole feature is built around is unchanged: nothing here
 * invents a meaning. A sense with no definition is returned with the field
 * null, and the dictionary page says plainly that nobody has supplied it yet.
 */
export class DictionaryService {
  private readonly repository: DictionaryRepository;

  constructor(private readonly env: Env) {
    this.repository = new DictionaryRepository(env.DB);
  }

  get repo(): DictionaryRepository {
    return this.repository;
  }

  /** A page of entries, each one complete. */
  async search(
    filters: DictionaryFilters,
  ): Promise<{ items: Record<string, unknown>[]; total: number }> {
    const { items, total } = await this.repository.search(filters);
    return { items: await this.attachChildren(items, filters.statuses), total };
  }

  /**
   * Attaches senses, examples, variants and recordings to a set of headwords.
   *
   * `childStatuses` follows the caller: the public dictionary sees published
   * children only, a language editor sees drafts too. A published word with a
   * draft third sense shows two senses to a visitor and three to its editor,
   * which is the behaviour the editorial workflow promises everywhere else.
   */
  async attachChildren(
    words: Record<string, unknown>[],
    statuses: string[],
  ): Promise<Record<string, unknown>[]> {
    if (words.length === 0) return words;

    const ids = words.map((word) => String(word['id'])).filter((id) => id !== '');
    if (ids.length === 0) return words;

    const [senses, examples, variants, audio] = await Promise.all([
      this.repository.sensesFor(ids, statuses),
      this.repository.examplesFor(ids, statuses),
      this.repository.variantsFor(ids, statuses),
      this.loadAudio(ids, statuses),
    ]);

    const sensesByWord = groupBy(senses, (row) => row.word_id);
    const examplesByWord = groupBy(examples, (row) => row.word_id);
    const variantsByWord = groupBy(variants, (row) => row.word_id);
    const audioByWord = groupBy(audio, (row) => row.word_id);

    return words.map((word) => {
      const id = String(word['id']);
      const wordSenses = sensesByWord.get(id) ?? [];
      const wordExamples = examplesByWord.get(id) ?? [];

      return {
        ...word,
        // Parsed here rather than in the client, so every consumer sees a list
        // and none of them has to know it is stored as JSON text.
        parts_of_speech: this.partsOfSpeechFor(word, wordSenses),
        senses: wordSenses.map((sense) => this.shapeSense(sense)),
        examples: wordExamples.map((example) => this.shapeExample(example)),
        variants: (variantsByWord.get(id) ?? []).map((variant) => this.shapeVariant(variant)),
        pronunciations: audioByWord.get(id) ?? [],
      };
    });
  }

  /**
   * Every part of speech this word belongs to.
   *
   * Merged from the headword's own list and from its senses, because a word
   * that is a noun in sense 1 and a verb in sense 2 is both — and an entry may
   * carry the list on the headword before anybody has split it into senses.
   */
  private partsOfSpeechFor(word: Record<string, unknown>, senses: SenseRecord[]): string[] {
    const parts = new Set<string>();

    const stored = word['parts_of_speech'];
    if (typeof stored === 'string' && stored.trim() !== '') {
      try {
        const parsed: unknown = JSON.parse(stored);
        if (Array.isArray(parsed)) {
          for (const item of parsed) if (typeof item === 'string') parts.add(item);
        }
      } catch {
        // Stored by hand rather than through the API. Treat it as one value
        // rather than dropping an editor's work on a formatting mistake.
        parts.add(stored.trim());
      }
    }

    // The legacy single column, for entries recorded before senses existed.
    const legacy = word['part_of_speech'];
    if (typeof legacy === 'string' && legacy.trim() !== '') parts.add(legacy.trim());

    for (const sense of senses) {
      if (sense.part_of_speech) parts.add(sense.part_of_speech);
    }

    return [...parts];
  }

  private shapeSense(sense: SenseRecord): Record<string, unknown> {
    return {
      id: sense.id,
      sense_number: sense.sense_number,
      part_of_speech: sense.part_of_speech,
      english_meaning: sense.english_meaning,
      definition: sense.definition,
      usage_note: sense.usage_note,
      register: sense.register,
      domain: sense.domain,
      verification_status: sense.verification_status,
    };
  }

  private shapeExample(
    example: ExampleRecord & { storage_key: string | null; audio_status: string | null },
  ): Record<string, unknown> {
    return {
      id: example.id,
      sense_id: example.sense_id,
      sentence_ekoli: example.sentence_ekoli,
      sentence_english: example.sentence_english,
      pronunciation: example.pronunciation,
      speaker: example.speaker,
      context_note: example.context_note,
      // The recording is offered only once it is published. An unpublished
      // audio file is not served, and a URL that 404s is worse than none.
      audio_url:
        example.storage_key && example.audio_status === CONTENT_STATUS.PUBLISHED
          ? publicMediaUrl(this.env.PUBLIC_MEDIA_BASE_URL, example.storage_key)
          : null,
    };
  }

  private shapeVariant(variant: VariantRecord): Record<string, unknown> {
    return {
      id: variant.id,
      variant: variant.variant,
      variant_type: variant.variant_type,
      dialect_or_area: variant.dialect_or_area,
      speaker: variant.speaker,
      notes: variant.notes,
    };
  }

  /** Pronunciation recordings of the headword itself. */
  private async loadAudio(
    wordIds: string[],
    statuses: string[],
  ): Promise<{ word_id: string; [key: string]: unknown }[]> {
    if (wordIds.length === 0) return [];

    const wordPlaceholders = wordIds.map(() => '?').join(', ');
    const statusPlaceholders = statuses.map(() => '?').join(', ');

    const result = await this.env.DB.prepare(
      `SELECT la."id", la."word_id", la."speaker", la."dialect_or_variation", la."notes",
              ma."storage_key", ma."mime_type", ma."status" AS media_status
       FROM "language_audio" la
       INNER JOIN "media_assets" ma ON ma."id" = la."media_asset_id"
       WHERE la."word_id" IN (${wordPlaceholders})
         AND la."status" IN (${statusPlaceholders})
       ORDER BY la."created_at" ASC`,
    )
      .bind(...wordIds, ...statuses)
      .all<{
        id: string;
        word_id: string;
        speaker: string | null;
        dialect_or_variation: string | null;
        notes: string | null;
        storage_key: string;
        mime_type: string;
        media_status: string;
      }>();

    return (result.results ?? [])
      .filter((row) => row.media_status === CONTENT_STATUS.PUBLISHED)
      .map((row) => ({
        id: row.id,
        word_id: row.word_id,
        speaker: row.speaker,
        dialect_or_variation: row.dialect_or_variation,
        notes: row.notes,
        mime_type: row.mime_type,
        audio_url: publicMediaUrl(this.env.PUBLIC_MEDIA_BASE_URL, row.storage_key),
      }));
  }
}

function groupBy<T>(rows: T[], key: (row: T) => string): Map<string, T[]> {
  const grouped = new Map<string, T[]>();
  for (const row of rows) {
    const id = key(row);
    const list = grouped.get(id);
    if (list) list.push(row);
    else grouped.set(id, [row]);
  }
  return grouped;
}
