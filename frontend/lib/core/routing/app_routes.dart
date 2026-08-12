/// Every path in the application, in one place.
///
/// Paths are clean and permanent because the archive is meant to be linked to
/// from WhatsApp, printed on a Leboku banner as a QR code, and indexed by
/// search engines. A URL that works today should still work in ten years.
class AppRoutes {
  const AppRoutes._();

  // --- Public ---------------------------------------------------------------
  static const String home = '/';
  static const String about = '/about';
  static const String history = '/history';
  static const String culture = '/culture';
  static const String language = '/language';
  static const String leboku = '/leboku';
  static const String people = '/people';
  static const String leaders = '/leaders';
  static const String news = '/news';
  static const String events = '/events';
  static const String gallery = '/gallery';
  static const String videos = '/videos';
  static const String community = '/community';
  static const String businesses = '/businesses';
  static const String organizations = '/organizations';
  static const String contribute = '/contribute';
  static const String preservationTeam = '/preservation-team';
  static const String contact = '/contact';
  static const String search = '/search';

  // --- Account --------------------------------------------------------------
  static const String signIn = '/sign-in';
  static const String register = '/register';

  // --- Editorial ------------------------------------------------------------
  // The Editorial Team's own area. Separate from /admin by design: an editorial
  // account never sees an administrative control.
  static const String editorial = '/editorial';
  static const String editorialDashboard = '/editorial/dashboard';
  static const String editorialHomepage = '/editorial/homepage';
  static const String editorialPages = '/editorial/pages';
  static const String editorialNavigation = '/editorial/navigation';
  static const String editorialHistory = '/editorial/history';
  static const String editorialCulture = '/editorial/culture';
  static const String editorialLanguage = '/editorial/language';
  static const String editorialLeboku = '/editorial/leboku';
  static const String editorialPeople = '/editorial/people';
  static const String editorialNews = '/editorial/news';
  static const String editorialEvents = '/editorial/events';
  static const String editorialGallery = '/editorial/gallery';
  static const String editorialVideos = '/editorial/videos';
  static const String editorialCommunity = '/editorial/community';
  static const String editorialSubmissions = '/editorial/submissions';
  static const String editorialSources = '/editorial/sources';
  static const String editorialContributors = '/editorial/contributors';
  static const String editorialMedia = '/editorial/media';

  // --- Super Admin ----------------------------------------------------------
  static const String admin = '/admin';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminUsers = '/admin/users';
  static const String adminRoles = '/admin/roles';
  static const String adminEditorialTeam = '/admin/editorial-team';
  static const String adminContent = '/admin/content';
  static const String adminSubmissions = '/admin/submissions';
  static const String adminMedia = '/admin/media';
  static const String adminSources = '/admin/sources';
  static const String adminAuditLogs = '/admin/audit-logs';
  static const String adminSecurity = '/admin/security';
  static const String adminSettings = '/admin/settings';

  // --- Builders for parameterised paths -------------------------------------

  static String historyEntry(String slug) => '$history/$slug';
  static String cultureEntry(String slug) => '$culture/$slug';
  static String leader(String slug) => '$leaders/$slug';
  static String person(String slug) => '$people/$slug';
  static String newsItem(String slug) => '$news/$slug';
  static String event(String slug) => '$events/$slug';
  static String galleryAlbum(String slug) => '$gallery/$slug';
  static String video(String slug) => '$videos/$slug';
  static String business(String slug) => '$businesses/$slug';
  static String organization(String slug) => '$organizations/$slug';
  static String project(String slug) => '$community/$slug';
  static String languageEntry(String id) => '$language/$id';

  /// `/leboku/2026`, `/leboku/2027`, and every year thereafter.
  static String festivalYear(int year) => '$leboku/$year';

  static String searchFor(String query) => '$search?q=${Uri.encodeQueryComponent(query)}';

  /// Sends an unauthenticated visitor to sign-in and back again afterwards.
  static String signInReturningTo(String location) =>
      '$signIn?redirect=${Uri.encodeQueryComponent(location)}';

  /// Opens the contribution form pre-set to propose a correction to a record.
  static String suggestCorrection(String resourceType, String title) =>
      '$contribute?type=correction&about=${Uri.encodeQueryComponent('$resourceType: $title')}';

  /// Maps a search result's resource key to its public path.
  static String? forSearchHit(String resource, String segment) {
    switch (resource) {
      case 'history':
        return historyEntry(segment);
      case 'culture':
        return cultureEntry(segment);
      case 'leaders':
        return leader(segment);
      case 'people':
        return person(segment);
      case 'news':
        return newsItem(segment);
      case 'events':
        return event(segment);
      case 'galleries':
        return galleryAlbum(segment);
      case 'videos':
        return video(segment);
      case 'businesses':
        return business(segment);
      case 'organizations':
        return organization(segment);
      case 'community':
        return project(segment);
      case 'language':
        return languageEntry(segment);
      case 'festivals':
        return '$leboku/$segment';
      case 'pages':
        return '/$segment';
      default:
        return null;
    }
  }
}

/// One entry in the site navigation.
///
/// The live menus come from the CMS so the Editorial Team can rename or reorder
/// them. These constants are the fallback used before the CMS has loaded, or if
/// it cannot be reached — the navigation must never be empty.
class NavItem {
  const NavItem({required this.label, required this.path, this.description, this.isCta = false});

