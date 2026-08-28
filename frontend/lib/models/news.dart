/// NEWS.
///
/// ---------------------------------------------------------------------------
/// THE STORY BODY IS STRUCTURED BLOCKS, NOT HTML
/// ---------------------------------------------------------------------------
///
/// Every paragraph, heading, quote, list, photograph, video and table is a
/// typed object. Nothing here can contain markup, which is why the server can
/// validate a shape instead of trying to scrub arbitrary HTML — and why the
/// Editorial Team never has to write any.
///
/// It also means the story renders as native widgets on a phone and in a
/// browser, identically, and that the plain text a search engine reads comes
/// from the same source as the page.
library;

import 'content_status.dart';

/// A story as it appears in a list.
class NewsSummary {
  const NewsSummary({
    required this.id,
    required this.slug,
    required this.title,
    this.excerpt,
    this.newsDate,
    this.location,
    this.publishedAt,
    this.isFeatured = false,
    this.isImportant = false,
    this.authorName,
    this.contributorName,
    this.categorySlug,
    this.categoryName,
    this.categoryAccent,
    this.coverUrl,
    this.coverAlt,
    this.photoCount = 0,
    this.videoCount = 0,
    this.firstVideoThumbnail,
  });

  factory NewsSummary.fromJson(Map<String, dynamic> json) => NewsSummary(
    id: Json.str(json, 'id'),
    slug: Json.str(json, 'slug'),
    title: Json.str(json, 'title'),
    excerpt: Json.strOrNull(json, 'excerpt'),
    newsDate: Json.strOrNull(json, 'news_date'),
    location: Json.strOrNull(json, 'location'),
    publishedAt: Json.strOrNull(json, 'published_at'),
    isFeatured: Json.boolVal(json, 'is_featured'),
    isImportant: Json.boolVal(json, 'is_important'),
    authorName: Json.strOrNull(json, 'author_name'),
    contributorName: Json.strOrNull(json, 'contributor_name'),
    categorySlug: Json.strOrNull(json, 'category_slug'),
    categoryName: Json.strOrNull(json, 'category_name'),
    categoryAccent: Json.strOrNull(json, 'category_accent'),
    coverUrl: Json.strOrNull(json, 'cover_url'),
    coverAlt: Json.strOrNull(json, 'cover_alt'),
    photoCount: Json.intVal(json, 'photo_count'),
    videoCount: Json.intVal(json, 'video_count'),
    firstVideoThumbnail: Json.strOrNull(json, 'first_video_thumbnail'),
  );

  final String id;
  final String slug;
  final String title;
  final String? excerpt;

  /// When it HAPPENED, which is not when it was published. A meeting held in
  /// March and written up in June is a March story, and the card says so.
  final String? newsDate;

  final String? location;
  final String? publishedAt;
  final bool isFeatured;
  final bool isImportant;
  final String? authorName;

  /// Who sent it in. Carried onto the published article and never cleared by an
  /// edit.
  final String? contributorName;

  final String? categorySlug;
  final String? categoryName;
  final String? categoryAccent;
  final String? coverUrl;
  final String? coverAlt;
  final int photoCount;
  final int videoCount;

  /// The YouTube still, used where a story has film but no cover photograph —
  /// so a video story is never a card with a grey rectangle on it.
  final String? firstVideoThumbnail;

  bool get hasVideo => videoCount > 0;

  /// Whatever image this card can show, in order of preference.
  String? get thumbnail => coverUrl ?? firstVideoThumbnail;

  /// The date to print. What happened when, falling back to when it was told.
  String? get displayDate => newsDate ?? publishedAt;
}

/// One story, whole.
class NewsStory {
  const NewsStory({
    required this.summary,
    this.body = const <NewsBlock>[],
    this.media = const <NewsMedia>[],
    this.sources = const <NewsSource>[],
    this.tags = const <({String slug, String name})>[],
    this.related = const <NewsSummary>[],
    this.source,
    this.sourceUrl,
    this.sourceNote,
  });

  factory NewsStory.fromJson(Map<String, dynamic> json) => NewsStory(
    summary: NewsSummary.fromJson(json),
    body: Json.objectList(json, 'body').map(NewsBlock.fromJson).toList(growable: false),
    media: Json.objectList(json, 'media').map(NewsMedia.fromJson).toList(growable: false),
    sources: Json.objectList(json, 'sources').map(NewsSource.fromJson).toList(growable: false),
    tags: Json.objectList(json, 'tags')
        .map((Map<String, dynamic> row) => (
              slug: Json.str(row, 'slug'),
              name: Json.str(row, 'name'),
            ))
        .toList(growable: false),
    related: Json.objectList(json, 'related').map(NewsSummary.fromJson).toList(growable: false),
    source: Json.strOrNull(json, 'source'),
    sourceUrl: Json.strOrNull(json, 'source_url'),
    sourceNote: Json.strOrNull(json, 'source_note'),
  );

