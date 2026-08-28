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

  /// The canonical festivals section. Leboku is the largest of the community's
  /// festivals, not the only one, so the section is general.
  static const String festivals = '/festivals';

  /// Kept working so links printed on earlier festival materials still resolve.
  static const String leboku = '/leboku';

  static const String ageGrades = '/age-grades';
  static const String culturalGroups = '/cultural-groups';

  /// Every kind of group in one section.
  ///
  /// `/age-grades` and `/cultural-groups` are this page with a filter applied
  /// rather than sections of their own — they need the same things of the
  /// archive, and a visitor looking for their age grade should be able to
  /// discover the dance troupe on the way.
  static const String groups = '/groups';
  static const String music = '/music';
  static const String people = '/people';

  /// The profile builder for adding somebody to the People section.
  ///
  /// A structured form rather than the generic contribution page, because the
  /// destination is structured — see `contribute_person_page.dart`.
  static const String contributePerson = '/people/add';
  static const String leaders = '/leaders';
  static const String news = '/news';
  static const String events = '/events';
  static const String gallery = '/gallery';
  static const String videos = '/videos';
  static const String community = '/community';
  static const String businesses = '/businesses';
  static const String organizations = '/organizations';
  static const String contribute = '/contribute';

  // --- The last sections of the proposal to be built -----------------------

  /// §8 — the oral history archive.
  static const String voices = '/voices';

  /// §18 — folktales and the long tellings. Proverbs, riddles and praise names
  /// stay in the language section, where they can carry their pronunciation.
  static const String stories = '/stories';

  /// §17 — the children's area. `/learn` rather than `/children`, because it is
  /// named for what somebody does there rather than for who they are.
  static const String learn = '/learn';

  /// §16 — the map.
  static const String map = '/discover';

  /// §13 — the Hall of Fame, shown only when the community switches it on.
  static const String hallOfFame = '/hall-of-fame';

  /// Sending in news.
  ///
  /// A form of its own rather than the general contribution page: news has a
  /// shape — a headline, what happened, when, and where — and asking for that
  /// shape is what gets it published instead of filed behind photographs.
  static const String contributeNews = '/news/submit';

  /// Contributing a word is not contributing a photograph. A word arrives with
  /// variants, parts of speech, several meanings and a sentence showing it in
  /// use, none of which fit a "title and description" form — so it has one of
  /// its own.
  static const String contributeWord = '/language/contribute';

  /// Registering an age grade, and the workspace its administrators run it from.
  static const String registerAgeGrade = '/age-grades/register';
  static const String registerGroup = '/groups/register';
  static const String myAgeGrades = '/my/age-grades';

  /// The combined photograph stream — every picture in the archive, whichever
  /// album it belongs to.
  static const String photographs = '/gallery/photographs';

  /// The people Ekoli-Yeden came from.
  ///
  /// Public, with no sign-in: a memorial only members can read is one the
  /// family living abroad cannot show their children.
  static const String ancestry = '/ancestry';

  /// Recording that somebody has died. A claim, and nothing more, until family
  /// confirm it — which is why it has a page of its own that says so rather
  /// than a button hidden in a menu.
  static const String reportPassing = '/ancestry/report';

  /// The places of Ekori — the wards, the quarters inside them, and the
  /// compounds inside those.
  static const String places = '/places';

  static const String preservationTeam = '/preservation-team';
  static const String contact = '/contact';

  /// The policy pages.
  ///
  /// Linked from the footer of every page, because that is where somebody
  /// looks for them, and reachable without an account, because somebody
  /// deciding whether to make an account needs to read them first.
  static const String terms = '/terms';
  static const String privacy = '/privacy';
  static const String cookies = '/cookies';
  static const String search = '/search';

  // --- The user account -----------------------------------------------------
  // One account for the whole platform. Registering IS joining — there is no
  // separate contributor account.
  // The forums, the opportunities
  // board and the directory all read the profile these pages maintain; none of
  // them has a sign-in of its own.
  static const String join = '/join';
  static const String directory = '/directory';

  /// Yakoli Opportunities — jobs, scholarships, training and grants.
  ///
  /// Signed-in only, because the feature IS the matching and there is nothing
  /// useful to show somebody the archive knows nothing about.
  static const String opportunities = '/opportunities';
  static const String postOpportunity = '/opportunities/post';

  /// MESSAGES BETWEEN MEMBERS.
  ///
  /// The whole point of the section: you can reach anybody in the community
  /// without being given their phone number, and without publishing your own.
  static const String messages = '/messages';

  /// The community forums.
  static const String forums = '/community/forums';

  /// The moderators' side of the forums: the report queue and the log.
  ///
  /// A static segment under `/community/forums`, which means it must be
  /// registered ahead of `/community/forums/:space` in the router — a space
  /// whose slug happened to be "moderation" would otherwise shadow it.
  static const String forumModeration = '/community/forums/moderation';

  // --- Account --------------------------------------------------------------
  static const String signIn = '/sign-in';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String account = '/account';
  static const String accountProfile = '/account/profile';
  static const String accountPrivacy = '/account/privacy';
  static const String accountNotifications = '/account/notifications';

  /// A member's own family connections, and the requests waiting on them.
  static const String accountFamily = '/account/family';

  /// Contesting a report that this account's holder has died.
  ///
  /// The server names this path in the notice it returns, so it has to resolve.
  /// It lands on the account page, where the notice and its one button sit
  /// above everything else.
  static const String accountContest = '/account/contest';

  /// Who has asked to see this member's phone number or email, and who is
  /// currently holding them.
  ///
  /// The path the server names in the notification it sends when somebody
  /// asks, so it has to resolve.
  static const String accountRequests = '/account/requests';

  /// Every birthday wish this member has received, kept by year.
  static const String accountBirthdays = '/account/birthdays';

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
  static const String editorialVoices = '/editorial/voices';
  static const String editorialStories = '/editorial/stories';
  static const String editorialQuizzes = '/editorial/quizzes';

  /// The composer, for a story that does not exist yet.
  static const String editorialNewsCompose = '/editorial/news/compose';
  static const String editorialEvents = '/editorial/events';
  static const String editorialGallery = '/editorial/gallery';
  static const String editorialVideos = '/editorial/videos';
  static const String editorialCommunity = '/editorial/community';
  static const String editorialSubmissions = '/editorial/submissions';
  static const String editorialSources = '/editorial/sources';
  static const String editorialContributors = '/editorial/contributors';
  static const String editorialMedia = '/editorial/media';
  static const String editorialContributions = '/editorial/contributions';
  static const String editorialFestivalGalleries = '/editorial/festival-galleries';
  static const String editorialWordSubmissions = '/editorial/word-submissions';

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
  static const String adminContributions = '/admin/contributions';

  /// The four queues that answer the community.
  ///
  /// Each of these is a path the Worker already puts in a notification, so they
  /// are not free to change: an administrator told that somebody has sent in
  /// news must land on the page that holds it.
  static const String adminPersonSubmissions = '/admin/person-submissions';
  static const String adminNewsSubmissions = '/admin/news-submissions';
  static const String adminOpportunities = '/admin/opportunities';
  static const String adminRemembrance = '/admin/remembrance';

  /// Who the community is, in counts — and the places members have named that
  /// the archive does not recognise yet.
  static const String adminCommunity = '/admin/community';

  /// What the public has written to the Preservation Team.
  ///
  /// The path the server puts in the notification it sends when a message
  /// arrives, so it has to resolve.
  static const String adminMessages = '/admin/messages';
  static const String adminFestivalGalleries = '/admin/festival-galleries';

  // --- Builders for parameterised paths -------------------------------------

  static String historyEntry(String slug) => '$history/$slug';
  static String cultureEntry(String slug) => '$culture/$slug';
  static String leader(String slug) => '$leaders/$slug';
  static String person(String slug) => '$people/$slug';
  static String newsItem(String slug) => '$news/$slug';
  static String event(String slug) => '$events/$slug';
  static String galleryAlbum(String slug) => '$gallery/$slug';
  static String video(String slug) => '$videos/$slug';
  static String voice(String slug) => '$voices/$slug';
  static String story(String slug) => '$stories/$slug';
  static String quiz(String slug) => '$learn/$slug';
  static String business(String slug) => '$businesses/$slug';
  static String organization(String slug) => '$organizations/$slug';
  static String project(String slug) => '$community/$slug';
  static String languageEntry(String id) => '$language/$id';

  /// A festival by slug — `/festivals/leboku-2026`.
  static String festival(String slug) => '$festivals/$slug';

  /// `/leboku/2026`, `/leboku/2027`, and every year thereafter. Retained for
  /// links already in circulation.
  static String festivalYear(int year) => '$leboku/$year';

  /// A member's public page — `/directory/alice-obeten`.
  ///
  /// Under the directory rather than under `/account`, because it is a page
  /// about a person that other people read, not part of anybody's own account.
  static String memberProfile(String handle) => '$directory/$handle';

  /// One opportunity — `/opportunities/teacher-at-ekori-secondary`.
  static String opportunity(String slug) => '$opportunities/$slug';

  /// The composer, opened on an existing story.
  static String editorialNewsEdit(String id) => '$editorialNews/$id';

  /// One place — `/places/ukekeya`.
  static String place(String slug) => '$places/$slug';

  /// One memorial — `/ancestry/chief-obeten-ako`.
  ///
  /// This is the path the server puts in the notification it sends when a
  /// memorial is published, so the two must stay in step.
  static String ancestryRecord(String slug) => '$ancestry/$slug';

  /// One conversation — `/messages/<id>`.
  ///
  /// A real address rather than a hidden state, so the browser's back button
  /// works and a conversation survives a page refresh.
  static String conversation(String id) => '$messages/$id';

  /// One forum space — `/community/forums/general`.
  static String forumSpace(String slug) => '$forums/$slug';

  /// One conversation — `/community/forums/general/the-road-to-ajere`.
  ///
  /// This is the path the server puts in a notification when somebody replies
  /// to you, so the two must stay in step.
  static String forumTopic(String space, String topic) => '$forums/$space/$topic';

  /// The composer, for a conversation that does not exist yet.
  static String forumNewTopic(String space) => '$forums/$space/new';

  static String ageGrade(String slug) => '$ageGrades/$slug';

  /// The workspace a grade's own administrators run their page from.
  static String ageGradeManage(String slug) => '$ageGrades/$slug/manage';

  static String ageGradePost(String gradeSlug, String postSlug) =>
      '$ageGrades/$gradeSlug/posts/$postSlug';

  static String culturalGroup(String slug) => '$culturalGroups/$slug';

  /// One group's page, whatever kind it is.
  static String group(String slug) => '$groups/$slug';

  /// The officers' side of a group: requests to join, dues, issues.
  static String groupManage(String slug) => '$groups/$slug/manage';

  /// A member's own dues for one group.
  static String groupDues(String slug) => '$groups/$slug/dues';
  static String musicEntry(String slug) => '$music/$slug';

  /// One area of the cultural archive — `/culture/area/food`.
  ///
  /// A separate segment from `/culture/<slug>`, which is an article. An area is
  /// a shelf; an article is a thing on it, and the two need different addresses.
  static String cultureArea(String slug) => '$culture/area/$slug';

  /// The contribution form, pre-set to one area of the cultural archive.
  static String contributeToArea(String areaLabel) =>
      '$contribute?type=cultural_material&about=${Uri.encodeQueryComponent('Culture: $areaLabel')}';

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
        return festival(segment);
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
  NavItem(
    label: 'Festivals',
    path: AppRoutes.festivals,
    description: 'Lekoli Boku and the festivals of Ekoli-Yeden',
  ),
  NavItem(label: 'People', path: AppRoutes.people, description: 'People of Ekoli-Yeden'),
  NavItem(
    label: 'Voices',
    path: AppRoutes.voices,
    description: 'Elders and others, recorded in their own words',
  ),
  NavItem(
    label: 'Stories',
    path: AppRoutes.stories,
    description: 'Folktales and the long tellings',
  ),
  NavItem(
    label: 'Discover',
    path: AppRoutes.map,
    description: 'The wards, quarters and landmarks of Ekori',
  ),
  NavItem(
    label: 'For children',
    path: AppRoutes.learn,
    description: 'Learn about Ekori — greetings, numbers and quizzes',
  ),
  NavItem(label: 'News', path: AppRoutes.news, description: 'Community news and announcements'),
  NavItem(
    label: 'Gallery',
    path: AppRoutes.gallery,
    description: 'Photographs and film from the archive',
  ),
  NavItem(
    label: 'Community',
    path: AppRoutes.community,
    description: 'Development projects, inside the news section',
  ),
  NavItem(
    label: 'Join',
    path: AppRoutes.join,
    description: 'One account — registering makes you part of Ekoli-Yeden',
  ),
  NavItem(
    label: 'Messages',
    path: AppRoutes.messages,
    description: 'Write to anybody in the community — no phone number needed',
  ),
  NavItem(label: 'Contribute', path: AppRoutes.contribute, isCta: true),
];

