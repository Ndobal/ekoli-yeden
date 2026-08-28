import '../core/config/app_config.dart';
import '../models/ancestry.dart';
import '../services/api/api_client.dart';
import '../services/api/api_response.dart';

/// REMEMBRANCE, AND THE ANCESTRY RECORDS.
///
/// ---------------------------------------------------------------------------
/// THE ORDER OF THESE METHODS IS THE ORDER OF THE PROCESS, AND THAT MATTERS
/// ---------------------------------------------------------------------------
///
/// `report` is a claim and changes nothing. `confirm` requires somebody who was
/// already family — a relationship accepted before the report was made — and is
/// what stills the account. `contest` is the account holder saying they are
/// here, and restores everything at once, with no review and no deadline.
/// `publishMemorial` is the Preservation Team deciding the archive should carry
/// a page, which is a different statement again.
///
/// Recording a living person as dead is the most damaging thing anybody can do
/// on this platform. Nothing in this class should ever be collapsed into fewer
/// steps for convenience.
class RemembranceRepository {
  const RemembranceRepository(this._api);

  final ApiClient _api;

  // --- The ancestry records -------------------------------------------------

  /// Everybody the archive remembers. Public — no account needed.
  Future<PaginatedResult<AncestryRecord>> ancestry({
    int page = 1,
    int perPage = AppConfig.defaultPageSize,
    String? query,
    String? groupId,
  }) {
    return _api.list<AncestryRecord>(
      '/api/ancestry',
      AncestryRecord.fromJson,
      authenticated: false,
      query: <String, dynamic>{
        'page': page,
        'perPage': perPage,
        'q': ?query,
        'group': ?groupId,
      },
    );
  }

  Future<AncestryRecord> record(String slug) async {
    final Map<String, dynamic> data =
        await _api.get('/api/ancestry/$slug', authenticated: false);
    return AncestryRecord.fromJson(data);
  }

  /// Leaves a tribute. It appears at once — a condolence that arrives three
  /// days later, after the burial, has missed what it was for.
  Future<String> leaveTribute(
    String slug, {
    required String message,
    String? relationship,
  }) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/ancestry/$slug/tributes',
      body: <String, dynamic>{'message': message, 'relationship': ?relationship},
    );
    return data['message']?.toString() ?? 'Thank you.';
  }

  // --- A member acting on their own account ---------------------------------

  /// What this account is told, if anything. Null for almost everybody.
  Future<MemorialNotice?> notice() async {
    final Map<String, dynamic> data = await _api.get('/api/membership/remembrance/notice');
    final Object? notice = data['notice'];
    if (notice is! Map<String, dynamic>) return null;
    return MemorialNotice.fromJson(notice);
  }

  /// "I am not dead."
  ///
  /// Restores the account immediately. There is no deadline on this and no
  /// review before it takes effect: wrongly restoring a genuinely deceased
  /// account for a day costs nothing next to a living person being unable to
  /// undo it.
  Future<String> contest({String? note}) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/membership/remembrance/contest',
      body: <String, dynamic>{'note': ?note},
    );
    return data['message']?.toString() ?? 'Your account has been restored.';
  }

  /// Records that somebody has died. A claim, and nothing more, until family
  /// confirm it.
  Future<String> report({
    required String subjectName,
    String? subjectUserId,
    String? relationship,
    String? groupId,
    String? dateOfDeath,
    String? placeOfDeath,
    String? detail,
  }) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/membership/remembrance/reports',
      body: <String, dynamic>{
        'subject_name': subjectName,
        'subject_user_id': ?subjectUserId,
        'relationship': ?relationship,
        'group_id': ?groupId,
        'date_of_death': ?dateOfDeath,
        'place_of_death': ?placeOfDeath,
        'detail': ?detail,
      },
    );
    return data['message']?.toString() ?? 'Recorded. The family will be asked to confirm it.';
  }

  /// Confirms a report. The server checks that the relationship existed before
  /// the report was made; this only asks.
  Future<String> confirm(String reportId, {String? note}) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/membership/remembrance/reports/$reportId/confirm',
      body: <String, dynamic>{'note': ?note},
    );
    return data['message']?.toString() ?? 'Confirmed.';
  }

  // --- The Preservation Team ------------------------------------------------

  Future<PaginatedResult<DeathReport>> reports({
    String state = 'reported',
    int page = 1,
    int perPage = AppConfig.defaultPageSize,
  }) {
    return _api.list<DeathReport>(
      '/api/admin/remembrance',
      DeathReport.fromJson,
      query: <String, dynamic>{'state': state, 'page': page, 'perPage': perPage},
    );
  }

  /// Publishes the memorial. Returns the slug of the page it created.
  Future<String> publishMemorial(
    String reportId, {
    String? biography,
    int? birthYear,
    String? groupId,
  }) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/admin/remembrance/$reportId/publish',
      body: <String, dynamic>{
        'biography': ?biography,
        'birth_year': ?birthYear,
        'group_id': ?groupId,
      },
    );
    return data['slug']?.toString() ?? '';
  }

  /// The undo, available at every stage. Restores the account.
  Future<void> reject(String reportId, {String? reason}) =>
      _api.post('/api/admin/remembrance/$reportId/reject', body: <String, dynamic>{
        'reason': ?reason,
      });
}
