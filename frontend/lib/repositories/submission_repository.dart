import '../core/config/app_config.dart';
import '../models/content_record.dart';
import '../services/api/api_client.dart';
import '../services/api/api_response.dart';

/// CONTRIBUTE TO EKOLI YEDEN.
///
/// A submission is a proposal, never content. It enters `pending_review` and
/// only a moderator can move it — there is no client path, and no server path,
/// that publishes a contribution automatically.
class SubmissionRepository {
  const SubmissionRepository(this._api);

  final ApiClient _api;

  /// What may be submitted, and what happens after it is.
  Future<ContributionGuide> guide() async {
    final Map<String, dynamic> data = await _api.get('/api/contribute/types', authenticated: false);
    return ContributionGuide.fromJson(data);
  }

  /// Submits material. Open to anyone; no account required.
  Future<SubmissionReceipt> submit({
    required String submissionType,
    required String title,
    required bool consentGiven,
    String? description,
    String? submitterName,
    String? submitterEmail,
    String? submitterPhone,
    String? submitterRelationship,
    List<String> mediaAssetIds = const <String>[],
    String? youtubeUrl,
  }) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/contribute',
      authenticated: false,
      body: <String, dynamic>{
        'submission_type': submissionType,
        'title': title,
        'consent_given': consentGiven,
        'description': ?description,
        'submitter_name': ?submitterName,
        'submitter_email': ?submitterEmail,
        'submitter_phone': ?submitterPhone,
        'submitter_relationship': ?submitterRelationship,
        'youtube_url': ?youtubeUrl,
        if (mediaAssetIds.isNotEmpty) 'media_asset_ids': mediaAssetIds,
      },
    );
    return SubmissionReceipt.fromJson(data);
  }

  /// Lets a contributor follow up using the code they were given.
  Future<Map<String, dynamic>> checkStatus(String referenceCode) {
    return _api.get('/api/contribute/status/$referenceCode', authenticated: false);
  }

  // --- Moderation -----------------------------------------------------------

  Future<PaginatedResult<ContentRecord>> queue({
    int page = 1,
    int perPage = AppConfig.defaultPageSize,
    String? status,
    String? submissionType,
    String? search,
  }) {
    return _api.list<ContentRecord>(
      '/api/admin/submissions',
      ContentRecord.fromJson,
      query: <String, dynamic>{
        'page': page,
        'perPage': perPage,
        'status': ?status,
        'submission_type': ?submissionType,
        if (search != null && search.isNotEmpty) 'q': search,
      },
    );
  }

  Future<ContentRecord> find(String id) async {
    final Map<String, dynamic> data = await _api.get('/api/admin/submissions/$id');
    return ContentRecord.fromJson(data);
  }

  Future<ContentRecord> review(String id, {required String status, String? notes}) async {
    final Map<String, dynamic> data = await _api.patch(
      '/api/admin/submissions/$id/review',
      body: <String, dynamic>{'status': status, 'review_notes': ?notes},
    );
    return ContentRecord.fromJson(data);
  }
}

/// The receipt a contributor keeps.
class SubmissionReceipt {
  const SubmissionReceipt({
    required this.id,
    required this.referenceCode,
    required this.status,
    required this.message,
  });

  factory SubmissionReceipt.fromJson(Map<String, dynamic> json) {
    return SubmissionReceipt(
      id: json['id'] as String? ?? '',
      referenceCode: json['referenceCode'] as String? ?? '',
      status: json['status'] as String? ?? 'pending_review',
      message: json['message'] as String? ?? 'Your contribution has been received.',
    );
  }

  final String id;
  final String referenceCode;
  final String status;
  final String message;
}

/// What may be contributed and what happens next.
class ContributionGuide {
  const ContributionGuide({
    required this.types,
    required this.workflow,
    required this.note,
  });

  factory ContributionGuide.fromJson(Map<String, dynamic> json) {
    final List<dynamic> types = (json['types'] as List<dynamic>?) ?? const <dynamic>[];
    final List<dynamic> workflow = (json['workflow'] as List<dynamic>?) ?? const <dynamic>[];
    return ContributionGuide(
      types: types
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> item) => (
                slug: item['slug'] as String? ?? '',
                label: item['label'] as String? ?? '',
              ))
          .toList(growable: false),
      workflow: workflow.map((dynamic item) => item.toString()).toList(growable: false),
      note: json['note'] as String? ?? '',
    );
  }

  final List<({String slug, String label})> types;
  final List<String> workflow;
  final String note;
}
