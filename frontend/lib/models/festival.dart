import 'content_status.dart';
import 'content_record.dart';
import 'video.dart';

/// One edition of a festival — Leboku 2026, Leboku 2027, and so on.
///
/// Each year is its own record, which is what turns the festival section into
/// a year-by-year archive rather than a page that is overwritten annually.
class Festival {
  const Festival({
    required this.id,
    required this.slug,
    required this.name,
    required this.year,
    required this.status,
    this.theme,
    this.description,
    this.startDate,
    this.endDate,
    this.location,
    this.programme = const <Map<String, dynamic>>[],
    this.sponsors = const <Map<String, dynamic>>[],
    this.announcements = const <Map<String, dynamic>>[],
    this.committee = const <Map<String, dynamic>>[],
    this.coverMediaId,
    this.galleryId,
    this.isArchived = false,
  });

  factory Festival.fromJson(Map<String, dynamic> json) {
    return Festival(
      id: Json.str(json, 'id'),
      slug: Json.str(json, 'slug'),
      name: Json.str(json, 'name', fallback: 'Festival'),
      year: Json.intVal(json, 'year'),
      status: Json.str(json, 'status'),
      theme: Json.strOrNull(json, 'theme'),
      description: Json.strOrNull(json, 'description'),
      startDate: Json.strOrNull(json, 'start_date'),
      endDate: Json.strOrNull(json, 'end_date'),
      location: Json.strOrNull(json, 'location'),
      // These arrive already decoded from their stored JSON by the Worker.
      programme: Json.objectList(json, 'programme'),
      sponsors: Json.objectList(json, 'sponsors'),
      announcements: Json.objectList(json, 'announcements'),
      committee: Json.objectList(json, 'committee'),
      coverMediaId: Json.strOrNull(json, 'cover_media_id'),
      galleryId: Json.strOrNull(json, 'gallery_id'),
      isArchived: Json.boolVal(json, 'is_archived'),
    );
  }

  final String id;
  final String slug;
  final String name;
  final int year;
  final String status;
  final String? theme;
  final String? description;
  final String? startDate;
  final String? endDate;
  final String? location;
  final List<Map<String, dynamic>> programme;
  final List<Map<String, dynamic>> sponsors;
  final List<Map<String, dynamic>> announcements;
  final List<Map<String, dynamic>> committee;
  final String? coverMediaId;
  final String? galleryId;
  final bool isArchived;

  String get displayName => '$name $year';

  /// Whether this edition is still ahead of us, which decides whether the page
  /// shows a countdown or an archive.
  bool get isUpcoming {
    final DateTime? start = DateTime.tryParse(startDate ?? '');
    if (start == null) return !isArchived;
    return start.isAfter(DateTime.now());
  }

  Duration? get timeUntilStart {
    final DateTime? start = DateTime.tryParse(startDate ?? '');
    if (start == null) return null;
    final Duration remaining = start.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }
}

/// A festival together with everything attached to it.
///
/// One request renders a whole festival page: the edition, its programme
/// events, its photographs and its videos.
class FestivalDetail {
  const FestivalDetail({
    required this.festival,
    required this.events,
    required this.videos,
    required this.gallery,
  });

  factory FestivalDetail.fromJson(Map<String, dynamic> json) {
    return FestivalDetail(
      festival: Festival.fromJson((json['festival'] as Map<String, dynamic>?) ?? <String, dynamic>{}),
      events: Json.objectList(json, 'events').map(ContentRecord.fromJson).toList(growable: false),
      videos: Json.objectList(json, 'videos').map(Video.fromJson).toList(growable: false),
      gallery: Json.objectList(json, 'gallery'),
    );
  }

  final Festival festival;
  final List<ContentRecord> events;
  final List<Video> videos;

  /// Gallery items already joined to their media URLs by the Worker.
  final List<Map<String, dynamic>> gallery;

  bool get hasContent => events.isNotEmpty || videos.isNotEmpty || gallery.isNotEmpty;
}

/// A single year in the festival series, as listed on `/leboku`.
class FestivalEdition {
  const FestivalEdition({
    required this.id,
    required this.slug,
    required this.name,
    required this.year,
    this.theme,
    this.startDate,
    this.endDate,
    this.isArchived = false,
  });

  factory FestivalEdition.fromJson(Map<String, dynamic> json) {
    return FestivalEdition(
      id: Json.str(json, 'id'),
      slug: Json.str(json, 'slug'),
      name: Json.str(json, 'name'),
      year: Json.intVal(json, 'year'),
      theme: Json.strOrNull(json, 'theme'),
      startDate: Json.strOrNull(json, 'start_date'),
      endDate: Json.strOrNull(json, 'end_date'),
      isArchived: Json.boolVal(json, 'is_archived'),
    );
  }

  final String id;
  final String slug;
  final String name;
  final int year;
  final String? theme;
  final String? startDate;
  final String? endDate;
  final bool isArchived;
}
