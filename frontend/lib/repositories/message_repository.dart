import '../core/config/app_config.dart';
import '../models/content_status.dart';
import '../models/message.dart';
import '../services/api/api_client.dart';
import '../services/api/api_response.dart';

/// MESSAGES BETWEEN MEMBERS.
///
/// One rule governs every method here: *you can reach somebody without being
/// given their number*. Search returns names, conversations return messages,
/// and neither returns a way to contact anybody off this platform.
///
/// Asking for somebody's phone number is a separate, explicit act at the bottom
/// of this file, and the answer belongs to them.
class MessageRepository {
  const MessageRepository(this._api);

  final ApiClient _api;

  /// My conversations, newest activity first.
  Future<PaginatedResult<Conversation>> conversations({
    int page = 1,
    int perPage = AppConfig.defaultPageSize,
  }) {
    return _api.list<Conversation>(
      '/api/messages',
      Conversation.fromJson,
      query: <String, dynamic>{'page': page, 'perPage': perPage},
    );
  }

  /// The badge number, and nothing else.
  Future<int> unread() async {
    final Map<String, dynamic> data = await _api.get('/api/messages/unread');
    return Json.intVal(data, 'unread');
  }

  /// Members you could write to, by name.
  ///
  /// This is the search that makes the whole feature usable: type a name, find
  /// the person, write to them. It carries no contact details at all.
  Future<List<MessagePerson>> findPeople(String query) async {
    final Map<String, dynamic> data = await _api.get(
      '/api/messages/people',
      query: <String, dynamic>{'q': query},
    );

    return (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(MessagePerson.fromJson)
        .toList(growable: false);
  }

  /// Opens the conversation with somebody, or finds the one already there.
  ///
  /// Idempotent: pressing "message" twice does not produce two threads.
  Future<Conversation> open({String? handle, String? userId}) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/messages/conversations',
      body: <String, dynamic>{'handle': ?handle, 'user_id': ?userId},
    );
    return Conversation.fromJson(data);
  }

  /// One conversation and its messages. Reading it marks it read.
  Future<ConversationThread> thread(
    String id, {
    int page = 1,
    int perPage = 50,
  }) async {
    final Map<String, dynamic> data = await _api.get(
      '/api/messages/$id',
      query: <String, dynamic>{'page': page, 'perPage': perPage},
    );
    return ConversationThread.fromJson(data);
  }

  Future<void> send(String conversationId, String body, {String? mediaId}) => _api.post(
    '/api/messages/$conversationId',
    body: <String, dynamic>{'body': body, 'media_id': ?mediaId},
  );

  Future<int> markRead(String conversationId) async {
    final Map<String, dynamic> data = await _api.post('/api/messages/$conversationId/read');
    return Json.intVal(data, 'unread');
  }

  /// Archive, mute or block — on your own side only. Putting a thread away
  /// does not remove the other person's record of it.
  Future<void> update(
    String conversationId, {
    bool? archived,
    bool? muted,
    bool? blocked,
  }) => _api.patch(
    '/api/messages/$conversationId',
    body: <String, dynamic>{
      'is_archived': ?archived,
      'is_muted': ?muted,
      'is_blocked': ?blocked,
    },
  );

  // --- Asking for somebody's contact details --------------------------------

  /// "May I have your number?"
  ///
  /// Sends a request with a reason. Nothing of theirs is shared until they say
  /// yes, and being declined is final — which is what makes "no" mean
  /// something.
  Future<String> requestContact({
    String? handle,
    String? userId,
    String? reason,
    bool wantsPhone = true,
    bool wantsEmail = false,
  }) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/messages/contact-requests',
      body: <String, dynamic>{
        'handle': ?handle,
        'user_id': ?userId,
        'reason': ?reason,
        'wants_phone': wantsPhone,
        'wants_email': wantsEmail,
      },
    );
    return Json.str(data, 'message', fallback: 'Asked.');
  }

  /// Requests waiting on me, what I have asked, and who holds my details.
  Future<ContactRequestInbox> contactRequests() async {
    final Map<String, dynamic> data = await _api.get('/api/messages/contact-requests');
    return ContactRequestInbox.fromJson(data);
  }

  /// Yes, or no. Only the person being asked can call this.
  Future<String> decide(
    String requestId, {
    required bool approve,
    bool? sharePhone,
    bool? shareEmail,
    String? note,
  }) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/messages/contact-requests/$requestId/decide',
      body: <String, dynamic>{
        'decision': approve ? 'approve' : 'decline',
        'share_phone': ?sharePhone,
        'share_email': ?shareEmail,
        'note': ?note,
      },
    );
    return Json.str(data, 'message', fallback: 'Saved.');
  }

  /// Taking it back. Effective on the next request — the grant is read on every
  /// profile rather than cached anywhere.
  Future<void> revoke(String viewerId) =>
      _api.delete('/api/messages/contact-grants/$viewerId');
}
