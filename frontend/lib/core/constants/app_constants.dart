/// Values shared across the application.
///
/// These mirror definitions that the Cloudflare Worker enforces. The copies
/// here exist so the interface can label and lay things out — never so the
/// client can make a decision the server should make. Authorisation, status
/// filtering and validation all happen on the server regardless of what this
/// file says.
library;

/// The editorial workflow every moderated content type moves through.
class ContentStatus {
  const ContentStatus._();

  static const String draft = 'draft';
  static const String pendingReview = 'pending_review';
  static const String approved = 'approved';
  static const String published = 'published';
  static const String archived = 'archived';
  static const String rejected = 'rejected';

  static const List<String> all = <String>[
    draft,
    pendingReview,
    approved,
    published,
    archived,
    rejected,
  ];

  /// Human labels for the admin interface.
  static const Map<String, String> labels = <String, String>{
    draft: 'Draft',
    pendingReview: 'Pending review',
    approved: 'Approved',
    published: 'Published',
    archived: 'Archived',
    rejected: 'Rejected',
  };

  static String label(String status) => labels[status] ?? status;
}

/// Whether a factual claim has been checked by the Verification Team.
class VerificationStatus {
  const VerificationStatus._();

  static const String unverified = 'unverified';
  static const String inReview = 'in_review';
  static const String verified = 'verified';
  static const String disputed = 'disputed';

  static const Map<String, String> labels = <String, String>{
    unverified: 'Awaiting verification',
    inReview: 'Being verified',
    verified: 'Verified',
    disputed: 'Disputed',
  };

  static String label(String status) => labels[status] ?? status;
}

/// Platform roles. The authoritative list lives in the `roles` table.
class AppRoles {
  const AppRoles._();

  static const String superAdmin = 'super_admin';
  static const String contentAdministrator = 'content_administrator';
  static const String heritageEditor = 'heritage_editor';
  static const String languageEditor = 'language_editor';
  static const String mediaManager = 'media_manager';
  static const String lebokuManager = 'leboku_manager';
  static const String moderator = 'moderator';
  static const String contributor = 'contributor';
  static const String publicVisitor = 'public_visitor';

  static const Map<String, String> labels = <String, String>{
    superAdmin: 'Super Admin',
    contentAdministrator: 'Content Administrator',
    heritageEditor: 'Heritage Editor',
    languageEditor: 'Language Editor',
    mediaManager: 'Media Manager',
    lebokuManager: 'Leboku Manager',
    moderator: 'Moderator',
    contributor: 'Contributor',
    publicVisitor: 'Public Visitor',
  };

  static String label(String slug) => labels[slug] ?? slug;
}

/// R2 folders. Videos are absent by design — YouTube is the video host.
class MediaFolders {
  const MediaFolders._();

  static const String images = 'images';
  static const String audio = 'audio';
  static const String documents = 'documents';
  static const String avatars = 'avatars';
  static const String heritage = 'heritage';
  static const String language = 'language';
  static const String leboku = 'leboku';

  static const List<String> all = <String>[
    images,
    audio,
    documents,
    avatars,
    heritage,
    language,
    leboku,
  ];
}

/// How the archive organises its YouTube videos.
class VideoCategories {
  const VideoCategories._();

  static const Map<String, String> labels = <String, String>{
    'leboku': 'Leboku',
    'history': 'History',
    'interviews': 'Interviews',
    'culture': 'Culture',
    'community': 'Community',
    'events': 'Events',
    'documentaries': 'Documentaries',
    'music': 'Music',
    'oral_history': 'Oral history',
  };

  static List<String> get all => labels.keys.toList();

  static String label(String slug) => labels[slug] ?? slug;
}

/// The kinds of entry the Ekoli language dictionary holds.
class LanguageEntryTypes {
  const LanguageEntryTypes._();

  static const Map<String, String> labels = <String, String>{
    'word': 'Word',
    'phrase': 'Phrase',
    'greeting': 'Greeting',
    'proverb': 'Proverb',
    'idiom': 'Idiom',
    'number': 'Number',
    'name': 'Name',
    'song': 'Song',
    'riddle': 'Riddle',
  };

  static List<String> get all => labels.keys.toList();

  static String label(String slug) => labels[slug] ?? slug;
}

/// What a visitor may contribute to the archive.
class SubmissionTypes {
  const SubmissionTypes._();

  static const Map<String, String> labels = <String, String>{
    'historical_photograph': 'Old photograph',
    'historical_document': 'Historical document',
    'story': 'Story',
    'oral_history': 'Oral history or interview',
    'language_recording': 'Ekoli language recording',
    'video': 'Video (YouTube link)',
    'notable_person': 'Information about a notable person',
    'cultural_material': 'Cultural material',
    'correction': 'A correction to something published',
    'other': 'Something else',
  };

  static List<String> get all => labels.keys.toList();

  static String label(String slug) => labels[slug] ?? slug;
}

/// The volunteer organisation that fills the archive.
class PreservationTeam {
  const PreservationTeam._();

  static const String name = 'Ekoli-Yeden Preservation Team';

  static const Map<String, String> positions = <String, String>{
    'coordinator': 'Coordinator',
    'secretary': 'Secretary',
    'history_and_research': 'History & Research Team',
    'language_preservation': 'Language Preservation Team',
    'media': 'Media Team',
    'technology': 'Technology Team',
    'verification': 'Verification Team',
    'community_outreach': 'Community Outreach Team',
    'archive': 'Archive Team',
    'volunteer': 'Volunteer',
  };

  static String label(String slug) => positions[slug] ?? slug;
}

/// Text shown wherever the community has not yet supplied material.
///
/// The archive says plainly that something is not yet recorded rather than
/// filling the space with invented content.
class Placeholders {
  const Placeholders._();

  static const String awaitingMaterial =
      'This section is ready and waiting for verified material from the community.';
  static const String awaitingVerification =
      'This entry has not yet been verified by the Ekoli-Yeden Preservation Team.';
  static const String notYetSupplied = 'To be supplied';
  static const String contributePrompt =
      'Do you have photographs, documents, stories or recordings that belong here? Please share them.';
}