  final NewsSummary summary;
  final List<NewsBlock> body;
  final List<NewsMedia> media;
  final List<NewsSource> sources;
  final List<({String slug, String name})> tags;
  final List<NewsSummary> related;
  final String? source;
  final String? sourceUrl;

  /// How the contributor said they knew. Kept beside the story rather than
  /// folded into it: news from somebody who was there is a different thing
  /// from news read in a group chat.
  final String? sourceNote;

  List<NewsMedia> get photographs =>
      media.where((NewsMedia item) => item.isImage).toList(growable: false);

  List<NewsMedia> get videos =>
      media.where((NewsMedia item) => item.isVideo).toList(growable: false);
}

/// One block of a story.
class NewsBlock {
  const NewsBlock({
    required this.type,
    this.text,
    this.level = 2,
    this.items = const <String>[],
    this.marks = const <NewsMark>[],
    this.mediaId,
    this.youtubeId,
    this.caption,
    this.align,
    this.rows = const <List<String>>[],
  });

  factory NewsBlock.fromJson(Map<String, dynamic> json) => NewsBlock(
    type: Json.str(json, 'type', fallback: 'paragraph'),
    text: Json.strOrNull(json, 'text'),
    level: Json.intVal(json, 'level', fallback: 2),
    items: Json.stringList(json, 'items'),
    marks: Json.objectList(json, 'marks').map(NewsMark.fromJson).toList(growable: false),
    mediaId: Json.strOrNull(json, 'mediaId'),
    youtubeId: Json.strOrNull(json, 'youtubeId'),
    caption: Json.strOrNull(json, 'caption'),
    align: Json.strOrNull(json, 'align'),
    rows: (json['rows'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<List<dynamic>>()
        .map((List<dynamic> row) => row.map((dynamic cell) => cell.toString()).toList(growable: false))
        .toList(growable: false),
  );

  final String type;
  final String? text;
  final int level;
  final List<String> items;
  final List<NewsMark> marks;
  final String? mediaId;
  final String? youtubeId;
  final String? caption;
  final String? align;
  final List<List<String>> rows;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type,
    if (text != null) 'text': text,
    if (type == 'heading') 'level': level,
    if (items.isNotEmpty) 'items': items,
    if (marks.isNotEmpty) 'marks': marks.map((NewsMark m) => m.toJson()).toList(growable: false),
    if (mediaId != null) 'mediaId': mediaId,
    if (youtubeId != null) 'youtubeId': youtubeId,
    if (caption != null) 'caption': caption,
    if (align != null) 'align': align,
    if (rows.isNotEmpty) 'rows': rows,
  };

  NewsBlock copyWith({String? text, List<String>? items, int? level, String? caption}) => NewsBlock(
    type: type,
    text: text ?? this.text,
    level: level ?? this.level,
    items: items ?? this.items,
    marks: marks,
    mediaId: mediaId,
    youtubeId: youtubeId,
    caption: caption ?? this.caption,
    align: align,
    rows: rows,
  );
}

/// Bold, italic or a link, over a range of a block's text.
class NewsMark {
  const NewsMark({required this.type, required this.start, required this.end, this.href});

  factory NewsMark.fromJson(Map<String, dynamic> json) => NewsMark(
    type: Json.str(json, 'type'),
    start: Json.intVal(json, 'start'),
    end: Json.intVal(json, 'end'),
    href: Json.strOrNull(json, 'href'),
  );

  final String type;
  final int start;
  final int end;
  final String? href;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type,
    'start': start,
    'end': end,
    if (href != null) 'href': href,
  };
}

/// A photograph or a film attached to a story.
class NewsMedia {
  const NewsMedia({
    required this.id,
    required this.mediaType,
    this.url,
    this.mimeType,
    this.youtubeId,
    this.embedUrl,
    this.thumbnailUrl,
    this.videoTitle,
    this.videoDescription,
    this.caption,
    this.altText,
    this.photographer,
    this.copyright,
    this.takenAt,
    this.displayOrder = 0,
  });

  factory NewsMedia.fromJson(Map<String, dynamic> json) => NewsMedia(
    id: Json.str(json, 'id'),
    mediaType: Json.str(json, 'media_type', fallback: 'image'),
    url: Json.strOrNull(json, 'url'),
    mimeType: Json.strOrNull(json, 'mime_type'),
    youtubeId: Json.strOrNull(json, 'youtube_id'),
    embedUrl: Json.strOrNull(json, 'embed_url'),
    thumbnailUrl: Json.strOrNull(json, 'thumbnail_url'),
    videoTitle: Json.strOrNull(json, 'video_title'),
    videoDescription: Json.strOrNull(json, 'video_description'),
    caption: Json.strOrNull(json, 'caption'),
    altText: Json.strOrNull(json, 'alt_text'),
    photographer: Json.strOrNull(json, 'photographer'),
    copyright: Json.strOrNull(json, 'copyright'),
    takenAt: Json.strOrNull(json, 'taken_at'),
    displayOrder: Json.intVal(json, 'display_order'),
  );

