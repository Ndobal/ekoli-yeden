/// THE YAKOLI FORUMS.
///
/// Three spaces, and the community's own conversation inside them.
///
/// TWO THINGS IN THESE TYPES ARE DELIBERATE AND SHOULD SURVIVE REFACTORING.
///
/// `ForumAuthor` carries a nullable handle rather than a member record. In a
/// youth space the server sends a name and nothing else — no handle, no
/// location, no contact — because a post by a fifteen-year-old should not also
/// publish where to find them. Modelling the author as a full member profile
/// here would invite a screen to render fields the server correctly withheld.
///
/// Nothing in this file sorts by `reactionCount`. Ordering a community's
/// conversation by approval is how the loudest thing wins and the quiet
/// question goes unanswered. The server orders by when somebody last spoke,
/// and the client keeps that order.
library;

import 'content_status.dart';

/// One of the forum spaces, as it appears on the index.
class ForumSpace {
  const ForumSpace({
    required this.id,
    required this.slug,
    required this.name,
    this.tagline,
    this.description,
    this.kind = 'community',
    this.icon,
    this.accent,
    this.topicCount = 0,
    this.isYouthSpace = false,
    this.visibility = 'members',
    this.canRead = false,
    this.canPost = false,
    this.blockedReason,
  });

  factory ForumSpace.fromJson(Map<String, dynamic> json) => ForumSpace(
    id: Json.str(json, 'id'),
    slug: Json.str(json, 'slug'),
    name: Json.str(json, 'name'),
    tagline: Json.strOrNull(json, 'tagline'),
    description: Json.strOrNull(json, 'description'),
    kind: Json.str(json, 'kind', fallback: 'community'),
    icon: Json.strOrNull(json, 'icon'),
    accent: Json.strOrNull(json, 'accent'),
    topicCount: Json.intVal(json, 'topic_count'),
    isYouthSpace: Json.boolVal(json, 'is_youth_space'),
    visibility: Json.str(json, 'visibility', fallback: 'members'),
    canRead: Json.boolVal(json, 'can_read'),
    canPost: Json.boolVal(json, 'can_post'),
    blockedReason: Json.strOrNull(json, 'blocked_reason'),
  );

  final String id;
  final String slug;
  final String name;
  final String? tagline;
  final String? description;
  final String kind;
  final String? icon;
  final String? accent;
  final int topicCount;

  /// A space that may contain minors. Author cards there carry a name only.
  final bool isYouthSpace;

  final String visibility;

  /// A space the caller may not read is still listed, so somebody who has an
  /// account but no membership can see that a third space exists and how to
  /// reach it, rather than never learning of it.
  final bool canRead;
  final bool canPost;

  /// Why they cannot post, in words they can act on.
  final String? blockedReason;

  bool get isPublic => visibility == 'public';
}

/// A shelf inside a space.
class ForumCategory {
  const ForumCategory({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    this.section,
    this.icon,
    this.topicCount = 0,
    this.postPermission = 'members',
  });

  factory ForumCategory.fromJson(Map<String, dynamic> json) => ForumCategory(
    id: Json.str(json, 'id'),
    slug: Json.str(json, 'slug'),
    name: Json.str(json, 'name'),
    description: Json.strOrNull(json, 'description'),
    section: Json.strOrNull(json, 'section'),
    icon: Json.strOrNull(json, 'icon'),
    topicCount: Json.intVal(json, 'topic_count'),
    postPermission: Json.str(json, 'post_permission', fallback: 'members'),
  );

  final String id;
  final String slug;
  final String name;
  final String? description;
  final String? section;
  final String? icon;
  final int topicCount;

  /// An announcements shelf is readable by everybody and writable by few.
  final String postPermission;

  bool get isModeratorsOnly => postPermission == 'moderators';
}

/// Who wrote something, shaped for the space it was written in.
class ForumAuthor {
  const ForumAuthor({required this.name, this.handle, this.avatarUrl});

  factory ForumAuthor.fromJson(Map<String, dynamic>? json) => json == null
      ? const ForumAuthor(name: 'A member')
      : ForumAuthor(
          name: Json.str(json, 'name', fallback: 'A member'),
          handle: Json.strOrNull(json, 'handle'),
          avatarUrl: Json.strOrNull(json, 'avatar_url'),
        );

  final String name;

