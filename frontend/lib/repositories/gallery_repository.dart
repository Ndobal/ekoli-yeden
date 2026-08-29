import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../models/content_status.dart';
import '../models/gallery.dart';
import '../services/api/api_client.dart';
import '../services/api/api_response.dart';

/// GALLERIES AND PHOTOGRAPHS.
///
/// Two views of the same records: one album, or every photograph at once. A
/// picture filed under Leboku 2026 appears in both, because a festival album is
/// an ordinary gallery — one upload, one record, and nothing copied anywhere.
class GalleryRepository {
  const GalleryRepository(this._api);

  final ApiClient _api;

  /// One album with its photographs and their labels.
  Future<Gallery> album(String identifier) async {
    final Map<String, dynamic> data = await _api.get(
      '/api/galleries/$identifier',
      authenticated: false,
    );
    return Gallery.fromJson(data);
  }

  /// Every published album with a count of what it holds.
  ///
  /// Drives the filter bar above the photographs. A count is most of what makes
  /// a filter worth pressing — "Leboku 2026 (48)" tells a visitor where the
  /// pictures are; a bare album name does not.
  Future<List<AlbumSummary>> albums() async {
    final Map<String, dynamic> data = await _api.get(
      '/api/galleries/albums/index',
      authenticated: false,
    );
    return Json.objectList(data, 'items').map(AlbumSummary.fromJson).toList(growable: false);
  }

  /// Every published photograph in the archive, newest first.
  ///
  /// `festivalId` narrows it to one festival's years, `galleryId` to one album.
  Future<PaginatedResult<Photograph>> photographs({
    int page = 1,
    int perPage = AppConfig.defaultPageSize,
    String? galleryId,
    String? festivalId,
  }) {
    return _api.list<Photograph>(
      '/api/photographs',
      Photograph.fromJson,
      authenticated: false,
      query: <String, dynamic>{
        'page': page,
        'perPage': perPage,
        'gallery_id': ?galleryId,
        'festival_id': ?festivalId,
      },
    );
  }

  // --- The Media Team's side ------------------------------------------------

  /// Every festival with its album and a photograph count.
  ///
  /// Creates any album that is missing as a side effect, which is how an
  /// edition added before festivals had galleries repairs itself by being
  /// looked at.
  /// Every festival with its years beneath it.
  Future<List<FestivalWithYears>> festivalAlbums() async {
    final Map<String, dynamic> data = await _api.get('/api/admin/festival-galleries');
    return Json.objectList(data, 'items')
        .map(FestivalWithYears.fromJson)
        .toList(growable: false);
  }

  /// Records a new festival — Odagum, Ekpirikum, whatever the community
  /// celebrates. The parent only: a festival just recorded has no year yet.
  Future<String> createFestival({
    required String name,
    String? shortDescription,
    String? description,
    String? usuallyCelebrated,
  }) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/admin/festivals',
      body: <String, dynamic>{
        'name': name,
        'slug': name.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-'),
        'short_description': ?shortDescription,
        'description': ?description,
        'usually_celebrated': ?usuallyCelebrated,
        'status': 'published',
      },
    );
    return Json.str(data, 'id');
  }

  /// Adds a year to a festival: Leboku 2025, Leboku 2024.
  ///
  /// The album is an ordinary gallery, which is what puts it in the festival's
  /// archive and the Gallery's album list at once without a second record.
  Future<String> addFestivalYear({
    required String festivalId,
    required int year,
    String? title,
    String? description,
    String? location,
  }) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/admin/festivals/$festivalId/years',
      body: <String, dynamic>{
        'year': year,
        'title': ?title,
        'description': ?description,
        'location': ?location,
      },
    );
    return Json.str(data, 'message', fallback: 'Year added.');
  }

  /// An album's contents in every status, for the person cataloguing it.
  Future<({Gallery gallery, List<Photograph> items, Map<String, int> counts})> manage(
    String galleryId,
  ) async {
    final Map<String, dynamic> data = await _api.get('/api/admin/galleries/$galleryId/items');
    final Map<String, dynamic> counts =
        (data['counts'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    return (
      gallery: Gallery.fromJson((data['gallery'] as Map<String, dynamic>?) ?? <String, dynamic>{}),
      items: Json.objectList(data, 'items').map(Photograph.fromJson).toList(growable: false),
      counts: counts.map(
        (String key, dynamic value) =>
            MapEntry<String, int>(key, value is num ? value.toInt() : 0),
      ),
    );
  }

  /// Uploads a photograph straight into an album.
  ///
  /// One request rather than two: the Media Team's real task is forty pictures
  /// from Saturday, all belonging to the same year, and a two-step flow is how
  /// albums end up half-filled.
  Future<String> uploadIntoAlbum({
    required String galleryId,
    required Uint8List bytes,
    required String filename,
    String folder = 'leboku',
    String? caption,
    String? credit,
  }) async {
    final Map<String, dynamic> data = await _api.upload(
      path: '/api/admin/galleries/$galleryId/items',
      bytes: bytes,
      filename: filename,
      folder: folder,
      fields: <String, String>{'title': ?caption, 'description': ?caption, 'credit': ?credit},
    );
    return Json.str(data, 'itemId');
  }

  /// Cataloguing: who is in it, where, when, who took it.
  Future<void> label(
    String itemId, {
    String? caption,
    String? peoplePictured,
    String? photographer,
    String? location,
    String? takenAt,
    String? status,
  }) {
    return _api.patch(
      '/api/admin/gallery-items/$itemId',
      body: <String, dynamic>{
        'caption': ?caption,
        'people_pictured': ?peoplePictured,
        'photographer': ?photographer,
        'location': ?location,
        'taken_at': ?takenAt,
        'status': ?status,
      },
    );
  }

  /// Files a photograph already in the media library into an album.
  Future<void> addExisting({
    required String galleryId,
    required String mediaAssetId,
    String? caption,
    String? contributedBy,
  }) {
    return _api.post(
      '/api/admin/galleries/$galleryId/items/existing',
      body: <String, dynamic>{
        'media_asset_id': mediaAssetId,
        'caption': ?caption,
        'contributed_by': ?contributedBy,
      },
    );
  }

  /// Takes a photograph out of an album. The file itself is kept — removing a
  /// picture from an album and destroying it should never be the same click.
  Future<void> removeFromAlbum(String itemId) {
    return _api.delete('/api/admin/gallery-items/$itemId');
  }
}
