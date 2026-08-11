import '../models/content_status.dart';
import '../services/api/api_client.dart';

/// The CMS: the text of the public website, held in the database.
class CmsRepository {
  const CmsRepository(this._api);

  final ApiClient _api;

  /// One request for everything the site needs to render its text.
  Future<CmsBundle> bundle() async {
    final Map<String, dynamic> data = await _api.get('/api/cms/bundle', authenticated: false);
    return CmsBundle.fromJson(data);
  }

  /// The hero carousel with its images resolved.
  Future<List<HeroSlide>> hero() async {
    final Map<String, dynamic> data = await _api.get('/api/cms/hero', authenticated: false);
    return Json.objectList(data, 'slides').map(HeroSlide.fromJson).toList(growable: false);
  }

  /// Sources cited by a record — shown on history and culture pages.
  Future<List<CitedSource>> sourcesFor(String resourceType, String resourceId) async {
    final Map<String, dynamic> data = await _api.get(
      '/api/sources/$resourceType/$resourceId',
      authenticated: false,
    );
    return Json.objectList(data, 'sources').map(CitedSource.fromJson).toList(growable: false);
  }

  /// Contributor acknowledgement for a record.
  Future<List<ContributorCredit>> contributorsFor(String resourceType, String resourceId) async {
    final Map<String, dynamic> data = await _api.get(
      '/api/contributors/$resourceType/$resourceId',
      authenticated: false,
    );
    return Json.objectList(data, 'contributors')
        .map(ContributorCredit.fromJson)
        .toList(growable: false);
  }

  // --- Editorial ------------------------------------------------------------

  Future<Map<String, dynamic>> editorialStrings({String? group, String? page}) {
    return _api.get(
      '/api/editorial/strings',
      query: <String, dynamic>{'group': ?group, 'page': ?page},
    );
  }

  Future<void> saveDraft(String key, String value) async {
    await _api.put('/api/editorial/strings/$key', body: <String, dynamic>{'value': value});
  }

  Future<void> submitForReview(String key) async {
    await _api.post('/api/editorial/strings/$key/submit');
  }

  Future<void> reviewString(String key, {required bool approved}) async {
    await _api.post(
      '/api/editorial/strings/$key/review',
      body: <String, dynamic>{'approved': approved},
    );
  }

  Future<void> publishString(String key) async {
    await _api.post('/api/editorial/strings/$key/publish');
  }

  Future<Map<String, dynamic>> editorialDashboard() => _api.get('/api/editorial/dashboard');

  Future<Map<String, dynamic>> editorialHero() => _api.get('/api/editorial/hero');

  Future<void> updateHeroSlide(int slideNumber, Map<String, dynamic> values) async {
    await _api.put('/api/editorial/hero/$slideNumber', body: values);
  }

  Future<Map<String, dynamic>> editorialNavigation() => _api.get('/api/editorial/navigation');

  Future<void> updateNavigationItem(String id, Map<String, dynamic> values) async {
    await _api.patch('/api/editorial/navigation/$id', body: values);
  }

  Future<Map<String, dynamic>> sources() => _api.get('/api/editorial/sources');

  Future<Map<String, dynamic>> versionsFor(String resourceType, String resourceId) {
    return _api.get('/api/editorial/versions/$resourceType/$resourceId');
  }
}

/// Everything the public site needs to render its text.
class CmsBundle {
  const CmsBundle({
    required this.strings,
    required this.hero,
    required this.primaryNav,
    required this.footerNav,
  });

