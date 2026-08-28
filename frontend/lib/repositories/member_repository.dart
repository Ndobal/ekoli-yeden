import '../core/config/app_config.dart';
import '../models/content_status.dart';
import '../models/member.dart';
import '../services/api/api_client.dart';
import '../services/api/api_response.dart';

/// THE OKOLI ACCOUNT.
///
/// One account for the whole platform. The forum, the opportunities board and
/// the directory read the profile this maintains rather than keeping user
/// systems of their own.
///
/// Note what is absent: nothing here reconstructs a value the server withheld.
/// A profile arrives already shaped to what the viewer may see, and a null
/// field means either "not filled in" or "not shown to you" — the client
/// deliberately cannot tell which.
class MemberRepository {
  const MemberRepository(this._api);

  final ApiClient _api;

  /// Everything the joining form and the profile editor need to draw
  /// themselves, including the exact wording of every choice offered.
  Future<MembershipOptions> options() async {
    final Map<String, dynamic> data = await _api.get(
      '/api/membership/options',
      authenticated: false,
    );
    return MembershipOptions.fromJson(data);
  }

  /// Turns this account into a membership.
  Future<({String handle, String membershipNumber, String status, String message})> join({
    String? fullName,
  }) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/membership/join',
      body: <String, dynamic>{'full_name': ?fullName},
    );
    return (
      handle: Json.str(data, 'handle'),
      membershipNumber: Json.str(data, 'membershipNumber'),
      status: Json.str(data, 'status', fallback: 'active'),
      message: Json.str(data, 'message', fallback: 'Welcome to the Yakoli community.'),
    );
  }

  /// The whole account in one request — profile, notifications, what is still
  /// worth filling in.
  Future<MemberDashboard> dashboard() async {
    final Map<String, dynamic> data = await _api.get('/api/membership/dashboard');
    return MemberDashboard.fromJson(data);
  }

  Future<MemberProfile> me() async {
    final Map<String, dynamic> data = await _api.get('/api/membership/me');
    return MemberProfile.fromJson(data);
  }

  /// Saves one stage of the profile.
  ///
  /// Everything is optional. A member may answer three questions today and
  /// three more next week, and neither loses the other.
  Future<MemberProfile> updateProfile(Map<String, dynamic> values) async {
    final Map<String, dynamic> data = await _api.patch(
      '/api/membership/me',
      body: values,
    );
    return MemberProfile.fromJson(data);
  }

  /// Changes what other people can see.
  ///
  /// Separate from `updateProfile` because it is a different act: changing
  /// what the world knows about you should not happen as a side effect of
  /// correcting your job title.
  Future<MemberProfile> updatePrivacy({
    String? profileVisibility,
    bool? showContact,
    bool? showEmployment,
    bool? showLocation,
    bool? showEducation,
    bool? listedInDirectory,
    String? messagesFrom,
    bool? findableForMessages,
    bool? notifyOpportunities,
    bool? notifyForum,
    bool? notifyCommunity,
  }) async {
    final Map<String, dynamic> data = await _api.patch(
      '/api/membership/me/privacy',
      body: <String, dynamic>{
        'profile_visibility': ?profileVisibility,
        'show_contact': ?showContact,
        'show_employment': ?showEmployment,
        'show_location': ?showLocation,
        'show_education': ?showEducation,
        'listed_in_directory': ?listedInDirectory,
        'messages_from': ?messagesFrom,
        'findable_for_messages': ?findableForMessages,
        'notify_opportunities': ?notifyOpportunities,
        'notify_forum': ?notifyForum,
        'notify_community': ?notifyCommunity,
      },
    );
    return MemberProfile.fromJson(data);
  }

  /// Replaces the member's skills.
  ///
  /// An entry with a `name` but no `skillId` is a skill the vocabulary does
  /// not have yet; the server adds it rather than refusing. Turning somebody
  /// away because their trade is not on a list is how a profile gets abandoned
  /// half-finished.
  Future<List<MemberSkill>> setSkills(List<MemberSkillEntry> entries) async {
    final Map<String, dynamic> data = await _api.put(
      '/api/membership/me/skills',
      body: <String, dynamic>{
        'skills': entries.map((MemberSkillEntry entry) => entry.toJson()).toList(growable: false),
      },
    );
    return Json.objectList(data, 'skills').map(MemberSkill.fromJson).toList(growable: false);
  }

  Future<List<MemberInterest>> setInterests(List<String> interestIds) async {
    final Map<String, dynamic> data = await _api.put(
      '/api/membership/me/interests',
      body: <String, dynamic>{'interests': interestIds},
    );
    return Json.objectList(data, 'interests').map(MemberInterest.fromJson).toList(growable: false);
  }

  /// The skill vocabulary, searchable, ordered by how many members hold each.
  Future<List<MemberSkill>> searchSkills({String? query, String? category}) async {
    final Map<String, dynamic> data = await _api.get(
      '/api/membership/skills',
      authenticated: false,
      query: <String, dynamic>{
        if (query != null && query.isNotEmpty) 'q': query,
        'category': ?category,
      },
    );
    return Json.objectList(data, 'items').map(MemberSkill.fromJson).toList(growable: false);
  }

  /// Somebody else's profile.
  ///
  /// Throws `NotFoundException` where the viewer may not see it — the server
  /// answers 404 rather than 403 on purpose, because whether a private profile
  /// exists is itself private.
  Future<MemberProfile> member(String handle) async {
    final Map<String, dynamic> data = await _api.get('/api/members/$handle');
    return MemberProfile.fromJson(data);
  }

  // --- The Yakoli directory (Module 7) --------------------------------------

  /// Members who chose to be findable, searchable by profession, skill and
  /// place.
  ///
  /// Signed-in only. The directory is the community's list of itself, not a
  /// public register — a page of real people with their professions and their
  /// locations is not something to leave open to whoever finds the address.
  ///
  /// Only members who opted in appear at all — that is enforced in the server's
  /// query rather than filtered afterwards, so nothing on this side can list
  /// somebody who asked not to be listed.
  Future<PaginatedResult<MemberProfile>> directory({
    int page = 1,
    int perPage = AppConfig.defaultPageSize,
    String? query,
    String? professionId,
    String? country,
    String? employmentStatus,
    /// §14 — only members who have offered to mentor.
    bool mentoringOnly = false,
  }) {
    return _api.list<MemberProfile>(
      '/api/directory',
      MemberProfile.fromJson,
      query: <String, dynamic>{
        'page': page,
        'perPage': perPage,
        'q': ?query,
        'profession': ?professionId,
        'country': ?country,
        'employment': ?employmentStatus,
        if (mentoringOnly) 'mentoring': '1',
      },
    );
  }

  /// The professions and countries that actually have somebody behind them.
  ///
  /// Only occupied ones: a filter list offering thirty professions where
  /// twenty-eight return nothing teaches people the directory is empty.
  Future<({List<({String id, String name, int count})> professions, List<({String name, int count})> countries})>
      directoryFacets() async {
    final Map<String, dynamic> data = await _api.get('/api/directory/facets');

    return (
      professions: Json.objectList(data, 'professions')
          .map((Map<String, dynamic> row) => (
                id: Json.str(row, 'id'),
                name: Json.str(row, 'name'),
                count: Json.intVal(row, 'count'),
              ))
          .toList(growable: false),
      countries: Json.objectList(data, 'countries')
          .map((Map<String, dynamic> row) =>
              (name: Json.str(row, 'name'), count: Json.intVal(row, 'count')))
          .toList(growable: false),
    );
  }

  // --- Notifications --------------------------------------------------------

  Future<PaginatedResult<MemberNotification>> notifications({
    int page = 1,
    int perPage = AppConfig.defaultPageSize,
    bool unreadOnly = false,
  }) {
    return _api.list<MemberNotification>(
      '/api/notifications',
      MemberNotification.fromJson,
      query: <String, dynamic>{
        'page': page,
        'perPage': perPage,
        if (unreadOnly) 'unread': 'true',
      },
    );
  }

  Future<int> markRead(String id) async {
    final Map<String, dynamic> data = await _api.post('/api/notifications/$id/read');
    return Json.intVal(data, 'unread');
  }

  Future<void> markAllRead() async {
    await _api.post('/api/notifications/read-all');
  }

  // --- Administration -------------------------------------------------------

  /// The community snapshot. Aggregated counts only — never individual people.
  Future<CommunitySnapshot> statistics() async {
    final Map<String, dynamic> data = await _api.get('/api/admin/membership/statistics');
    return CommunitySnapshot.fromJson(data);
  }
}