const List<NavItem> fallbackFooterNavigation = <NavItem>[
  NavItem(label: 'Community forums', path: AppRoutes.forums),
  NavItem(label: 'Ancestry records', path: AppRoutes.ancestry),
  NavItem(label: 'The places of Ekori', path: AppRoutes.places),
  NavItem(label: 'Age grades', path: AppRoutes.ageGrades),
  NavItem(label: 'Contribute a word', path: AppRoutes.contributeWord),
  NavItem(label: 'Every photograph', path: AppRoutes.photographs),
  NavItem(label: 'Cultural groups', path: AppRoutes.culturalGroups),
  NavItem(label: 'Cultural music', path: AppRoutes.music),
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
  NavItem(
    label: 'News',
    path: AppRoutes.editorialNews,
    description: 'The newsroom — write, review, schedule and publish',
  ),
  NavItem(label: 'Events', path: AppRoutes.editorialEvents),
  NavItem(label: 'Gallery', path: AppRoutes.editorialGallery),
  NavItem(label: 'Videos', path: AppRoutes.editorialVideos),
  NavItem(label: 'Community', path: AppRoutes.editorialCommunity),
  NavItem(
    label: 'Festival photographs',
    path: AppRoutes.editorialFestivalGalleries,
    description: 'One album per festival year',
  ),
  NavItem(label: 'Media library', path: AppRoutes.editorialMedia, description: 'Upload photographs, audio and documents'),
  NavItem(label: 'Submissions', path: AppRoutes.editorialSubmissions, description: 'What the community has sent in'),
  NavItem(
    label: 'Contributed files',
    path: AppRoutes.editorialContributions,
    description: 'Photographs and documents awaiting review',
  ),
  NavItem(
    label: 'Proposed words',
    path: AppRoutes.editorialWordSubmissions,
    description: 'Dictionary entries sent in by the community',
  ),
  NavItem(
    label: 'Voices of Ekori',
    path: AppRoutes.editorialVoices,
    description: 'Oral history recordings, transcripts and consent',
  ),
  NavItem(
    label: 'Stories',
    path: AppRoutes.editorialStories,
    description: 'Folktales and the long tellings',
  ),
  NavItem(
    label: 'Quizzes',
    path: AppRoutes.editorialQuizzes,
    description: 'The children’s learning area',
  ),
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
  AppRoutes.editorialEvents: (resource: 'events', title: 'Events'),
  AppRoutes.editorialGallery: (resource: 'galleries', title: 'Gallery'),
  AppRoutes.editorialVideos: (resource: 'videos', title: 'Videos'),
  AppRoutes.editorialCommunity: (resource: 'community', title: 'Community projects'),
  AppRoutes.editorialVoices: (resource: 'recordings', title: 'Voices of Ekori'),
  AppRoutes.editorialStories: (resource: 'stories', title: 'Stories and folklore'),
  AppRoutes.editorialQuizzes: (resource: 'quizzes', title: 'Quizzes'),
};

