import '../core/constants/app_constants.dart';
import 'content_status.dart';

/// An entry in the dictionary.
///
/// A word is not one meaning. It is a headword with variant forms, one or more
/// parts of speech, one or more senses, sentences showing it in use, and
/// recordings of somebody saying it. This model carries all of that, because a
/// dictionary that flattens a word into a single gloss is a glossary.
///
/// Every field is supplied by a native speaker or a recognised language
/// scholar. The platform never generates, guesses or completes the meaning of a
/// word — an entry whose meaning nobody has confirmed is shown as awaiting a
/// speaker, with the field left empty.
class LanguageEntry {
  const LanguageEntry({
    required this.id,
    required this.word,
    required this.status,
    required this.verificationStatus,
    required this.entryType,
    required this.pronunciations,
    this.partsOfSpeech = const <String>[],
    this.senses = const <WordSense>[],
    this.examples = const <WordExample>[],
    this.variants = const <WordVariant>[],
    this.englishMeaning,
    this.definition,
    this.exampleSentence,
    this.exampleTranslation,
    this.partOfSpeech,
    this.dialectOrVariation,
    this.notes,
    this.speaker,
    this.categoryId,
    this.phoneticRespelling,
    this.ipa,
    this.tonePattern,
    this.pluralForm,
    this.singularForm,
    this.literalTranslation,
    this.usageNotes,
    this.register,
    this.etymology,
    this.seeAlso,
    this.initialLetter,
  });

  factory LanguageEntry.fromJson(Map<String, dynamic> json) {
    return LanguageEntry(
      id: Json.str(json, 'id'),
      word: Json.str(json, 'word'),
      status: Json.str(json, 'status', fallback: ContentStatus.draft),
      verificationStatus: Json.str(
        json,
        'verification_status',
        fallback: VerificationStatus.unverified,
      ),
      entryType: Json.str(json, 'entry_type', fallback: 'word'),
      pronunciations: Json.objectList(json, 'pronunciations')
          .map(Pronunciation.fromJson)
          .toList(growable: false),
      partsOfSpeech: Json.stringList(json, 'parts_of_speech'),
      senses: Json.objectList(json, 'senses').map(WordSense.fromJson).toList(growable: false),
      examples: Json.objectList(json, 'examples').map(WordExample.fromJson).toList(growable: false),
      variants: Json.objectList(json, 'variants').map(WordVariant.fromJson).toList(growable: false),
      englishMeaning: Json.strOrNull(json, 'english_meaning'),
      definition: Json.strOrNull(json, 'definition'),
      exampleSentence: Json.strOrNull(json, 'example_sentence'),
      exampleTranslation: Json.strOrNull(json, 'example_translation'),
      partOfSpeech: Json.strOrNull(json, 'part_of_speech'),
      dialectOrVariation: Json.strOrNull(json, 'dialect_or_variation'),
      notes: Json.strOrNull(json, 'notes'),
      speaker: Json.strOrNull(json, 'speaker'),
      categoryId: Json.strOrNull(json, 'category_id'),
      phoneticRespelling: Json.strOrNull(json, 'phonetic_respelling'),
      ipa: Json.strOrNull(json, 'ipa'),
      tonePattern: Json.strOrNull(json, 'tone_pattern'),
      pluralForm: Json.strOrNull(json, 'plural_form'),
      singularForm: Json.strOrNull(json, 'singular_form'),
      literalTranslation: Json.strOrNull(json, 'literal_translation'),
      usageNotes: Json.strOrNull(json, 'usage_notes'),
      register: Json.strOrNull(json, 'register'),
      etymology: Json.strOrNull(json, 'etymology'),
      seeAlso: Json.strOrNull(json, 'see_also'),
      initialLetter: Json.strOrNull(json, 'initial_letter'),
    );
  }

  final String id;
  final String word;
  final String status;
  final String verificationStatus;
  final String entryType;

  /// A word may carry several recordings — different speakers, different
  /// variations. That is a feature of a language archive, not a duplicate.
  final List<Pronunciation> pronunciations;

  /// Every part of speech this word belongs to. A word can be a noun and a
  /// verb at once, and forcing a choice between them loses half the entry.
  final List<String> partsOfSpeech;

  /// The distinct meanings, numbered as a dictionary numbers them.
  final List<WordSense> senses;

  /// Sentences showing the word in use, in both languages.
  final List<WordExample> examples;

  /// Other forms: how a different quarter says it, an older form, a plural.
  final List<WordVariant> variants;