/// One skill as the editor holds it while it is being chosen.
class MemberSkillEntry {
  const MemberSkillEntry({this.skillId, this.name, this.proficiency = 'unspecified', this.years});

  /// An existing skill from the vocabulary.
  final String? skillId;

  /// A skill the vocabulary does not have. The server creates it.
  final String? name;

  final String proficiency;
  final int? years;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'skill_id': ?skillId,
        'name': ?name,
        'proficiency': proficiency,
        'years': ?years,
      };
}

/// The community snapshot: counts, never names.
///
/// An administrator planning community development needs to know how many
/// members are seeking work. They do not need — and this does not carry — a
/// list of who those people are.
class CommunitySnapshot {
  const CommunitySnapshot({
    required this.total,
    required this.byWorkGroup,
    required this.byCountry,
    required this.topSkills,
    required this.inDirectory,
    required this.inEkoliYeden,
    required this.diaspora,
    this.note,
  });

  factory CommunitySnapshot.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> groups =
        (json['byWorkGroup'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    List<({String label, int total})> counted(String key, String labelKey) {
      return Json.objectList(json, key)
          .map((Map<String, dynamic> row) => (
                label: Json.str(row, labelKey),
                total: Json.intVal(row, 'total'),
              ))
          .toList(growable: false);
    }

    return CommunitySnapshot(
      total: Json.intVal(json, 'total'),
      byWorkGroup: groups.map(
        (String key, dynamic value) =>
            MapEntry<String, int>(key, value is num ? value.toInt() : 0),
      ),
      byCountry: counted('byCountry', 'country'),
      topSkills: counted('topSkills', 'name'),
      inDirectory: Json.intVal(json, 'inDirectory'),
      inEkoliYeden: Json.intVal(json, 'inEkoliYeden'),
      diaspora: Json.intVal(json, 'diaspora'),
      note: Json.strOrNull(json, 'note'),
    );
  }

  final int total;
  final Map<String, int> byWorkGroup;
  final List<({String label, int total})> byCountry;
  final List<({String label, int total})> topSkills;
  final int inDirectory;
  final int inEkoliYeden;
  final int diaspora;

  /// The server's own statement about what this does and does not contain.
  final String? note;

  bool get isEmpty => total == 0;
}
