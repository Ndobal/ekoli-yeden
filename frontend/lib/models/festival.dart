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
    this.fullName,
    this.tagline,
    this.logoUrl,
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
    this.isFeatured = false,
  });

  factory Festival.fromJson(Map<String, dynamic> json) {
    return Festival(
      id: Json.str(json, 'id'),
      slug: Json.str(json, 'slug'),
      name: Json.str(json, 'name', fallback: 'Festival'),
      year: Json.intVal(json, 'year'),
      status: Json.str(json, 'status'),
      fullName: Json.strOrNull(json, 'full_name'),
      tagline: Json.strOrNull(json, 'tagline'),
      logoUrl: Json.strOrNull(json, 'logo_url'),
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
      isFeatured: Json.boolVal(json, 'is_featured'),
    );
  }

  final String id;
  final String slug;

  /// The short name people use — "Leboku".
  final String name;

  final int year;
  final String status;

  /// The full ceremonial name where it differs — "Lekoli Boku New Yam Festival".
  final String? fullName;

  /// The line carried on the festival's own materials.
  final String? tagline;

  /// The festival's own logo, resolved by the Worker. Null until one is
  /// uploaded, in which case the page draws a branded panel instead.
  final String? logoUrl;

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

  /// The edition the site gives prominence to.
  final bool isFeatured;

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

/// The festivals index: the one to feature, and the rest.
///
/// Which edition is featured is decided by the server — whichever the Editorial
/// Team flagged, falling back to the most recent unarchived one — so the client
/// makes no assumption about which festival matters.
class FestivalIndex {
  const FestivalIndex({required this.featured, required this.past, required this.total});

  factory FestivalIndex.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? featured = json['featured'] as Map<String, dynamic>?;
    return FestivalIndex(
      featured: featured == null ? null : Festival.fromJson(featured),
      past: Json.objectList(json, 'past').map(Festival.fromJson).toList(growable: false),
      total: Json.intVal(json, 'total'),
    );
  }

  final Festival? featured;
  final List<Festival> past;
  final int total;

  bool get isEmpty => featured == null && past.isEmpty;
}

/// One phase of a festival's programme.
///
/// A festival is not a single day: there is a run-up, the main day, and
/// activities afterwards. Keeping the phase means the programme reads as a
/// sequence rather than an undifferentiated list.
class ProgrammePhase {
  const ProgrammePhase({required this.phase, required this.items});

  factory ProgrammePhase.fromJson(Map<String, dynamic> json) {
    return ProgrammePhase(
      phase: Json.str(json, 'phase', fallback: 'other'),
      items: Json.objectList(json, 'items').map(ContentRecord.fromJson).toList(growable: false),
    );
  }

  /// `lead_up`, `main_day`, `after` or `other`.
  final String phase;

  final List<ContentRecord> items;
}

/// A festival together with everything attached to it.
///
/// One request renders a whole festival page: the edition, its programme
/// grouped by phase, its photographs and its videos.
class FestivalDetail {
  const FestivalDetail({
    required this.festival,
    required this.events,
    required this.programme,
    required this.videos,
    required this.gallery,
    this.albums = const <FestivalAlbum>[],
    this.galleryId,
    this.gallerySlug,
  });

  factory FestivalDetail.fromJson(Map<String, dynamic> json) {
    return FestivalDetail(
      festival: Festival.fromJson((json['festival'] as Map<String, dynamic>?) ?? <String, dynamic>{}),
      events: Json.objectList(json, 'events').map(ContentRecord.fromJson).toList(growable: false),
      programme: Json.objectList(json, 'programme')
          .map(ProgrammePhase.fromJson)
          .toList(growable: false),
      videos: Json.objectList(json, 'videos').map(Video.fromJson).toList(growable: false),
      gallery: Json.objectList(json, 'gallery'),
      albums: Json.objectList(json, 'albums')
          .map(FestivalAlbum.fromJson)
          .toList(growable: false),
      galleryId: Json.strOrNull(json, 'gallery_id'),
      gallerySlug: Json.strOrNull(json, 'gallery_slug'),
    );
  }

  final Festival festival;
  final List<ContentRecord> events;

  /// The programme, already grouped and ordered by the Worker.
  final List<ProgrammePhase> programme;

  final List<Video> videos;

  /// Gallery items already joined to their media URLs by the Worker.
  final List<Map<String, dynamic>> gallery;

  /// The album this edition's photographs belong to.
  ///
  /// Present even when the album is empty, because "this festival has an album
  /// and nothing is in it" is a different — and more useful — thing to say than
  /// nothing at all. It is what lets the page ask for photographs.
  /// Every year of this festival, newest first.
  ///
  /// Each is an ordinary gallery carrying `festival_id` and `year`, so the same
  /// record is listed by the Gallery section — one album, two doors.
  final List<FestivalAlbum> albums;

  final String? galleryId;
  final String? gallerySlug;

  bool get hasContent =>
      events.isNotEmpty || videos.isNotEmpty || gallery.isNotEmpty || programme.isNotEmpty;
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


/// One year of a festival.
class FestivalAlbum {
  const FestivalAlbum({
    required this.id,
    required this.slug,
    required this.title,
    this.year,
    this.description,
    this.location,
    this.eventDate,
    this.coverUrl,
    this.photoCount = 0,
    this.videoCount = 0,
  });

  factory FestivalAlbum.fromJson(Map<String, dynamic> json) => FestivalAlbum(
    id: Json.str(json, 'id'),
    slug: Json.str(json, 'slug'),
    title: Json.str(json, 'title'),
    year: Json.intOrNull(json, 'year'),
    description: Json.strOrNull(json, 'description'),
    location: Json.strOrNull(json, 'location'),
    eventDate: Json.strOrNull(json, 'event_date'),
    coverUrl: Json.strOrNull(json, 'cover_url'),
    photoCount: Json.intVal(json, 'photo_count'),
    videoCount: Json.intVal(json, 'video_count'),
  );

  final String id;
  final String slug;
  final String title;
  final int? year;
  final String? description;
  final String? location;
  final String? eventDate;
  final String? coverUrl;
  final int photoCount;
  final int videoCount;

  /// "12 photographs and 3 films", or what is true of it.
  String get holdings {
    final List<String> parts = <String>[
      if (photoCount > 0) '$photoCount photograph${photoCount == 1 ? '' : 's'}',
      if (videoCount > 0) '$videoCount film${videoCount == 1 ? '' : 's'}',
    ];
    if (parts.isEmpty) return 'Nothing published yet';
    return parts.join(' and ');
  }
}
