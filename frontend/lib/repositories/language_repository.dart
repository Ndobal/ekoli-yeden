import '../core/config/app_config.dart';
import '../models/language_entry.dart';
import '../services/api/api_client.dart';
import '../services/api/api_response.dart';

/// The Ekoli Digital Language Academy.
///
/// Search works in both directions — the API searches the Ekoli word and its
/// English meaning in the same query — so a visitor can look up either.
class LanguageRepository {
  const LanguageRepository(this._api);

  final ApiClient _api;

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
    final List<dynamic> raw = (data['words'] as List<dynamic>?) ?? const <dynamic>[];
    return (
      category: LanguageCategory.fromJson(
        (data['category'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      words: raw
          .whereType<Map<String, dynamic>>()
          .map(LanguageEntry.fromJson)
          .toList(growable: false),
    );
  }
}