  factory CmsBundle.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rawStrings =
        (json['strings'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final Map<String, dynamic> nav =
        (json['navigation'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    return CmsBundle(
      strings: rawStrings.map(
        (String key, dynamic value) => MapEntry<String, String>(key, value.toString()),
      ),
      hero: Json.objectList(json, 'hero').map(HeroSlide.fromJson).toList(growable: false),
      primaryNav: Json.objectList(nav, 'primary').map(CmsNavItem.fromJson).toList(growable: false),
      footerNav: Json.objectList(nav, 'footer').map(CmsNavItem.fromJson).toList(growable: false),
    );
  }

  static const CmsBundle empty = CmsBundle(
    strings: <String, String>{},
    hero: <HeroSlide>[],
    primaryNav: <CmsNavItem>[],
    footerNav: <CmsNavItem>[],
  );

  final Map<String, String> strings;
  final List<HeroSlide> hero;
  final List<CmsNavItem> primaryNav;
  final List<CmsNavItem> footerNav;
}

class CmsNavItem {
  const CmsNavItem({
    required this.label,
    required this.path,
    this.description,
    this.isCta = false,
  });

  factory CmsNavItem.fromJson(Map<String, dynamic> json) {
    return CmsNavItem(
      label: Json.str(json, 'label'),
      path: Json.str(json, 'path', fallback: '/'),
      description: Json.strOrNull(json, 'description'),
      isCta: Json.boolVal(json, 'isCta'),
    );
  }

  final String label;
  final String path;
  final String? description;
  final bool isCta;
}

/// One slide of the homepage carousel.
class HeroSlide {
  const HeroSlide({
    required this.slideNumber,
    required this.title,
    this.eyebrow,
    this.description,
    this.imageUrl,
    this.imageAltText,
    this.primaryButtonLabel,
    this.primaryButtonPath,
    this.secondaryButtonLabel,
    this.secondaryButtonPath,
  });

  factory HeroSlide.fromJson(Map<String, dynamic> json) {
    return HeroSlide(
      slideNumber: Json.intVal(json, 'slideNumber', fallback: 1),
      title: Json.str(json, 'title'),
      eyebrow: Json.strOrNull(json, 'eyebrow'),
      description: Json.strOrNull(json, 'description'),
      imageUrl: Json.strOrNull(json, 'imageUrl'),
      imageAltText: Json.strOrNull(json, 'imageAltText'),
      primaryButtonLabel: Json.strOrNull(json, 'primaryButtonLabel'),
      primaryButtonPath: Json.strOrNull(json, 'primaryButtonPath'),
      secondaryButtonLabel: Json.strOrNull(json, 'secondaryButtonLabel'),
      secondaryButtonPath: Json.strOrNull(json, 'secondaryButtonPath'),
    );
  }

  final int slideNumber;
  final String title;
  final String? eyebrow;
  final String? description;

  /// Null until the Media Team attaches an approved photograph. The carousel
  /// draws a branded panel in that case rather than a broken image.
  final String? imageUrl;

  final String? imageAltText;
  final String? primaryButtonLabel;
  final String? primaryButtonPath;
  final String? secondaryButtonLabel;
  final String? secondaryButtonPath;

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasPrimaryButton => primaryButtonLabel != null && primaryButtonPath != null;
  bool get hasSecondaryButton => secondaryButtonLabel != null && secondaryButtonPath != null;
}

/// A citation shown under a history or culture article.
class CitedSource {
  const CitedSource({
    required this.id,
    required this.title,
    required this.sourceType,
    required this.reliability,
    this.author,
    this.url,
    this.publication,
    this.publicationDate,
    this.accessedDate,
    this.citationText,
    this.supports,
    this.notes,
  });

  factory CitedSource.fromJson(Map<String, dynamic> json) {
    return CitedSource(
      id: Json.str(json, 'id'),
      title: Json.str(json, 'title'),
      sourceType: Json.str(json, 'source_type', fallback: 'web'),
      reliability: Json.str(json, 'reliability', fallback: 'unassessed'),
      author: Json.strOrNull(json, 'author'),
      url: Json.strOrNull(json, 'url'),
      publication: Json.strOrNull(json, 'publication'),
      publicationDate: Json.strOrNull(json, 'publication_date'),
      accessedDate: Json.strOrNull(json, 'accessed_date'),
      citationText: Json.strOrNull(json, 'citation_text'),
      supports: Json.strOrNull(json, 'supports'),
      notes: Json.strOrNull(json, 'notes'),
    );
  }

  final String id;
  final String title;
  final String sourceType;

  /// How much weight the archive gives this source. A community blog post and
  /// an interview with an elder are both useful, and are not the same thing.
  final String reliability;

  final String? author;
  final String? url;
  final String? publication;
  final String? publicationDate;
  final String? accessedDate;
  final String? citationText;
  final String? supports;
  final String? notes;

  /// The citation as it should read on the page.
  String get display {
    if (citationText != null && citationText!.isNotEmpty) return citationText!;
    final List<String> parts = <String>[
      ?author,
      title,
      ?publication,
      ?publicationDate,
    ];
    return parts.join('. ');
  }

  /// True where the archive should warn the reader about this source.
  bool get isContested => reliability == 'contested';

  static const Map<String, String> reliabilityLabels = <String, String>{
    'unassessed': 'Not yet assessed',
    'primary': 'Primary source',
    'secondary': 'Secondary source',
    'tertiary': 'Tertiary source',
    'contested': 'Contested source',
  };

  String get reliabilityLabel => reliabilityLabels[reliability] ?? reliability;
}

/// A contributor acknowledgement, shown on published material.
class ContributorCredit {
  const ContributorCredit({
    required this.id,
    required this.name,
    required this.credit,
    this.type,
  });

  factory ContributorCredit.fromJson(Map<String, dynamic> json) {
    return ContributorCredit(
      id: Json.str(json, 'id'),
      name: Json.str(json, 'name'),
      credit: Json.str(json, 'credit'),
      type: Json.strOrNull(json, 'type'),
    );
  }

  final String id;
  final String name;

  /// The full line, e.g. "Photo contributed by: Ama Obeten".
  final String credit;

  final String? type;
}
