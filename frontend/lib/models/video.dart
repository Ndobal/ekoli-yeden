import '../core/constants/app_constants.dart';
import 'content_status.dart';

/// A video in the archive.
///
/// The file itself always lives on YouTube; this is the catalogue record. The
/// watch, embed and thumbnail URLs are derived by the Worker from the video id,
/// so a video renders with no YouTube API call on the page.
class Video {
  const Video({
    required this.id,
    required this.title,
    required this.youtubeVideoId,
    required this.thumbnailUrl,
    required this.watchUrl,
    required this.embedUrl,
    required this.status,
    this.slug,
    this.description,
    this.category,
    this.publishedDate,
    this.durationSeconds,
    this.speaker,
    this.transcript,
    this.isFeatured = false,
    this.verificationStatus,
    this.relatedFestivalId,
    this.relatedEventId,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    final String videoId = Json.str(json, 'youtube_video_id');
    return Video(
      id: Json.str(json, 'id'),
      title: Json.str(json, 'title', fallback: 'Untitled video'),
      youtubeVideoId: videoId,
      thumbnailUrl: Json.str(
        json,
        'thumbnail_url',
        fallback: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
      ),
      watchUrl: Json.str(
        json,
        'watch_url',
        fallback: 'https://www.youtube.com/watch?v=$videoId',
      ),
      embedUrl: Json.str(
        json,
        'embed_url',
        fallback: 'https://www.youtube-nocookie.com/embed/$videoId',
      ),
      status: Json.str(json, 'status', fallback: ContentStatus.draft),
      slug: Json.strOrNull(json, 'slug'),
      description: Json.strOrNull(json, 'description'),
      category: Json.strOrNull(json, 'category'),
      publishedDate: Json.strOrNull(json, 'published_date'),
      durationSeconds: Json.intOrNull(json, 'duration_seconds'),
      speaker: Json.strOrNull(json, 'speaker'),
      transcript: Json.strOrNull(json, 'transcript'),
      isFeatured: Json.boolVal(json, 'is_featured'),
      verificationStatus: Json.strOrNull(json, 'verification_status'),
      relatedFestivalId: Json.strOrNull(json, 'related_festival_id'),
      relatedEventId: Json.strOrNull(json, 'related_event_id'),
    );
  }

  final String id;
  final String title;
  final String youtubeVideoId;
  final String thumbnailUrl;
  final String watchUrl;
  final String embedUrl;
  final String status;
  final String? slug;
  final String? description;
  final String? category;
  final String? publishedDate;
  final int? durationSeconds;
  final String? speaker;

  /// A written transcript is what makes an oral-history recording searchable —
  /// the difference between a video existing and a video being findable.
  final String? transcript;

  final bool isFeatured;
  final String? verificationStatus;
  final String? relatedFestivalId;
  final String? relatedEventId;

  String get pathSegment => slug ?? id;
  String get categoryLabel => category == null ? 'Uncategorised' : VideoCategories.label(category!);
  bool get hasTranscript => transcript != null && transcript!.trim().isNotEmpty;
}
