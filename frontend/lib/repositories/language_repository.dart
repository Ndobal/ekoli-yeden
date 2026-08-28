import '../core/config/app_config.dart';
import '../models/content_status.dart';
import '../models/language_entry.dart';
import '../services/api/api_client.dart';
import '../services/api/api_response.dart';

/// THE DICTIONARY.
///
/// Search works in both directions and across the whole entry: the headword,
/// its variant forms, every sense, and the example sentences. A visitor
/// usually knows the form their own family says rather than the form an editor
/// chose as the headword, so matching only headwords would fail exactly the
/// person the dictionary exists for.
class LanguageRepository {
  const LanguageRepository(this._api);

  final ApiClient _api;

  /// A page of the dictionary, narrowed by whatever the visitor has selected.
  Future<PaginatedResult<LanguageEntry>> search(
    DictionaryQuery query, {
    int perPage = AppConfig.defaultPageSize,
  }) {
    return _api.list<LanguageEntry>(
      '/api/language',
      LanguageEntry.fromJson,
      authenticated: false,
      query: <String, dynamic>{
        'page': query.page,
        'perPage': perPage,
        if (query.search != null && query.search!.isNotEmpty) 'q': query.search,
        'letter': ?query.letter,
        'category_id': ?query.categoryId,
        'entry_type': ?query.entryType,
        'part_of_speech': ?query.partOfSpeech,
        if (query.verifiedOnly) 'verification_status': 'verified',
        if (query.hasAudio) 'has_audio': 'true',
        if (query.hasExample) 'has_example': 'true',
        if (query.sortByRecent) 'sort': 'recent',
      },
    );
  }

  /// Kept for the simpler callers — the homepage strip and the search page.
  Future<PaginatedResult<LanguageEntry>> entries({
    int page = 1,
    int perPage = AppConfig.defaultPageSize,
    String? search,
    String? categoryId,
    String? entryType,
    String? verificationStatus,
  }) {
    return _api.list<LanguageEntry>(
      '/api/language',
      LanguageEntry.fromJson,
      authenticated: false,
      query: <String, dynamic>{
        'page': page,
        'perPage': perPage,
        if (search != null && search.isNotEmpty) 'q': search,
        'category_id': ?categoryId,
        'entry_type': ?entryType,
        'verification_status': ?verificationStatus,
      },
    );
  }

  Future<LanguageEntry> entry(String id) async {
    final Map<String, dynamic> data = await _api.get('/api/language/$id', authenticated: false);
    return LanguageEntry.fromJson(data);
  }

  /// Everything the dictionary page needs before it can draw itself: the A–Z
  /// index with counts, the parts of speech, the categories, and how much of
  /// the language is recorded so far. One request rather than four.
  Future<DictionaryIndex> index() async {
    final Map<String, dynamic> data = await _api.get(
      '/api/language/index',
      authenticated: false,
    );
    return DictionaryIndex.fromJson(data);
  }

  Future<List<LanguageCategory>> categories() async {
    final PaginatedResult<LanguageCategory> result = await _api.list<LanguageCategory>(
      '/api/language/categories',
      LanguageCategory.fromJson,
      authenticated: false,
      query: <String, dynamic>{'perPage': 100},
    );
    return result.items;
  }

