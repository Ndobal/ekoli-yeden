import '../core/config/app_config.dart';
import '../models/video.dart';
import '../services/api/api_client.dart';
import '../services/api/api_response.dart';

/// The video archive.
///
/// Every video is hosted on YouTube. This reads the catalogue records that
/// organise them into Leboku, history, interviews, culture, community, events,
/// documentaries, music and oral history.
class VideoRepository {
  const VideoRepository(this._api);

  final ApiClient _api;

  Future<PaginatedResult<Video>> list({
    int page = 1,
    int perPage = AppConfig.defaultPageSize,
    String? category,
    String? search,
    String? festivalId,
  }) {
    return _api.list<Video>(
      '/api/videos',
      Video.fromJson,
      authenticated: false,
      query: <String, dynamic>{
        'page': page,
        'perPage': perPage,
        'category': ?category,
        'related_festival_id': ?festivalId,
        if (search != null && search.isNotEmpty) 'q': search,
      },
    );
  }

  Future<Video> find(String identifier) async {
    final Map<String, dynamic> data = await _api.get(
      '/api/videos/$identifier',
      authenticated: false,
    );
    return Video.fromJson(data);
  }

  Future<PaginatedResult<Video>> adminList({
    int page = 1,
    int perPage = AppConfig.defaultPageSize,
    String? status,
  }) {
    return _api.list<Video>(
      '/api/admin/videos',
      Video.fromJson,
      query: <String, dynamic>{'page': page, 'perPage': perPage, 'status': ?status},
    );
  }

  /// Adds a video to the archive.
  ///
  /// `youtubeVideoId` may be a bare id or any YouTube URL — the Worker extracts
  /// the id, so a Media Team volunteer can paste whatever their browser shows.
  Future<Video> create({
    required String title,
    required String youtubeVideoId,
    String? description,
    String? category,
    String? publishedDate,
    String? relatedFestivalId,
    String? speaker,
    String? transcript,
  }) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/admin/videos',
      body: <String, dynamic>{
        'title': title,
        'youtube_video_id': youtubeVideoId,
        'description': ?description,
        'category': ?category,
        'published_date': ?publishedDate,
        'related_festival_id': ?relatedFestivalId,
        'speaker': ?speaker,
        'transcript': ?transcript,
      },
    );
    return Video.fromJson(data);
  }

  Future<Video> update(String id, Map<String, dynamic> values) async {
    final Map<String, dynamic> data = await _api.patch('/api/admin/videos/$id', body: values);
    return Video.fromJson(data);
  }

  Future<Video> changeStatus(String id, String status) async {
    final Map<String, dynamic> data = await _api.patch(
      '/api/admin/videos/$id/status',
      body: <String, dynamic>{'status': status},
    );
    return Video.fromJson(data);
  }

  Future<void> delete(String id) async => _api.delete('/api/admin/videos/$id');
}
