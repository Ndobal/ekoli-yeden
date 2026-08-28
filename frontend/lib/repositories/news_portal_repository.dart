import '../core/config/app_config.dart';
import '../models/content_status.dart';
import '../models/news.dart';
import '../services/api/api_client.dart';
import '../services/api/api_response.dart';

/// THE NEWS PORTAL.
///
/// Separate from the generated content repository that also serves `/api/news`.
/// That one returns the plain record every section of the archive uses; this
/// one returns the same stories with their photographs, their film, their
/// category and their sources attached, which is what a publication needs and
/// what a record does not.
///
/// Nothing here can return an unpublished story. The public methods hit
/// `/api/news-portal`, whose queries require `status = 'published'` and a
/// publication time that has passed — there is no flag on this side that could
/// ask for anything else.
class NewsPortalRepository {
  const NewsPortalRepository(this._api);

  final ApiClient _api;

  // --- Public ---------------------------------------------------------------

  /// The whole front of the section in one request.
  ///
  /// One call rather than five, because this is the page people land on from a
  /// shared link, usually on a phone, and five round trips before anything
  /// renders is the difference between a news site and a spinner.
  Future<NewsOverview> overview() async {
    final Map<String, dynamic> data =
        await _api.get('/api/news-portal/overview', authenticated: false);
    return NewsOverview.fromJson(data);
  }

  Future<PaginatedResult<NewsSummary>> list({
    int page = 1,
    int perPage = AppConfig.defaultPageSize,
    String? category,
    String? tag,
    String? query,
    bool videoOnly = false,
  }) {
    return _api.list<NewsSummary>(
      '/api/news-portal',
      NewsSummary.fromJson,
      authenticated: false,
      query: <String, dynamic>{
        'page': page,
        'perPage': perPage,
        'category': ?category,
        'tag': ?tag,
        'q': ?query,
        if (videoOnly) 'video': 'true',
      },
    );
  }

  Future<NewsStory> story(String slug) async {
    final Map<String, dynamic> data =
        await _api.get('/api/news-portal/$slug', authenticated: false);
    return NewsStory.fromJson(data);
  }

