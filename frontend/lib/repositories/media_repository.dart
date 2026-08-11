import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../models/media_asset.dart';
import '../services/api/api_client.dart';
import '../services/api/api_response.dart';

/// The R2 media library.
///
/// Uploads go through the Worker, which validates the folder, the MIME type
/// and the size before anything reaches the bucket. The client never holds an
/// R2 credential or a pre-signed bucket URL.
class MediaRepository {
  const MediaRepository(this._api);

  final ApiClient _api;

  /// The folders, accepted types and size limits, so a form can validate
  /// before uploading. The Worker re-checks all of it.
  Future<MediaConfig> config() async {
    final Map<String, dynamic> data = await _api.get('/api/media/config', authenticated: false);
    return MediaConfig.fromJson(data);
  }

  Future<PaginatedResult<MediaAsset>> list({
    int page = 1,
    int perPage = AppConfig.defaultPageSize,
    String? folder,
    String? status,
    String? search,
  }) {
    return _api.list<MediaAsset>(
      '/api/admin/media',
      MediaAsset.fromJson,
      query: <String, dynamic>{
        'page': page,
        'perPage': perPage,
        'folder': ?folder,
        'status': ?status,
        if (search != null && search.isNotEmpty) 'q': search,
      },
    );
  }

  /// Uploads on behalf of an editor. Lands as `approved` in the library.
  Future<MediaAsset> upload({
    required Uint8List bytes,
    required String filename,
    required String folder,
    String? title,
    String? description,
    String? altText,
    String? credit,
  }) async {
    final Map<String, dynamic> data = await _api.upload(
      path: '/api/admin/media',
      bytes: bytes,
      filename: filename,
      folder: folder,
      fields: <String, String>{
        'title': ?title,
        'description': ?description,
        'alt_text': ?altText,
        'credit': ?credit,
      },
    );
    return MediaAsset.fromJson(data);
  }

  /// Uploads on behalf of a visitor contributing material.
  ///
  /// Lands as `pending_review` and is invisible to the public until a moderator
  /// approves it. No account is required — an elder's grandchild with a
  /// photograph on their phone should not have to register first.
  Future<String> contributeUpload({
    required Uint8List bytes,
    required String filename,
    required String folder,
  }) async {
    final Map<String, dynamic> data = await _api.upload(
      path: '/api/contribute/media',
      bytes: bytes,
      filename: filename,
      folder: folder,
      authenticated: false,
    );
    return data['id'] as String;
  }

  /// Records what a photograph shows — the step that makes it findable.
  Future<MediaAsset> catalogue(String id, Map<String, dynamic> values) async {
    final Map<String, dynamic> data = await _api.patch('/api/admin/media/$id', body: values);
    return MediaAsset.fromJson(data);
  }

  Future<void> delete(String id) async => _api.delete('/api/admin/media/$id');
}

/// Upload rules, as reported by the Worker.
class MediaConfig {
  const MediaConfig({required this.folders, required this.globalMaxBytes});

  factory MediaConfig.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = (json['folders'] as List<dynamic>?) ?? const <dynamic>[];
    return MediaConfig(
      folders: raw.whereType<Map<String, dynamic>>().map(FolderRule.fromJson).toList(growable: false),
      globalMaxBytes: (json['globalMaxBytes'] as num?)?.toInt() ?? 25 * 1024 * 1024,
    );
  }

  final List<FolderRule> folders;
  final int globalMaxBytes;

  FolderRule? rulesFor(String folder) {
    for (final FolderRule rule in folders) {
      if (rule.folder == folder) return rule;
    }
    return null;
  }
}

class FolderRule {
  const FolderRule({
    required this.folder,
    required this.acceptedMimeTypes,
    required this.maxBytes,
  });

  factory FolderRule.fromJson(Map<String, dynamic> json) {
    final List<dynamic> types = (json['acceptedMimeTypes'] as List<dynamic>?) ?? const <dynamic>[];
    return FolderRule(
      folder: json['folder'] as String? ?? '',
      acceptedMimeTypes: types.map((dynamic item) => item.toString()).toList(growable: false),
      maxBytes: (json['maxBytes'] as num?)?.toInt() ?? 0,
    );
  }

  final String folder;
  final List<String> acceptedMimeTypes;
  final int maxBytes;

  bool accepts(String mimeType) => acceptedMimeTypes.contains(mimeType);
}
