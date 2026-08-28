import '../core/config/app_config.dart';
import '../models/age_grade.dart';
import '../models/content_status.dart';
import '../services/api/api_client.dart';
import '../services/api/api_response.dart';

/// AGE GRADES.
///
/// The one part of the archive a community member runs themselves. A grade
/// registers, waits for the Preservation Team to confirm it, and from then on
/// its own administrators add its members, its photographs and its news.
///
/// Every write here is authorised by the Worker on a single question — does
/// this person administer *this* grade? — which grants nothing anywhere else.
class AgeGradeRepository {
  const AgeGradeRepository(this._api);

  final ApiClient _api;

  // --- Reading --------------------------------------------------------------

  Future<PaginatedResult<AgeGrade>> list({
    int page = 1,
    int perPage = AppConfig.defaultPageSize,
    String? search,
  }) {
    return _api.list<AgeGrade>(
      '/api/age-grades',
      AgeGrade.fromJson,
      authenticated: false,
      query: <String, dynamic>{
        'page': page,
        'perPage': perPage,
        if (search != null && search.isNotEmpty) 'q': search,
      },
    );
  }

  /// One grade with its posts, its roster and its photographs.
  Future<AgeGrade> grade(String identifier) async {
    final Map<String, dynamic> data = await _api.get(
      '/api/age-grades/$identifier',
      authenticated: false,
    );
    return AgeGrade.fromJson(data);
  }

  Future<AgeGradePost> post(String gradeSlug, String postSlug) async {
    final Map<String, dynamic> data = await _api.get(
      '/api/age-grades/$gradeSlug/posts/$postSlug',
      authenticated: false,
    );
    return AgeGradePost.fromJson(data);
  }

  Future<PaginatedResult<AgeGradePost>> posts(String identifier, {int page = 1}) {
    return _api.list<AgeGradePost>(
      '/api/age-grades/$identifier/posts',
      AgeGradePost.fromJson,
      authenticated: false,
      query: <String, dynamic>{'page': page},
    );
  }

  /// The most recent posts across every published grade.
  ///
  /// What makes the section index a living thing rather than a list of names.
  Future<List<AgeGradePost>> activity() async {
    final Map<String, dynamic> data = await _api.get(
      '/api/age-grades-activity',
      authenticated: false,
    );
    return Json.objectList(data, 'items').map(AgeGradePost.fromJson).toList(growable: false);
  }

  // --- Running a grade ------------------------------------------------------

  /// The grades the signed-in person administers.
  Future<List<AgeGrade>> mine() async {
    final Map<String, dynamic> data = await _api.get('/api/my/age-grades');
    return Json.objectList(data, 'items').map(AgeGrade.fromJson).toList(growable: false);
  }

  /// Registers a grade. The registrar becomes its lead administrator.
  Future<({String id, String slug, String message})> register({
    required String title,
    int? formedYear,
    String? subtitle,
    String? birthYears,
    String? excerpt,
    String? body,
    String? motto,
    String? office,
    String? contactName,
    String? contactPhone,
    String? contactEmail,
  }) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/age-grades',
      body: <String, dynamic>{
        'title': title,
        'formed_year': ?formedYear,
        'subtitle': ?subtitle,
        'birth_years': ?birthYears,
        'excerpt': ?excerpt,
        'body': ?body,
        'motto': ?motto,
        'office': ?office,
        'contact_name': ?contactName,
        'contact_phone': ?contactPhone,
        'contact_email': ?contactEmail,
      },
    );

    return (
      id: Json.str(data, 'id'),
      slug: Json.str(data, 'slug'),
      message: Json.str(
        data,
        'message',
        fallback: 'Your age grade has been registered and is waiting to be confirmed.',
      ),
    );
  }

  /// Everything about a grade, drafts included, for somebody who runs it.
  Future<AgeGradeWorkspace> workspace(String identifier) async {
    final Map<String, dynamic> data = await _api.get('/api/age-grades/$identifier/manage');
    return AgeGradeWorkspace.fromJson(data);
  }

  Future<void> updateGrade(
    String identifier, {
    String? title,
    String? subtitle,
    int? formedYear,
    String? birthYears,
    String? excerpt,
    String? body,
    String? motto,
    String? contactName,
    String? contactPhone,
    String? contactEmail,
  }) {
    return _api.patch(
      '/api/age-grades/$identifier',
      body: <String, dynamic>{
        'title': ?title,
        'subtitle': ?subtitle,
        'formed_year': ?formedYear,
        'birth_years': ?birthYears,
        'excerpt': ?excerpt,
        'body': ?body,
        'motto': ?motto,
        'contact_name': ?contactName,
        'contact_phone': ?contactPhone,
        'contact_email': ?contactEmail,
      },
    );
  }

  // --- Posts ----------------------------------------------------------------

  Future<({AgeGradePost post, String message})> createPost(
    String identifier, {
    required String title,
    String? body,
    String? excerpt,
    String postType = 'update',
    String? eventDate,
  }) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/age-grades/$identifier/posts',
      body: <String, dynamic>{
        'title': title,
        'body': ?body,
        'excerpt': ?excerpt,
        'post_type': postType,
        'event_date': ?eventDate,
      },
    );

    return (
      post: AgeGradePost.fromJson(data),
      message: Json.str(data, 'message', fallback: 'Posted.'),
    );
  }

  Future<void> updatePost(
    String identifier,
    String postId, {
    String? title,
    String? body,
    String? excerpt,
    String? postType,
    String? eventDate,
    String? status,
  }) {
    return _api.patch(
      '/api/age-grades/$identifier/posts/$postId',
      body: <String, dynamic>{
        'title': ?title,
        'body': ?body,
        'excerpt': ?excerpt,
        'post_type': ?postType,
        'event_date': ?eventDate,
        'status': ?status,
      },
    );
  }

  Future<void> deletePost(String identifier, String postId) {
    return _api.delete('/api/age-grades/$identifier/posts/$postId');
  }

  // --- People ---------------------------------------------------------------

  /// Appoints another administrator by email address.
  ///
  /// By email because a lead knows their age-mate's email and has no way to
  /// know an internal identifier. The account has to exist already — creating
  /// one on somebody's behalf is an administrative act, not a grade's to make.
  Future<String> appointAdmin(
    String identifier, {
    required String email,
    String adminRole = 'admin',
    String? office,
  }) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/age-grades/$identifier/admins',
      body: <String, dynamic>{'email': email, 'admin_role': adminRole, 'office': ?office},
    );
    return Json.str(data, 'message', fallback: 'They can now help run this page.');
  }

  Future<void> removeAdmin(String identifier, String userId) {
    return _api.delete('/api/age-grades/$identifier/admins/$userId');
  }

  Future<AgeGradeMember> addMember(
    String identifier, {
    required String fullName,
    String? office,
    int? joinedYear,
    String? notes,
    bool isDeceased = false,
    int? deceasedYear,
  }) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/age-grades/$identifier/members',
      body: <String, dynamic>{
        'full_name': fullName,
        'office': ?office,
        'joined_year': ?joinedYear,
        'notes': ?notes,
        'is_deceased': isDeceased,
        'deceased_year': ?deceasedYear,
      },
    );
    return AgeGradeMember.fromJson(data);
  }

  Future<void> removeMember(String identifier, String memberId) {
    return _api.delete('/api/age-grades/$identifier/members/$memberId');
  }
}
