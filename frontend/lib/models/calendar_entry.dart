import 'content_status.dart';

/// SOMETHING HAPPENING IN EKOLI-YEDEN.
///
/// An event or a festival. They are different records in the database — a
/// festival has editions, a programme and a committee; an event has a start
/// time and a venue — and they are the same thing to somebody looking at a
/// calendar.
///
/// So the server merges them and hands each one a `path`. The client does not
/// work out where a row should link to, because only the server knows which
/// kind of record it came from.
class CalendarEntry {
  const CalendarEntry({
    required this.id,
    required this.kind,
    required this.slug,
    required this.title,
    required this.path,
    this.description,
    this.eventType,
    this.startsAt,
    this.endsAt,
    this.location,
    this.venue,
    this.organiser,
    this.gallerySlug,
    this.festivalSlug,
    this.bannerMediaId,
    this.flierMediaId,
  });

  factory CalendarEntry.fromJson(Map<String, dynamic> json) => CalendarEntry(
        id: Json.str(json, 'id'),
        kind: Json.str(json, 'kind', fallback: 'event'),
        slug: Json.str(json, 'slug'),
        title: Json.str(json, 'title', fallback: 'An occasion'),
        path: Json.str(json, 'path'),
        description: Json.strOrNull(json, 'description'),
        eventType: Json.strOrNull(json, 'event_type'),
        startsAt: Json.strOrNull(json, 'starts_at'),
        endsAt: Json.strOrNull(json, 'ends_at'),
        location: Json.strOrNull(json, 'location'),
        venue: Json.strOrNull(json, 'venue'),
        organiser: Json.strOrNull(json, 'organiser'),
        gallerySlug: Json.strOrNull(json, 'gallery_slug'),
        festivalSlug: Json.strOrNull(json, 'festival_slug'),
        bannerMediaId: Json.strOrNull(json, 'banner_media_id'),
        flierMediaId: Json.strOrNull(json, 'flier_media_id'),
      );

  final String id;
  final String kind;
  final String slug;
  final String title;

  /// Where pressing it goes. Supplied by the server — the whole point of
  /// merging two kinds of record into one list.
  final String path;

  final String? description;
  final String? eventType;
  final String? startsAt;
  final String? endsAt;
  final String? location;
  final String? venue;
  final String? organiser;

  /// Its own album, where it has one.
  final String? gallerySlug;

  /// The festival this belongs to, where it belongs to one.
  ///
  /// A Leboku event appears on the festival page AND on the events page, from
  /// one record — hiding it inside the festival is how a community calendar
  /// ends up looking empty in a busy year.
  final String? festivalSlug;

  /// The wide image across the top of its own page.
  final String? bannerMediaId;

  /// The poster as it was designed. Shown whole and never cropped, because a
  /// flier carries the date, the venue and the names inside the image.
  final String? flierMediaId;

  bool get isPartOfFestival => festivalSlug != null && kind != 'festival';

  bool get isFestival => kind == 'festival';

  String? get where => venue ?? location;

  String get typeLabel => switch (eventType) {
        'town_hall' => 'Town hall',
        'festival' => 'Festival',
        'ceremony' => 'Ceremony',
        'meeting' => 'Meeting',
        'burial' => 'Burial',
        'launch' => 'Launch',
        'fundraiser' => 'Fundraiser',
        'sport' => 'Sport',
        'religious' => 'Religious',
        'education' => 'Education',
        _ => 'Gathering',
      };
}

/// Everything happening, in the three states an occasion can be in.
class EventsCalendar {
  const EventsCalendar({
    this.upcoming = const <CalendarEntry>[],
    this.past = const <CalendarEntry>[],
    this.undated = const <CalendarEntry>[],
    this.types = const <({String value, String label})>[],
  });

  factory EventsCalendar.fromJson(Map<String, dynamic> json) {
    List<CalendarEntry> read(String key) =>
        Json.objectList(json, key).map(CalendarEntry.fromJson).toList(growable: false);

    return EventsCalendar(
      upcoming: read('upcoming'),
      past: read('past'),
      // Neither upcoming nor past. An occasion whose date has not been fixed
      // has not happened, and filing it under "already held" would be wrong.
      undated: read('undated'),
      types: Json.objectList(json, 'types')
          .map(
            (Map<String, dynamic> row) => (
              value: Json.str(row, 'value'),
              label: Json.str(row, 'label'),
            ),
          )
          .toList(growable: false),
    );
  }

  final List<CalendarEntry> upcoming;
  final List<CalendarEntry> past;
  final List<CalendarEntry> undated;
  final List<({String value, String label})> types;

  bool get isEmpty => upcoming.isEmpty && past.isEmpty && undated.isEmpty;
}