  // The flat fields, kept for entries recorded before senses existed. The
  // server mirrors sense 1 into them, so an older reader still sees the entry.
  final String? englishMeaning;
  final String? definition;
  final String? exampleSentence;
  final String? exampleTranslation;
  final String? partOfSpeech;
  final String? dialectOrVariation;
  final String? notes;
  final String? speaker;
  final String? categoryId;

  // How it sounds, written three ways for three kinds of reader: a respelling
  // anybody can say aloud, IPA for a linguist, and the tone pattern — which is
  // not optional in a tonal language, where two words differing only in tone
  // are two different words.
  final String? phoneticRespelling;
  final String? ipa;
  final String? tonePattern;

  final String? pluralForm;
  final String? singularForm;

  /// What the word literally says, where that differs from what it means.
  final String? literalTranslation;

  final String? usageNotes;
  final String? register;
  final String? etymology;
  final String? seeAlso;
  final String? initialLetter;

  bool get isVerified => verificationStatus == VerificationStatus.verified;
  bool get hasAudio => pronunciations.isNotEmpty;
  bool get hasVariants => variants.isNotEmpty;

  /// The senses to render, falling back to the flat fields for older entries.
  List<WordSense> get displaySenses {
    if (senses.isNotEmpty) return senses;
    if (englishMeaning == null && definition == null) return const <WordSense>[];
    return <WordSense>[
      WordSense(
        id: '$id-legacy',
        senseNumber: 1,
        partOfSpeech: partOfSpeech,
        englishMeaning: englishMeaning,
        definition: definition,
      ),
    ];
  }

  /// The examples to render, falling back to the flat pair.
  List<WordExample> get displayExamples {
    if (examples.isNotEmpty) return examples;
    if (exampleSentence == null) return const <WordExample>[];
    return <WordExample>[
      WordExample(
        id: '$id-legacy',
        sentenceEkoli: exampleSentence!,
        sentenceEnglish: exampleTranslation,
      ),
    ];
  }

  bool get hasMeaning => displaySenses.any((WordSense sense) => sense.hasMeaning);
  bool get hasExample => displayExamples.isNotEmpty;

  /// Parts of speech to label the entry with, merged from every source.
  List<String> get displayPartsOfSpeech {
    if (partsOfSpeech.isNotEmpty) return partsOfSpeech;
    final List<String> fromSenses = senses
        .map((WordSense sense) => sense.partOfSpeech)
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    if (fromSenses.isNotEmpty) return fromSenses;
    return partOfSpeech == null ? const <String>[] : <String>[partOfSpeech!];
  }

  /// Any of the ways the word's sound has been written down.
  String? get soundGuide => phoneticRespelling ?? ipa;

  String get entryTypeLabel => LanguageEntryTypes.label(entryType);
  String get verificationLabel => VerificationStatus.label(verificationStatus);

  /// What to show where no meaning has been supplied.
  ///
  /// The archive says so plainly rather than leaving an empty space that reads
  /// as an oversight — or worse, filling it with a guess.
  String get meaningOrPlaceholder {
    for (final WordSense sense in displaySenses) {
      if (sense.hasMeaning) return sense.englishMeaning!;
    }
    return 'Meaning not yet supplied by a native speaker.';
  }
}

/// One distinct meaning of a word, with its own part of speech.
class WordSense {
  const WordSense({
    required this.id,
    required this.senseNumber,
    this.partOfSpeech,
    this.englishMeaning,
    this.definition,
    this.usageNote,
    this.register,
    this.domain,
    this.verificationStatus = VerificationStatus.unverified,
  });

  factory WordSense.fromJson(Map<String, dynamic> json) {
    return WordSense(
      id: Json.str(json, 'id'),
      senseNumber: Json.intVal(json, 'sense_number', fallback: 1),
      partOfSpeech: Json.strOrNull(json, 'part_of_speech'),
      englishMeaning: Json.strOrNull(json, 'english_meaning'),
      definition: Json.strOrNull(json, 'definition'),
      usageNote: Json.strOrNull(json, 'usage_note'),
      register: Json.strOrNull(json, 'register'),
      domain: Json.strOrNull(json, 'domain'),
      verificationStatus: Json.str(
        json,
        'verification_status',
        fallback: VerificationStatus.unverified,
      ),
    );
  }

  final String id;
  final int senseNumber;
  final String? partOfSpeech;
  final String? englishMeaning;
  final String? definition;

  /// When and by whom this sense is used — a word said only by elders, or only
  /// at a funeral, is mis-taught without it.
  final String? usageNote;
  final String? register;
  final String? domain;
  final String verificationStatus;

  bool get hasMeaning => englishMeaning != null && englishMeaning!.trim().isNotEmpty;

  String get partOfSpeechLabel => PartsOfSpeech.label(partOfSpeech ?? '');
}

