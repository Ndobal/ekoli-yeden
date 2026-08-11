import '../core/config/app_config.dart';
import '../models/content_record.dart';
import '../services/api/api_client.dart';
import '../services/api/api_response.dart';

/// Reads and writes any of the archive's content types.
///
/// The API exposes the same shape for every content type — that is what the
/// content registry on the Worker buys us — so one repository serves history,
/// leaders, people, news, events, galleries, businesses, organizations and
/// community projects. `resource` is the URL segment: `history`, `leaders`, …
class ContentRepository {
  const ContentRepository(this._api, this.resource);

  final ApiClient _api;
  final String resource;

  // --- Public reads ---------------------------------------------------------

  /// Published records only. Anonymous — no token is sent.
  Future<PaginatedResult<ContentRecord>> list({
    int page = 1,
    int perPage = AppConfig.defaultPageSize,
    String? search,
    String? category,
    String? sort,
    String? order,
  }) {
    return _api.list<ContentRecord>(
      '/api/$resource',
      ContentRecord.fromJson,
      authenticated: false,
      query: <String, dynamic>{
        'page': page,
        'perPage': perPage,
        if (search != null && search.isNotEmpty) 'q': search,
        if (category != null && category.isNotEmpty) 'category': category,
        'sort': ?sort,
        'order': ?order,
      },
    );
  }

  /// One published record, by slug or id.
  Future<ContentRecord> find(String identifier) async {
    final Map<String, dynamic> data = await _api.get(
      '/api/$resource/$identifier',
      authenticated: false,
    );
    return ContentRecord.fromJson(data);
  }

  // --- Admin ----------------------------------------------------------------

  /// Every status, for editors. The server checks the permission.
  Future<PaginatedResult<ContentRecord>> adminList({
    int page = 1,
    int perPage = AppConfig.defaultPageSize,
    String? status,
    String? search,
    String? sort,
    String? order,
  }) {
    return _api.list<ContentRecord>(
      '/api/admin/$resource',
      ContentRecord.fromJson,
      query: <String, dynamic>{
        'page': page,
        'perPage': perPage,
        if (status != null && status.isNotEmpty) 'status': status,
        if (search != null && search.isNotEmpty) 'q': search,
        'sort': ?sort,
        'order': ?order,
      },
    );
  }

  Future<ContentRecord> adminFind(String identifier) async {
    final Map<String, dynamic> data = await _api.get('/api/admin/$resource/$identifier');
    return ContentRecord.fromJson(data);
  }

  Future<ContentRecord> create(Map<String, dynamic> values) async {
    final Map<String, dynamic> data = await _api.post('/api/admin/$resource', body: values);
    return ContentRecord.fromJson(data);
  }

  Future<ContentRecord> update(String id, Map<String, dynamic> values) async {
    final Map<String, dynamic> data = await _api.patch('/api/admin/$resource/$id', body: values);
    return ContentRecord.fromJson(data);
  }

  /// Moves an entry through the editorial workflow.
  ///
  /// Kept separate from `update` because publishing is a distinct act with its
  /// own permission and its own audit entry on the server.
  Future<ContentRecord> changeStatus(String id, String status) async {
    final Map<String, dynamic> data = await _api.patch(
      '/api/admin/$resource/$id/status',
      body: <String, dynamic>{'status': status},
    );
    return ContentRecord.fromJson(data);
  }

  Future<void> delete(String id) async {
    await _api.delete('/api/admin/$resource/$id');
  }
}