  /// Null in a youth space, and null for a member with no public page. A
  /// screen must treat the absence as "do not link", never as an error.
  final String? handle;
  final String? avatarUrl;

  /// One or two letters for the avatar, when there is no photograph.
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

/// A conversation, as it appears in a list.
class ForumTopic {
  const ForumTopic({
    required this.id,
    required this.slug,
    required this.title,
    this.excerpt = '',
    this.authorName = 'A member',
    this.categoryName,
    this.categorySlug,
    this.isPinned = false,
    this.isLocked = false,
    this.replyCount = 0,
    this.reactionCount = 0,
    this.lastReplyAt,
    this.status = 'published',
    this.createdAt,
  });

  factory ForumTopic.fromJson(Map<String, dynamic> json) => ForumTopic(
    id: Json.str(json, 'id'),
    slug: Json.str(json, 'slug'),
    title: Json.str(json, 'title'),
    excerpt: Json.str(json, 'excerpt'),
    authorName: Json.str(json, 'author_name', fallback: 'A member'),
    categoryName: Json.strOrNull(json, 'category_name'),
    categorySlug: Json.strOrNull(json, 'category_slug'),
    isPinned: Json.boolVal(json, 'is_pinned'),
    isLocked: Json.boolVal(json, 'is_locked'),
    replyCount: Json.intVal(json, 'reply_count'),
    reactionCount: Json.intVal(json, 'reaction_count'),
    lastReplyAt: Json.strOrNull(json, 'last_reply_at'),
    status: Json.str(json, 'status', fallback: 'published'),
    createdAt: Json.strOrNull(json, 'created_at'),
  );

  final String id;
  final String slug;
  final String title;
  final String excerpt;
  final String authorName;
  final String? categoryName;
  final String? categorySlug;
  final bool isPinned;
  final bool isLocked;
  final int replyCount;
  final int reactionCount;
  final String? lastReplyAt;
  final String status;
  final String? createdAt;

  /// When the conversation was last alive — a reply if there is one, otherwise
  /// when it was started.
  String? get lastActivityAt => lastReplyAt ?? createdAt;

  bool get isAwaitingApproval => status == 'pending_review';
  bool get isHidden => status == 'hidden';
}

/// One space, opened: its shelves, its conversations, and what the reader may
/// do here.
class ForumSpaceView {
  const ForumSpaceView({
    required this.space,
    required this.categories,
    required this.topics,
    required this.viewer,
    this.total = 0,
    this.page = 1,
    this.totalPages = 1,
    this.isIndexable = false,
  });

  factory ForumSpaceView.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> space =
        (json['space'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return ForumSpaceView(
      space: ForumSpace.fromJson(space),
      isIndexable: Json.boolVal(space, 'is_indexable'),
      categories: Json.objectList(json, 'categories')
          .map(ForumCategory.fromJson)
          .toList(growable: false),
      topics: Json.objectList(json, 'topics')
          .map(ForumTopic.fromJson)
          .toList(growable: false),
      viewer: ForumViewer.fromJson(json['viewer'] as Map<String, dynamic>?),
      total: Json.intVal(json, 'total'),
      page: Json.intVal(json, 'page', fallback: 1),
      totalPages: Json.intVal(json, 'totalPages', fallback: 1),
    );
  }

  final ForumSpace space;
  final List<ForumCategory> categories;
  final List<ForumTopic> topics;
  final ForumViewer viewer;
  final int total;
  final int page;
  final int totalPages;

  /// The server says whether search engines may index this space. Two of the
  /// three may contain minors and are marked not indexable; the page sets
  /// `noindex` from this as well, rather than relying on the server alone.
  final bool isIndexable;

  /// Shelves grouped by the heading they sit under, in the order the server
  /// sent them.
  Map<String, List<ForumCategory>> get categoriesBySection {
    final Map<String, List<ForumCategory>> grouped = <String, List<ForumCategory>>{};
    for (final ForumCategory category in categories) {
      grouped
          .putIfAbsent(category.section ?? 'Conversations', () => <ForumCategory>[])
          .add(category);
    }
    return grouped;
  }
}

/// What the person reading may do here.
class ForumViewer {
  const ForumViewer({
    this.canPost = false,
    this.isModerator = false,
    this.blockedReason,
    this.isMine = false,
  });