  final String label;
  final String path;
  final String? description;
  final bool isCta;
}

const List<NavItem> fallbackPrimaryNavigation = <NavItem>[
  NavItem(label: 'Home', path: AppRoutes.home),
  NavItem(label: 'About', path: AppRoutes.about, description: 'About Ekoli-Yeden and this archive'),
  NavItem(label: 'History', path: AppRoutes.history, description: 'Our history and heritage'),
  NavItem(label: 'Culture', path: AppRoutes.culture, description: 'Traditions and community life'),
  NavItem(label: 'Language', path: AppRoutes.language, description: 'Learn the Ekoli language'),
  NavItem(label: 'Leboku', path: AppRoutes.leboku, description: 'The Leboku festival, year by year'),
  NavItem(label: 'People', path: AppRoutes.people, description: 'People of Ekoli-Yeden'),
  NavItem(label: 'News', path: AppRoutes.news, description: 'Community news and announcements'),
  NavItem(label: 'Gallery', path: AppRoutes.gallery, description: 'Photographs from the archive'),
  NavItem(label: 'Videos', path: AppRoutes.videos, description: 'The video archive'),
  NavItem(label: 'Community', path: AppRoutes.community, description: 'Projects and organizations'),
  NavItem(label: 'Contribute', path: AppRoutes.contribute, isCta: true),
];

const List<NavItem> fallbackFooterNavigation = <NavItem>[
  NavItem(label: 'Events', path: AppRoutes.events),
  NavItem(label: 'Businesses', path: AppRoutes.businesses),
  NavItem(label: 'Organizations', path: AppRoutes.organizations),
  NavItem(label: 'Leadership', path: AppRoutes.leaders),
  NavItem(label: 'Preservation Team', path: AppRoutes.preservationTeam),
  NavItem(label: 'Contact', path: AppRoutes.contact),
  NavItem(label: 'Search the archive', path: AppRoutes.search),
];

/// The Editorial Team's sidebar. Content only — no administration.
const List<NavItem> editorialNavigation = <NavItem>[
  NavItem(label: 'Dashboard', path: AppRoutes.editorialDashboard),
  NavItem(label: 'Homepage', path: AppRoutes.editorialHomepage, description: 'Hero carousel and homepage sections'),
  NavItem(label: 'Website text', path: AppRoutes.editorialPages, description: 'All editable page text'),
  NavItem(label: 'Navigation', path: AppRoutes.editorialNavigation, description: 'Menu labels and order'),
  NavItem(label: 'History', path: AppRoutes.editorialHistory),
  NavItem(label: 'Culture', path: AppRoutes.editorialCulture),
  NavItem(label: 'Language', path: AppRoutes.editorialLanguage),
  NavItem(label: 'Leboku', path: AppRoutes.editorialLeboku),
  NavItem(label: 'People', path: AppRoutes.editorialPeople),
  NavItem(label: 'News', path: AppRoutes.editorialNews),
  NavItem(label: 'Events', path: AppRoutes.editorialEvents),
  NavItem(label: 'Gallery', path: AppRoutes.editorialGallery),
  NavItem(label: 'Videos', path: AppRoutes.editorialVideos),
  NavItem(label: 'Community', path: AppRoutes.editorialCommunity),
  NavItem(label: 'Media library', path: AppRoutes.editorialMedia, description: 'Upload photographs, audio and documents'),
  NavItem(label: 'Submissions', path: AppRoutes.editorialSubmissions, description: 'What the community has sent in'),
  NavItem(label: 'Sources', path: AppRoutes.editorialSources, description: 'The citation library'),
];

/// The content types an editor can create and edit, and the resource key each
/// maps to. Drives both the sidebar and the generated editorial routes, so the
/// two can never drift apart.
const Map<String, ({String resource, String title})> editorialContentScreens =
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

/// The Super Admin sidebar. Administration only — a different interface.
const List<NavItem> adminNavigation = <NavItem>[
  NavItem(label: 'System overview', path: AppRoutes.adminDashboard),
  NavItem(label: 'Users', path: AppRoutes.adminUsers),
  NavItem(label: 'Roles & permissions', path: AppRoutes.adminRoles),
  NavItem(label: 'Editorial Team', path: AppRoutes.adminEditorialTeam),
  NavItem(label: 'Content', path: AppRoutes.adminContent),
  NavItem(label: 'Submissions', path: AppRoutes.adminSubmissions),
  NavItem(label: 'Media library', path: AppRoutes.adminMedia),
  NavItem(label: 'Sources', path: AppRoutes.adminSources),
  NavItem(label: 'Audit logs', path: AppRoutes.adminAuditLogs),
  NavItem(label: 'Security', path: AppRoutes.adminSecurity),
  NavItem(label: 'Site settings', path: AppRoutes.adminSettings),
  // The Super Admin edits and publishes content from the Editorial workspace
  // rather than a second, parallel set of screens. The wildcard permission
  // means every control there is available; this is the way in.
  NavItem(
    label: 'Editorial workspace →',
    path: AppRoutes.editorialDashboard,
    description: 'Write, edit and publish website content',
  ),
];
