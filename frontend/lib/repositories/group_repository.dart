import '../core/config/app_config.dart';
import '../models/community_group.dart';
import '../models/content_status.dart';
import '../services/api/api_client.dart';
import '../services/api/api_response.dart';

/// COMMUNITY GROUPS.
///
/// Age grades, cultural groups, associations. The server decides what the
/// caller may see and do on every request; nothing here is a permission check,
/// only a request for what the caller is entitled to.
class GroupRepository {
  const GroupRepository(this._api);

  final ApiClient _api;

  /// The groups of Ekoli-Yeden, optionally narrowed to one kind.
  Future<PaginatedResult<CommunityGroup>> list({
    int page = 1,
    int perPage = AppConfig.defaultPageSize,
    String? kind,
    String? query,
  }) {
    return _api.list<CommunityGroup>(
      '/api/groups',
      CommunityGroup.fromJson,
      authenticated: false,
      query: <String, dynamic>{
        'page': page,
        'perPage': perPage,
        'kind': ?kind,
        'q': ?query,
      },
    );
  }

  /// One group, with everything the caller's standing in it entitles them to.
  ///
  /// Sent authenticated where possible: the same URL returns more to a member
  /// than to a visitor, and more again to an officer.
  Future<CommunityGroup> show(String identifier, {bool authenticated = true}) async {
    final Map<String, dynamic> data = await _api.get(
      '/api/groups/$identifier',
      authenticated: authenticated,
    );
    return CommunityGroup.fromJson(data);
  }

  /// What a group may be, and how joining one can work.
  Future<({List<({String value, String label})> kinds, List<({String value, String label})> policies})>
      kinds() async {
    final Map<String, dynamic> data = await _api.get('/api/groups/kinds', authenticated: false);

    List<({String value, String label})> read(String key) => Json.objectList(data, key)
        .map((Map<String, dynamic> row) => (
              value: Json.str(row, 'value'),
              label: Json.str(row, 'label'),
            ))
        .toList(growable: false);

    return (kinds: read('kinds'), policies: read('joinPolicies'));
  }

  /// "Which age grade is mine?", answered for the dashboard.
  Future<GroupSuggestions> suggestions() async {
    final Map<String, dynamic> data = await _api.get('/api/membership/groups/suggestions');
    return GroupSuggestions.fromJson(data);
  }

