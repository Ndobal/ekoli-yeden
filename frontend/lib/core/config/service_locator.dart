import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../repositories/account_repository.dart';
import '../../repositories/admin_repository.dart';
import '../../repositories/age_grade_repository.dart';
import '../../repositories/cms_repository.dart';
import '../../repositories/contact_repository.dart';
import '../../repositories/content_repository.dart';
import '../../repositories/festival_repository.dart';
import '../../repositories/event_repository.dart';
import '../../repositories/forum_repository.dart';
import '../../repositories/gallery_repository.dart';
import '../../repositories/group_repository.dart';
import '../../repositories/kinship_repository.dart';
import '../../repositories/language_repository.dart';
import '../../repositories/media_repository.dart';
import '../../repositories/member_repository.dart';
import '../../repositories/message_repository.dart';
import '../../repositories/news_portal_repository.dart';
import '../../repositories/news_repository.dart';
import '../../repositories/opportunity_repository.dart';
import '../../repositories/people_repository.dart';
import '../../repositories/place_repository.dart';
import '../../repositories/discover_repository.dart';
import '../../repositories/community_repository.dart';
import '../../repositories/remembrance_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../repositories/submission_repository.dart';
import '../../repositories/video_repository.dart';
import '../../services/api/api_client.dart';
import '../../services/auth/auth_controller.dart';
import '../../services/auth/auth_service.dart';
import 'cms_controller.dart';
import 'site_settings_controller.dart';

/// Wires the application's services together.
///
/// One `ApiClient` is shared by every repository, so a token refresh triggered
/// by one screen benefits all of them.
class ServiceLocator {
  const ServiceLocator._();

  /// Resource keys, matching the Worker's content registry.
  static const String history = 'history';
  static const String leaders = 'leaders';
  static const String people = 'people';
  static const String news = 'news';
  static const String events = 'events';
  static const String galleries = 'galleries';
  static const String businesses = 'businesses';
  static const String organizations = 'organizations';
  static const String community = 'community';
  static const String pages = 'pages';

  static List<SingleChildWidget> providers(ApiClient api, AuthController auth) {
    return <SingleChildWidget>[
      Provider<ApiClient>.value(value: api),
      ChangeNotifierProvider<AuthController>.value(value: auth),

      Provider<SettingsRepository>(create: (_) => SettingsRepository(api)),
      Provider<CmsRepository>(create: (_) => CmsRepository(api)),
      Provider<ContactRepository>(create: (_) => ContactRepository(api)),
      Provider<FestivalRepository>(create: (_) => FestivalRepository(api)),
      Provider<GalleryRepository>(create: (_) => GalleryRepository(api)),
      Provider<GroupRepository>(create: (_) => GroupRepository(api)),
      Provider<EventRepository>(create: (_) => EventRepository(api)),
      Provider<ForumRepository>(create: (_) => ForumRepository(api)),
      Provider<NewsRepository>(create: (_) => NewsRepository(api)),
      Provider<NewsPortalRepository>(create: (_) => NewsPortalRepository(api)),
      Provider<OpportunityRepository>(create: (_) => OpportunityRepository(api)),
      Provider<KinshipRepository>(create: (_) => KinshipRepository(api)),
      Provider<RemembranceRepository>(create: (_) => RemembranceRepository(api)),
      Provider<PeopleRepository>(create: (_) => PeopleRepository(api)),
      Provider<PlaceRepository>(create: (_) => PlaceRepository(api)),
      // Voices of Ekori, the map, the Hall of Fame and the children's quizzes.
      Provider<DiscoverRepository>(create: (_) => DiscoverRepository(api)),
      Provider<CommunityRepository>(create: (_) => CommunityRepository(api)),
      Provider<AgeGradeRepository>(create: (_) => AgeGradeRepository(api)),
      Provider<MemberRepository>(create: (_) => MemberRepository(api)),
      Provider<MessageRepository>(create: (_) => MessageRepository(api)),
      Provider<LanguageRepository>(create: (_) => LanguageRepository(api)),
      Provider<VideoRepository>(create: (_) => VideoRepository(api)),
      Provider<MediaRepository>(create: (_) => MediaRepository(api)),
      Provider<SubmissionRepository>(create: (_) => SubmissionRepository(api)),
      Provider<AdminRepository>(create: (_) => AdminRepository(api)),
      Provider<AccountRepository>(create: (_) => AccountRepository(api)),

      // Content repositories are constructed on demand by `contentRepository`
      // below rather than registered one by one: there are fourteen of them and
      // they differ only by their resource key.
      Provider<ContentRepositoryFactory>(create: (_) => ContentRepositoryFactory(api)),

      // The two controllers that hold the site's own configuration and text.
      // Both start loading immediately so the first paint has them.
      ChangeNotifierProvider<SiteSettingsController>(
        create: (_) => SiteSettingsController(SettingsRepository(api))..load(),
      ),
      ChangeNotifierProvider<CmsController>(
        create: (_) => CmsController(CmsRepository(api))..load(),
      ),
    ];
  }

  /// Builds the shared client and authentication controller.
  ///
  /// Returned together because the client needs a way to tell the controller
  /// that a session has ended, and the controller needs the client to talk to
  /// the Worker.
  static ({ApiClient api, AuthController auth}) bootstrap() {
    final ApiClient api = ApiClient();
    final AuthController auth = AuthController(AuthService(api));
    api.onSessionExpired = auth.onSessionExpired;
    return (api: api, auth: auth);
  }
}

/// Creates a `ContentRepository` for a given resource key.
class ContentRepositoryFactory {
  const ContentRepositoryFactory(this._api);

  final ApiClient _api;

  ContentRepository forResource(String resource) => ContentRepository(_api, resource);
}

/// Convenience accessor used by feature screens.
extension RepositoryAccess on BuildContext {
  ContentRepository contentRepository(String resource) =>
      read<ContentRepositoryFactory>().forResource(resource);
}
