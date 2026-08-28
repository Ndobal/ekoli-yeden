import 'content_status.dart';

/// THE OKOLI ACCOUNT.
///
/// One account for the whole platform. This model is what the forum, the
/// opportunities board and the directory all read — none of them keeps a user
/// system of its own.
///
/// A profile arrives already shaped by the server to what the viewer is allowed
/// to see. A field that is null here may mean "not filled in" or "not shown to
/// you", and the client deliberately cannot tell the two apart — which is the
/// point. Nothing in this file reconstructs a hidden value.
class MemberProfile {
  const MemberProfile({
    required this.id,
    required this.handle,
    required this.membershipNumber,
    required this.membershipStatus,
    this.userId,
    this.fullName,
    this.displayName,
    this.email,
    this.headline,
    this.bio,
    this.avatarUrl,
    this.phone,
    this.whatsappNumber,
    this.country,
    this.stateRegion,
    this.lga,
    this.communityArea,
    this.placeText,
    this.clan,
    this.city,
    this.isInEkoliYeden = false,
    this.isDiaspora = false,
    this.connection,
    this.connectionNote,
    this.relationship,
    this.relationshipLabel,
    this.professionId,
    this.profession,
    this.professionOther,
    this.industry,
    this.employer,
    this.yearsExperience,
    this.educationLevel,
    this.educationField,
    this.institution,
    this.employmentStatus,
    this.workGroup,
    this.workGroupLabel,
    this.openToOpportunities = false,
    this.birthYear,
    this.profileVisibility = 'members',
    this.showContact = false,
    this.showEmployment = false,
    this.showLocation = true,
    this.showEducation = true,
    this.listedInDirectory = false,
    this.messagesFrom = 'members',
    this.findableForMessages = true,
    this.notifyOpportunities = true,
    this.notifyForum = true,
    this.notifyCommunity = true,
    this.completionPercent = 0,
    this.joinedAt,
    this.skills = const <MemberSkill>[],
    this.interests = const <MemberInterest>[],
  });

  factory MemberProfile.fromJson(Map<String, dynamic> json) {
    return MemberProfile(
      id: Json.str(json, 'id'),
      handle: Json.str(json, 'handle'),
      membershipNumber: Json.str(json, 'membership_number'),
      membershipStatus: Json.str(json, 'membership_status', fallback: 'active'),
      userId: Json.strOrNull(json, 'user_id'),
      fullName: Json.strOrNull(json, 'full_name'),
      displayName: Json.strOrNull(json, 'display_name'),
      email: Json.strOrNull(json, 'email'),
      headline: Json.strOrNull(json, 'headline'),
      bio: Json.strOrNull(json, 'bio'),
      avatarUrl: Json.strOrNull(json, 'avatar_url'),
      phone: Json.strOrNull(json, 'phone'),
      whatsappNumber: Json.strOrNull(json, 'whatsapp_number'),
      country: Json.strOrNull(json, 'country'),
      stateRegion: Json.strOrNull(json, 'state_region'),
      lga: Json.strOrNull(json, 'lga'),
      communityArea: Json.strOrNull(json, 'community_area'),
      placeText: Json.strOrNull(json, 'place_text'),
      clan: Json.strOrNull(json, 'clan'),
      city: Json.strOrNull(json, 'city'),
      isInEkoliYeden: Json.boolVal(json, 'is_in_ekoli_yeden'),
      isDiaspora: Json.boolVal(json, 'is_diaspora'),
      connection: Json.strOrNull(json, 'connection'),
      connectionNote: Json.strOrNull(json, 'connection_note'),
      relationship: Json.strOrNull(json, 'relationship'),
      relationshipLabel: Json.strOrNull(json, 'relationship_label'),
      professionId: Json.strOrNull(json, 'profession_id'),
      profession: Json.strOrNull(json, 'profession'),
      professionOther: Json.strOrNull(json, 'profession_other'),
      industry: Json.strOrNull(json, 'industry'),
      employer: Json.strOrNull(json, 'employer'),
      yearsExperience: Json.intOrNull(json, 'years_experience'),
      educationLevel: Json.strOrNull(json, 'education_level'),
      educationField: Json.strOrNull(json, 'education_field'),
      institution: Json.strOrNull(json, 'institution'),
      employmentStatus: Json.strOrNull(json, 'employment_status'),
      workGroup: Json.strOrNull(json, 'work_group'),
      workGroupLabel: Json.strOrNull(json, 'work_group_label'),
      openToOpportunities: Json.boolVal(json, 'open_to_opportunities'),
      birthYear: Json.intOrNull(json, 'birth_year'),
      profileVisibility: Json.str(json, 'profile_visibility', fallback: 'members'),
      showContact: Json.boolVal(json, 'show_contact'),
      showEmployment: Json.boolVal(json, 'show_employment'),
      showLocation: Json.boolVal(json, 'show_location', fallback: true),
      showEducation: Json.boolVal(json, 'show_education', fallback: true),
      listedInDirectory: Json.boolVal(json, 'listed_in_directory'),
      messagesFrom: Json.str(json, 'messages_from', fallback: 'members'),
      findableForMessages: Json.boolVal(json, 'findable_for_messages', fallback: true),
      notifyOpportunities: Json.boolVal(json, 'notify_opportunities', fallback: true),
      notifyForum: Json.boolVal(json, 'notify_forum', fallback: true),
      notifyCommunity: Json.boolVal(json, 'notify_community', fallback: true),
      completionPercent: Json.intVal(json, 'completion_percent'),
      joinedAt: Json.strOrNull(json, 'joined_at'),
      skills: Json.objectList(json, 'skills').map(MemberSkill.fromJson).toList(growable: false),
      interests:
          Json.objectList(json, 'interests').map(MemberInterest.fromJson).toList(growable: false),
    );
  }

