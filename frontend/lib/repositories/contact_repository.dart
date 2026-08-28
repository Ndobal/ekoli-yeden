import '../core/config/app_config.dart';
import '../models/content_status.dart';
import '../services/api/api_client.dart';
import '../services/api/api_response.dart';

/// WRITING TO THE PRESERVATION TEAM.
///
/// No account is needed to send a message, and that is deliberate: somebody
/// asking what the archive holds about them, or asking for their photograph to
/// be taken down, must not have to create a record of themselves before they
/// can ask.
class ContactRepository {
  const ContactRepository(this._api);

  final ApiClient _api;

  /// The topics the form offers, from the server, so the two cannot disagree
  /// about what a topic is.
  Future<({List<ContactTopic> topics, List<({String value, String label})> replyChannels})>
  options() async {
    final Map<String, dynamic> data =
        await _api.get('/api/contact/topics', authenticated: false);

    return (
      topics: Json.objectList(data, 'topics').map(ContactTopic.fromJson).toList(growable: false),
      replyChannels: Json.objectList(data, 'replyChannels')
          .map(
            (Map<String, dynamic> row) =>
                (value: Json.str(row, 'value'), label: Json.str(row, 'label')),
          )
          .toList(growable: false),
    );
  }

  /// Sends a message. Returns the reference the sender keeps.
  Future<({String reference, String message})> send(Map<String, dynamic> values) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/contact',
      body: values,
      // Sent with the session where there is one, so an administrator can see
      // who wrote — and without one where there is not, which is the case this
      // form mainly exists for.
      authenticated: true,
    );

    return (
      reference: Json.str(data, 'reference'),
      message: Json.str(
        data,
        'message',
        fallback: 'Thank you. Your message has reached the Preservation Team.',
      ),
    );
  }

  /// What happened to a message, for whoever holds the reference.
  Future<({String status, String explanation})> status(String reference) async {
    final Map<String, dynamic> data =
        await _api.get('/api/contact/$reference', authenticated: false);
    return (status: Json.str(data, 'status'), explanation: Json.str(data, 'explanation'));
  }

  // --- The inbox ------------------------------------------------------------

  Future<PaginatedResult<ContactMessage>> inbox({
    String status = 'new',
    int page = 1,
    int perPage = AppConfig.defaultPageSize,
  }) {
    return _api.list<ContactMessage>(
      '/api/admin/contact',
      ContactMessage.fromJson,
      query: <String, dynamic>{'status': status, 'page': page, 'perPage': perPage},
    );
  }

  /// Picks one up, answers it, closes it, or sets it aside.
  Future<void> setStatus(String id, {required String status, String? notes}) => _api.post(
    '/api/admin/contact/$id/status',
    body: <String, dynamic>{'status': status, 'handling_notes': ?notes},
  );
}

/// One thing somebody might be writing about.
class ContactTopic {
  const ContactTopic({required this.value, required this.label, this.help});

  factory ContactTopic.fromJson(Map<String, dynamic> json) => ContactTopic(
    value: Json.str(json, 'value'),
    label: Json.str(json, 'label'),
    help: Json.strOrNull(json, 'help'),
  );

  final String value;
  final String label;
  final String? help;

  /// The two the law has an opinion about, plus complaints. Marked so the
  /// queue can show them first and the form can say what happens next.
  bool get isUrgent => value == 'privacy' || value == 'takedown' || value == 'complaint';
}

/// A message, as an administrator sees it.
class ContactMessage {
  const ContactMessage({
    required this.id,
    required this.reference,
    required this.name,
    required this.message,
    this.email,
    this.phone,
    this.preferredReply = 'email',
    this.topic = 'general',
    this.subject,
    this.status = 'new',
    this.handlingNotes,
    this.answeredAt,
    this.createdAt,
  });

  factory ContactMessage.fromJson(Map<String, dynamic> json) => ContactMessage(
    id: Json.str(json, 'id'),
    reference: Json.str(json, 'reference_code'),
    name: Json.str(json, 'name', fallback: 'Somebody'),
    message: Json.str(json, 'message'),
    email: Json.strOrNull(json, 'email'),
    phone: Json.strOrNull(json, 'phone'),
    preferredReply: Json.str(json, 'preferred_reply', fallback: 'email'),
    topic: Json.str(json, 'topic', fallback: 'general'),
    subject: Json.strOrNull(json, 'subject'),
    status: Json.str(json, 'status', fallback: 'new'),
    handlingNotes: Json.strOrNull(json, 'handling_notes'),
    answeredAt: Json.strOrNull(json, 'answered_at'),
    createdAt: Json.strOrNull(json, 'created_at'),
  );

  final String id;
  final String reference;
  final String name;
  final String message;
  final String? email;
  final String? phone;

  /// How they asked to be answered. Worth showing beside the message: an
  /// administrator who replies by email to somebody who asked for a phone call
  /// has not answered them.
  final String preferredReply;

  final String topic;
  final String? subject;
  final String status;
  final String? handlingNotes;
  final String? answeredAt;
  final String? createdAt;

  bool get isUrgent => topic == 'privacy' || topic == 'takedown' || topic == 'complaint';

  String get topicLabel {
    switch (topic) {
      case 'correction':
        return 'A correction';
      case 'contribution':
        return 'Something to add';
      case 'privacy':
        return 'What do you hold about me';
      case 'takedown':
        return 'Please remove something';
      case 'membership':
        return 'Account or membership';
      case 'technical':
        return 'Something is broken';
      case 'press':
        return 'Press or research';
      case 'complaint':
        return 'A complaint';
      case 'other':
        return 'Something else';
      default:
        return 'General';
    }
  }

  /// How to answer them, in one line an administrator can act on.
  String get replyLine {
    switch (preferredReply) {
      case 'none':
        return 'No reply asked for';
      case 'phone':
        return phone == null ? 'Asked for a phone call — no number given' : 'Call $phone';
      case 'whatsapp':
        return phone == null ? 'Asked for WhatsApp — no number given' : 'WhatsApp $phone';
      default:
        return email == null ? 'Asked for email — no address given' : 'Email $email';
    }
  }
}