  /// A category together with every published word inside it.
  Future<({LanguageCategory category, List<LanguageEntry> words})> category(String slug) async {
    final Map<String, dynamic> data = await _api.get(
      '/api/language/categories/$slug',
      authenticated: false,
    );
    return (
      category: LanguageCategory.fromJson(
        (data['category'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      words: Json.objectList(data, 'words').map(LanguageEntry.fromJson).toList(growable: false),
    );
  }

  // --- Contributing a word --------------------------------------------------

  /// What the contribution form offers: the parts of speech, the categories and
  /// the kinds of variant. Served from the database rather than hard-coded, so
  /// the community's language scholars can add a category without a deployment.
  Future<WordFormOptions> contributionOptions() async {
    final Map<String, dynamic> data = await _api.get(
      '/api/contribute/word/form',
      authenticated: false,
    );
    return WordFormOptions.fromJson(data);
  }

  /// Proposes a dictionary entry.
  ///
  /// The whole entry travels at once — variants, parts of speech, meanings,
  /// sentences — in the shape the dictionary stores, so a language editor
  /// reviews something that already reads like an entry.
  Future<WordSubmissionReceipt> contributeWord({
    required String word,
    required List<Map<String, dynamic>> senses,
    String entryType = 'word',
    List<String> partsOfSpeech = const <String>[],
    List<Map<String, dynamic>> variants = const <Map<String, dynamic>>[],
    List<Map<String, dynamic>> examples = const <Map<String, dynamic>>[],
    String? phoneticRespelling,
    String? tonePattern,
    String? literalTranslation,
    String? usageNotes,
    String? dialectOrArea,
    String? categoryId,
    String? audioUploadId,
    String? contributorName,
    String? contributorEmail,
    String? contributorPhone,
    String? speakerCredentials,
  }) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/contribute/word',
      // Contributing requires a membership; the request has to carry the
      // session or it is refused before it is read.
      authenticated: true,
      body: <String, dynamic>{
        'word': word,
        'entry_type': entryType,
        'consent_given': true,
        'parts_of_speech': partsOfSpeech,
        'senses': senses,
        'variants': variants,
        'examples': examples,
        'phonetic_respelling': ?phoneticRespelling,
        'tone_pattern': ?tonePattern,
        'literal_translation': ?literalTranslation,
        'usage_notes': ?usageNotes,
        'dialect_or_area': ?dialectOrArea,
        'category_id': ?categoryId,
        'audio_upload_id': ?audioUploadId,
        'contributor_name': ?contributorName,
        'contributor_email': ?contributorEmail,
        'contributor_phone': ?contributorPhone,
        'speaker_credentials': ?speakerCredentials,
      },
    );
    return WordSubmissionReceipt.fromJson(data);
  }

  // --- The language editor's side -------------------------------------------

  /// Entries the community has proposed, awaiting a language editor.
  ///
  /// Each row carries whether the dictionary already holds the word, so a
  /// reviewer merges rather than creating a duplicate they have to find later.
  Future<List<ProposedWord>> wordSubmissions({String status = 'pending_review'}) async {
    final PaginatedResult<ProposedWord> result = await _api.list<ProposedWord>(
      '/api/admin/word-submissions',
      ProposedWord.fromJson,
      query: <String, dynamic>{'status': status, 'perPage': 50},
    );
    return result.items;
  }

  /// Turns a proposal into a draft dictionary entry, crediting the contributor.
  ///
  /// It arrives as a draft and unverified: accepting a contribution says "this
  /// is worth having", not "this is what the word means".
  Future<String> promoteWord(String id, {String? notes}) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/admin/word-submissions/$id/promote',
      body: <String, dynamic>{'review_notes': ?notes},
    );
    return Json.str(data, 'message', fallback: 'Added to the dictionary as a draft.');
  }

  Future<String> rejectWord(String id, {String? notes}) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/admin/word-submissions/$id/reject',
      body: <String, dynamic>{'review_notes': ?notes},
    );
    return Json.str(data, 'message', fallback: 'Marked as not accepted.');
  }

  /// Progress on a proposed entry, by the reference code the contributor keeps.
  Future<({String word, String status, bool published})> wordStatus(String reference) async {
    final Map<String, dynamic> data = await _api.get(
      '/api/contribute/word/$reference',
      authenticated: false,
    );
    return (
      word: Json.str(data, 'word'),
      status: Json.str(data, 'status'),
      published: Json.boolVal(data, 'published'),
    );
  }
}

/// The vocabulary the word contribution form offers.
class WordFormOptions {
  const WordFormOptions({
    required this.partsOfSpeech,
    required this.categories,
    required this.variantTypes,
    required this.guidance,
  });

  factory WordFormOptions.fromJson(Map<String, dynamic> json) {
    return WordFormOptions(
      partsOfSpeech: Json.objectList(json, 'partsOfSpeech')
          .map(PartOfSpeech.fromJson)
          .toList(growable: false),
      categories: Json.objectList(json, 'categories')
          .map(LanguageCategory.fromJson)
          .toList(growable: false),
      variantTypes: Json.objectList(json, 'variantTypes')
          .map(
            (Map<String, dynamic> item) => (
              value: Json.str(item, 'value'),
              label: Json.str(item, 'label'),
            ),
          )
          .toList(growable: false),
      guidance: Json.stringList(json, 'guidance'),
    );
  }

  final List<PartOfSpeech> partsOfSpeech;
  final List<LanguageCategory> categories;
  final List<({String value, String label})> variantTypes;

  /// What to tell a contributor before they start, in the archive's own words.
  final List<String> guidance;
}