  factory ForumViewer.fromJson(Map<String, dynamic>? json) => json == null
      ? const ForumViewer()
      : ForumViewer(
          canPost: Json.boolVal(json, 'can_post'),
          isModerator: Json.boolVal(json, 'is_moderator'),
          blockedReason: Json.strOrNull(json, 'blocked_reason'),
          isMine: Json.boolVal(json, 'is_mine'),
        );

  final bool canPost;
  final bool isModerator;
  final String? blockedReason;

  /// Whether the thing being viewed was written by the reader.
  final bool isMine;
}

/// One reply.
class ForumPost {
  const ForumPost({
    required this.id,
    required this.body,
    required this.author,
    this.parentPostId,
    this.reactionCount = 0,
    this.youReacted = false,
    this.isAnswer = false,
    this.status = 'published',
    this.editedAt,
    this.createdAt,
    this.isMine = false,
  });

  factory ForumPost.fromJson(Map<String, dynamic> json) => ForumPost(
    id: Json.str(json, 'id'),
    body: Json.str(json, 'body'),
    author: ForumAuthor.fromJson(json['author'] as Map<String, dynamic>?),
    parentPostId: Json.strOrNull(json, 'parent_post_id'),
    reactionCount: Json.intVal(json, 'reaction_count'),
    youReacted: Json.boolVal(json, 'you_reacted'),
    isAnswer: Json.boolVal(json, 'is_answer'),
    status: Json.str(json, 'status', fallback: 'published'),
    editedAt: Json.strOrNull(json, 'edited_at'),
    createdAt: Json.strOrNull(json, 'created_at'),
    isMine: Json.boolVal(json, 'is_mine'),
  );

  final String id;
  final String body;
  final ForumAuthor author;
  final String? parentPostId;
  final int reactionCount;
  final bool youReacted;
  final bool isAnswer;
  final String status;

  /// An edit is stamped rather than silent — a conversation where posts change
  /// under the people who replied to them is one nobody can follow.
  final String? editedAt;
  final String? createdAt;
  final bool isMine;

  bool get isHidden => status == 'hidden';
  bool get isRemoved => status == 'removed';
}

/// A conversation, opened.
class ForumTopicView {
  const ForumTopicView({
    required this.topic,
    required this.body,
    required this.author,
    required this.posts,
    required this.viewer,
    this.youReacted = false,
    this.isFollowing = false,
  });

  factory ForumTopicView.fromJson(Map<String, dynamic> json) => ForumTopicView(
    topic: ForumTopic.fromJson(json),
    body: Json.str(json, 'body'),
    author: ForumAuthor.fromJson(json['author'] as Map<String, dynamic>?),
    posts: Json.objectList(json, 'posts').map(ForumPost.fromJson).toList(growable: false),
    viewer: ForumViewer.fromJson(json['viewer'] as Map<String, dynamic>?),
    youReacted: Json.boolVal(json, 'you_reacted'),
    isFollowing: Json.boolVal(json, 'is_following'),
  );

  final ForumTopic topic;
  final String body;
  final ForumAuthor author;
  final List<ForumPost> posts;
  final ForumViewer viewer;
  final bool youReacted;
  final bool isFollowing;
}

/// Something a member reported, waiting on a moderator.
///
/// The reported thing travels with the report — its text, its author, and
/// where it sits. A queue of ids is a queue somebody has to look up one at a
/// time, and a moderator who cannot read what was reported either acts blind
/// or does not act.
class ForumReport {
  const ForumReport({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.detail,
    this.status = 'open',
    this.createdAt,
    this.reviewNotes,
    this.targetTitle,
    this.targetBody,
    this.targetStatus,
    this.targetAuthorName,
    this.targetAuthorId,
    this.targetSpaceSlug,
    this.targetTopicSlug,
  });

  factory ForumReport.fromJson(Map<String, dynamic> json) => ForumReport(
    id: Json.str(json, 'id'),
    targetType: Json.str(json, 'target_type', fallback: 'post'),
    targetId: Json.str(json, 'target_id'),
    reason: Json.str(json, 'reason', fallback: 'other'),
    detail: Json.strOrNull(json, 'detail'),
    status: Json.str(json, 'status', fallback: 'open'),
    createdAt: Json.strOrNull(json, 'created_at'),
    reviewNotes: Json.strOrNull(json, 'review_notes'),
    targetTitle: Json.strOrNull(json, 'target_title'),
    targetBody: Json.strOrNull(json, 'target_body'),
    targetStatus: Json.strOrNull(json, 'target_status'),
    targetAuthorName: Json.strOrNull(json, 'target_author_name'),
    targetAuthorId: Json.strOrNull(json, 'target_author_id'),
    targetSpaceSlug: Json.strOrNull(json, 'target_space_slug'),
    targetTopicSlug: Json.strOrNull(json, 'target_topic_slug'),
  );