  final String id;

  /// The public address of the profile. Separate from the name, so changing
  /// your name does not break a link somebody has already shared.
  final String handle;

  final String membershipNumber;
  final String membershipStatus;
  final String? userId;

  final String? fullName;
  final String? displayName;
  final String? email;
  final String? headline;
  final String? bio;
  final String? avatarUrl;

  final String? phone;
  final String? whatsappNumber;

  final String? country;
  final String? stateRegion;
  final String? lga;
  final String? communityArea;

  /// Where in Ekori they are from, in their own words.
  ///
  /// Their words rather than the place the archive matched them to. A wrong
  /// match is then something that can be seen and corrected, instead of
  /// silently replacing what somebody said about their own home.
  final String? placeText;

  final String? clan;
  final String? city;

  /// Derived by the server from the community and LGA, and the first tier of
  /// the proximity sort the opportunities board uses.
  final bool isInEkoliYeden;
  final bool isDiaspora;

  final String? connection;
  final String? connectionNote;

  /// WHAT THEY ARE TO EKOLI-YEDEN — indigene, resident, friend, researcher,
  /// organisation.
  ///
  /// Not a role and never consulted for permission. A person has two
  /// independent facts about them: what they are to Ekoli-Yeden, and what they
  /// do on this platform. An indigene may be an ordinary user or the Super
  /// Admin, and a researcher may be a contributor — folding the two into one
  /// word forces somebody to be described as what they are not.
  final String? relationship;

  /// The server's own wording for it, so the label lives in one place.
  final String? relationshipLabel;

  final String? professionId;

  /// The profession's label, resolved by the server.
  final String? profession;
  final String? professionOther;

  final String? industry;
  final String? employer;
  final int? yearsExperience;

  final String? educationLevel;
  final String? educationField;
  final String? institution;

  /// Present on your own profile always; on somebody else's only where they
  /// have turned it on **and** it is not a hardship. The server withholds
  /// "seeking work" and "not seeking" from everybody, whatever the switches
  /// say — the platform does not publish that a person is out of work.
  final String? employmentStatus;
  final String? workGroup;
  final String? workGroupLabel;

  final bool openToOpportunities;

  /// Only ever present on your own profile.
  final int? birthYear;

  final String profileVisibility;
  final bool showContact;
  final bool showEmployment;
  final bool showLocation;
  final bool showEducation;
  final bool listedInDirectory;

  /// Who may write to this member: 'members' or 'nobody'.
  final String messagesFrom;

  /// Whether they appear when somebody searches for a name to message.
  ///
  /// Kept apart from [listedInDirectory] deliberately: not wanting to be in the
  /// community's published list is not the same as not wanting your own cousin
  /// to be able to find you and say hello.
  final bool findableForMessages;

  final bool notifyOpportunities;
  final bool notifyForum;
  final bool notifyCommunity;

