import '../core/config/app_config.dart';
import '../models/forum.dart';
import '../services/api/api_client.dart';
import '../services/api/api_response.dart';

/// THE YAKOLI FORUMS.
///
/// Every access decision is the server's. This class asks and renders the
/// answer; it never decides for itself whether somebody may read a space or
/// post in it. That matters most in the two spaces that may contain minors:
/// a members-only space answers "not found" rather than "forbidden" to an
/// anonymous caller, so its contents are not probeable, and a client that
/// second-guessed that would undo it.
class ForumRepository {
  const ForumRepository(this._api);

  final ApiClient _api;

  /// The spaces, and whether the caller may enter each.
  ///
  /// Unauthenticated on purpose: the general space is public and a visitor
  /// arriving from a WhatsApp link should be able to read it before being
  /// asked to sign in for anything.
  Future<List<ForumSpace>> spaces() async {
    final Map<String, dynamic> data = await _api.get('/api/forums', authenticated: false);
    return (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ForumSpace.fromJson)
        .toList(growable: false);
  }

  /// One space, with its shelves and its conversations.
  Future<ForumSpaceView> space(
    String slug, {
    int page = 1,
    int perPage = AppConfig.defaultPageSize,
    String? category,
    String? query,
  }) async {
    final Map<String, dynamic> data = await _api.get(
      '/api/forums/$slug',
      query: <String, dynamic>{
        'page': page,
        'perPage': perPage,
        'category': ?category,
        'q': ?query,
      },
    );
    return ForumSpaceView.fromJson(data);
  }

  /// One conversation with its replies.
  Future<ForumTopicView> topic(String space, String topic) async {
    final Map<String, dynamic> data = await _api.get('/api/forums/$space/topics/$topic');
    return ForumTopicView.fromJson(data);
  }

  /// Starts a conversation.
  ///
  /// Returns the slug to open and the message to show. A space that holds new
  /// conversations for a moderator says so in that message rather than leaving
  /// the author to wonder why their post is not on the list.
  Future<({String slug, String status, String message})> createTopic(
    String space, {
    required String title,
    required String body,
    required String categoryId,
  }) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/forums/$space/topics',
      body: <String, dynamic>{'title': title, 'body': body, 'category_id': categoryId},
    );

    return (
      slug: data['slug']?.toString() ?? '',
      status: data['status']?.toString() ?? 'published',
      message: data['message']?.toString() ?? 'Posted.',
    );
  }

  Future<void> reply(
    String space,
    String topic, {
    required String body,
    String? parentPostId,
  }) => _api.post(
    '/api/forums/$space/topics/$topic/replies',
    body: <String, dynamic>{'body': body, 'parent_post_id': ?parentPostId},
  );

  /// Edits your own reply. The server stamps the edit.
  Future<void> editPost(String postId, String body) =>
      _api.patch('/api/forums/posts/$postId', body: <String, dynamic>{'body': body});

  /// Adds or removes a reaction. Returns where it now stands, so a screen can
  /// show the truth rather than assuming the press worked.
  Future<bool> react(
    String targetType,
    String id, {
    String kind = 'appreciate',
  }) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/forums/$targetType/$id/react',
      body: <String, dynamic>{'kind': kind},
    );
    return data['reacted'] == true;
  }

  /// Follows or unfollows a conversation. Returns where it now stands.
  Future<bool> follow(String topicId) async {
    final Map<String, dynamic> data = await _api.post('/api/forums/topics/$topicId/follow');
    return data['following'] == true;
  }

  /// Reports a topic or a reply.
  ///
  /// One press and a reason. Somebody being harassed should not have to write
  /// an essay about it first, which is why `detail` is optional everywhere.
  Future<String> report(
    String targetType,
    String id, {
    required String reason,
    String? detail,
  }) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/forums/$targetType/$id/report',
      body: <String, dynamic>{'reason': reason, 'detail': ?detail},
    );
    return data['message']?.toString() ?? 'The moderators have been told.';
  }

  // --- Moderation ----------------------------------------------------------

  Future<PaginatedResult<ForumReport>> reports({
    String status = 'open',
    int page = 1,
    int perPage = AppConfig.defaultPageSize,
  }) {
    return _api.list<ForumReport>(
      '/api/forums/admin/reports',
      ForumReport.fromJson,
      query: <String, dynamic>{'status': status, 'page': page, 'perPage': perPage},
    );
  }

  /// Hide, remove, restore, lock, unlock, pin, unpin, approve.
  ///
  /// The reason is passed on to the moderation log, which is append-only —
  /// "who removed my post, and why?" has to have an answer somebody else can
  /// check.
  Future<void> moderate({
    required String action,
    required String targetType,
    required String targetId,
    String? reason,
  }) => _api.post(
    '/api/forums/admin/moderate',
    body: <String, dynamic>{
      'action': action,
      'target_type': targetType,
      'target_id': targetId,
      'reason': ?reason,
    },
  );

  Future<void> settleReport(String id, {required String status, String? notes}) => _api.post(
    '/api/forums/admin/reports/$id/settle',
    body: <String, dynamic>{'status': status, 'notes': ?notes},
  );

  /// A warning, a suspension or a ban. The member is always told which, and
  /// when it ends.
  Future<void> sanction({
    required String userId,
    required String kind,
    String? reason,
    String? spaceId,
    int? days,
  }) => _api.post(
    '/api/forums/admin/sanctions',
    body: <String, dynamic>{
      'user_id': userId,
      'kind': kind,
      'reason': ?reason,
      'space_id': ?spaceId,
      'days': ?days,
    },
  );

  /// The moderation log — readable by every moderator, not only the one who
  /// acted.
  Future<List<ForumModerationAction>> moderationLog() async {
    final Map<String, dynamic> data = await _api.get('/api/forums/admin/actions');
    return (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ForumModerationAction.fromJson)
        .toList(growable: false);
  }
}