/// A sentence showing the word in use.
///
/// The pair matters, and so does the third field: a sentence in the language
/// with no pronunciation is half an example, because the reader can read it and
/// still not know what it sounds like.
class WordExample {
  const WordExample({
    required this.id,
    required this.sentenceEkoli,
    this.sentenceEnglish,
    this.pronunciation,
    this.audioUrl,
    this.speaker,
    this.contextNote,
  });

  factory WordExample.fromJson(Map<String, dynamic> json) {
    return WordExample(
      id: Json.str(json, 'id'),
      sentenceEkoli: Json.str(json, 'sentence_ekoli'),
      sentenceEnglish: Json.strOrNull(json, 'sentence_english'),
      pronunciation: Json.strOrNull(json, 'pronunciation'),
      audioUrl: Json.strOrNull(json, 'audio_url'),
      speaker: Json.strOrNull(json, 'speaker'),
      contextNote: Json.strOrNull(json, 'context_note'),
    );
  }

  final String id;
  final String sentenceEkoli;
  final String? sentenceEnglish;

  /// How the sentence is pronounced, written for somebody to read aloud.
  final String? pronunciation;

  /// A recording of the whole sentence — worth more than all three text fields.
  final String? audioUrl;

  final String? speaker;
  final String? contextNote;

  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;
}

/// Another form of the same word.
class WordVariant {
  const WordVariant({
    required this.id,
    required this.variant,
    required this.variantType,
    this.dialectOrArea,
    this.speaker,
    this.notes,
  });

  factory WordVariant.fromJson(Map<String, dynamic> json) {
    return WordVariant(
      id: Json.str(json, 'id'),
      variant: Json.str(json, 'variant'),
      variantType: Json.str(json, 'variant_type', fallback: 'alternate'),
      dialectOrArea: Json.strOrNull(json, 'dialect_or_area'),
      speaker: Json.strOrNull(json, 'speaker'),
      notes: Json.strOrNull(json, 'notes'),
    );
  }

  final String id;
  final String variant;
  final String variantType;

  /// Which quarter, family or age group says it this way.
  final String? dialectOrArea;
  final String? speaker;
  final String? notes;

  String get typeLabel => VariantTypes.label(variantType);
}

/// A pronunciation recording of the headword, stored in R2 under `language/`.
class Pronunciation {
  const Pronunciation({
    required this.id,
    required this.audioUrl,
    this.speaker,
    this.dialectOrVariation,
    this.notes,
    this.mimeType,
  });

  factory Pronunciation.fromJson(Map<String, dynamic> json) {
    return Pronunciation(
      id: Json.str(json, 'id'),
      audioUrl: Json.str(json, 'audio_url'),
      speaker: Json.strOrNull(json, 'speaker'),
      dialectOrVariation: Json.strOrNull(json, 'dialect_or_variation'),
      notes: Json.strOrNull(json, 'notes'),
      mimeType: Json.strOrNull(json, 'mime_type'),
    );
  }

  final String id;
  final String audioUrl;
  final String? speaker;
  final String? dialectOrVariation;
  final String? notes;
  final String? mimeType;

  String get speakerLabel => speaker ?? 'Speaker not recorded';
}

/// A grouping of language entries: greetings, numbers, family terms.
class LanguageCategory {
  const LanguageCategory({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    this.sortOrder = 0,
  });

  factory LanguageCategory.fromJson(Map<String, dynamic> json) {
    return LanguageCategory(
      id: Json.str(json, 'id'),
      slug: Json.str(json, 'slug'),
      name: Json.str(json, 'name'),
      description: Json.strOrNull(json, 'description'),
      sortOrder: Json.intVal(json, 'sort_order'),
    );
  }

  final String id;
  final String slug;
  final String name;
  final String? description;
  final int sortOrder;
}

/// One part of speech the dictionary recognises.
///
/// Served from the database rather than hard-coded, because Lokaa grammar is
/// not English grammar and the categories the community's language scholars
/// need should not require a deployment to add.
class PartOfSpeech {
  const PartOfSpeech({
    required this.slug,
    required this.label,
    this.abbreviation,
    this.description,
  });

  factory PartOfSpeech.fromJson(Map<String, dynamic> json) {
    return PartOfSpeech(
      slug: Json.str(json, 'slug'),
      label: Json.str(json, 'label'),
      abbreviation: Json.strOrNull(json, 'abbreviation'),
      description: Json.strOrNull(json, 'description'),
    );
  }

  final String slug;
  final String label;
  final String? abbreviation;
  final String? description;
}

/// One letter of the A–Z index, with how many entries sit behind it.
class DictionaryLetter {
  const DictionaryLetter({required this.letter, required this.total});

