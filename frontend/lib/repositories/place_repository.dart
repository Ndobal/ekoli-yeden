import '../models/place.dart';
import '../services/api/api_client.dart';

/// THE PLACES OF EKORI.
///
/// There is no `create` here, and there is none on the server either. A place
/// appears because two different members typed its name into their own
/// profiles — one person typing something is a spelling, two people typing the
/// same thing is a place. The administrator methods at the bottom promote one
/// early or correct one the threshold created; they are not the ordinary path.
class PlaceRepository {
  const PlaceRepository(this._api);

  final ApiClient _api;

  /// Every place, flat, ordered by depth then name — ready to be assembled into
  /// a tree or offered in a picker.
  Future<List<Place>> all() async {
    final Map<String, dynamic> data = await _api.get('/api/places', authenticated: false);
    return (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(Place.fromJson)
        .toList(growable: false);
  }

  /// One place, with what is above it and what is inside it.
  Future<Place> find(String identifier) async {
    final Map<String, dynamic> data =
        await _api.get('/api/places/$identifier', authenticated: false);
    return Place.fromJson(data);
  }

  // --- Keeping the list -----------------------------------------------------

  Future<List<PlaceCandidate>> candidates({String state = 'open'}) async {
    final Map<String, dynamic> data = await _api.get(
      '/api/admin/places/candidates',
      query: <String, dynamic>{'state': state},
    );
    return (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(PlaceCandidate.fromJson)
        .toList(growable: false);
  }

  /// Makes a typed name a real place — early, or with its spelling and its
  /// parent corrected.
  Future<void> promote(String candidateId, {String? name, String? parentId}) => _api.post(
    '/api/admin/places/candidates/$candidateId/promote',
    body: <String, dynamic>{'name': ?name, 'parent_id': ?parentId},
  );

  Future<void> dismiss(String candidateId) =>
      _api.post('/api/admin/places/candidates/$candidateId/dismiss');
}
