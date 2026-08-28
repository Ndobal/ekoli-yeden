import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/about/about_pages.dart';
import '../../features/ancestry/ancestry_pages.dart';
import '../../features/ancestry/report_passing_page.dart';
import '../../features/auth/auth_pages.dart';
import '../../features/auth/password_reset_pages.dart';
import '../../features/businesses/directory_pages.dart';
import '../../features/contributions/contribute_page.dart';
import '../../features/age_grades/age_grade_workspace.dart';
import '../../features/culture/cultural_life_pages.dart';
import '../../features/culture/culture_area_page.dart';
import '../../features/culture/culture_pages.dart';
import '../../features/editorial/editorial_dashboard.dart';
import '../../features/editorial/editorial_text_page.dart';
import '../../features/events/events_pages.dart';
import '../../features/forums/forum_moderation_page.dart';
import '../../features/forums/forum_new_topic_page.dart';
import '../../features/forums/forum_pages.dart';
import '../../features/forums/forum_topic_page.dart';
import '../../features/gallery/gallery_pages.dart';
import '../../features/groups/group_workspace_pages.dart';
import '../../features/membership/birthdays_page.dart';
import '../../features/people/contribute_person_page.dart';
import '../../features/membership/directory_page.dart';
import '../../features/membership/family_page.dart';
import '../../features/opportunities/opportunities_pages.dart';
import '../../features/opportunities/post_opportunity_page.dart';
import '../../features/groups/groups_pages.dart';
import '../../features/history/history_pages.dart';
import '../../features/home/home_page.dart';
import '../../features/legal/legal_pages.dart';
import '../../features/language/language_pages.dart';
import '../../features/membership/account_page.dart';
import '../../features/messages/contact_requests_page.dart';
import '../../features/messages/messages_page.dart';
import '../../features/membership/join_page.dart';
import '../../features/membership/member_profile_page.dart';
import '../../features/membership/notifications_page.dart';
import '../../features/membership/privacy_page.dart';
import '../../features/membership/profile_editor_page.dart';
import '../../features/language/word_contribution_page.dart';
import '../../features/leadership/leadership_pages.dart';
import '../../features/leboku/festival_pages.dart';
import '../../features/news/contribute_news_page.dart';
import '../../features/news/news_article_page.dart';
import '../../features/news/news_portal_page.dart';
import '../../features/people/people_pages.dart';
import '../../features/people/person_profile_page.dart';
import '../../features/places/places_pages.dart';
import '../../features/search/search_page.dart';
import '../../features/videos/video_pages.dart';
import '../../features/workspace/contributions_page.dart';
import '../../features/workspace/festival_galleries_page.dart';
import '../../features/workspace/media_library_page.dart';
import '../../features/workspace/news_composer.dart';
import '../../features/workspace/news_workspace.dart';
import '../../features/workspace/contact_inbox_page.dart';
import '../../features/workspace/community_snapshot_page.dart';
import '../../features/workspace/review_queues.dart';
import '../../features/workspace/word_submissions_page.dart';
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

      // --- The policy pages -------------------------------------------------
      // Public and unauthenticated: somebody deciding whether to make an
      // account has to be able to read them first.
      GoRoute(path: AppRoutes.terms, builder: (_, _) => const TermsPage()),
      GoRoute(path: AppRoutes.privacy, builder: (_, _) => const PrivacyPolicyPage()),
      GoRoute(path: AppRoutes.cookies, builder: (_, _) => const CookiesPage()),
      GoRoute(path: AppRoutes.preservationTeam, builder: (_, _) => const PreservationTeamPage()),

      // --- The places of Ekori ----------------------------------------------
      GoRoute(
        path: AppRoutes.places,
        builder: (_, _) => const PlacesPage(),
        routes: <RouteBase>[
          GoRoute(
            path: ':slug',
            builder: (_, GoRouterState state) =>
                PlaceDetailPage(slug: state.pathParameters['slug']!),
          ),
        ],
      ),

      // --- Remembrance ------------------------------------------------------
      // The memorial pages, and the form that starts a report. `report` is
      // registered ahead of `:slug` so it is never read as somebody's name.
      GoRoute(
        path: AppRoutes.ancestry,
        builder: (_, _) => const AncestryListPage(),
        routes: <RouteBase>[
          GoRoute(path: 'report', builder: (_, _) => const ReportPassingPage()),
          GoRoute(
            path: ':slug',
            builder: (_, GoRouterState state) =>
                AncestryDetailPage(slug: state.pathParameters['slug']!),
          ),
        ],
      ),

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
          // Ahead of `:slug`, so `area` is never read as an article slug. An
          // area is a shelf; an article is a thing on it, and the two need
          // different addresses.
          GoRoute(
            path: 'area/:slug',
            builder: (_, GoRouterState state) =>
                CultureAreaPage(slug: state.pathParameters['slug']!),
          ),
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
          // Ahead of `:slug`, so `add` is never read as somebody's name.
          GoRoute(path: 'add', builder: (_, _) => const ContributePersonPage()),
          GoRoute(
            path: ':slug',
            builder: (_, GoRouterState state) =>
                PersonProfilePage(slug: state.pathParameters['slug']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.language,
        builder: (_, _) => const LanguageListPage(),
        routes: <RouteBase>[
          // Before any word route: `contribute` is a form, not a headword.
          GoRoute(path: 'contribute', builder: (_, _) => const WordContributionPage()),
        ],
      ),

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

      // --- Community groups ------------------------------------------------
      // The one part of the archive the community runs directly: a group
      // registers, and from then on its own officers keep its page.
      //
      // ONE SECTION, NOT THREE.
      //
      // Age grades and cultural groups used to be separate features with
      // separate tables, pages and routes. They need the same things of the
      // archive — a roster, a way to join, officers, dues, somewhere to raise
      // a problem — and building those once per kind of group is how they
      // drift apart.
      //
      // So `/age-grades` and `/cultural-groups` are kept as addresses, because
      // they are linked from the footer and people have them, but both render
      // the groups section with a filter applied. There is one source of truth
      // behind them, which is what stops a grade registered at one address
      // being invisible at the other.
      GoRoute(
        path: AppRoutes.groups,
        builder: (_, _) => const GroupsListPage(),
        routes: <RouteBase>[
          // Ahead of `:slug`, so `register` is never read as a group's slug.
          GoRoute(path: 'register', builder: (_, _) => const RegisterGroupPage()),
          GoRoute(
            path: ':slug/manage',
            builder: (_, GoRouterState state) =>
                GroupManagePage(slug: state.pathParameters['slug']!),
          ),
          GoRoute(
            path: ':slug/dues',
            builder: (_, GoRouterState state) =>
                GroupDuesPage(slug: state.pathParameters['slug']!),
          ),
          GoRoute(
            path: ':slug',
            builder: (_, GoRouterState state) =>
                GroupDetailPage(slug: state.pathParameters['slug']!),
          ),
        ],
      ),

      // The same section, entered by a more specific door.
      GoRoute(
        path: AppRoutes.ageGrades,
        builder: (_, _) => const GroupsListPage(fixedKind: 'age_grade'),
        routes: <RouteBase>[
          GoRoute(path: 'register', builder: (_, _) => const RegisterGroupPage()),
          GoRoute(
            path: ':slug/manage',
            builder: (_, GoRouterState state) =>
                GroupManagePage(slug: state.pathParameters['slug']!),
          ),
          GoRoute(
            path: ':slug',
            builder: (_, GoRouterState state) =>
                GroupDetailPage(slug: state.pathParameters['slug']!),
          ),
        ],
      ),
      GoRoute(path: AppRoutes.myAgeGrades, builder: (_, _) => const MyAgeGradesPage()),

      // --- Cultural life ---------------------------------------------------
      GoRoute(
        path: AppRoutes.culturalGroups,
        builder: (_, _) => const GroupsListPage(fixedKind: 'cultural_group'),
        routes: <RouteBase>[
          GoRoute(
            path: ':slug',
            builder: (_, GoRouterState state) =>
                GroupDetailPage(slug: state.pathParameters['slug']!),
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
        builder: (_, _) => const NewsPortalPage(),
        routes: <RouteBase>[
          // Ahead of `:slug`, so `submit` is never read as a headline's slug.
          GoRoute(path: 'submit', builder: (_, _) => const ContributeNewsPage()),
          GoRoute(
            path: ':slug',
            builder: (_, GoRouterState state) =>
                NewsArticlePage(slug: state.pathParameters['slug']!),
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
          // Ahead of `:slug`: `photographs` is the combined stream across every
          // album, not an album called "photographs".
          GoRoute(path: 'photographs', builder: (_, _) => const AllPhotographsPage()),
          GoRoute(
            path: ':slug',
            builder: (_, GoRouterState state) =>
                GalleryDetailPage(slug: state.pathParameters['slug']!),
          ),
        ],
      ),
      // Videos live in the Gallery now, as a tab. This path is kept working —
      // it is printed on materials and shared in messages — and opens the
      // Gallery with the film showing.
      GoRoute(
        path: AppRoutes.videos,
        builder: (_, _) => const GalleryListPage(initialTab: GalleryTab.videos),
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
      // --- The Yakoli forums (Module 5) -------------------------------------
      // Registered ahead of `/community`, whose `:slug` child would otherwise
      // read "forums" as a community project and answer "not found".
      GoRoute(
        path: AppRoutes.forums,
        builder: (_, _) => const ForumsIndexPage(),
        routes: <RouteBase>[
          // Before `:space`, or a space whose slug happened to be "moderation"
          // would shadow the moderators' own screen.
          GoRoute(path: 'moderation', builder: (_, _) => const ForumModerationPage()),
          GoRoute(
            path: ':space',
            builder: (_, GoRouterState state) =>
                ForumSpacePage(slug: state.pathParameters['space']!),
            routes: <RouteBase>[
              // Likewise before `:topic`.
              GoRoute(
                path: 'new',
                builder: (_, GoRouterState state) =>
                    ForumNewTopicPage(space: state.pathParameters['space']!),
              ),
              GoRoute(
                path: ':topic',
                builder: (_, GoRouterState state) => ForumTopicPage(
                  space: state.pathParameters['space']!,
                  topic: state.pathParameters['topic']!,
                ),
              ),
            ],
          ),
        ],
      ),

      // Development projects are a tab of News now — a borehole being finished
      // is news, and the project is what the news is about. The address keeps
      // working and opens News with that tab showing.
      GoRoute(
        path: AppRoutes.community,
        builder: (_, _) => const NewsPortalPage(initialTab: NewsTab.projects),
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

      // --- The user account -------------------------------------------------
      // One account for the whole platform. `/account` is the account acting on
      // itself;
      // `/directory/<handle>` is one member looking at another, which is why
      // they sit under different paths.
      GoRoute(path: AppRoutes.join, builder: (_, _) => const JoinPage()),

      // --- Messages ---------------------------------------------------------
      // The conversation is a child route with its own URL rather than a state
      // inside the list, so the back button behaves and a thread can be linked
      // to from a notification.
      GoRoute(
        path: AppRoutes.messages,
        builder: (_, _) => const MessagesPage(),
        routes: <RouteBase>[
          GoRoute(
            path: ':id',
            builder: (_, GoRouterState state) =>
                MessagesPage(conversationId: state.pathParameters['id']),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.account,
        builder: (_, GoRouterState state) =>
            AccountPage(justJoinedNumber: state.uri.queryParameters['joined']),
        routes: <RouteBase>[
          GoRoute(path: 'profile', builder: (_, _) => const ProfileEditorPage()),
          GoRoute(path: 'privacy', builder: (_, _) => const PrivacyPage()),
          GoRoute(path: 'family', builder: (_, _) => const FamilyPage()),
          GoRoute(path: 'birthdays', builder: (_, _) => const BirthdaysPage()),
          GoRoute(path: 'notifications', builder: (_, _) => const NotificationsPage()),
          GoRoute(path: 'requests', builder: (_, _) => const ContactRequestsPage()),
          // The path the memorial notice names. The notice and its button are
          // at the top of the account page itself, so this lands there.
          GoRoute(path: 'contest', redirect: (_, _) => AppRoutes.account),
        ],
      ),

      // --- The Yakoli directory (Module 7) ---------------------------------
      GoRoute(
        path: AppRoutes.directory,
        builder: (_, _) => const DirectoryPage(),
        routes: <RouteBase>[
          GoRoute(
            path: ':handle',
            builder: (_, GoRouterState state) =>
                MemberProfilePage(handle: state.pathParameters['handle']!),
          ),
        ],
      ),

      // --- Yakoli Opportunities (Module 6) ---------------------------------
      GoRoute(
        path: AppRoutes.opportunities,
        builder: (_, _) => const OpportunitiesPage(),
        routes: <RouteBase>[
          // Ahead of `:slug`, so `post` is never read as a listing's slug.
          GoRoute(path: 'post', builder: (_, _) => const PostOpportunityPage()),
          GoRoute(
            path: ':slug',
            builder: (_, GoRouterState state) =>
                OpportunityDetailPage(slug: state.pathParameters['slug']!),
          ),
        ],
      ),
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
        path: AppRoutes.editorialFestivalGalleries,
        builder: (_, _) => const FestivalGalleriesPage(workspace: WorkspaceKind.editorial),
      ),
      // The newsroom. `compose` before `:id`, so it is never read as a story id.
      GoRoute(
        path: AppRoutes.editorialNews,
        builder: (_, _) => const NewsWorkspacePage(workspace: WorkspaceKind.editorial),
        routes: <RouteBase>[
          GoRoute(
            path: 'compose',
            builder: (_, _) => const NewsComposerPage(workspace: WorkspaceKind.editorial),
          ),
          GoRoute(
            path: ':id',
            builder: (_, GoRouterState state) => NewsComposerPage(
              workspace: WorkspaceKind.editorial,
              newsId: state.pathParameters['id'],
            ),
          ),
        ],
      ),

      GoRoute(
        path: AppRoutes.editorialWordSubmissions,
        builder: (_, _) => const WordSubmissionsPage(workspace: WorkspaceKind.editorial),
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
        path: AppRoutes.adminFestivalGalleries,
        builder: (_, _) => const FestivalGalleriesPage(workspace: WorkspaceKind.admin),
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

      // The four queues that answer the community. Each path is one the Worker
      // already puts in a notification, so they must resolve.
      GoRoute(
        path: AppRoutes.adminPersonSubmissions,
        builder: (_, _) => const PersonSubmissionsPage(workspace: WorkspaceKind.admin),
      ),
      GoRoute(
        path: AppRoutes.adminNewsSubmissions,
        builder: (_, _) => const NewsSubmissionsPage(workspace: WorkspaceKind.admin),
      ),
      GoRoute(
        path: AppRoutes.adminOpportunities,
        builder: (_, _) => const OpportunityReviewPage(workspace: WorkspaceKind.admin),
      ),
      GoRoute(
        path: AppRoutes.adminRemembrance,
        builder: (_, _) => const RemembranceQueuePage(workspace: WorkspaceKind.admin),
      ),
      GoRoute(
        path: AppRoutes.adminCommunity,
        builder: (_, _) => const CommunitySnapshotPage(workspace: WorkspaceKind.admin),
      ),
      GoRoute(
        path: AppRoutes.adminMessages,
        builder: (_, _) => const ContactInboxPage(workspace: WorkspaceKind.admin),
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
