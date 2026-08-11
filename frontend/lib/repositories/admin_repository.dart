import '../core/config/app_config.dart';
import '../models/content_record.dart';
import '../services/api/api_client.dart';
import '../services/api/api_response.dart';

/// Administration: the dashboard, users, roles and the audit trail.
class AdminRepository {
  const AdminRepository(this._api);

  final ApiClient _api;

  /// Counts per content type and status, and the moderation queue.
  ///
  /// Every number is zero on a fresh installation, which is the correct state
  /// for an archive the community has not yet filled.
  Future<DashboardSummary> dashboard() async {
    final Map<String, dynamic> data = await _api.get('/api/admin/dashboard');
    return DashboardSummary.fromJson(data);
  }

  Future<PaginatedResult<ContentRecord>> users({
    int page = 1,
    int perPage = AppConfig.defaultPageSize,
    String? search,
  }) {
    return _api.list<ContentRecord>(
      '/api/admin/users',
      ContentRecord.fromJson,
      query: <String, dynamic>{
        'page': page,
        'perPage': perPage,
        if (search != null && search.isNotEmpty) 'q': search,
      },
    );
  }

  Future<Map<String, dynamic>> createUser({
    required String email,
    required String displayName,
    required String password,
    List<String> roles = const <String>[],
    String? preservationTeamPosition,
  }) {
    return _api.post(
      '/api/admin/users',
      body: <String, dynamic>{
        'email': email,
        'display_name': displayName,
        'password': password,
        'roles': roles,
        'preservation_team_position': ?preservationTeamPosition,
      },
    );
  }

  Future<Map<String, dynamic>> updateUser(String id, Map<String, dynamic> values) {
    return _api.patch('/api/admin/users/$id', body: values);
  }

  Future<void> assignRole(String userId, String role) async {
    await _api.post('/api/admin/users/$userId/roles', body: <String, dynamic>{'role': role});
  }

  Future<void> revokeRole(String userId, String role) async {
    await _api.delete('/api/admin/users/$userId/roles/$role');
  }

  /// The platform roles, together with the Preservation Team structure.
  Future<RolesResponse> roles() async {
    final Map<String, dynamic> data = await _api.get('/api/admin/roles');
    return RolesResponse.fromJson(data);
  }

  Future<void> changeOwnPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.post(
      '/api/admin/account/password',
      body: <String, dynamic>{'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  Future<PaginatedResult<ContentRecord>> auditLogs({
    int page = 1,
    int perPage = AppConfig.defaultPageSize,
    String? resourceType,
    String? search,
  }) {
    return _api.list<ContentRecord>(
      '/api/admin/audit-logs',
      ContentRecord.fromJson,
      query: <String, dynamic>{
        'page': page,
        'perPage': perPage,
        'resource_type': ?resourceType,
        if (search != null && search.isNotEmpty) 'q': search,
      },
    );
  }
}

class DashboardSummary {
  const DashboardSummary({
    required this.environment,
    required this.publishedRecords,
    required this.awaitingReview,
    required this.pendingSubmissions,
    required this.registeredUsers,
    required this.content,
    required this.media,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> summary =
        (json['summary'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final List<dynamic> content = (json['content'] as List<dynamic>?) ?? const <dynamic>[];

    return DashboardSummary(
      environment: json['environment'] as String? ?? 'development',
      publishedRecords: (summary['publishedRecords'] as num?)?.toInt() ?? 0,
      awaitingReview: (summary['awaitingReview'] as num?)?.toInt() ?? 0,
      pendingSubmissions: (summary['pendingSubmissions'] as num?)?.toInt() ?? 0,
      registeredUsers: (summary['registeredUsers'] as num?)?.toInt() ?? 0,
      content: content
          .whereType<Map<String, dynamic>>()
          .map(ContentTypeCount.fromJson)
          .toList(growable: false),
      media: _counts(json['media']),
    );
  }

  final String environment;
  final int publishedRecords;
  final int awaitingReview;
  final int pendingSubmissions;
  final int registeredUsers;
  final List<ContentTypeCount> content;
  final Map<String, int> media;

  int get mediaTotal => media.values.fold(0, (int sum, int value) => sum + value);

  /// True on a fresh installation, which the dashboard says plainly rather
  /// than showing a wall of zeros with no explanation.
  bool get archiveIsEmpty => publishedRecords == 0 && mediaTotal == 0;

  static Map<String, int> _counts(dynamic value) {
    if (value is! Map<String, dynamic>) return const <String, int>{};
    return value.map<String, int>(
      (String key, dynamic count) => MapEntry<String, int>(key, (count as num?)?.toInt() ?? 0),
    );
  }
}

class ContentTypeCount {
  const ContentTypeCount({
    required this.resource,
    required this.label,
    required this.byStatus,
  });

  factory ContentTypeCount.fromJson(Map<String, dynamic> json) {
    return ContentTypeCount(
      resource: json['resource'] as String? ?? '',
      label: json['label'] as String? ?? '',
      byStatus: DashboardSummary._counts(json['byStatus']),
    );
  }

  final String resource;
  final String label;
  final Map<String, int> byStatus;

  int get total => byStatus.values.fold(0, (int sum, int value) => sum + value);
  int get published => byStatus['published'] ?? 0;
  int get pending => byStatus['pending_review'] ?? 0;
  int get drafts => byStatus['draft'] ?? 0;
}

class RolesResponse {
  const RolesResponse({required this.roles, required this.preservationTeam});

  factory RolesResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> roles = (json['roles'] as List<dynamic>?) ?? const <dynamic>[];
    final List<dynamic> team = (json['preservationTeam'] as List<dynamic>?) ?? const <dynamic>[];
    return RolesResponse(
      roles: roles.whereType<Map<String, dynamic>>().map(RoleDefinition.fromJson).toList(growable: false),
      preservationTeam: team.whereType<Map<String, dynamic>>().toList(growable: false),
    );
  }

  final List<RoleDefinition> roles;
  final List<Map<String, dynamic>> preservationTeam;
}

class RoleDefinition {
  const RoleDefinition({
    required this.id,
    required this.slug,
    required this.name,
    required this.permissions,
    this.description,
  });

  factory RoleDefinition.fromJson(Map<String, dynamic> json) {
    final List<dynamic> permissions = (json['permissions'] as List<dynamic>?) ?? const <dynamic>[];
    return RoleDefinition(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      permissions: permissions.map((dynamic item) => item.toString()).toList(growable: false),
      description: json['description'] as String?,
    );
  }

  final String id;
  final String slug;
  final String name;
  final List<String> permissions;
  final String? description;
}