  Future<({String id, String slug, String message})> create({
    required String kind,
    required String title,
    String? subtitle,
    String? motto,
    String? excerpt,
    String? body,
    int? formedYear,
    int? birthYearFrom,
    int? birthYearTo,
    String joinPolicy = 'by_request',
    String? contactName,
    String? contactPhone,
    String? contactEmail,
  }) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/groups',
      body: <String, dynamic>{
        'kind': kind,
        'title': title,
        'subtitle': ?subtitle,
        'motto': ?motto,
        'excerpt': ?excerpt,
        'body': ?body,
        'formed_year': ?formedYear,
        'birth_year_from': ?birthYearFrom,
        'birth_year_to': ?birthYearTo,
        'join_policy': joinPolicy,
        'contact_name': ?contactName,
        'contact_phone': ?contactPhone,
        'contact_email': ?contactEmail,
      },
    );

    return (
      id: Json.str(data, 'id'),
      slug: Json.str(data, 'slug'),
      message: Json.str(data, 'message', fallback: 'Registered.'),
    );
  }

  Future<void> update(String id, Map<String, dynamic> values) =>
      _api.patch('/api/groups/$id', body: values);

  /// Ask to join, or join outright where the group allows it.
  Future<({String state, String message})> join(String id, {String? note}) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/groups/$id/join',
      body: <String, dynamic>{'note': ?note},
    );
    return (
      state: Json.str(data, 'state', fallback: 'requested'),
      message: Json.str(data, 'message', fallback: 'Asked.'),
    );
  }

  Future<List<Map<String, dynamic>>> joinRequests(String id) async {
    final Map<String, dynamic> data = await _api.get('/api/groups/$id/requests');
    return Json.objectList(data, 'items');
  }

  Future<void> decideRequest(String memberId, {required bool accept}) =>
      _api.post('/api/groups/members/$memberId/decide', body: <String, dynamic>{'accept': accept});

  Future<void> addOfficer(String id, {required String handle, required String role, String? office}) =>
      _api.post(
        '/api/groups/$id/officers',
        body: <String, dynamic>{'handle': handle, 'admin_role': role, 'office': ?office},
      );

  Future<void> removeOfficer(String id, String userId) =>
      _api.delete('/api/groups/$id/officers/$userId');

  // --- Money ---------------------------------------------------------------

  Future<void> addPaymentAccount(
    String id, {
    required String bankName,
    required String accountName,
    required String accountNumber,
    String? label,
    String? instructions,
    String visibility = 'members',
    bool isPrimary = true,
  }) =>
      _api.post(
        '/api/groups/$id/accounts',
        body: <String, dynamic>{
          'bank_name': bankName,
          'account_name': accountName,
          'account_number': accountNumber,
          'label': ?label,
          'instructions': ?instructions,
          'visibility': visibility,
          'is_primary': isPrimary,
        },
      );

  Future<void> updatePaymentAccount(String id, String accountId, Map<String, dynamic> values) =>
      _api.patch('/api/groups/$id/accounts/$accountId', body: values);

  Future<List<Map<String, dynamic>>> accountHistory(String id) async {
    final Map<String, dynamic> data = await _api.get('/api/groups/$id/accounts/history');
    return Json.objectList(data, 'items');
  }

  /// Records a payment the member says they have made.
  ///
  /// No money passes through the platform. This is a shared ledger so that the
  /// member and the treasurer are looking at the same list.
  Future<void> declareDues(
    String id, {
    required double amount,
    String? periodLabel,
    String? paidOn,
    String method = 'bank_transfer',
    String? reference,
    String? note,
  }) =>
      _api.post(
        '/api/groups/$id/dues',
        body: <String, dynamic>{
          'amount': amount,
          'period_label': ?periodLabel,
          'paid_on': ?paidOn,
          'method': method,
          'reference': ?reference,
          'note': ?note,
        },
      );

  Future<({List<DuesPayment> items, List<Map<String, dynamic>> summary})> dues(
    String id, {
    String? state,
  }) async {
    final Map<String, dynamic> data = await _api.get(
      '/api/groups/$id/dues',
      query: <String, dynamic>{'state': ?state},
    );

    return (
      items: Json.objectList(data, 'items').map(DuesPayment.fromJson).toList(growable: false),
      summary: Json.objectList(data, 'summary'),
    );
  }

  Future<void> settleDues(String paymentId, {required String state, String? note}) =>
      _api.post(
        '/api/groups/dues/$paymentId/settle',
        body: <String, dynamic>{'state': state, 'officer_note': ?note},
      );

  // --- Issues --------------------------------------------------------------

  Future<void> raiseIssue(
    String id, {
    required String kind,
    required String subject,
    String? detail,
    bool isPrivate = true,
  }) =>
      _api.post(
        '/api/groups/$id/issues',
        body: <String, dynamic>{
          'kind': kind,
          'subject': subject,
          'detail': ?detail,
          'is_private': isPrivate,
        },
      );

  Future<({List<GroupIssue> items, bool isOfficer})> issues(String id) async {
    final Map<String, dynamic> data = await _api.get('/api/groups/$id/issues');
    return (
      items: Json.objectList(data, 'items').map(GroupIssue.fromJson).toList(growable: false),
      isOfficer: Json.boolVal(data, 'is_officer'),
    );
  }

  Future<void> settleIssue(String issueId, {required String state, String? resolution}) =>
      _api.post(
        '/api/groups/issues/$issueId/settle',
        body: <String, dynamic>{'state': state, 'resolution': ?resolution},
      );
}
