import '../core/constants/app_constants.dart';
import 'content_status.dart';

/// A record from any of the archive's content tables.
///
/// One model rather than fourteen. The tables share the same spine — id, slug,
/// title, body, status, verification, SEO, timestamps — and the fields that
/// differ are reached through `raw`. This keeps the client honest about what it
/// actually knows: adding a column in Module 2 does not require a new Dart
/// class before the value can be displayed.
class ContentRecord {
  const ContentRecord({
    required this.id,
    required this.status,
    required this.raw,
    this.slug,
    this.title,
    this.summary,
    this.body,
    this.category,
    this.coverMediaId,
    this.verificationStatus,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory ContentRecord.fromJson(Map<String, dynamic> json) {
    return ContentRecord(
      id: Json.str(json, 'id'),
      status: Json.str(json, 'status', fallback: ContentStatus.draft),
      slug: Json.strOrNull(json, 'slug'),
      // The tables use different names for their principal label; a person has
      // a name, a history entry has a title, a language entry has a word.
      title: Json.strOrNull(json, 'title') ??
          Json.strOrNull(json, 'name') ??
          Json.strOrNull(json, 'word'),
      summary: Json.strOrNull(json, 'summary') ??
          Json.strOrNull(json, 'excerpt') ??
          Json.strOrNull(json, 'headline') ??
          Json.strOrNull(json, 'description'),
      body: Json.strOrNull(json, 'body') ?? Json.strOrNull(json, 'biography'),
      category: Json.strOrNull(json, 'category'),
      coverMediaId: Json.strOrNull(json, 'cover_media_id') ??
          Json.strOrNull(json, 'portrait_media_id') ??
          Json.strOrNull(json, 'photo_media_id') ??
          Json.strOrNull(json, 'logo_media_id'),
      verificationStatus: Json.strOrNull(json, 'verification_status'),
      sortOrder: Json.intVal(json, 'sort_order'),
      createdAt: Json.strOrNull(json, 'created_at'),
      updatedAt: Json.strOrNull(json, 'updated_at'),
      raw: json,
    );
  }

  final String id;
  final String status;
  final String? slug;
  final String? title;
  final String? summary;
  final String? body;
  final String? category;
  final String? coverMediaId;
  final String? verificationStatus;
  final int sortOrder;
  final String? createdAt;
  final String? updatedAt;

  /// The full record, for fields specific to one content type.
  final Map<String, dynamic> raw;

  /// The URL segment for this record, preferring the slug for readable links.
  String get pathSegment => slug ?? id;

  String get displayTitle => title ?? 'Untitled';

  bool get isVerified => verificationStatus == VerificationStatus.verified;

  /// True when the entry states a fact about Ekoli-Yeden that nobody has
  /// confirmed yet. The interface says so rather than presenting it as settled.
  bool get needsVerification =>
      verificationStatus != null && verificationStatus != VerificationStatus.verified;

  T? field<T>(String key) {
    final dynamic value = raw[key];
    return value is T ? value : null;
  }

  String? text(String key) => Json.strOrNull(raw, key);
  int? number(String key) => Json.intOrNull(raw, key);
  bool flag(String key) => Json.boolVal(raw, key);
}