  final String id;
  final String targetType;
  final String targetId;
  final String reason;
  final String? detail;
  final String status;
  final String? createdAt;
  final String? reviewNotes;

  final String? targetTitle;
  final String? targetBody;
  final String? targetStatus;
  final String? targetAuthorName;
  final String? targetAuthorId;
  final String? targetSpaceSlug;
  final String? targetTopicSlug;

  /// The one thing in this module that reorders anything.
  bool get isChildSafety => reason == 'child_safety';

  String get reasonLabel => ForumReasons.label(reason);

  bool get isTopic => targetType == 'topic';

  /// Whether the thing has already been taken down — the queue says so, so a
  /// moderator does not hide something twice and wonder why nothing changed.
  bool get isAlreadyActioned => targetStatus == 'hidden' || targetStatus == 'removed';

  /// The conversation this belongs to, where both parts are known.
  ({String space, String topic})? get conversation {
    final String? space = targetSpaceSlug;
    final String? topic = targetTopicSlug;
    if (space == null || topic == null) return null;
    return (space: space, topic: topic);
  }
}

/// An entry in the moderation log.
class ForumModerationAction {
  const ForumModerationAction({
    required this.id,
    required this.action,
    required this.targetType,
    required this.targetId,
    this.moderatorName,
    this.reason,
    this.expiresAt,
    this.createdAt,
  });

  factory ForumModerationAction.fromJson(Map<String, dynamic> json) => ForumModerationAction(
    id: Json.str(json, 'id'),
    action: Json.str(json, 'action'),
    targetType: Json.str(json, 'target_type'),
    targetId: Json.str(json, 'target_id'),
    moderatorName: Json.strOrNull(json, 'moderator_name'),
    reason: Json.strOrNull(json, 'reason'),
    expiresAt: Json.strOrNull(json, 'expires_at'),
    createdAt: Json.strOrNull(json, 'created_at'),
  );

  final String id;
  final String action;
  final String targetType;
  final String targetId;
  final String? moderatorName;
  final String? reason;
  final String? expiresAt;
  final String? createdAt;
}

/// The reasons a report may give, in the words the server accepts.
///
/// `child_safety` is the only one that acts before a moderator does: it hides
/// the content the moment it is sent. The wording says so, because somebody
/// deciding whether to press it deserves to know what happens next.
class ForumReasons {
  const ForumReasons._();

  static const List<({String value, String label, String help})> all =
      <({String value, String label, String help})>[
        (value: 'abuse', label: 'Abusive', help: 'Insults, threats or cruelty towards somebody.'),
        (
          value: 'harassment',
          label: 'Harassment',
          help: 'Somebody is being followed or targeted.',
        ),
        (
          value: 'spam',
          label: 'Spam',
          help: 'Advertising, or the same message posted over and over.',
        ),
        (
          value: 'misinformation',
          label: 'Not true',
          help: 'It states something about the community that is false.',
        ),
        (
          value: 'inappropriate',
          label: 'Inappropriate',
          help: 'Not fit for this community to read.',
        ),
        (value: 'off_topic', label: 'Off topic', help: 'It does not belong in this space.'),
        (
          value: 'personal_information',
          label: 'Private details',
          help: 'A phone number, an address, or anything else that should not be public.',
        ),
        (
          value: 'child_safety',
          label: 'A child is at risk',
          help: 'Acted on immediately — the post is hidden the moment you send this.',
        ),
        (value: 'other', label: 'Something else', help: 'Tell the moderators what is wrong.'),
      ];

  static String label(String value) {
    for (final ({String value, String label, String help}) reason in all) {
      if (reason.value == value) return reason.label;
    }
    return value;
  }
}

/// The four ways to react. There is no disagree button, and reactions order
/// nothing.
class ForumReactions {
  const ForumReactions._();

  static const List<({String value, String label})> all = <({String value, String label})>[
    (value: 'appreciate', label: 'Thank you'),
    (value: 'agree', label: 'I agree'),
    (value: 'helpful', label: 'This helped'),
    (value: 'celebrate', label: 'Congratulations'),
  ];
}