  Future<List<NewsCategory>> categories() async {
    final Map<String, dynamic> data =
        await _api.get('/api/news-portal/categories', authenticated: false);
    return (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(NewsCategory.fromJson)
        .toList(growable: false);
  }

  Future<List<({String slug, String name, int count})>> tags() async {
    final Map<String, dynamic> data =
        await _api.get('/api/news-portal/tags', authenticated: false);
    return Json.objectList(data, 'items')
        .map(
          (Map<String, dynamic> row) => (
            slug: Json.str(row, 'slug'),
            name: Json.str(row, 'name'),
            count: Json.intVal(row, 'usage_count'),
          ),
        )
        .toList(growable: false);
  }

  // --- Editorial ------------------------------------------------------------

  /// Every story, whatever its state, with the counts for the tabs.
  Future<({List<EditorialNewsRow> items, Map<String, int> counts, int total, int totalPages})>
  editorialList({String status = 'all', String? query, int page = 1}) async {
    final Map<String, dynamic> data = await _api.get(
      '/api/editorial/news-list',
      query: <String, dynamic>{'status': status, 'q': ?query, 'page': page, 'perPage': 30},
    );

    final Map<String, dynamic> rawCounts =
        (data['counts'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    return (
      items: Json.objectList(data, 'items')
          .map(EditorialNewsRow.fromJson)
          .toList(growable: false),
      counts: rawCounts.map(
        (String key, dynamic value) =>
            MapEntry<String, int>(key, value is num ? value.toInt() : 0),
      ),
      total: Json.intVal(data, 'total'),
      totalPages: Json.intVal(data, 'totalPages', fallback: 1),
    );
  }

  Future<EditorialNews> editorialStory(String identifier) async {
    final Map<String, dynamic> data = await _api.get('/api/editorial/news/$identifier');
    return EditorialNews.fromJson(data);
  }

  /// Starts a story. Always a draft — there is no parameter that publishes.
  Future<String> create(Map<String, dynamic> values) async {
    final Map<String, dynamic> data = await _api.post('/api/editorial/news', body: values);
    return Json.str(data, 'id');
  }

  Future<void> update(String id, Map<String, dynamic> values, {String? changeSummary}) =>
      _api.patch(
        '/api/editorial/news/$id',
        body: <String, dynamic>{...values, 'change_summary': ?changeSummary},
      );

  /// Every movement through the workflow: submit, approve, request changes,
  /// publish, schedule, archive, reject.
  Future<void> setState(
    String id, {
    required String status,
    String? comment,
    String? scheduledFor,
  }) => _api.post(
    '/api/editorial/news/$id/state',
    body: <String, dynamic>{
      'status': status,
      'comment': ?comment,
      'scheduled_publish_at': ?scheduledFor,
    },
  );

  Future<void> setFlags(
    String id, {
    bool? featured,
    bool? important,
    String? importantExpiresAt,
  }) => _api.post(
    '/api/editorial/news/$id/flags',
    body: <String, dynamic>{
      'is_featured': ?featured,
      'is_important': ?important,
      'important_expires_at': ?importantExpiresAt,
    },
  );

  /// Attaches a photograph already in the media library, or a YouTube video.
  Future<void> addMedia(
    String newsId, {
    required String mediaType,
    String? mediaId,
    String? youtubeUrl,
    String? caption,
    String? altText,
    String? photographer,
    String? videoTitle,
  }) => _api.post(
    '/api/editorial/news/$newsId/media',
    body: <String, dynamic>{
      'media_type': mediaType,
      'media_id': ?mediaId,
      'youtube_url': ?youtubeUrl,
      'caption': ?caption,
      'alt_text': ?altText,
      'photographer': ?photographer,
      'video_title': ?videoTitle,
    },
  );

  Future<void> updateMedia(
    String newsId,
    String mediaId, {
    String? caption,
    String? altText,
    String? photographer,
  }) => _api.patch(
    '/api/editorial/news/$newsId/media/$mediaId',
    body: <String, dynamic>{
      'caption': ?caption,
      'alt_text': ?altText,
      'photographer': ?photographer,
    },
  );

  Future<void> removeMedia(String newsId, String mediaId) =>
      _api.delete('/api/editorial/news/$newsId/media/$mediaId');

  Future<void> reorderMedia(String newsId, List<String> order) =>
      _api.post('/api/editorial/news/$newsId/media/order', body: <String, dynamic>{'order': order});

  Future<void> addSource(
    String newsId, {
    required String sourceType,
    String? title,
    String? author,
    String? url,
    String? notes,
  }) => _api.post(
    '/api/editorial/news/$newsId/sources',
    body: <String, dynamic>{
      'source_type': sourceType,
      'title': ?title,
      'author': ?author,
      'url': ?url,
      'notes': ?notes,
    },
  );

  Future<void> removeSource(String newsId, String sourceId) =>
      _api.delete('/api/editorial/news/$newsId/sources/$sourceId');

  /// Creates or edits a category, without a deployment.
  Future<void> saveCategory({
    String? id,
    required String name,
    String? description,
    int sortOrder = 500,
    bool isActive = true,
  }) => _api.post(
    '/api/editorial/news-categories',
    body: <String, dynamic>{
      'id': ?id,
      'name': name,
      'description': ?description,
      'sort_order': sortOrder,
      'is_active': isActive,
    },
  );

  /// Runs the scheduler by hand, for a story that should have gone out and did
  /// not.
  Future<String> publishDue() async {
    final Map<String, dynamic> data = await _api.post('/api/editorial/news/publish-due');
    return Json.str(data, 'message', fallback: 'Done.');
  }
}

/// A row in the editorial list.
class EditorialNewsRow {
  const EditorialNewsRow({
    required this.id,
    required this.slug,
    required this.title,
    required this.status,
    this.excerpt,
    this.newsDate,
    this.publishedAt,
    this.scheduledPublishAt,
    this.isFeatured = false,
    this.isImportant = false,
    this.contributorName,
    this.authorName,
    this.reviewNotes,
    this.categoryName,
    this.coverUrl,
    this.updatedAt,
  });

  factory EditorialNewsRow.fromJson(Map<String, dynamic> json) => EditorialNewsRow(
    id: Json.str(json, 'id'),
    slug: Json.str(json, 'slug'),
    title: Json.str(json, 'title'),
    status: Json.str(json, 'status', fallback: 'draft'),
    excerpt: Json.strOrNull(json, 'excerpt'),
    newsDate: Json.strOrNull(json, 'news_date'),
    publishedAt: Json.strOrNull(json, 'published_at'),
    scheduledPublishAt: Json.strOrNull(json, 'scheduled_publish_at'),
    isFeatured: Json.boolVal(json, 'is_featured'),
    isImportant: Json.boolVal(json, 'is_important'),
    contributorName: Json.strOrNull(json, 'contributor_name'),
    authorName: Json.strOrNull(json, 'author_name'),
    reviewNotes: Json.strOrNull(json, 'review_notes'),
    categoryName: Json.strOrNull(json, 'category_name'),
    coverUrl: Json.strOrNull(json, 'cover_url'),
    updatedAt: Json.strOrNull(json, 'updated_at'),
  );

  final String id;
  final String slug;
  final String title;
  final String status;
  final String? excerpt;
  final String? newsDate;
  final String? publishedAt;
  final String? scheduledPublishAt;
  final bool isFeatured;
  final bool isImportant;

  /// Who sent it in, where somebody did. Shown in the queue so an editor knows
  /// at a glance whether there is a person waiting on an answer.
  final String? contributorName;

  final String? authorName;
  final String? reviewNotes;
  final String? categoryName;
  final String? coverUrl;
  final String? updatedAt;

  bool get isFromMember => contributorName != null;
}
