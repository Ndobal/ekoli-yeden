import '../models/content_status.dart';
import '../services/api/api_client.dart';

/// FAMILY, BIRTHDAYS AND REMEMBRANCE.
///
/// Three features resting on one record: an accepted relationship between two
/// members. Family is that record; birthdays decide who to tell using it; and
/// remembrance decides who may confirm a death using it.
///
/// That last one is why accepting is not a courtesy. Nothing here lets a
/// relationship exist because one side said so.
class KinshipRepository {
  const KinshipRepository(this._api);

  final ApiClient _api;

  // --- Family ---------------------------------------------------------------

  /// My family: confirmed connections, and what is waiting on me.
  Future<({List<Relationship> accepted, List<Relationship> incoming, List<Relationship> outgoing})>
      family() async {
    final Map<String, dynamic> data = await _api.get('/api/membership/family');

    List<Relationship> read(String key) =>
        Json.objectList(data, key).map(Relationship.fromJson).toList(growable: false);

    return (
      accepted: read('accepted'),
      incoming: read('incoming'),
      outgoing: read('outgoing'),
    );
  }

  /// The relationships the platform recognises, grouped for a picker.
  Future<List<({String label, List<({String value, String label})> options})>>
      relationshipOptions() async {
    final Map<String, dynamic> data = await _api.get('/api/membership/family/options');

    return Json.objectList(data, 'groups')
        .map(
          (Map<String, dynamic> group) => (
            label: Json.str(group, 'label'),
            options: Json.objectList(group, 'options')
                .map((Map<String, dynamic> o) =>
                    (value: Json.str(o, 'value'), label: Json.str(o, 'label')))
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  /// Asks somebody to confirm a relationship, by handle or by phone number.
  ///
  /// The phone form answers identically whether or not a member holds that
  /// number — otherwise it would be a way to test a list of numbers against the
  /// membership. Do not "improve" the message it returns.
  Future<String> request({
    required String type,
    String? handle,
    String? phone,
    String? note,
  }) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/membership/family/requests',
      body: <String, dynamic>{
        'type': type,
        'handle': ?handle,
        'phone': ?phone,
        'note': ?note,
      },
    );
    return Json.str(data, 'message', fallback: 'Asked.');
  }

  Future<void> accept(String id, {required String reverseType}) =>
      _api.post(
        '/api/membership/family/$id/accept',
        body: <String, dynamic>{'reverse_type': reverseType},
      );

  Future<void> decline(String id) => _api.post('/api/membership/family/$id/decline');

  Future<void> remove(String id) => _api.delete('/api/membership/family/$id');

  // --- Birthdays ------------------------------------------------------------

  /// Whose birthday it is among the people I know, and whether it is my own.
  Future<({List<BirthdayCard> prompts, Map<String, dynamic>? own})> birthdaysToday() async {
    final Map<String, dynamic> data = await _api.get('/api/membership/birthdays/today');

    return (
      prompts: Json.objectList(data, 'prompts').map(BirthdayCard.fromJson).toList(growable: false),
      own: data['own'] as Map<String, dynamic>?,
    );
  }

  Future<void> wish(String userId, {required String message, bool isPrayer = false}) =>
      _api.post(
        '/api/membership/birthdays/$userId/wish',
        body: <String, dynamic>{'message': message, 'is_prayer': isPrayer},
      );

  /// "Not now." Recorded, so the card does not come back until next year.
  Future<void> skip(String userId) => _api.post('/api/membership/birthdays/$userId/skip');

  /// One year of somebody's birthday chart, and every year that has wishes.
  Future<BirthdayChart> chart(String handle, {int? year}) async {
    final Map<String, dynamic> data = await _api.get(
      '/api/members/$handle/birthdays',
      query: <String, dynamic>{'year': ?year?.toString()},
    );
    return BirthdayChart.fromJson(data);
  }
}

/// A family connection, as the member reading it sees it.
class Relationship {
  const Relationship({
    required this.id,
    required this.state,
    required this.typeLabel,
    required this.personName,
    this.personHandle,
    this.personUserId,
    this.avatarUrl,
    this.requestedTypeLabel,
    this.reverseOptions = const <({String value, String label})>[],
    this.note,
    this.awaitingMe = false,
  });

