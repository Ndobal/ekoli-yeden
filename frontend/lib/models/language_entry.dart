import '../core/constants/app_constants.dart';
import 'content_status.dart';

/// An entry in the Ekoli language dictionary.
///
/// Every field here is supplied by a native speaker or a recognised Ekoli
/// language scholar. The platform never generates, guesses or completes the
/// meaning of an Ekoli word — an entry whose meaning nobody has confirmed is
/// shown as awaiting verification, with the field left empty.
class LanguageEntry {
  const LanguageEntry({
    required this.id,
    required this.word,
    required this.status,
    required this.verificationStatus,
    required this.entryType,
    required this.pronunciations,
    this.englishMeaning,
    this.definition,
    this.exampleSentence,
    this.exampleTranslation,
    this.partOfSpeech,
    this.dialectOrVariation,
    this.notes,
    this.speaker,
    this.categoryId,
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
      englishMeaning: Json.strOrNull(json, 'english_meaning'),
      definition: Json.strOrNull(json, 'definition'),
      exampleSentence: Json.strOrNull(json, 'example_sentence'),
      exampleTranslation: Json.strOrNull(json, 'example_translation'),
      partOfSpeech: Json.strOrNull(json, 'part_of_speech'),
      dialectOrVariation: Json.strOrNull(json, 'dialect_or_variation'),
      notes: Json.strOrNull(json, 'notes'),
      speaker: Json.strOrNull(json, 'speaker'),
      categoryId: Json.strOrNull(json, 'category_id'),
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

  final String? englishMeaning;
  final String? definition;
  final String? exampleSentence;
  final String? exampleTranslation;
  final String? partOfSpeech;
  final String? dialectOrVariation;
  final String? notes;
  final String? speaker;
  final String? categoryId;

  bool get isVerified => verificationStatus == VerificationStatus.verified;
  bool get hasAudio => pronunciations.isNotEmpty;
  bool get hasMeaning => englishMeaning != null && englishMeaning!.trim().isNotEmpty;
  bool get hasExample => exampleSentence != null && exampleSentence!.trim().isNotEmpty;

  String get entryTypeLabel => LanguageEntryTypes.label(entryType);
  String get verificationLabel => VerificationStatus.label(verificationStatus);

  /// What to show where the meaning has not been supplied.
  ///
  /// The archive says so plainly rather than leaving an empty space that reads
  /// as an oversight — or worse, filling it with a guess.
  String get meaningOrPlaceholder =>
      hasMeaning ? englishMeaning! : 'Meaning not yet supplied by a native speaker.';
}

/// A pronunciation recording, stored in R2 under `language/`.
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
