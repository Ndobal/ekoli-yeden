/// DISCOVER EKORI — §16 of the proposal.
///
/// ---------------------------------------------------------------------------
/// A PLACE WITHOUT COORDINATES IS STILL A PLACE
/// ---------------------------------------------------------------------------
///
/// [latitude] and [longitude] are nullable and most of them are null, because
/// nobody has recorded where these places are yet. The map page lists those
/// separately rather than dropping them, so the community can see exactly what
/// is still to be marked.
///
/// The archive does not estimate a position from a name. A pin in roughly the
/// right area looks as authoritative as a surveyed one and is a great deal
/// harder to correct once people have started trusting it.
library;

import 'content_status.dart';

const Map<String, String> placeKindLabels = <String, String>{
  'village': 'Village',
  'ward': 'Ward',
  'quarter': 'Quarter',
  'compound': 'Compound',
  'beach': 'Beach',
  'landmark': 'Landmark',
  'school': 'School',
  'church': 'Church',
  'facility': 'Community facility',
  'natural': 'Natural feature',
};

class MapPlace {
  const MapPlace({
    required this.id,
    required this.slug,
    required this.name,
    this.kind = 'quarter',
    this.description,
    this.knownFor,
    this.latitude,
    this.longitude,
    this.parentId,
    this.coverUrl,
  });

  factory MapPlace.fromJson(Map<String, dynamic> json) => MapPlace(
    id: Json.str(json, 'id'),
    slug: Json.str(json, 'slug'),
    name: Json.str(json, 'name'),
    kind: Json.str(json, 'kind', fallback: 'quarter'),
    description: Json.strOrNull(json, 'description'),
    knownFor: Json.strOrNull(json, 'known_for'),
    latitude: Json.doubleOrNull(json, 'latitude'),
    longitude: Json.doubleOrNull(json, 'longitude'),
    parentId: Json.strOrNull(json, 'parent_id'),
    coverUrl: Json.strOrNull(json, 'cover_url'),
  );

  final String id;
  final String slug;
  final String name;
  final String kind;
  final String? description;
  final String? knownFor;
  final double? latitude;
  final double? longitude;
  final String? parentId;
  final String? coverUrl;

  bool get isPlaced => latitude != null && longitude != null;
  String get kindLabel => placeKindLabels[kind] ?? 'Place';
}

/// The frame the placed points sit in, computed from real coordinates only.
class MapBounds {
  const MapBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  factory MapBounds.fromJson(Map<String, dynamic> json) => MapBounds(
    minLat: Json.doubleOrNull(json, 'min_lat') ?? 0,
    maxLat: Json.doubleOrNull(json, 'max_lat') ?? 0,
    minLng: Json.doubleOrNull(json, 'min_lng') ?? 0,
    maxLng: Json.doubleOrNull(json, 'max_lng') ?? 0,
  );

  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  double get latSpan => (maxLat - minLat).abs();
  double get lngSpan => (maxLng - minLng).abs();

  /// A single marked place has no extent, and two on the same street have very
  /// little. Padding keeps the projection from dividing by something near zero
  /// and blowing one pin up to fill the canvas.
  MapBounds padded() {
    const double minimumSpan = 0.004; // roughly 400m — a village, not a country
    final double latPad = latSpan < minimumSpan ? (minimumSpan - latSpan) / 2 : latSpan * 0.12;
    final double lngPad = lngSpan < minimumSpan ? (minimumSpan - lngSpan) / 2 : lngSpan * 0.12;
    return MapBounds(
      minLat: minLat - latPad,
      maxLat: maxLat + latPad,
      minLng: minLng - lngPad,
      maxLng: maxLng + lngPad,
    );
  }
}

class MapOverview {
  const MapOverview({
    required this.items,
    required this.placedCount,
    required this.unplacedCount,
    this.bounds,
  });

  factory MapOverview.fromJson(Map<String, dynamic> json) => MapOverview(
    items: Json.objectList(json, 'items').map(MapPlace.fromJson).toList(growable: false),
    placedCount: Json.intVal(json, 'placed_count'),
    unplacedCount: Json.intVal(json, 'unplaced_count'),
    bounds: json['bounds'] is Map<String, dynamic>
        ? MapBounds.fromJson(json['bounds'] as Map<String, dynamic>)
        : null,
  );

  final List<MapPlace> items;
  final int placedCount;
  final int unplacedCount;
  final MapBounds? bounds;

  List<MapPlace> get placed =>
      items.where((MapPlace place) => place.isPlaced).toList(growable: false);
  List<MapPlace> get unplaced =>
      items.where((MapPlace place) => !place.isPlaced).toList(growable: false);

  bool get hasAnyPosition => placedCount > 0;
}
