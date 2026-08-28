/// MESSAGES BETWEEN MEMBERS.
///
/// ---------------------------------------------------------------------------
/// NOTHING IN THIS FILE CARRIES A PHONE NUMBER OR AN EMAIL ADDRESS
/// ---------------------------------------------------------------------------
///
/// That is not an omission to be tidied up later. The whole messaging module
/// exists to make one thing true — *you can reach somebody without being given
/// their number* — and a search result or a conversation header that carried a
/// contact detail would quietly undo it on the first screen.
///
/// Contact details live on a profile, behind two gates: the member switching
/// them on for everybody, or the member saying yes to one particular person who
/// asked. See `ContactRequest` at the bottom of this file, and `contact_grants`
/// in the Worker.
library;

import 'content_status.dart';

/// One conversation, as it appears in the list.
class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    required this.other,
    this.lastMessageText,
    this.lastMessageAt,
    this.lastMessageIsMine = false,
    this.unreadCount = 0,
    this.isMuted = false,
    this.isBlocked = false,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: Json.str(json, 'id'),
    title: Json.str(json, 'title', fallback: 'A member'),
    other: MessagePerson.fromJson(json['other'] as Map<String, dynamic>?),
    lastMessageText: Json.strOrNull(json, 'last_message_text'),
    lastMessageAt: Json.strOrNull(json, 'last_message_at'),
    lastMessageIsMine: Json.boolVal(json, 'last_message_is_mine'),
    unreadCount: Json.intVal(json, 'unread_count'),
    isMuted: Json.boolVal(json, 'is_muted'),
    isBlocked: Json.boolVal(json, 'is_blocked'),
  );

  final String id;
  final String title;
  final MessagePerson other;
  final String? lastMessageText;
  final String? lastMessageAt;

  /// Whether the last line was written by the reader. Shown as "You: …", which
  /// is the difference between a thread waiting on you and one you left.
  final bool lastMessageIsMine;

  final int unreadCount;
  final bool isMuted;
  final bool isBlocked;

  bool get hasUnread => unreadCount > 0;

  /// A conversation opened but not yet spoken in.
  bool get isEmpty => lastMessageAt == null;
}

/// Somebody you are talking to, or could talk to.
///
/// A name, a handle, a headline, where they are from. Deliberately nothing
/// else — see the note at the top of this file.
class MessagePerson {
  const MessagePerson({
    required this.userId,
    required this.name,
    this.handle,
    this.headline,
    this.from,
    this.avatarUrl,
    this.acceptsMessages = true,
  });

  factory MessagePerson.fromJson(Map<String, dynamic>? json) => json == null
      ? const MessagePerson(userId: '', name: 'A member')
      : MessagePerson(
          userId: Json.str(json, 'user_id'),
          name: Json.str(json, 'name', fallback: 'A member'),
          handle: Json.strOrNull(json, 'handle'),
          headline: Json.strOrNull(json, 'headline'),
          from: Json.strOrNull(json, 'from'),
          avatarUrl: Json.strOrNull(json, 'avatar_url'),
          acceptsMessages: Json.boolVal(json, 'accepts_messages', fallback: true),
        );

  final String userId;
  final String name;
  final String? handle;
  final String? headline;

  /// Where in Ekori they are from, in their own words. The one piece of
  /// context that helps somebody recognise a name they half-remember.
  final String? from;

  final String? avatarUrl;

  /// Said in the search result rather than discovered on send: somebody who has
  /// closed their messages should show as unreachable before you write four
  /// paragraphs to them.
  final bool acceptsMessages;

  String get initials {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return parts.first.substring(0, 1).toUpperCase() +
        parts.last.substring(0, 1).toUpperCase();
  }
}

/// One message.
class Message {
  const Message({
    required this.id,
    required this.body,
    required this.senderName,
    this.senderId,
    this.isMine = false,
    this.status = 'sent',
    this.mediaUrl,
    this.mediaName,
    this.mediaType,
    this.editedAt,
    this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: Json.str(json, 'id'),
    body: Json.str(json, 'body'),
    senderName: Json.str(json, 'sender_name', fallback: 'A member'),
    senderId: Json.strOrNull(json, 'sender_id'),
    isMine: Json.boolVal(json, 'is_mine'),
    status: Json.str(json, 'status', fallback: 'sent'),
    mediaUrl: Json.strOrNull(json, 'media_url'),
    mediaName: Json.strOrNull(json, 'media_name'),
    mediaType: Json.strOrNull(json, 'media_type'),
    editedAt: Json.strOrNull(json, 'edited_at'),
    createdAt: Json.strOrNull(json, 'created_at'),
  );

  final String id;
  final String body;
  final String senderName;
  final String? senderId;
  final bool isMine;
  final String status;
  final String? mediaUrl;
  final String? mediaName;
  final String? mediaType;
  final String? editedAt;
  final String? createdAt;

  bool get isRemoved => status != 'sent';
  bool get hasImage => (mediaType ?? '').startsWith('image/');
}

/// A conversation, opened.
class ConversationThread {
  const ConversationThread({
    required this.id,
    required this.messages,
    this.with_,
    this.isMuted = false,
    this.isBlocked = false,
    this.total = 0,
  });

