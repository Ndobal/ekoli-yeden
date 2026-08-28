import 'content_status.dart';

/// A PHOTOGRAPH IN THE ARCHIVE.
///
/// The descriptive fields are what turn a picture into an archive record: who
/// is in it, where, when, who took it. They are what make a photograph
/// understandable in fifty years by somebody who was not there.
///
/// They are also frequently empty, and the interface says so rather than
/// hiding it. An unlabelled photograph is preserved but not yet documented,
/// and naming that difference is how the archive asks for help with it.
class Photograph {
  const Photograph({
    required this.id,
    required this.url,
    this.galleryId,
    this.gallerySlug,
    this.galleryTitle,
    this.caption,
    this.photographer,
    this.peoplePictured,
    this.takenAt,
    this.location,
    this.contributedBy,
    this.altText,
    this.mimeType,
    this.status,
  });

  factory Photograph.fromJson(Map<String, dynamic> json) {
    return Photograph(
      id: Json.str(json, 'id'),
      url: Json.str(json, 'url'),
      galleryId: Json.strOrNull(json, 'gallery_id'),
      gallerySlug: Json.strOrNull(json, 'gallery_slug'),
      galleryTitle: Json.strOrNull(json, 'gallery_title'),
      caption: Json.strOrNull(json, 'caption'),
      photographer: Json.strOrNull(json, 'photographer'),
      peoplePictured: Json.strOrNull(json, 'people_pictured'),
      takenAt: Json.strOrNull(json, 'taken_at'),
      location: Json.strOrNull(json, 'location'),
      contributedBy: Json.strOrNull(json, 'contributed_by'),
      altText: Json.strOrNull(json, 'alt_text'),
      mimeType: Json.strOrNull(json, 'mime_type'),
      status: Json.strOrNull(json, 'status'),
    );
  }

  final String id;
  final String url;

  /// Which album it belongs to. Carried on the combined stream so a photograph
  /// found there can be traced back to the year it came from.
  final String? galleryId;
  final String? gallerySlug;
  final String? galleryTitle;

  final String? caption;
  final String? photographer;
  final String? peoplePictured;
  final String? takenAt;
  final String? location;

  /// The community member who supplied it, credited on the picture itself.
  final String? contributedBy;

  final String? altText;
  final String? mimeType;
  final String? status;

  bool get isDocumented => caption != null || peoplePictured != null || takenAt != null;

  /// Whether this record is a moving picture rather than a still one.
  ///
  /// An album holds both. A clip of the crowning and a photograph of it are
  /// the same kind of record — same album, same labels, same year — and differ
  /// only in how they are shown, so the distinction lives here rather than in
  /// a separate model that would have to be filed and searched separately.
  bool get isVideo => mimeType != null && mimeType!.startsWith('video/');

  /// What this is called in prose, so a caption or an empty state can say
  /// "video" where it is one without every message needing two versions.
  String get kindNoun => isVideo ? 'video' : 'photograph';

  /// What a screen reader is told. Falls back to saying plainly that the
  /// picture has not been described yet, which is more useful than silence.
  String get accessibleLabel =>
      altText ?? caption ?? 'A $kindNoun from the Ekoli-Yeden archive, not yet described';