  factory Relationship.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> person =
        (json['person'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    return Relationship(
      id: Json.str(json, 'id'),
      state: Json.str(json, 'state'),
      typeLabel: Json.str(json, 'type_label', fallback: 'Related'),
      requestedTypeLabel: Json.strOrNull(json, 'requested_type_label'),
      personName: Json.str(person, 'name', fallback: 'A member'),
      personHandle: Json.strOrNull(person, 'handle'),
      personUserId: Json.strOrNull(person, 'user_id'),
      avatarUrl: Json.strOrNull(person, 'avatar_url'),
      note: Json.strOrNull(json, 'note'),
      awaitingMe: Json.boolVal(json, 'awaiting_me'),
      reverseOptions: Json.objectList(json, 'reverse_options')
          .map((Map<String, dynamic> o) =>
              (value: Json.str(o, 'value'), label: Json.str(o, 'label')))
          .toList(growable: false),
    );
  }

  final String id;
  final String state;
  final String typeLabel;
  final String? requestedTypeLabel;
  final String personName;
  final String? personHandle;
  final String? personUserId;
  final String? avatarUrl;
  final String? note;
  final bool awaitingMe;

  /// What the accepter may say they are in return. Only they can know whether
  /// they are the son or the daughter, and the archive does not ask anybody to
  /// record their sex so it can guess.
  final List<({String value, String label})> reverseOptions;
}

/// Somebody whose birthday it is today.
class BirthdayCard {
  const BirthdayCard({
    required this.userId,
    required this.name,
    this.handle,
    this.avatarUrl,
    this.headline,
    this.wishesEnabled = true,
  });

  factory BirthdayCard.fromJson(Map<String, dynamic> json) => BirthdayCard(
        userId: Json.str(json, 'user_id'),
        name: Json.str(json, 'name', fallback: 'A member'),
        handle: Json.strOrNull(json, 'handle'),
        avatarUrl: Json.strOrNull(json, 'avatar_url'),
        headline: Json.strOrNull(json, 'headline'),
        wishesEnabled: Json.boolVal(json, 'wishes_enabled', fallback: true),
      );

  final String userId;
  final String name;
  final String? handle;
  final String? avatarUrl;
  final String? headline;
  final bool wishesEnabled;
}

/// A year of somebody's birthday wishes.
///
/// Kept by year because that is the question a member actually asks years
/// later — "what did people say to me in 2027?" — and a feed cannot answer it.
class BirthdayChart {
  const BirthdayChart({
    required this.year,
    this.years = const <int>[],
    this.wishes = const <BirthdayWish>[],
    this.memberName,
  });

  factory BirthdayChart.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> member =
        (json['member'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    return BirthdayChart(
      year: Json.intVal(json, 'year'),
      memberName: Json.strOrNull(member, 'name'),
      years: Json.objectList(json, 'years')
          .map((Map<String, dynamic> row) => Json.intVal(row, 'year'))
          .toList(growable: false),
      wishes: Json.objectList(json, 'wishes')
          .map(BirthdayWish.fromJson)
          .toList(growable: false),
    );
  }

  final int year;
  final String? memberName;
  final List<int> years;
  final List<BirthdayWish> wishes;
}

class BirthdayWish {
  const BirthdayWish({
    required this.id,
    required this.message,
    required this.senderName,
    this.isPrayer = false,
    this.senderAvatarUrl,
    this.createdAt,
  });

  factory BirthdayWish.fromJson(Map<String, dynamic> json) => BirthdayWish(
        id: Json.str(json, 'id'),
        message: Json.str(json, 'message'),
        senderName: Json.str(json, 'sender_name', fallback: 'A member'),
        isPrayer: Json.boolVal(json, 'is_prayer'),
        senderAvatarUrl: Json.strOrNull(json, 'sender_avatar_url'),
        createdAt: Json.strOrNull(json, 'created_at'),
      );

  final String id;
  final String message;
  final String senderName;
  final bool isPrayer;
  final String? senderAvatarUrl;
  final String? createdAt;
}
