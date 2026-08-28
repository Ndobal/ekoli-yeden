import '../core/config/app_config.dart';
import '../models/content_status.dart';
import '../models/submissions.dart';
import '../services/api/api_client.dart';
import '../services/api/api_response.dart';

/// NEWS THE COMMUNITY SENDS IN.
///
/// Writing news and publishing news are different permissions, and this is the
/// gap between them: anybody may write, an administrator decides what goes out
/// under the community's name.
///
/// Before this existed, a member who heard that the borehole was finished had
/// nowhere to put it except the generic contribution form, where it arrived as
/// an untitled file and sat in a media queue. That is what a structured
/// destination fixes.
class NewsRepository {
  const NewsRepository(this._api);

  final ApiClient _api;

  /// The categories, and what the form should tell somebody before they write.
  Future<({List<({String value, String label})> categories, List<String> guidance})>
  formOptions() async {
    final Map<String, dynamic> data =
        await _api.get('/api/contribute/news/form', authenticated: false);

    return (
      categories: Json.objectList(data, 'categories')
          .map(
            (Map<String, dynamic> row) =>
                (value: Json.str(row, 'value'), label: Json.str(row, 'label')),
          )
          .toList(growable: false),
      guidance: Json.stringList(data, 'guidance'),
    );
  }

  /// Sends news for review. Returns the reference the contributor keeps.
  Future<({String reference, String message})> submit(Map<String, dynamic> values) async {
    final Map<String, dynamic> data = await _api.post('/api/contribute/news', body: values);
    return (
      reference: Json.str(data, 'reference', fallback: 'EY-000000'),
      message: Json.str(
        data,
        'message',
        fallback: 'Thank you. An administrator reads everything that arrives.',
      ),
    );
  }

  /// What happened to something somebody sent in, by their reference.
  Future<({String status, String explanation, String? reviewNotes, String? newsSlug})> status(
    String reference,
  ) async {
    final Map<String, dynamic> data =
        await _api.get('/api/contribute/news/$reference', authenticated: false);

    return (
      status: Json.str(data, 'status'),
      explanation: Json.str(data, 'explanation'),
      reviewNotes: Json.strOrNull(data, 'review_notes'),
      newsSlug: Json.strOrNull(data, 'slug'),
    );
  }

  // --- The administrators' queue -------------------------------------------

  Future<PaginatedResult<NewsSubmission>> submissions({
    String status = 'pending_review',
    int page = 1,
    int perPage = AppConfig.defaultPageSize,
  }) {
    return _api.list<NewsSubmission>(
      '/api/admin/news-submissions',
      NewsSubmission.fromJson,
      query: <String, dynamic>{'status': status, 'page': page, 'perPage': perPage},
    );
  }

  /// Publishes it, optionally reworded first.
  ///
  /// What the administrator cannot do is lose who sent it: the contributor and
  /// their account of how they know travel onto the published item whatever is
  /// changed here.
  Future<String> promote(
    String id, {
    String? title,
    String? excerpt,
    String? body,
    String? category,
  }) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/admin/news-submissions/$id/promote',
      body: <String, dynamic>{
        'title': ?title,
        'excerpt': ?excerpt,
        'body': ?body,
        'category': ?category,
      },
    );
    return Json.strOrNull(data, 'slug') ?? '';
  }

  /// Ask for more, or decline it.
  Future<void> review(String id, {required String status, String? notes}) => _api.post(
    '/api/admin/news-submissions/$id/review',
    body: <String, dynamic>{'status': status, 'review_notes': ?notes},
  );
}