  /// The line under the picture: who took it, and who gave it to the archive.
  String? get creditLine {
    final List<String> parts = <String>[
      if (photographer != null) '${isVideo ? 'Filmed' : 'Photograph'} by $photographer',
      if (contributedBy != null) 'Contributed by $contributedBy',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// AN ALBUM AS A FILTER.
///
/// The gallery page opens on the photographs themselves and offers the albums
/// as a row of filters above them. That needs far less than the full album —
/// a name, a count and enough context for one line — so it is a separate,
/// cheap record rather than a list of full albums each carrying its
/// photographs and its prose.
class AlbumSummary {
  const AlbumSummary({
    required this.id,
    required this.slug,
    required this.title,
    required this.itemCount,
    this.description,
    this.category,
    this.eventDate,
    this.location,
    this.festivalId,
    this.isFestivalGallery = false,
    this.videoCount = 0,
  });

  factory AlbumSummary.fromJson(Map<String, dynamic> json) {
    return AlbumSummary(
      id: Json.str(json, 'id'),
      slug: Json.str(json, 'slug'),
      title: Json.str(json, 'title', fallback: 'Album'),
      itemCount: Json.intVal(json, 'item_count'),
      description: Json.strOrNull(json, 'description'),
      category: Json.strOrNull(json, 'category'),
      eventDate: Json.strOrNull(json, 'event_date'),
      location: Json.strOrNull(json, 'location'),
      festivalId: Json.strOrNull(json, 'festival_id'),
      isFestivalGallery: Json.boolVal(json, 'is_festival_gallery'),
      videoCount: Json.intVal(json, 'video_count'),
    );
  }

  final String id;
  final String slug;
  final String title;
  final int itemCount;
  final String? description;
  final String? category;
  final String? eventDate;
  final String? location;
  final String? festivalId;
  final bool isFestivalGallery;
  final int videoCount;

  /// Whether this album has anything in it yet. An empty album is still shown
  /// to anybody who can fill it, and hidden from a visitor who cannot.
  bool get isEmpty => itemCount == 0;

  /// The year a festival album belongs to, pulled from its title where the
  /// album carries no date of its own — "Leboku 2026" is the common shape.
  String? get year {
    if (eventDate != null && eventDate!.length >= 4) return eventDate!.substring(0, 4);
    final RegExpMatch? match = RegExp(r'\b(19|20)\d{2}\b').firstMatch(title);
    return match?.group(0);
  }
}

/// An album: an ordered set of photographs with a title and a description.
///
/// Every festival edition owns one, which is what gives a photograph a year to
/// belong to. Because a festival album is an ordinary gallery, the same
/// photographs also appear in the main Gallery section without being filed
/// twice.
class Gallery {
  const Gallery({
    required this.id,
    required this.slug,
    required this.title,
    required this.status,
    this.description,
    this.category,
    this.eventDate,
    this.location,
    this.festivalId,
    this.isFestivalGallery = false,
    this.items = const <Photograph>[],
    this.total = 0,
  });

  factory Gallery.fromJson(Map<String, dynamic> json) {
    return Gallery(
      id: Json.str(json, 'id'),
      slug: Json.str(json, 'slug'),
      title: Json.str(json, 'title', fallback: 'Album'),
      status: Json.str(json, 'status'),
      description: Json.strOrNull(json, 'description'),
      category: Json.strOrNull(json, 'category'),
      eventDate: Json.strOrNull(json, 'event_date'),
      location: Json.strOrNull(json, 'location'),
      festivalId: Json.strOrNull(json, 'festival_id'),
      isFestivalGallery: Json.boolVal(json, 'is_festival_gallery'),
      items: Json.objectList(json, 'items').map(Photograph.fromJson).toList(growable: false),
      total: Json.intVal(json, 'total'),
    );
  }

  final String id;
  final String slug;
  final String title;
  final String status;
  final String? description;
  final String? category;
  final String? eventDate;
  final String? location;
  final String? festivalId;
  final bool isFestivalGallery;
  final List<Photograph> items;
  final int total;

  bool get isEmpty => items.isEmpty;

  /// How many of the items are film rather than stills.
  ///
  /// Counted from what was loaded rather than stored, so it cannot disagree
  /// with what is actually on the page.
  int get videoCount => items.where((Photograph item) => item.isVideo).length;
}

/// A festival's album as the workspace lists it: the year, the album, and how
/// many photographs are in it, so a Media Team volunteer picks a year rather
/// than hunting for an album by name.
class FestivalAlbum {
  const FestivalAlbum({
    required this.festivalId,
    required this.festivalName,
    required this.year,
    required this.galleryId,
    required this.gallerySlug,
    required this.galleryTitle,
    required this.galleryStatus,
    required this.total,
    this.festivalSlug,
    this.festivalStatus,
    this.counts = const <String, int>{},
  });

  factory FestivalAlbum.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> counts =
        (json['counts'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    return FestivalAlbum(
      festivalId: Json.str(json, 'festival_id'),
      festivalName: Json.str(json, 'festival_name', fallback: 'Festival'),
      year: Json.intVal(json, 'year'),
      galleryId: Json.str(json, 'gallery_id'),
      gallerySlug: Json.str(json, 'gallery_slug'),
      galleryTitle: Json.str(json, 'gallery_title'),
      galleryStatus: Json.str(json, 'gallery_status'),
      total: Json.intVal(json, 'total'),
      festivalSlug: Json.strOrNull(json, 'festival_slug'),
      festivalStatus: Json.strOrNull(json, 'festival_status'),
      counts: counts.map(
        (String key, dynamic value) =>
            MapEntry<String, int>(key, value is num ? value.toInt() : 0),
      ),
    );
  }

  final String festivalId;
  final String festivalName;
  final int year;
  final String galleryId;
  final String gallerySlug;
  final String galleryTitle;
  final String galleryStatus;
  final int total;
  final String? festivalSlug;
  final String? festivalStatus;

  /// Photographs per status, so the workspace can say how many are still draft.
  final Map<String, int> counts;

  String get displayName => '$festivalName $year';

  int get published => counts['published'] ?? 0;
  int get awaiting => total - published;
}
