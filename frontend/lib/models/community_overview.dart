/// THE COMMUNITY HUB, IN ONE RESPONSE.
///
/// Counts, the newest people, the groups, and what has happened lately.
///
/// The activity is assembled by the Worker from the things themselves — the
/// photographs, the conversations, the people who joined — rather than from an
/// activity table every module has to remember to write to. See
/// `community.controller.ts` for why.
library;

import 'content_status.dart';

class CommunityOverview {
  const CommunityOverview({
    required this.stats,
    required this.members,
    required this.groups,
    required this.activity,
  });

  factory CommunityOverview.fromJson(Map<String, dynamic> json) => CommunityOverview(
    stats: CommunityStats.fromJson(
      (json['stats'] as Map<String, dynamic>?) ?? <String, dynamic>{},
    ),
    members: Json.objectList(json, 'members')
        .map(CommunityMember.fromJson)
        .toList(growable: false),
    groups: Json.objectList(json, 'groups')
        .map(CommunityGroupCard.fromJson)
        .toList(growable: false),
    activity: Json.objectList(json, 'activity')
        .map(ActivityEntry.fromJson)
        .toList(growable: false),
  );

  final CommunityStats stats;
  final List<CommunityMember> members;
  final List<CommunityGroupCard> groups;
  final List<ActivityEntry> activity;
}

class CommunityStats {
  const CommunityStats({
    this.members = 0,
    this.groups = 0,
    this.ageGrades = 0,
    this.forums = 0,
    this.topics = 0,
    this.posts = 0,
    this.photographs = 0,
    this.news = 0,
    this.history = 0,
    this.words = 0,
    this.people = 0,
    this.recordings = 0,
  });

  factory CommunityStats.fromJson(Map<String, dynamic> json) => CommunityStats(
    members: Json.intVal(json, 'members'),
    groups: Json.intVal(json, 'groups'),
    ageGrades: Json.intVal(json, 'age_grades'),
    forums: Json.intVal(json, 'forums'),
    topics: Json.intVal(json, 'topics'),
    posts: Json.intVal(json, 'posts'),
    photographs: Json.intVal(json, 'photographs'),
    news: Json.intVal(json, 'news'),
    history: Json.intVal(json, 'history'),
    words: Json.intVal(json, 'words'),
    people: Json.intVal(json, 'people'),
    recordings: Json.intVal(json, 'recordings'),
  );

  final int members;
  final int groups;
  final int ageGrades;
  final int forums;
  final int topics;
  final int posts;
  final int photographs;
  final int news;
  final int history;
  final int words;
  final int people;
  final int recordings;
}

class CommunityMember {
  const CommunityMember({
    required this.handle,
    required this.name,
    this.headline,
    this.place,
    this.joinedAt,
    this.avatarUrl,
    this.openToMentoring = false,
  });

  factory CommunityMember.fromJson(Map<String, dynamic> json) => CommunityMember(
    handle: Json.str(json, 'handle'),
    name: Json.str(json, 'name', fallback: 'A member'),
    headline: Json.strOrNull(json, 'headline'),
    place: Json.strOrNull(json, 'place'),
    joinedAt: Json.strOrNull(json, 'joined_at'),
    avatarUrl: Json.strOrNull(json, 'avatar_url'),
    openToMentoring: Json.boolVal(json, 'open_to_mentoring'),
  );

  final String handle;
  final String name;
  final String? headline;
  final String? place;
  final String? joinedAt;
  final String? avatarUrl;
  final bool openToMentoring;
}

class CommunityGroupCard {
  const CommunityGroupCard({
    required this.slug,
    required this.name,
    this.kind,
    this.memberCount = 0,
    this.detail,
    this.coverUrl,
  });

  factory CommunityGroupCard.fromJson(Map<String, dynamic> json) => CommunityGroupCard(
    slug: Json.str(json, 'slug'),
    name: Json.str(json, 'name', fallback: 'A group'),
    kind: Json.strOrNull(json, 'kind'),
    memberCount: Json.intVal(json, 'member_count'),
    detail: Json.strOrNull(json, 'detail'),
    coverUrl: Json.strOrNull(json, 'cover_url'),
  );

  final String slug;
  final String name;
  final String? kind;
  final int memberCount;
  final String? detail;
  final String? coverUrl;

  bool get isAgeGrade => kind == 'age_grade';
}

/// One thing that happened.
class ActivityEntry {
  const ActivityEntry({
    required this.kind,
    this.at,
    this.title,
    this.actor,
    this.parentSlug,
    this.parentTitle,
    this.imageUrl,
  });

  factory ActivityEntry.fromJson(Map<String, dynamic> json) => ActivityEntry(
    kind: Json.str(json, 'kind', fallback: 'other'),
    at: Json.strOrNull(json, 'at'),
    title: Json.strOrNull(json, 'title'),
    actor: Json.strOrNull(json, 'actor'),
    parentSlug: Json.strOrNull(json, 'parent_slug'),
    parentTitle: Json.strOrNull(json, 'parent_title'),
    imageUrl: Json.strOrNull(json, 'image_url'),
  );

  final String kind;
  final String? at;
  final String? title;
  final String? actor;
  final String? parentSlug;
  final String? parentTitle;
  final String? imageUrl;

  /// What happened, in a sentence somebody would actually say.
  String get sentence => switch (kind) {
    'photograph' => actor == null || actor!.isEmpty
        ? 'A photograph was added to ${parentTitle ?? 'the archive'}'
        : '$actor added a photograph to ${parentTitle ?? 'the archive'}',
    'conversation' => 'A conversation was started in ${parentTitle ?? 'the forums'}',
    'news' => actor == null || actor!.isEmpty
        ? 'News was published'
        : '$actor published news',
    'member' => place == null
        ? '${title ?? 'Somebody'} joined Ekoli-Yeden'
        : '${title ?? 'Somebody'} joined from $place',
    _ => title ?? 'Something happened',
  };

  String? get place => (parentTitle ?? '').isEmpty ? null : parentTitle;
}
