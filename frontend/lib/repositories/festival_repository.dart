import '../models/festival.dart';
import '../services/api/api_client.dart';

/// The festival archive.
///
/// `/leboku` lists the series and `/leboku/2026` opens one edition, so the
/// public URLs read the way a visitor would expect and every past year stays
/// reachable at a permanent address.
class FestivalRepository {
  const FestivalRepository(this._api);

  final ApiClient _api;

  /// Every edition of the Leboku series, newest first.
  Future<List<FestivalEdition>> lebokuEditions() async {
    final Map<String, dynamic> data = await _api.get('/api/leboku', authenticated: false);
    final List<dynamic> raw = (data['editions'] as List<dynamic>?) ?? const <dynamic>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(FestivalEdition.fromJson)
        .toList(growable: false);
  }

  /// One edition, with its programme, gallery and videos in a single request.
  ///
  /// `identifier` may be a year (`2026`) or a slug (`leboku-2026`), so links
  /// printed on earlier festival materials keep resolving.
  Future<FestivalDetail> festival(String identifier) async {
    final bool isYear = RegExp(r'^\d{4}$').hasMatch(identifier);
    final Map<String, dynamic> data = await _api.get(
      isYear ? '/api/leboku/$identifier' : '/api/festivals/$identifier',
      authenticated: false,
    );
    return FestivalDetail.fromJson(data);
  }

  /// The festivals index: the featured edition and the earlier ones.
  Future<FestivalIndex> index() async {
    final Map<String, dynamic> data = await _api.get('/api/festivals', authenticated: false);
    return FestivalIndex.fromJson(data);
  }

  /// Every published festival as a flat list.
  Future<List<Festival>> all() async {
    final Map<String, dynamic> data = await _api.get('/api/festivals', authenticated: false);
    final List<dynamic> raw = (data['items'] as List<dynamic>?) ?? const <dynamic>[];
    return raw.whereType<Map<String, dynamic>>().map(Festival.fromJson).toList(growable: false);
  }
}
