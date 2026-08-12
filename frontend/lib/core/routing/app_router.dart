import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/about/about_pages.dart';
import '../../features/auth/auth_pages.dart';
import '../../features/auth/password_reset_pages.dart';
import '../../features/businesses/directory_pages.dart';
import '../../features/contributions/contribute_page.dart';
import '../../features/culture/cultural_life_pages.dart';
import '../../features/culture/culture_pages.dart';
import '../../features/editorial/editorial_dashboard.dart';
import '../../features/editorial/editorial_text_page.dart';
import '../../features/events/events_pages.dart';
import '../../features/gallery/gallery_pages.dart';
import '../../features/history/history_pages.dart';
import '../../features/home/home_page.dart';
import '../../features/language/language_pages.dart';
import '../../features/leadership/leadership_pages.dart';
import '../../features/leboku/festival_pages.dart';
import '../../features/news/news_pages.dart';
import '../../features/people/people_pages.dart';
import '../../features/search/search_page.dart';
import '../../features/videos/video_pages.dart';
import '../../features/workspace/contributions_page.dart';
import '../../features/workspace/media_library_page.dart';
import '../../features/workspace/workspace_pages.dart';
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

      // --- Festivals -------------------------------------------------------
      // `/festivals` is canonical. `/leboku` and `/leboku/<year>` still resolve
      // so that links already printed on festival materials keep working — a
      // permanent archive should not break its own addresses.
      GoRoute(
        path: AppRoutes.festivals,
        builder: (_, _) => const FestivalsIndexPage(),
        routes: <RouteBase>[
          GoRoute(
            path: ':slug',
            builder: (_, GoRouterState state) =>
                FestivalDetailPage(identifier: state.pathParameters['slug']!),
          ),
        ],
      ),
      GoRoute(path: AppRoutes.leboku, redirect: (_, _) => AppRoutes.festivals),
      GoRoute(
        path: '${AppRoutes.leboku}/:year',
        builder: (_, GoRouterState state) =>
            FestivalDetailPage(identifier: state.pathParameters['year']!),
      ),

      // --- Cultural life ---------------------------------------------------
      GoRoute(
        path: AppRoutes.ageGrades,
        builder: (_, _) => const AgeGradesListPage(),
        routes: <RouteBase>[
          GoRoute(
            path: ':slug',
            builder: (_, GoRouterState state) =>
                AgeGradeDetailPage(slug: state.pathParameters['slug']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.culturalGroups,
        builder: (_, _) => const CulturalGroupsListPage(),
        routes: <RouteBase>[
          GoRoute(
            path: ':slug',
            builder: (_, GoRouterState state) =>
                CulturalGroupDetailPage(slug: state.pathParameters['slug']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.music,
        builder: (_, _) => const CulturalMusicListPage(),
        routes: <RouteBase>[
          GoRoute(
            path: ':slug',
            builder: (_, GoRouterState state) =>
                CulturalMusicDetailPage(slug: state.pathParameters['slug']!),
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
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, _) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (_, GoRouterState state) =>
            ResetPasswordPage(token: state.uri.queryParameters['token']),
      ),

      // --- Editorial Team ---------------------------------------------------
      // Every item in `editorialNavigation` has a route here. A sidebar link
      // that 404s is worse than no link at all, so the content screens are
      // generated from the same map the sidebar is built from.
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
      GoRoute(
        path: AppRoutes.editorialMedia,
        builder: (_, _) => const MediaLibraryPage(workspace: WorkspaceKind.editorial),
      ),
      GoRoute(
        path: AppRoutes.editorialSubmissions,
        builder: (_, _) => const SubmissionsQueuePage(workspace: WorkspaceKind.editorial),
      ),
      GoRoute(
        path: AppRoutes.editorialSources,
        builder: (_, _) => const SourcesPage(workspace: WorkspaceKind.editorial),
      ),
      GoRoute(
        path: AppRoutes.editorialContributions,
        builder: (_, _) => const ContributionsReviewPage(workspace: WorkspaceKind.editorial),
      ),
      GoRoute(
        path: AppRoutes.editorialContributors,
        builder: (_, _) => const SubmissionsQueuePage(workspace: WorkspaceKind.editorial),
      ),
      ..._editorialContentRoutes(),

      // --- Super Admin ------------------------------------------------------
      // Likewise: every item in `adminNavigation` resolves.
      GoRoute(path: AppRoutes.admin, redirect: (_, _) => AppRoutes.adminDashboard),
      GoRoute(path: AppRoutes.adminDashboard, builder: (_, _) => const AdminDashboard()),
      GoRoute(path: AppRoutes.adminUsers, builder: (_, _) => const AdminUsersPage()),
      GoRoute(path: AppRoutes.adminRoles, builder: (_, _) => const AdminRolesPage()),
      GoRoute(path: AppRoutes.adminAuditLogs, builder: (_, _) => const AdminAuditLogPage()),
      GoRoute(path: AppRoutes.adminEditorialTeam, builder: (_, _) => const AdminEditorialTeamPage()),
      GoRoute(path: AppRoutes.adminContent, builder: (_, _) => const AdminContentPage()),
      GoRoute(path: AppRoutes.adminSettings, builder: (_, _) => const AdminSettingsPage()),
      GoRoute(path: AppRoutes.adminSecurity, builder: (_, _) => const AdminSecurityPage()),
      GoRoute(
        path: AppRoutes.adminMedia,
        builder: (_, _) => const MediaLibraryPage(workspace: WorkspaceKind.admin),
      ),
      GoRoute(
        path: AppRoutes.adminSubmissions,
        builder: (_, _) => const SubmissionsQueuePage(workspace: WorkspaceKind.admin),
      ),
      GoRoute(
        path: AppRoutes.adminContributions,
        builder: (_, _) => const ContributionsReviewPage(workspace: WorkspaceKind.admin),
      ),
      GoRoute(
        path: AppRoutes.adminSources,
        builder: (_, _) => const SourcesPage(workspace: WorkspaceKind.admin),
      ),
    ],
  );
}

/// The editorial content screens.
///
/// Generated from `editorialContentScreens`, which is also what builds the
/// sidebar — so a link and its route cannot drift apart.
List<GoRoute> _editorialContentRoutes() {
  return editorialContentScreens.entries
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