/// A dictionary entry the community has proposed, as a reviewer sees it.
///
/// Already in the shape of an entry — variants, parts of speech, meanings,
/// sentences — so accepting it is one action rather than a re-typing.
class ProposedWord {
  const ProposedWord({
    required this.id,
    required this.referenceCode,
    required this.word,
    required this.entryType,
    required this.status,
    required this.senses,
    required this.examples,
    required this.variants,
    required this.partsOfSpeech,
    this.phoneticRespelling,
    this.tonePattern,
    this.literalTranslation,
    this.usageNotes,
    this.dialectOrArea,
    this.contributorName,
    this.contributorEmail,
    this.contributorPhone,
    this.speakerCredentials,
    this.createdAt,
    this.existingEntryId,
    this.existingEntryWord,
  });

  factory ProposedWord.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? existing = json['existing_entry'] as Map<String, dynamic>?;

    return ProposedWord(
      id: Json.str(json, 'id'),
      referenceCode: Json.str(json, 'reference_code'),
      word: Json.str(json, 'word'),
      entryType: Json.str(json, 'entry_type', fallback: 'word'),
      status: Json.str(json, 'status', fallback: 'pending_review'),
      senses: Json.objectList(json, 'senses'),
      examples: Json.objectList(json, 'examples'),
      variants: Json.objectList(json, 'variants'),
      partsOfSpeech: Json.stringList(json, 'parts_of_speech'),
      phoneticRespelling: Json.strOrNull(json, 'phonetic_respelling'),
      tonePattern: Json.strOrNull(json, 'tone_pattern'),
      literalTranslation: Json.strOrNull(json, 'literal_translation'),
      usageNotes: Json.strOrNull(json, 'usage_notes'),
      dialectOrArea: Json.strOrNull(json, 'dialect_or_area'),
      contributorName: Json.strOrNull(json, 'contributor_name'),
      contributorEmail: Json.strOrNull(json, 'contributor_email'),
      contributorPhone: Json.strOrNull(json, 'contributor_phone'),
      speakerCredentials: Json.strOrNull(json, 'speaker_credentials'),
      createdAt: Json.strOrNull(json, 'created_at'),
      // Set when the dictionary already holds this word. Not a rejection: a
      // second speaker confirming a meaning, or giving another, is worth having.
      existingEntryId: existing == null ? null : Json.strOrNull(existing, 'id'),
      existingEntryWord: existing == null ? null : Json.strOrNull(existing, 'word'),
    );
  }

  final String id;
  final String referenceCode;
  final String word;
  final String entryType;
  final String status;
  final List<Map<String, dynamic>> senses;
  final List<Map<String, dynamic>> examples;
  final List<Map<String, dynamic>> variants;
  final List<String> partsOfSpeech;
  final String? phoneticRespelling;
  final String? tonePattern;
  final String? literalTranslation;
  final String? usageNotes;
  final String? dialectOrArea;

  /// Who supplied it, and how they know it. A word's authority rests on this,
  /// which is why it is the part a language editor reads first.
  final String? contributorName;
  final String? contributorEmail;
  final String? contributorPhone;
  final String? speakerCredentials;

  final String? createdAt;
  final String? existingEntryId;
  final String? existingEntryWord;

  bool get duplicatesExistingEntry => existingEntryId != null;

  /// The meanings as plain lines, for a reviewer scanning the queue.
  List<String> get meanings => senses
      .map((Map<String, dynamic> sense) => Json.strOrNull(sense, 'english_meaning'))
      .whereType<String>()
      .toList(growable: false);
}

/// The confirmation a contributor keeps.
class WordSubmissionReceipt {
  const WordSubmissionReceipt({
    required this.referenceCode,
    required this.message,
    this.alreadyRecordedWord,
  });

  factory WordSubmissionReceipt.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? existing = json['alreadyRecorded'] as Map<String, dynamic>?;
    return WordSubmissionReceipt(
      referenceCode: Json.str(json, 'referenceCode'),
      message: Json.str(json, 'message', fallback: 'Thank you. A language editor will check this.'),
      alreadyRecordedWord: existing == null ? null : Json.strOrNull(existing, 'word'),
    );
  }

  final String referenceCode;
  final String message;

  /// Set when the dictionary already holds this word. Not a rejection: a second
  /// speaker confirming a meaning, or giving another one, is worth having.
  final String? alreadyRecordedWord;

  bool get addsToExistingEntry => alreadyRecordedWord != null;
}
