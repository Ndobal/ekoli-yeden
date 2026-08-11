import '../core/constants/app_constants.dart';
import 'content_status.dart';

/// A file held in R2, described by its D1 record.
///
/// `url` is a link back through the Worker, never a direct bucket URL — the
/// Worker checks the record's status before it streams any bytes.
class MediaAsset {
  const MediaAsset({
    required this.id,
    required this.storageKey,
    required this.folder,
    required this.mimeType,
    required this.sizeBytes,
    required this.status,
    required this.url,
    this.title,
    this.description,
    this.altText,
    this.credit,
    this.capturedAt,
    this.location,
    this.originalFilename,
    this.verificationStatus,
    this.createdAt,
  });

  factory MediaAsset.fromJson(Map<String, dynamic> json) {
    return MediaAsset(
      id: Json.str(json, 'id'),
      storageKey: Json.str(json, 'storage_key'),
      folder: Json.str(json, 'folder', fallback: MediaFolders.images),
      mimeType: Json.str(json, 'mime_type', fallback: 'application/octet-stream'),
      sizeBytes: Json.intVal(json, 'size_bytes'),
      status: Json.str(json, 'status', fallback: ContentStatus.pendingReview),
      url: Json.str(json, 'url'),
      title: Json.strOrNull(json, 'title'),
      description: Json.strOrNull(json, 'description'),
      altText: Json.strOrNull(json, 'alt_text'),
      credit: Json.strOrNull(json, 'credit'),
      capturedAt: Json.strOrNull(json, 'captured_at'),
      location: Json.strOrNull(json, 'location'),
      originalFilename: Json.strOrNull(json, 'original_filename'),
      verificationStatus: Json.strOrNull(json, 'verification_status'),
      createdAt: Json.strOrNull(json, 'created_at'),
    );
  }

  final String id;
  final String storageKey;
  final String folder;
  final String mimeType;
  final int sizeBytes;
  final String status;
  final String url;
  final String? title;
  final String? description;
  final String? altText;
  final String? credit;
  final String? capturedAt;
  final String? location;
  final String? originalFilename;
  final String? verificationStatus;
  final String? createdAt;

  bool get isImage => mimeType.startsWith('image/');
  bool get isAudio => mimeType.startsWith('audio/');
  bool get isDocument => !isImage && !isAudio;

  String get displayTitle => title ?? originalFilename ?? 'Untitled file';

  /// Alt text for screen readers.
  ///
  /// Falls back to a description of what the file is rather than repeating the
  /// filename, which tells a blind visitor nothing.
  String get accessibleLabel {
    if (altText != null && altText!.isNotEmpty) return altText!;
    if (title != null && title!.isNotEmpty) return title!;
    return 'An item from the Ekoli-Yeden archive that has not yet been described.';
  }

  /// True where the archive still needs somebody to say what this shows.
  bool get needsCataloguing =>
      (title == null || title!.isEmpty) &&
      (description == null || description!.isEmpty) &&
      capturedAt == null;
}