/// The Super Admin sidebar. Administration only — a different interface.
const List<NavItem> adminNavigation = <NavItem>[
  NavItem(label: 'System overview', path: AppRoutes.adminDashboard),
  NavItem(label: 'Users', path: AppRoutes.adminUsers),
  NavItem(label: 'Roles & permissions', path: AppRoutes.adminRoles),
  NavItem(label: 'Editorial Team', path: AppRoutes.adminEditorialTeam),
  NavItem(label: 'Content', path: AppRoutes.adminContent),
  NavItem(label: 'Submissions', path: AppRoutes.adminSubmissions),
  NavItem(
    label: 'Contributed files',
    path: AppRoutes.adminContributions,
    description: 'Files awaiting review',
  ),
  NavItem(
    label: 'Profiles sent in',
    path: AppRoutes.adminPersonSubmissions,
    description: 'People the community has asked us to record',
  ),
  NavItem(
    label: 'News sent in',
    path: AppRoutes.adminNewsSubmissions,
    description: 'Written by members, published by administrators',
  ),
  NavItem(
    label: 'Opportunities',
    path: AppRoutes.adminOpportunities,
    description: 'Reported listings, and listings awaiting review',
  ),
  NavItem(
    label: 'Remembrance',
    path: AppRoutes.adminRemembrance,
    description: 'Death reports, and the memorials published from them',
  ),
  NavItem(
    label: 'The community',
    path: AppRoutes.adminCommunity,
    description: 'Counts only, and the places members have named',
  ),
  NavItem(
    label: 'Messages',
    path: AppRoutes.adminMessages,
    description: 'What the public has written to the Preservation Team',
  ),
  NavItem(
    label: 'Festival photographs',
    path: AppRoutes.adminFestivalGalleries,
    description: 'One album per festival year',
  ),
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
