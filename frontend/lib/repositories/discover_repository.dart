import '../models/learning.dart';
import '../models/map_place.dart';
import '../models/content_record.dart';
import '../models/recording.dart';
import '../services/api/api_client.dart';

/// The three sections finished last: Voices of Ekori, the map, and the
/// children's area — plus the Hall of Fame, which existed as a column and a
/// switch and nothing else.
///
/// All of these read published rows only, and the Worker hard-codes that. None
/// of them sends anything back: in particular there is deliberately no method
/// here that submits a child's quiz answers anywhere.
class DiscoverRepository {
  const DiscoverRepository(this._api);

  final ApiClient _api;

  // -------------------------------------------------------------------------
  // §8  Voices of Ekori
  // -------------------------------------------------------------------------

  Future<List<Recording>> recordings({String? topic, String? search}) async {
    final Map<String, dynamic> data = await _api.get(
      '/api/recordings',
      authenticated: false,
      query: <String, String>{
        if (topic != null && topic.isNotEmpty) 'topic': topic,
        if (search != null && search.isNotEmpty) 'search': search,
        'per_page': '60',
      },
    );
    return (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(Recording.fromJson)
        .toList(growable: false);
  }

  Future<Recording> recording(String identifier) async {
    final Map<String, dynamic> data =
        await _api.get('/api/recordings/$identifier', authenticated: false);
    return Recording.fromJson(data);
  }

  // -------------------------------------------------------------------------
  // §16  The map
  // -------------------------------------------------------------------------

  Future<MapOverview> map() async {
    final Map<String, dynamic> data =
        await _api.get('/api/map/places', authenticated: false);
    return MapOverview.fromJson(data);
  }

  /// Records where a place stands, or clears a position recorded in error.
  ///
  /// Pass nulls for both to clear. Editorial only — the Worker checks.
  Future<void> setCoordinates(String placeId, {double? latitude, double? longitude}) {
    return _api.post(
      '/api/editorial/places/$placeId/coordinates',
      body: <String, dynamic>{'latitude': latitude, 'longitude': longitude},
    );
  }

  // -------------------------------------------------------------------------
  // §13  The Hall of Fame
  // -------------------------------------------------------------------------

  /// Returns `null` when the community has not switched the Hall of Fame on.
  ///
  /// Distinguished from "on, but nobody in it yet" on purpose: those are two
  /// different things to say to a visitor, and the endpoint reports which.
  Future<List<ContentRecord>?> hallOfFame() async {
    final Map<String, dynamic> data =
        await _api.get('/api/hall-of-fame', authenticated: false);
    if (data['enabled'] != true) return null;
    return (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ContentRecord.fromJson)
        .toList(growable: false);
  }

  // -------------------------------------------------------------------------
  // §17  Learn about Ekori
  // -------------------------------------------------------------------------

  Future<List<QuizSummary>> quizzes({String? subject}) async {
    final Map<String, dynamic> data = await _api.get(
      '/api/quizzes',
      authenticated: false,
      query: <String, String>{
        if (subject != null && subject.isNotEmpty) 'subject': subject,
        'per_page': '60',
      },
    );
    return (data['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(QuizSummary.fromJson)
        .toList(growable: false);
  }

  /// One quiz with its questions attached, ready to be marked in the browser.
  Future<Quiz> quiz(String identifier) async {
    final Map<String, dynamic> data =
        await _api.get('/api/learn/quizzes/$identifier', authenticated: false);
    return Quiz.fromJson(data);
  }
}
