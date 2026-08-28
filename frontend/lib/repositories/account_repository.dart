import 'package:flutter/foundation.dart';

import '../models/content_status.dart';
import '../services/api/api_client.dart';

/// Account recovery, and contributor file uploads.
///
/// Both are public-facing: neither requires an account, because the people who
/// most need them — a volunteer locked out, an elder's relative with a
/// photograph — are exactly the people least likely to have one.
class AccountRepository {
  const AccountRepository(this._api);

  final ApiClient _api;

  /// Requests a reset link.
  ///
  /// The reply is the same whether or not the address is registered, so nothing
  /// here can be used to discover who has an account.
  Future<String> forgotPassword(String email) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/auth/forgot-password',
      authenticated: false,
      body: <String, dynamic>{'email': email},
    );
    return Json.str(
      data,
      'message',
      fallback: 'If an account exists for that address, a reset link has been sent.',
    );
  }

  /// Checks a reset link before showing the form, so an expired link is caught
  /// before somebody types a password twice.
  Future<({bool valid, String message})> checkResetToken(String token) async {
    final Map<String, dynamic> data = await _api.get(
      '/api/auth/reset-password/${Uri.encodeComponent(token)}',
      authenticated: false,
    );
    return (
      valid: Json.boolVal(data, 'valid'),
      message: Json.str(data, 'message', fallback: 'That link could not be checked.'),
    );
  }

  Future<String> resetPassword({required String token, required String password}) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/auth/reset-password',
      authenticated: false,
      body: <String, dynamic>{'token': token, 'password': password},
    );
    return Json.str(data, 'message', fallback: 'Your password has been changed.');
  }

  /// Changes the signed-in user's own password.
  Future<void> changeOwnPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.post(
      '/api/admin/account/password',
      body: <String, dynamic>{
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  /// Generates a reset link for another user.
  ///
  /// The link comes back so an administrator can pass it on directly. That is
  /// the whole delivery mechanism until an email or WhatsApp service is
  /// configured — and it is better than an administrator choosing somebody's
  /// password, because no administrator ever learns it.
  Future<ResetLink> createResetLink(String userId, {String? channel}) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/admin/users/$userId/reset-link',
      body: <String, dynamic>{'channel': ?channel},
    );
    return ResetLink.fromJson(data);
  }

  // --- Contributor uploads --------------------------------------------------

  /// What may be uploaded, the size limits, and the permissions offered.
  Future<ContributionUploadConfig> uploadConfig() async {
    final Map<String, dynamic> data = await _api.get(
      '/api/contribute/upload-config',
      authenticated: false,
    );
    return ContributionUploadConfig.fromJson(data);
  }

  /// Uploads a contributed file into the submissions bucket.
  ///
  /// It is invisible to the public until the Preservation Team approves it, at
  /// which point it is copied into the archive with the contributor credited.
  Future<String> uploadContribution({
    required Uint8List bytes,
    required String filename,
    required String folder,
    String? caption,
    String? peoplePictured,
    String? takenAt,
    String? location,
    String? contributorName,
    String? contributorEmail,
    String? contributorPhone,
    String usagePermission = 'public_display_with_credit',
    String? submissionId,
  }) async {
    final Map<String, dynamic> data = await _api.upload(
      path: '/api/contribute/upload',
      bytes: bytes,
      filename: filename,
      folder: folder,
      // MUST carry the session. Contributing requires a membership, and this
      // request used to be sent with no Authorization header at all — so every
      // upload 401d the moment that rule arrived, including an administrator
      // uploading from their own workspace.
      authenticated: true,
      fields: <String, String>{
        'usage_permission': usagePermission,
        'caption': ?caption,
        'people_pictured': ?peoplePictured,
        'taken_at': ?takenAt,
        'location': ?location,
        'contributor_name': ?contributorName,
        'contributor_email': ?contributorEmail,
        'contributor_phone': ?contributorPhone,
        'submission_id': ?submissionId,
      },
    );
    return Json.str(data, 'id');
  }

  // --- Review ---------------------------------------------------------------

  Future<Map<String, dynamic>> contributionQueue({String status = 'pending_review'}) {
    return _api.get(
      '/api/admin/contributions',
      query: <String, dynamic>{'status': status, 'perPage': 60},
    );
  }

  /// Approves a contributed file, and optionally finishes the job.
  ///
  /// Approving alone only accessions the file: it becomes a media asset that
  /// no visitor can see, in no album. [galleryId] files it somewhere findable
  /// and [publish] puts it on the site. Both are the reviewer's choice, but
  /// leaving both off is how seven contributions to this archive ended up
  /// approved and invisible.
  ///
  /// Returns the API's account of what actually happened, which the screen
  /// shows verbatim rather than assuming success means "it is live".
  Future<String> approveContribution(
    String id, {
    String? notes,
    String? galleryId,
    bool publish = false,
  }) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/admin/contributions/$id/approve',
      body: <String, dynamic>{
        'review_notes': ?notes,
        'gallery_id': ?galleryId,
        'publish': publish,
      },
    );
    return Json.str(data, 'message', fallback: 'Approved.');
  }

  Future<void> rejectContribution(String id, {String? notes}) async {
    await _api.post(
      '/api/admin/contributions/$id/reject',
      body: <String, dynamic>{'review_notes': ?notes},
    );
  }
}

/// A generated reset link, and what happened when we tried to send it.
class ResetLink {
  const ResetLink({
    required this.resetUrl,
    required this.expiresAt,
    required this.delivered,
    required this.channel,
    required this.guidance,
    this.destination,
    this.reason,
  });

  factory ResetLink.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> delivery =
        (json['delivery'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return ResetLink(
      resetUrl: Json.str(json, 'resetUrl'),
      expiresAt: Json.str(json, 'expiresAt'),
      delivered: Json.boolVal(delivery, 'delivered'),
      channel: Json.str(delivery, 'channel', fallback: 'manual'),
      destination: Json.strOrNull(delivery, 'destination'),
      reason: Json.strOrNull(delivery, 'reason'),
      guidance: Json.str(json, 'guidance'),
    );
  }

  final String resetUrl;
  final String expiresAt;
  final bool delivered;
  final String channel;
  final String? destination;
  final String? reason;
  final String guidance;
}

/// Upload rules for contributors, as reported by the API.
class ContributionUploadConfig {
  const ContributionUploadConfig({
    required this.folders,
    required this.globalMaxBytes,
    required this.guidance,
    required this.usagePermissions,
  });

  factory ContributionUploadConfig.fromJson(Map<String, dynamic> json) {
    return ContributionUploadConfig(
      folders: Json.objectList(json, 'folders')
          .map(
            (Map<String, dynamic> f) => (
              folder: Json.str(f, 'folder'),
              maxBytes: Json.intVal(f, 'maxBytes'),
              acceptedMimeTypes: Json.stringList(f, 'acceptedMimeTypes'),
            ),
          )
          .toList(growable: false),
      globalMaxBytes: Json.intVal(json, 'globalMaxBytes', fallback: 26214400),
      guidance: Json.stringList(json, 'guidance'),
      usagePermissions: Json.objectList(json, 'usagePermissions')
          .map(
            (Map<String, dynamic> p) => (
              value: Json.str(p, 'value'),
              label: Json.str(p, 'label'),
            ),
          )
          .toList(growable: false),
    );
  }

  final List<({String folder, int maxBytes, List<String> acceptedMimeTypes})> folders;
  final int globalMaxBytes;
  final List<String> guidance;
  final List<({String value, String label})> usagePermissions;
}