  factory ConversationThread.fromJson(Map<String, dynamic> json) => ConversationThread(
    id: Json.str(json, 'id'),
    with_: json['with'] == null
        ? null
        : MessagePerson.fromJson(json['with'] as Map<String, dynamic>?),
    messages: Json.objectList(json, 'messages').map(Message.fromJson).toList(growable: false),
    isMuted: Json.boolVal(json, 'is_muted'),
    isBlocked: Json.boolVal(json, 'is_blocked'),
    total: Json.intVal(json, 'total'),
  );

  final String id;

  /// Named with a trailing underscore because `with` is a reserved word in
  /// Dart, and the API field is the right name for it.
  final MessagePerson? with_;

  final List<Message> messages;
  final bool isMuted;
  final bool isBlocked;
  final int total;
}

/// Somebody asking to see a member's phone number or email — or being asked.
class ContactRequest {
  const ContactRequest({
    required this.id,
    required this.name,
    this.handle,
    this.headline,
    this.wantsPhone = true,
    this.wantsEmail = false,
    this.reason,
    this.state = 'pending',
    this.createdAt,
  });

  factory ContactRequest.fromJson(Map<String, dynamic> json) => ContactRequest(
    id: Json.str(json, 'id'),
    name: Json.str(json, 'name', fallback: 'A member'),
    handle: Json.strOrNull(json, 'handle'),
    headline: Json.strOrNull(json, 'headline'),
    wantsPhone: Json.boolVal(json, 'wants_phone', fallback: true),
    wantsEmail: Json.boolVal(json, 'wants_email'),
    reason: Json.strOrNull(json, 'reason'),
    state: Json.str(json, 'state', fallback: 'pending'),
    createdAt: Json.strOrNull(json, 'created_at'),
  );

  final String id;
  final String name;
  final String? handle;
  final String? headline;
  final bool wantsPhone;
  final bool wantsEmail;

  /// Why they are asking, in their words. Shown to the person deciding,
  /// because "I am your cousin and there is a funeral" and "hi" are different
  /// requests and only one of them should be granted on the spot.
  final String? reason;

  final String state;
  final String? createdAt;

  bool get isPending => state == 'pending';

  String get askLabel {
    if (wantsPhone && wantsEmail) return 'your phone number and email address';
    if (wantsEmail) return 'your email address';
    return 'your phone number';
  }
}

/// Somebody currently holding your details, so you can take them back.
class ContactGrant {
  const ContactGrant({
    required this.viewerId,
    required this.name,
    this.handle,
    this.canSeePhone = false,
    this.canSeeEmail = false,
    this.grantedAt,
  });

  factory ContactGrant.fromJson(Map<String, dynamic> json) => ContactGrant(
    viewerId: Json.str(json, 'viewer_id'),
    name: Json.str(json, 'name', fallback: 'A member'),
    handle: Json.strOrNull(json, 'handle'),
    canSeePhone: Json.boolVal(json, 'can_see_phone'),
    canSeeEmail: Json.boolVal(json, 'can_see_email'),
    grantedAt: Json.strOrNull(json, 'granted_at'),
  );

  final String viewerId;
  final String name;
  final String? handle;
  final bool canSeePhone;
  final bool canSeeEmail;
  final String? grantedAt;

  String get whatTheyHave {
    if (canSeePhone && canSeeEmail) return 'your phone number and email';
    if (canSeeEmail) return 'your email';
    return 'your phone number';
  }
}

/// Everything the requests screen shows at once.
class ContactRequestInbox {
  const ContactRequestInbox({
    required this.incoming,
    required this.outgoing,
    required this.granted,
  });

  factory ContactRequestInbox.fromJson(Map<String, dynamic> json) => ContactRequestInbox(
    incoming: Json.objectList(json, 'incoming')
        .map(ContactRequest.fromJson)
        .toList(growable: false),
    outgoing: Json.objectList(json, 'outgoing')
        .map(ContactRequest.fromJson)
        .toList(growable: false),
    granted: Json.objectList(json, 'granted').map(ContactGrant.fromJson).toList(growable: false),
  );

  /// Waiting on this member to decide.
  final List<ContactRequest> incoming;

  /// What this member has asked of other people.
  final List<ContactRequest> outgoing;

  /// Who is currently holding their details.
  final List<ContactGrant> granted;

  bool get isEmpty => incoming.isEmpty && outgoing.isEmpty && granted.isEmpty;
}
