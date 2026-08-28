import '../core/config/app_config.dart';
import '../models/opportunity.dart';
import '../services/api/api_client.dart';
import '../services/api/api_response.dart';

/// YAKOLI OPPORTUNITIES.
///
/// The server does the matching. It holds both the member's skills and each
/// listing's, and it can order thousands of rows in SQL rather than shipping
/// them all here to be sorted in a browser on a phone.
class OpportunityRepository {
  const OpportunityRepository(this._api);

  final ApiClient _api;

  /// The board, already ordered for whoever is asking.
  Future<PaginatedResult<Opportunity>> list({
    int page = 1,
    int perPage = AppConfig.defaultPageSize,
    String? kind,
    String? tier,
    String? query,
    bool savedOnly = false,
  }) {
    return _api.list<Opportunity>(
      '/api/opportunities',
      Opportunity.fromJson,
      query: <String, dynamic>{
        'page': page,
        'perPage': perPage,
        'kind': ?kind,
        'tier': ?tier,
        'q': ?query,
        if (savedOnly) 'saved': 'true',
      },
    );
  }

  Future<Opportunity> show(String identifier) async {
    final Map<String, dynamic> data = await _api.get('/api/opportunities/$identifier');
    return Opportunity.fromJson(data);
  }

  Future<OpportunityOptions> options() async {
    final Map<String, dynamic> data =
        await _api.get('/api/opportunities/options', authenticated: false);
    return OpportunityOptions.fromJson(data);
  }

  Future<void> save(String id) => _api.post('/api/opportunities/$id/save');

  Future<void> unsave(String id) => _api.delete('/api/opportunities/$id/save');

  /// "This is a scam." One press from the listing.
  ///
  /// Enough independent reports take a listing down automatically, without
  /// waiting for a reviewer to be awake — a wrongly hidden listing costs
  /// somebody a few hours, a fraudulent one costs somebody their money.
  Future<void> report(String id, {required String reason, String? detail}) => _api.post(
        '/api/opportunities/$id/report',
        body: <String, dynamic>{'reason': reason, 'detail': ?detail},
      );

  /// Posts a listing. It goes to review before anybody sees it.
  Future<String> create(Map<String, dynamic> values) async {
    final Map<String, dynamic> data = await _api.post('/api/opportunities', body: values);
    return data['message']?.toString() ?? 'Submitted for review.';
  }

  // --- The reviewer's side --------------------------------------------------

  /// Listings waiting on somebody, by workflow status.
  Future<PaginatedResult<Opportunity>> forReview({
    String status = 'pending_review',
    int page = 1,
    int perPage = AppConfig.defaultPageSize,
  }) {
    return _api.list<Opportunity>(
      '/api/admin/opportunities',
      Opportunity.fromJson,
      query: <String, dynamic>{'status': status, 'page': page, 'perPage': perPage},
    );
  }

  /// What members have reported, with the listing each one is about.
  Future<List<OpportunityReport>> reports({String state = 'open'}) async {
    final Map<String, dynamic> data = await _api.get(
      '/api/admin/opportunities/reports',
      query: <String, dynamic>{'state': state},
    );

    return (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(OpportunityReport.fromJson)
        .toList(growable: false);
  }

  /// Publish, reject, verify, or take a flag off.
  ///
  /// Verifying is a claim the archive makes with its own name on it — that
  /// somebody checked this listing is real — which is why it is a separate
  /// action from publishing rather than a side effect of it.
  Future<void> decide(
    String id, {
    String? status,
    String? verificationStatus,
    bool? isFlagged,
    String? flagReason,
  }) => _api.patch(
    '/api/admin/opportunities/$id',
    body: <String, dynamic>{
      'status': ?status,
      'verification_status': ?verificationStatus,
      'is_flagged': ?isFlagged,
      'flag_reason': ?flagReason,
    },
  );

  Future<void> settleReport(String id, {required String state, String? note}) => _api.post(
    '/api/admin/opportunities/reports/$id/settle',
    body: <String, dynamic>{'state': state, 'note': ?note},
  );
}
