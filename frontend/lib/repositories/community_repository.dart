import '../models/community_overview.dart';
import '../services/api/api_client.dart';

/// THE COMMUNITY HUB.
///
/// One request for the whole page: the counts, the newest people, the groups
/// and what has happened lately. The Worker assembles the feed from the things
/// themselves rather than from an activity table — see `community.controller.ts`
/// for why that matters.
class CommunityRepository {
  const CommunityRepository(this._api);

  final ApiClient _api;

  /// Public: a visitor deciding whether to join should be able to see what
  /// they would be joining.
  Future<CommunityOverview> overview() async {
    final Map<String, dynamic> data =
        await _api.get('/api/community/overview', authenticated: false);
    return CommunityOverview.fromJson(data);
  }
}
