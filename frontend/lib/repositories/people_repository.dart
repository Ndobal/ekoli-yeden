import '../core/config/app_config.dart';
import '../models/content_status.dart';
import '../models/submissions.dart';
import '../services/api/api_client.dart';
import '../services/api/api_response.dart';

/// CONTRIBUTING A PERSON.
///
/// The People section holds structured records, so a contribution to it is a
/// structured profile rather than a title and a description. The same reasoning
/// that gave dictionary words their own form: when the destination is
/// structured, an unstructured contribution gets taken apart by whoever reviews
/// it — badly, and from memory.
class PeopleRepository {
  const PeopleRepository(this._api);

  final ApiClient _api;

  /// Sends a profile for review. Returns the reference the contributor keeps.
  Future<String> submitProfile(Map<String, dynamic> values) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/contribute/person',
      body: values,
    );
    return Json.str(data, 'reference', fallback: 'EY-000000');
  }

  /// The categories and consent bases the builder offers.
  Future<({List<({String value, String label})> categories, List<({String value, String label})> consentBases})>
      formOptions() async {
    final Map<String, dynamic> data =
        await _api.get('/api/contribute/person/form', authenticated: false);

    List<({String value, String label})> read(String key) => Json.objectList(data, key)
        .map((Map<String, dynamic> row) =>
            (value: Json.str(row, 'value'), label: Json.str(row, 'label')))
        .toList(growable: false);

    return (categories: read('categories'), consentBases: read('consentBases'));
  }

  /// What happened to a profile somebody sent in.
  Future<({String status, String explanation, String? reviewNotes})> status(
    String reference,
  ) async {
    final Map<String, dynamic> data = await _api.get(
      '/api/contribute/person/$reference',
      authenticated: false,
    );

    return (
      status: Json.str(data, 'status'),
      explanation: Json.str(data, 'explanation'),
      reviewNotes: Json.strOrNull(data, 'review_notes'),
    );
  }

  // --- The Heritage Team's queue --------------------------------------------

  Future<PaginatedResult<PersonSubmission>> submissions({
    String status = 'pending_review',
    int page = 1,
    int perPage = AppConfig.defaultPageSize,
  }) {
    return _api.list<PersonSubmission>(
      '/api/admin/person-submissions',
      PersonSubmission.fromJson,
      query: <String, dynamic>{'status': status, 'page': page, 'perPage': perPage},
    );
  }

  /// Publishes the profile.
  ///
  /// The copy is field for field, because the submission was built to match the
  /// destination. The server refuses if the person may be living and nobody has
  /// recorded how the archive may publish them — that is not a validation
  /// nicety, it is the whole reason the consent column exists.
  Future<String> promote(String id) async {
    final Map<String, dynamic> data =
        await _api.post('/api/admin/person-submissions/$id/promote');
    return Json.strOrNull(data, 'slug') ?? '';
  }

  /// Ask for more, mark it a duplicate, or decline it.
  Future<void> review(String id, {required String status, String? notes}) => _api.post(
    '/api/admin/person-submissions/$id/review',
    body: <String, dynamic>{'status': status, 'review_notes': ?notes},
  );
}
