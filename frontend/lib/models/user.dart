import '../core/constants/app_constants.dart';
import 'content_status.dart';

/// The signed-in user.
///
/// `permissions` is a mirror of what the server granted, used only to decide
/// which controls to draw. Every permission is checked again by the Worker on
/// every request, so hiding a button is a courtesy, not a security measure.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.status,
    required this.roles,
    required this.permissions,
    this.preservationTeamPosition,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: Json.str(json, 'id'),
      email: Json.str(json, 'email'),
      displayName: Json.str(json, 'displayName', fallback: Json.str(json, 'display_name')),
      status: Json.str(json, 'status', fallback: 'active'),
      roles: Json.stringList(json, 'roles'),
      permissions: Json.stringList(json, 'permissions').toSet(),
      preservationTeamPosition: Json.strOrNull(json, 'preservation_team_position'),
    );
  }

  final String id;
  final String email;
  final String displayName;
  final String status;
  final List<String> roles;
  final Set<String> permissions;
  final String? preservationTeamPosition;

  bool get isSuperAdmin => roles.contains(AppRoles.superAdmin);

  /// Super Admin holds the `*` wildcard and passes every check.
  ///
  /// This mirrors the server's decision so the interface can hide controls the
  /// caller cannot use. It is presentation only — the Worker re-decides every
  /// request, and hiding a button prevents confusion, not access.
  bool can(String permission) =>
      permissions.contains('*') || permissions.contains(permission);

  bool canAny(Iterable<String> candidates) => candidates.any(can);

  bool hasRole(String role) => roles.contains(role);

  /// True when the account may reach the administration area.
  ///
  /// Deliberately narrow: administration means users, roles, security, audit
  /// and settings. An Editorial Team member has none of those and must not see
  /// the interface for them.
  bool get canAccessAdmin =>
      isSuperAdmin ||
      canAny(const <String>[
        'users.manage',
        'roles.manage',
        'permissions.manage',
        'security.manage',
        'settings.manage',
        'audit.view',
      ]);

  /// True when the account may reach the editorial area.
  ///
  /// Anyone who can create, edit, review or publish content, or who can change
  /// the website's text. A plain Contributor cannot: they submit material
  /// through the public form and follow it by reference code, nothing more.
  bool get canAccessEditorial =>
      isSuperAdmin ||
      canAny(const <String>[
        'content.create',
        'content.edit',
        'content.read',
        'content.review',
        'content.publish',
        'content.manage',
        'pages.edit',
        'homepage.edit',
        'navigation.edit',
        'sources.manage',
      ]);

  /// Whether this account may make content live. Withheld from Writers and
  /// Editors so that writing and publishing stay separate acts.
  bool get canPublish => can('content.publish') || can('content.manage');

  bool get canReview => can('content.review') || can('content.manage');

  String get roleSummary => roles.isEmpty
      ? AppRoles.label(AppRoles.contributor)
      : roles.map(AppRoles.label).join(', ');

  /// Initials for the avatar placeholder.
  String get initials {
    final List<String> parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}
