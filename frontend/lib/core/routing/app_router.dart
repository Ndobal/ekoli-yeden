import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/about/about_pages.dart';
import '../../features/auth/auth_pages.dart';
import '../../features/businesses/directory_pages.dart';
import '../../features/contributions/contribute_page.dart';
import '../../features/culture/culture_pages.dart';
import '../../features/editorial/editorial_dashboard.dart';
import '../../features/editorial/editorial_text_page.dart';
import '../../features/events/events_pages.dart';
import '../../features/gallery/gallery_pages.dart';
import '../../features/history/history_pages.dart';
import '../../features/home/home_page.dart';
import '../../features/language/language_pages.dart';
import '../../features/leadership/leadership_pages.dart';
import '../../features/leboku/leboku_pages.dart';
import '../../features/news/news_pages.dart';
import '../../features/people/people_pages.dart';
import '../../features/search/search_page.dart';
import '../../features/videos/video_pages.dart';
import '../../admin/admin_dashboard.dart';
import '../../admin/admin_users_page.dart';
import '../../services/auth/auth_controller.dart';
import 'app_routes.dart';
import 'not_found_page.dart';

/// The route table.
///
/// Every section has a real URL. That matters more here than in most
/// applications: this archive is meant to be linked to from WhatsApp, printed
/// on a festival banner as a QR code, and indexed by search engines. Client-side
/// navigation state that produces no URL would defeat the purpose.
///
/// The redirect below is a convenience, not a security control. It stops a
/// signed-out visitor landing on an empty editorial screen; the Worker is what
/// actually refuses the data, on every request, regardless of what the client
/// chose to render.
GoRouter buildRouter(AuthController auth) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    // Rebuilds the redirect whenever the session changes, so signing out from
    // an editorial page moves the visitor immediately.
    refreshListenable: auth,
    errorBuilder: (BuildContext context, GoRouterState state) =>
        NotFoundPage(location: state.uri.toString()),

    redirect: (BuildContext context, GoRouterState state) {
      final String location = state.matchedLocation;
      final bool goingToEditorial = location.startsWith(AppRoutes.editorial);
      final bool goingToAdmin = location.startsWith(AppRoutes.admin);
      if (!goingToEditorial && !goingToAdmin) return null;

      // Still restoring a stored session on a page refresh — hold rather than
      // bounce an editor out of the area they were working in.
      if (auth.isResolving) return null;

      if (!auth.isSignedIn) return AppRoutes.signInReturningTo(location);
      if (goingToAdmin && !auth.canAccessAdmin) return AppRoutes.editorialDashboard;
      if (goingToEditorial && !auth.canAccessEditorial) return AppRoutes.home;
      return null;
    },

    routes: <RouteBase>[
      // --- Public ---------------------------------------------------------
      GoRoute(path: AppRoutes.home, builder: (_, _) => const HomePage()),
      GoRoute(path: AppRoutes.about, builder: (_, _) => const AboutPage()),
      GoRoute(path: AppRoutes.contact, builder: (_, _) => const ContactPage()),
      GoRoute(path: AppRoutes.preservationTeam, builder: (_, _) => const PreservationTeamPage()),

      GoRoute(
        path: AppRoutes.history,
        builder: (_, _) => const HistoryListPage(),
        routes: <RouteBase>[
          GoRoute(
            path: ':slug',
            builder: (_, GoRouterState state) =>
                HistoryDetailPage(slug: state.pathParameters['slug']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.culture,
        builder: (_, _) => const CultureListPage(),
        routes: <RouteBase>[
          GoRoute(
            path: ':slug',
            builder: (_, GoRouterState state) =>
                CultureDetailPage(slug: state.pathParameters['slug']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.leaders,
        builder: (_, _) => const LeadershipListPage(),
        routes: <RouteBase>[
          GoRoute(
            path: ':slug',
            builder: (_, GoRouterState state) =>
                LeaderDetailPage(slug: state.pathParameters['slug']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.people,
        builder: (_, _) => const PeopleListPage(),
        routes: <RouteBase>[
          GoRoute(
            path: ':slug',
            builder: (_, GoRouterState state) =>
                PersonDetailPage(slug: state.pathParameters['slug']!),
          ),
        ],
      ),
      GoRoute(path: AppRoutes.language, builder: (_, _) => const LanguageListPage()),
      GoRoute(
        path: AppRoutes.leboku,
        builder: (_, _) => const LebokuIndexPage(),
        routes: <RouteBase>[
          // `/leboku/2026`, `/leboku/2027`, and every year after.
          GoRoute(
            path: ':year',
            builder: (_, GoRouterState state) =>
                FestivalYearPage(year: state.pathParameters['year']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.news,
        builder: (_, _) => const NewsListPage(),
        routes: <RouteBase>[
          GoRoute(
            path: ':slug',
            builder: (_, GoRouterState state) =>
                NewsDetailPage(slug: state.pathParameters['slug']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.events,
        builder: (_, _) => const EventsListPage(),
        routes: <RouteBase>[
          GoRoute(
            path: ':slug',
            builder: (_, GoRouterState state) =>
                EventDetailPage(slug: state.pathParameters['slug']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.gallery,
        builder: (_, _) => const GalleryListPage(),
        routes: <RouteBase>[
          GoRoute(
            path: ':slug',
            builder: (_, GoRouterState state) =>
                GalleryDetailPage(slug: state.pathParameters['slug']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.videos,
        builder: (_, _) => const VideosListPage(),
        routes: <RouteBase>[
          GoRoute(
            path: ':slug',
            builder: (_, GoRouterState state) =>
                VideoDetailPage(identifier: state.pathParameters['slug']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.businesses,
        builder: (_, _) => const BusinessesListPage(),
        routes: <RouteBase>[
          GoRoute(
            path: ':slug',
            builder: (_, GoRouterState state) =>
                BusinessDetailPage(slug: state.pathParameters['slug']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.organizations,
        builder: (_, _) => const OrganizationsListPage(),
        routes: <RouteBase>[
          GoRoute(
            path: ':slug',
            builder: (_, GoRouterState state) =>
                OrganizationDetailPage(slug: state.pathParameters['slug']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.community,
        builder: (_, _) => const CommunityProjectsListPage(),
        routes: <RouteBase>[
          GoRoute(
            path: ':slug',
            builder: (_, GoRouterState state) =>
                CommunityProjectDetailPage(slug: state.pathParameters['slug']!),
          ),
        ],
      ),

      GoRoute(
        path: AppRoutes.contribute,
        builder: (_, GoRouterState state) => ContributePage(
          presetType: state.uri.queryParameters['type'],
          about: state.uri.queryParameters['about'],
        ),
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (_, GoRouterState state) =>
            SearchPage(initialQuery: state.uri.queryParameters['q']),
      ),

      // --- Account ---------------------------------------------------------
      GoRoute(
        path: AppRoutes.signIn,
        builder: (_, GoRouterState state) =>
            SignInPage(redirectTo: state.uri.queryParameters['redirect']),
      ),
      GoRoute(path: AppRoutes.register, builder: (_, _) => const RegisterPage()),

      // --- Editorial Team ---------------------------------------------------
      GoRoute(
        path: AppRoutes.editorial,
        redirect: (_, _) => AppRoutes.editorialDashboard,
      ),
      GoRoute(path: AppRoutes.editorialDashboard, builder: (_, _) => const EditorialDashboard()),
      GoRoute(
        path: AppRoutes.editorialPages,
        builder: (_, _) => const EditorialTextPage(),
      ),
      GoRoute(
        path: AppRoutes.editorialHomepage,
        builder: (_, _) => const EditorialTextPage(group: 'home', title: 'Homepage text'),
      ),
      GoRoute(
        path: AppRoutes.editorialNavigation,
        builder: (_, _) => const EditorialTextPage(group: 'navigation', title: 'Navigation'),
      ),
      ..._editorialContentRoutes(),

      // --- Super Admin ------------------------------------------------------
      GoRoute(path: AppRoutes.admin, redirect: (_, _) => AppRoutes.adminDashboard),
      GoRoute(path: AppRoutes.adminDashboard, builder: (_, _) => const AdminDashboard()),
      GoRoute(path: AppRoutes.adminUsers, builder: (_, _) => const AdminUsersPage()),
      GoRoute(path: AppRoutes.adminRoles, builder: (_, _) => const AdminRolesPage()),
      GoRoute(path: AppRoutes.adminAuditLogs, builder: (_, _) => const AdminAuditLogPage()),
    ],
  );
}

/// The editorial content screens, generated from the sidebar definition.
///
/// Each is the same list-and-workflow screen pointed at a different resource,
/// which is what the CMS registry on the server already makes possible.
List<GoRoute> _editorialContentRoutes() {
  const Map<String, ({String resource, String title})> screens =
      <String, ({String resource, String title})>{
    AppRoutes.editorialHistory: (resource: 'history', title: 'History'),
    AppRoutes.editorialCulture: (resource: 'culture', title: 'Culture'),
    AppRoutes.editorialLanguage: (resource: 'language', title: 'Language'),
    AppRoutes.editorialLeboku: (resource: 'festivals', title: 'Leboku'),
    AppRoutes.editorialPeople: (resource: 'people', title: 'People'),
    AppRoutes.editorialNews: (resource: 'news', title: 'News'),
    AppRoutes.editorialEvents: (resource: 'events', title: 'Events'),
    AppRoutes.editorialGallery: (resource: 'galleries', title: 'Gallery'),
    AppRoutes.editorialVideos: (resource: 'videos', title: 'Videos'),
    AppRoutes.editorialCommunity: (resource: 'community', title: 'Community projects'),
  };

  return screens.entries
      .map(
        (MapEntry<String, ({String resource, String title})> entry) => GoRoute(
          path: entry.key,
          builder: (_, _) => EditorialContentPage(
            resource: entry.value.resource,
            title: entry.value.title,
            path: entry.key,
          ),
        ),
      )
      .toList(growable: false);
}
