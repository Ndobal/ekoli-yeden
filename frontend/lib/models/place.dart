/// THE PLACES OF EKORI.
///
/// Ekori is not one place. It is Ajere and Ntan and Epenti and Afrekpe; inside
/// Ajere is Edang, and inside Edang is Ukekeya.
///
/// Somebody from Ukekeya is from Ukekeya, and from Edang, and from Ajere, and
/// from Ekori — all four are true at once. That is why a place has a parent and
/// a depth rather than a set of columns called `quarter` and `street`: a fixed
/// set of columns decides in advance how deep the community goes and what each
/// level is called, and is wrong the first time somebody names a level it does
/// not have.
library;

import 'content_status.dart';

class Place {
  const Place({
    required this.id,
    required this.slug,
    required this.name,
    this.parentId,
    this.kind = 'quarter',
    this.path,
    this.depth = 0,
    this.memberCount = 0,
    this.isCanonical = true,
    this.description,
    this.history,
    this.knownFor,
    this.ancestors = const <Place>[],
    this.children = const <Place>[],
    this.groups = const <PlaceGroup>[],
  });

  factory Place.fromJson(Map<String, dynamic> json) => Place(
    id: Json.str(json, 'id'),
    slug: Json.str(json, 'slug'),
    name: Json.str(json, 'name'),
    parentId: Json.strOrNull(json, 'parent_id'),
    kind: Json.str(json, 'kind', fallback: 'quarter'),
    path: Json.strOrNull(json, 'path'),
    depth: Json.intVal(json, 'depth'),
    memberCount: Json.intVal(json, 'member_count'),
    isCanonical: Json.boolVal(json, 'is_canonical', fallback: true),
    description: Json.strOrNull(json, 'description'),
    history: Json.strOrNull(json, 'history'),
    knownFor: Json.strOrNull(json, 'known_for'),
    ancestors: Json.objectList(json, 'ancestors').map(Place.fromJson).toList(growable: false),
    children: Json.objectList(json, 'children').map(Place.fromJson).toList(growable: false),
    groups: Json.objectList(json, 'groups').map(PlaceGroup.fromJson).toList(growable: false),
  );

  final String id;
  final String slug;
  final String name;
  final String? parentId;

  /// Named rather than numbered — "level 3" means nothing to anybody, and the
  /// community's own words for these are not interchangeable.
  final String kind;

  /// "Ekori / Ajere / Edang / Ukekeya", cached on the record.
  final String? path;

  final int depth;

  /// How many members give this place, or anywhere inside it, as where they
  /// are from.
  final int memberCount;

  /// False for a place the archive created automatically from what two people
  /// typed. Shown to a reviewer, not to a visitor: it is a note about how the
  /// record got here, not a judgement on whether the place is real.
  final bool isCanonical;

  final String? description;
  final String? history;
  final String? knownFor;

  final List<Place> ancestors;
  final List<Place> children;
  final List<PlaceGroup> groups;

  /// Everything above it, as one line: "in Edang, Ajere, Ekori".
  String? get lineage {
    if (ancestors.isEmpty) return null;
    return ancestors.reversed.map((Place place) => place.name).join(', ');
  }

  String get kindLabel {
    switch (kind) {
      case 'village':
        return 'Village';
      case 'ward':
        return 'Ward';
      case 'quarter':
        return 'Quarter';
      case 'compound':
        return 'Compound';
      case 'street':
        return 'Street';
      case 'clan':
        return 'Clan';
      case 'beach':
        return 'Beach';
      case 'landmark':
        return 'Landmark';
      case 'farmland':
        return 'Farmland';
      case 'market':
        return 'Market';
      case 'school':
        return 'School';
      default:
        return 'Place';
    }
  }
}

/// A group filed under a place — an age grade, a family, a dance troupe.
class PlaceGroup {
  const PlaceGroup({required this.id, required this.slug, required this.title, this.kind});

  factory PlaceGroup.fromJson(Map<String, dynamic> json) => PlaceGroup(
    id: Json.str(json, 'id'),
    slug: Json.str(json, 'slug'),
    title: Json.str(json, 'title'),
    kind: Json.strOrNull(json, 'kind'),
  );

  final String id;
  final String slug;
  final String title;
  final String? kind;
}

/// A name members have typed that the archive does not yet recognise.
///
/// `timesSeen` counts PEOPLE, not submissions. One person filling in a form six
/// times must not conjure a village; two different people saying the same thing
/// is the community telling you about a place.
class PlaceCandidate {
  const PlaceCandidate({
    required this.id,
    required this.rawName,
    this.timesSeen = 1,
    this.state = 'open',
    this.firstSeenAt,
    this.lastSeenAt,
  });

  factory PlaceCandidate.fromJson(Map<String, dynamic> json) => PlaceCandidate(
    id: Json.str(json, 'id'),
    rawName: Json.str(json, 'raw_name'),
    timesSeen: Json.intVal(json, 'times_seen', fallback: 1),
    state: Json.str(json, 'state', fallback: 'open'),
    firstSeenAt: Json.strOrNull(json, 'first_seen_at'),
    lastSeenAt: Json.strOrNull(json, 'last_seen_at'),
  );

  final String id;
  final String rawName;
  final int timesSeen;
  final String state;
  final String? firstSeenAt;
  final String? lastSeenAt;

  /// Two different people have said it, so the archive would have promoted it
  /// on its own. Reaching the queue in this state usually means a reviewer
  /// wants to correct the spelling or the parent before it lands.
  bool get meetsThreshold => timesSeen >= 2;
}
