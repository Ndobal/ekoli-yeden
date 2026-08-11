import '../services/api/api_client.dart';

/// Site settings, and the site-wide search.
///
/// Everything an administrator can change without a deployment comes from
/// here: the site name, the tagline, contact details, social links and the
/// switches that decide which sections are shown.
class SettingsRepository {
  const SettingsRepository(this._api);

  final ApiClient _api;

  /// Public settings only. Read once at startup.
  Future<SiteSettings> publicSettings() async {
    final Map<String, dynamic> data = await _api.get('/api/settings', authenticated: false);
    return SiteSettings(data);
  }

  Future<Map<String, dynamic>> adminSettings() => _api.get('/api/admin/settings');

  Future<Map<String, dynamic>> update(Map<String, dynamic> values) {
    return _api.put('/api/admin/settings', body: values);
  }

  /// Confirms the Worker is reachable, used by the health banner in development.
  Future<bool> health() async {
    try {
      final Map<String, dynamic> data = await _api.get('/api/health', authenticated: false);
      return data['status'] == 'healthy';
    } catch (_) {
      return false;
    }
  }

  /// One query across the whole archive.
  Future<SearchResults> search(String query, {List<String>? within}) async {
    final Map<String, dynamic> data = await _api.get(
      '/api/search',
      authenticated: false,
      query: <String, dynamic>{
        'q': query,
        if (within != null && within.isNotEmpty) 'in': within.join(','),
      },
    );
    return SearchResults.fromJson(data);
  }
}

/// Settings as the rest of the app reads them.
///
/// Every getter has a fallback, because a setting the community has not filled
/// in yet is the normal state — not an error.
class SiteSettings {
  const SiteSettings(this.values);

  static const SiteSettings empty = SiteSettings(<String, dynamic>{});

  final Map<String, dynamic> values;

  String get siteName => _string('site_name', 'Ekoli Yeden Digital Home');
  String get tagline => _string(
    'site_tagline',
    'Preserving Our Past. Celebrating Our Present. Building Our Future.',
  );
  String get communityName => _string('community_name', 'Ekoli-Yeden');
  String get festivalName => _string('festival_name', 'Leboku');

  String? get description => _nullable('site_description');
  String? get contactEmail => _nullable('contact_email');
  String? get contactPhone => _nullable('contact_phone');
  String? get contactAddress => _nullable('contact_address');
  String? get facebookUrl => _nullable('facebook_url');
  String? get youtubeUrl => _nullable('youtube_url');
  String? get instagramUrl => _nullable('instagram_url');
  String? get whatsappUrl => _nullable('whatsapp_url');

  int? get currentFestivalYear {
    final dynamic value = values['current_festival_year'];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  bool get contributionsOpen => _bool('feature_contributions_open', true);
  bool get languageAcademyEnabled => _bool('feature_language_academy', true);
  bool get businessDirectoryEnabled => _bool('feature_business_directory', true);
  bool get hallOfFameEnabled => _bool('feature_hall_of_fame', false);
  bool get publicRegistrationEnabled => _bool('feature_public_registration', true);
  bool get festivalCountdownEnabled => _bool('festival_countdown_enabled', false);

  bool get hasSocialLinks =>
      facebookUrl != null || youtubeUrl != null || instagramUrl != null || whatsappUrl != null;

  String _string(String key, String fallback) {
    final dynamic value = values[key];
    if (value == null) return fallback;
    final String text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String? _nullable(String key) {
    final dynamic value = values[key];
    if (value == null) return null;
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  bool _bool(String key, bool fallback) {
    final dynamic value = values[key];
    if (value is bool) return value;
    if (value is String) return value == 'true' || value == '1';
    if (value is num) return value != 0;
    return fallback;
  }
}

/// Search results, grouped by the part of the archive they came from.
class SearchResults {
  const SearchResults({required this.query, required this.total, required this.groups});

  factory SearchResults.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = (json['groups'] as List<dynamic>?) ?? const <dynamic>[];
    return SearchResults(
      query: json['query'] as String? ?? '',
      total: (json['total'] as num?)?.toInt() ?? 0,
      groups: raw.whereType<Map<String, dynamic>>().map(SearchGroup.fromJson).toList(growable: false),
    );
  }

  final String query;
  final int total;
  final List<SearchGroup> groups;

  bool get isEmpty => total == 0;
}

class SearchGroup {
  const SearchGroup({
    required this.resource,
    required this.label,
    required this.total,
    required this.hits,
  });

  factory SearchGroup.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = (json['hits'] as List<dynamic>?) ?? const <dynamic>[];
    return SearchGroup(
      resource: json['resource'] as String? ?? '',
      label: json['label'] as String? ?? '',
      total: (json['total'] as num?)?.toInt() ?? 0,
      hits: raw.whereType<Map<String, dynamic>>().map(SearchHit.fromJson).toList(growable: false),
    );
  }

  final String resource;
  final String label;
  final int total;
  final List<SearchHit> hits;
}

class SearchHit {
  const SearchHit({
    required this.resource,
    required this.id,
    required this.title,
    this.slug,
    this.excerpt,
  });

  factory SearchHit.fromJson(Map<String, dynamic> json) {
    return SearchHit(
      resource: json['resource'] as String? ?? '',
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '(untitled)',
      slug: json['slug'] as String?,
      excerpt: json['excerpt'] as String?,
    );
  }

  final String resource;
  final String id;
  final String title;
  final String? slug;
  final String? excerpt;

  String get pathSegment => slug ?? id;
}