  factory DictionaryLetter.fromJson(Map<String, dynamic> json) {
    return DictionaryLetter(
      letter: Json.str(json, 'letter'),
      total: Json.intVal(json, 'total'),
    );
  }

  final String letter;
  final int total;

  bool get isEmpty => total == 0;
}

/// Everything the dictionary page needs before it can draw itself.
class DictionaryIndex {
  const DictionaryIndex({
    required this.letters,
    required this.partsOfSpeech,
    required this.categories,
    required this.coverage,
  });

  factory DictionaryIndex.fromJson(Map<String, dynamic> json) {
    return DictionaryIndex(
      letters: Json.objectList(json, 'letters')
          .map(DictionaryLetter.fromJson)
          .toList(growable: false),
      partsOfSpeech: Json.objectList(json, 'partsOfSpeech')
          .map(PartOfSpeech.fromJson)
          .toList(growable: false),
      categories: Json.objectList(json, 'categories')
          .map(LanguageCategory.fromJson)
          .toList(growable: false),
      coverage: DictionaryCoverage.fromJson(
        (json['coverage'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
    );
  }

  final List<DictionaryLetter> letters;
  final List<PartOfSpeech> partsOfSpeech;
  final List<LanguageCategory> categories;
  final DictionaryCoverage coverage;
}

/// How much of the language is actually recorded.
///
/// Shown plainly on the page. An archive that hides how empty it is cannot
/// credibly ask the community to help fill it.
class DictionaryCoverage {
  const DictionaryCoverage({
    required this.total,
    required this.published,
    required this.verified,
    required this.withoutMeaning,
    required this.withAudio,
    required this.withExample,
  });

  factory DictionaryCoverage.fromJson(Map<String, dynamic> json) {
    return DictionaryCoverage(
      total: Json.intVal(json, 'total'),
      published: Json.intVal(json, 'published'),
      verified: Json.intVal(json, 'verified'),
      withoutMeaning: Json.intVal(json, 'withoutMeaning'),
      withAudio: Json.intVal(json, 'withAudio'),
      withExample: Json.intVal(json, 'withExample'),
    );
  }

  final int total;
  final int published;
  final int verified;
  final int withoutMeaning;
  final int withAudio;
  final int withExample;

  bool get isEmpty => total == 0;
}

/// The filters a visitor can narrow the dictionary by.
///
/// Held as one object so the page can pass a single value to the repository and
/// use it as the cache key that decides when to reload.
class DictionaryQuery {
  const DictionaryQuery({
    this.search,
    this.letter,
    this.categoryId,
    this.entryType,
    this.partOfSpeech,
    this.verifiedOnly = false,
    this.hasAudio = false,
    this.hasExample = false,
    this.sortByRecent = false,
    this.page = 1,
  });

  final String? search;
  final String? letter;
  final String? categoryId;
  final String? entryType;
  final String? partOfSpeech;
  final bool verifiedOnly;
  final bool hasAudio;
  final bool hasExample;
  final bool sortByRecent;
  final int page;

  DictionaryQuery copyWith({
    String? search,
    String? letter,
    String? categoryId,
    String? entryType,
    String? partOfSpeech,
    bool? verifiedOnly,
    bool? hasAudio,
    bool? hasExample,
    bool? sortByRecent,
    int? page,
    bool clearSearch = false,
    bool clearLetter = false,
    bool clearCategory = false,
    bool clearEntryType = false,
    bool clearPartOfSpeech = false,
  }) {
    return DictionaryQuery(
      search: clearSearch ? null : (search ?? this.search),
      letter: clearLetter ? null : (letter ?? this.letter),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      entryType: clearEntryType ? null : (entryType ?? this.entryType),
      partOfSpeech: clearPartOfSpeech ? null : (partOfSpeech ?? this.partOfSpeech),
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      hasAudio: hasAudio ?? this.hasAudio,
      hasExample: hasExample ?? this.hasExample,
      sortByRecent: sortByRecent ?? this.sortByRecent,
      // Any change to a filter returns to page 1: staying on page 4 of a
      // narrower result set shows an empty page and reads as a broken search.
      page: page ?? 1,
    );
  }

  bool get hasFilters =>
      letter != null ||
      categoryId != null ||
      entryType != null ||
      partOfSpeech != null ||
      verifiedOnly ||
      hasAudio ||
      hasExample;

  /// A stable key for the widget that reloads when the query changes.
  String get cacheKey =>
      '$search|$letter|$categoryId|$entryType|$partOfSpeech|$verifiedOnly|$hasAudio|$hasExample|$sortByRecent|$page';
}