  final String id;
  final String mediaType;
  final String? url;
  final String? mimeType;
  final String? youtubeId;
  final String? embedUrl;
  final String? thumbnailUrl;
  final String? videoTitle;
  final String? videoDescription;
  final String? caption;
  final String? altText;

  /// Credited per photograph, not per article. Eleven pictures of one meeting
  /// are often taken by three people, and an article-level "photographs by"
  /// line quietly takes two of them off the record.
  final String? photographer;

  final String? copyright;
  final String? takenAt;
  final int displayOrder;

  bool get isImage => mediaType == 'image';
  bool get isVideo => mediaType == 'youtube_video';

  /// The line under a photograph: what it shows, then who took it.
  String? get creditLine {
    final List<String> parts = <String>[
      ?caption,
      if (photographer != null) 'Photograph: $photographer',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// Where a story came from.
class NewsSource {
  const NewsSource({
    required this.id,
    required this.sourceType,
    this.title,
    this.author,
    this.publisher,
    this.url,
    this.publishedOn,
    this.notes,
  });

  factory NewsSource.fromJson(Map<String, dynamic> json) => NewsSource(
    id: Json.str(json, 'id'),
    sourceType: Json.str(json, 'source_type', fallback: 'other'),
    title: Json.strOrNull(json, 'title'),
    author: Json.strOrNull(json, 'author'),
    publisher: Json.strOrNull(json, 'publisher'),
    url: Json.strOrNull(json, 'url'),
    publishedOn: Json.strOrNull(json, 'published_on'),
    notes: Json.strOrNull(json, 'notes'),
  );

  final String id;
  final String sourceType;
  final String? title;
  final String? author;
  final String? publisher;
  final String? url;
  final String? publishedOn;
  final String? notes;

  String get typeLabel => NewsSourceTypes.label(sourceType);
}

/// The kinds of source a story can name.
class NewsSourceTypes {
  const NewsSourceTypes._();

  static const List<({String value, String label})> all = <({String value, String label})>[
    (value: 'community_submission', label: 'Sent in by a member'),
    (value: 'editorial_team', label: 'The Editorial Team'),
    (value: 'community_organization', label: 'A community organisation'),
    (value: 'official_announcement', label: 'An official announcement'),
    (value: 'newspaper', label: 'A newspaper'),
    (value: 'government', label: 'Government'),
    (value: 'interview', label: 'An interview'),
    (value: 'other', label: 'Somewhere else'),
  ];

  static String label(String value) {
    for (final ({String value, String label}) type in all) {
      if (type.value == value) return type.label;
    }
    return value;
  }
}

/// A category, kept by the Editorial Team.
class NewsCategory {
  const NewsCategory({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    this.accent,
    this.isActive = true,
    this.storyCount = 0,
  });

  factory NewsCategory.fromJson(Map<String, dynamic> json) => NewsCategory(
    id: Json.str(json, 'id'),
    slug: Json.str(json, 'slug'),
    name: Json.str(json, 'name'),
    description: Json.strOrNull(json, 'description'),
    accent: Json.strOrNull(json, 'accent'),
    isActive: Json.boolVal(json, 'is_active', fallback: true),
    storyCount: Json.intVal(json, 'story_count'),
  );

  final String id;
  final String slug;
  final String name;
  final String? description;
  final String? accent;
  final bool isActive;
  final int storyCount;
}

/// The front of the section, in one response.
class NewsOverview {
  const NewsOverview({
    this.announcements = const <NewsSummary>[],
    this.featured,
    this.latest = const <NewsSummary>[],
    this.videos = const <NewsSummary>[],
    this.categories = const <NewsCategory>[],
    this.total = 0,
  });

  factory NewsOverview.fromJson(Map<String, dynamic> json) => NewsOverview(
    announcements: Json.objectList(json, 'announcements')
        .map(NewsSummary.fromJson)
        .toList(growable: false),
    featured: json['featured'] == null
        ? null
        : NewsSummary.fromJson(json['featured'] as Map<String, dynamic>),
    latest: Json.objectList(json, 'latest').map(NewsSummary.fromJson).toList(growable: false),
    videos: Json.objectList(json, 'videos').map(NewsSummary.fromJson).toList(growable: false),
    categories: Json.objectList(json, 'categories')
        .map(NewsCategory.fromJson)
        .toList(growable: false),
    total: Json.intVal(json, 'total'),
  );

  /// The announcements that sit above everything. Each expires on its own, so
  /// an urgent notice stops being urgent without anybody remembering to take
  /// it down.
  final List<NewsSummary> announcements;

  final NewsSummary? featured;
  final List<NewsSummary> latest;
  final List<NewsSummary> videos;
  final List<NewsCategory> categories;
  final int total;

  bool get isEmpty => latest.isEmpty && featured == null && announcements.isEmpty;
}

/// A story as the Editorial Team sees it — with its state, its history and the
/// decisions taken on it.
class EditorialNews {
  const EditorialNews({
    required this.story,
    this.status = 'draft',
    this.categoryId,
    this.scheduledPublishAt,
    this.importantExpiresAt,
    this.reviewNotes,
    this.seoTitle,
    this.seoDescription,
    this.reviews = const <NewsReview>[],
    this.revisions = const <NewsRevision>[],
  });

  factory EditorialNews.fromJson(Map<String, dynamic> json) => EditorialNews(
    story: NewsStory.fromJson(json),
    status: Json.str(json, 'status', fallback: 'draft'),
    categoryId: Json.strOrNull(json, 'category_id'),
    scheduledPublishAt: Json.strOrNull(json, 'scheduled_publish_at'),
    importantExpiresAt: Json.strOrNull(json, 'important_expires_at'),
    reviewNotes: Json.strOrNull(json, 'review_notes'),
    seoTitle: Json.strOrNull(json, 'seo_title'),
    seoDescription: Json.strOrNull(json, 'seo_description'),
    reviews: Json.objectList(json, 'reviews').map(NewsReview.fromJson).toList(growable: false),
    revisions: Json.objectList(json, 'revisions')
        .map(NewsRevision.fromJson)
        .toList(growable: false),
  );

  final NewsStory story;
  final String status;
  final String? categoryId;
  final String? scheduledPublishAt;
  final String? importantExpiresAt;
  final String? reviewNotes;
  final String? seoTitle;
  final String? seoDescription;
  final List<NewsReview> reviews;
  final List<NewsRevision> revisions;
}

/// One editorial decision.
class NewsReview {
  const NewsReview({required this.decision, this.comment, this.reviewerName, this.createdAt});

  factory NewsReview.fromJson(Map<String, dynamic> json) => NewsReview(
    decision: Json.str(json, 'decision'),
    comment: Json.strOrNull(json, 'comment'),
    reviewerName: Json.strOrNull(json, 'reviewer_name'),
    createdAt: Json.strOrNull(json, 'created_at'),
  );

  final String decision;
  final String? comment;
  final String? reviewerName;
  final String? createdAt;
}

/// One saved version.
class NewsRevision {
  const NewsRevision({
    required this.id,
    this.title,
    this.changeSummary,
    this.editorName,
    this.createdAt,
  });

  factory NewsRevision.fromJson(Map<String, dynamic> json) => NewsRevision(
    id: Json.str(json, 'id'),
    title: Json.strOrNull(json, 'title'),
    changeSummary: Json.strOrNull(json, 'change_summary'),
    editorName: Json.strOrNull(json, 'editor_name'),
    createdAt: Json.strOrNull(json, 'created_at'),
  );

  final String id;
  final String? title;
  final String? changeSummary;
  final String? editorName;
  final String? createdAt;
}

/// The states a story moves through, and what each one means to an editor.
class NewsStatus {
  const NewsStatus._();

  static const List<({String value, String label, String meaning})> all =
      <({String value, String label, String meaning})>[
        (value: 'draft', label: 'Drafts', meaning: 'Being written. Nobody else can see it.'),
        (
          value: 'pending_review',
          label: 'Waiting',
          meaning: 'Sent for review. An editor needs to read it.',
        ),
        (
          value: 'changes_requested',
          label: 'Needs more',
          meaning: 'An editor asked for something before it can go out.',
        ),
        (value: 'approved', label: 'Approved', meaning: 'Ready. Somebody has to publish it.'),
        (
          value: 'scheduled',
          label: 'Scheduled',
          meaning: 'Approved and waiting for its moment. Not readable until then.',
        ),
        (value: 'published', label: 'Published', meaning: 'Live, and part of the archive.'),
        (
          value: 'archived',
          label: 'Archived',
          meaning: 'Off the front page. Still readable at its own address.',
        ),
        (value: 'rejected', label: 'Declined', meaning: 'Will not be published.'),
      ];

  static String label(String value) {
    for (final ({String value, String label, String meaning}) status in all) {
      if (status.value == value) return status.label;
    }
    return value;
  }

  static String meaning(String value) {
    for (final ({String value, String label, String meaning}) status in all) {
      if (status.value == value) return status.meaning;
    }
    return '';
  }
}