  final int completionPercent;
  final String? joinedAt;

  final List<MemberSkill> skills;
  final List<MemberInterest> interests;

  bool get isActive => membershipStatus == 'active';
  bool get isPending => membershipStatus == 'pending';

  String get name => fullName ?? displayName ?? 'Okoli member';

  /// What they do, from whichever field holds it.
  String? get professionLabel => profession ?? professionOther;

  /// "Ekoli-Yeden" · "Calabar, Cross River" · "London, United Kingdom".
  ///
  /// Built from whatever is present, because most profiles will not have all
  /// of it and a line reading "null, null" is worse than a shorter line.
  String? get locationLabel {
    if (isInEkoliYeden) return communityArea ?? 'Ekoli-Yeden';
    final List<String> parts = <String>[
      ?city,
      ?stateRegion,
      ?country,
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// The line under the name on a card.
  String? get summaryLine {
    final List<String> parts = <String>[
      ?professionLabel,
      ?locationLabel,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Two letters for the avatar placeholder.
  String get initials {
    final List<String> words =
        name.trim().split(RegExp(r'\s+')).where((String w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'OK';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return (words.first.substring(0, 1) + words.last.substring(0, 1)).toUpperCase();
  }
}

/// A skill a member holds, with how well they say they hold it.
///
/// Self-assessed, and labelled as such wherever it is shown — useful for
/// ordering a match, not a qualification the platform vouches for.
class MemberSkill {
  const MemberSkill({
    required this.id,
    required this.name,
    this.slug,
    this.category,
    this.proficiency = 'unspecified',
    this.years,
    this.memberCount = 0,
  });

  factory MemberSkill.fromJson(Map<String, dynamic> json) {
    return MemberSkill(
      id: Json.str(json, 'id'),
      name: Json.str(json, 'name'),
      slug: Json.strOrNull(json, 'slug'),
      category: Json.strOrNull(json, 'category'),
      proficiency: Json.str(json, 'proficiency', fallback: 'unspecified'),
      years: Json.intOrNull(json, 'years'),
      memberCount: Json.intVal(json, 'member_count'),
    );
  }

  final String id;
  final String name;
  final String? slug;
  final String? category;
  final String proficiency;
  final int? years;

  /// How many members hold this skill — what orders the picker, so somebody
  /// sees the community's actual skills rather than a seed list's order.
  final int memberCount;

  bool get hasProficiency => proficiency != 'unspecified';

  String get proficiencyLabel {
    switch (proficiency) {
      case 'beginner':
        return 'Beginner';
      case 'intermediate':
        return 'Intermediate';
      case 'advanced':
        return 'Advanced';
      case 'expert':
        return 'Expert';
      default:
        return '';
    }
  }
}

class MemberInterest {
  const MemberInterest({required this.id, required this.name, this.slug, this.description});

  factory MemberInterest.fromJson(Map<String, dynamic> json) {
    return MemberInterest(
      id: Json.str(json, 'id'),
      name: Json.str(json, 'name'),
      slug: Json.strOrNull(json, 'slug'),
      description: Json.strOrNull(json, 'description'),
    );
  }

  final String id;
  final String name;
  final String? slug;
  final String? description;
}

/// A profession, as the picker offers it.
class Profession {
  const Profession({required this.id, required this.name, this.slug, this.industry});

  factory Profession.fromJson(Map<String, dynamic> json) {
    return Profession(
      id: Json.str(json, 'id'),
      name: Json.str(json, 'name'),
      slug: Json.strOrNull(json, 'slug'),
      industry: Json.strOrNull(json, 'industry'),
    );
  }

  final String id;
  final String name;
  final String? slug;
  final String? industry;
}

/// One labelled choice, as the server words it.
///
/// The wording lives on the server for the employment question in particular:
/// "Not currently working — not seeking work" is a careful sentence, and it
/// should not be re-invented in the client where it can drift.
class LabelledChoice {
  const LabelledChoice({required this.value, required this.label, this.description, this.group});

  factory LabelledChoice.fromJson(Map<String, dynamic> json) {
    return LabelledChoice(
      value: Json.str(json, 'value'),
      label: Json.str(json, 'label'),
      description: Json.strOrNull(json, 'description'),
      group: Json.strOrNull(json, 'group'),
    );
  }

  final String value;
  final String label;
  final String? description;

  /// Which of the five work buckets an employment status falls into.
  final String? group;
}

/// Everything the joining form and the profile editor need to draw themselves.
class MembershipOptions {
  const MembershipOptions({
    required this.professions,
    required this.skills,
    required this.interests,
    required this.employmentStatuses,
    required this.connections,
    this.relationships = const <LabelledChoice>[],
    required this.educationLevels,
    required this.visibilities,
    required this.privacyPromise,
  });

  factory MembershipOptions.fromJson(Map<String, dynamic> json) {
    List<LabelledChoice> choices(String key) =>
        Json.objectList(json, key).map(LabelledChoice.fromJson).toList(growable: false);

    return MembershipOptions(
      professions:
          Json.objectList(json, 'professions').map(Profession.fromJson).toList(growable: false),
      skills: Json.objectList(json, 'skills').map(MemberSkill.fromJson).toList(growable: false),
      interests:
          Json.objectList(json, 'interests').map(MemberInterest.fromJson).toList(growable: false),
      employmentStatuses: choices('employmentStatuses'),
      connections: choices('connections'),
      relationships: choices('relationships'),
      educationLevels: choices('educationLevels'),
      visibilities: choices('visibilities'),
      privacyPromise: Json.stringList(json, 'privacyPromise'),
    );
  }

  final List<Profession> professions;
  final List<MemberSkill> skills;
  final List<MemberInterest> interests;
  final List<LabelledChoice> employmentStatuses;
  final List<LabelledChoice> connections;

  /// What somebody is to Ekoli-Yeden. The primary identity question, asked
  /// separately from the platform role a Super Admin assigns.
  final List<LabelledChoice> relationships;
  final List<LabelledChoice> educationLevels;
  final List<LabelledChoice> visibilities;

  /// What the platform promises about privacy, in its own words. Shown on the
  /// joining form, because somebody handing over their phone number deserves
  /// to read it before they do rather than after.
  final List<String> privacyPromise;

  /// Skills grouped by category, for a picker that is navigable rather than a
  /// wall of four hundred checkboxes.
  Map<String, List<MemberSkill>> get skillsByCategory {
    final Map<String, List<MemberSkill>> grouped = <String, List<MemberSkill>>{};
    for (final MemberSkill skill in skills) {
      grouped.putIfAbsent(skill.category ?? 'Other', () => <MemberSkill>[]).add(skill);
    }
    return grouped;
  }
}

/// One line in the notification list.
class MemberNotification {
  const MemberNotification({
    required this.id,
    required this.kind,
    required this.title,
    this.body,
    this.linkPath,
    this.readAt,
    this.createdAt,
  });

  factory MemberNotification.fromJson(Map<String, dynamic> json) {
    return MemberNotification(
      id: Json.str(json, 'id'),
      kind: Json.str(json, 'kind', fallback: 'general'),
      title: Json.str(json, 'title'),
      body: Json.strOrNull(json, 'body'),
      linkPath: Json.strOrNull(json, 'link_path'),
      readAt: Json.strOrNull(json, 'read_at'),
      createdAt: Json.strOrNull(json, 'created_at'),
    );
  }

  final String id;
  final String kind;
  final String title;
  final String? body;

  /// A path on this site. The server refuses to store anything else.
  final String? linkPath;

  final String? readAt;
  final String? createdAt;

  bool get isUnread => readAt == null;
}

/// The whole Okoli account, in one response.
class MemberDashboard {
  const MemberDashboard({
    required this.profile,
    required this.roles,
    required this.notifications,
    required this.unreadCount,
    required this.suggestions,
  });

  factory MemberDashboard.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> notifications =
        (json['notifications'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    return MemberDashboard(
      profile:
          MemberProfile.fromJson((json['profile'] as Map<String, dynamic>?) ?? <String, dynamic>{}),
      roles: Json.stringList(json, 'roles'),
      notifications: Json.objectList(notifications, 'recent')
          .map(MemberNotification.fromJson)
          .toList(growable: false),
      unreadCount: Json.intVal(notifications, 'unread'),
      suggestions: Json.stringList(json, 'suggestions'),
    );
  }

  final MemberProfile profile;
  final List<String> roles;
  final List<MemberNotification> notifications;
  final int unreadCount;

  /// What is still worth filling in, phrased as the thing it unlocks rather
  /// than as a scolding.
  final List<String> suggestions;
}
