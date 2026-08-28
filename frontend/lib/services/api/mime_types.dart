import 'package:http_parser/http_parser.dart';

/// WHAT KIND OF FILE THIS IS.
///
/// The browser's file picker does not reliably tell us — on web it frequently
/// reports nothing at all — and `MultipartFile.fromBytes` defaults to
/// `application/octet-stream`, which the API refuses in every folder. So a
/// perfectly ordinary photograph would arrive claiming to be an unknown binary
/// and be turned away.
///
/// The filename is the one thing we always have. It is a claim rather than a
/// fact, which is why the server re-derives the type and checks the file's
/// actual leading bytes before storing anything — nothing on this side is
/// trusted.
///
/// Kept in step with `ALLOWED_MIME_TYPES` in `worker/src/utils/files.ts`. A
/// type missing here is a file the API will refuse, so the two lists have to
/// agree.
const Map<String, String> _byExtension = <String, String>{
  // Images
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'jpe': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'gif': 'image/gif',
  'avif': 'image/avif',

  // Audio — the recordings that matter most to the language archive.
  'mp3': 'audio/mpeg',
  'm4a': 'audio/mp4',
  'aac': 'audio/aac',
  'ogg': 'audio/ogg',
  'oga': 'audio/ogg',
  'wav': 'audio/wav',
  'weba': 'audio/webm',

  // Video — short clips that belong to an album, uploaded like a photograph.
  // Anything long goes to YouTube and is catalogued by its link instead.
  //
  // .mov is here because iPhones produce it, and .3gp because cheaper Android
  // handsets still do. Those are the phones most likely to be at a village
  // event, so leaving either out would refuse much of what the community
  // actually records.
  //
  // .webm is both an audio and a video container. Video is far more often what
  // somebody has, and the server checks the file's own bytes either way.
  'mp4': 'video/mp4',
  'm4v': 'video/mp4',
  'mov': 'video/quicktime',
  'qt': 'video/quicktime',
  '3gp': 'video/3gpp',
  '3gpp': 'video/3gpp',
  'webm': 'video/webm',

  // Documents
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'txt': 'text/plain',
};

/// The MIME type for a filename, as a `MediaType` ready for a multipart part.
///
/// Falls back to `application/octet-stream` for anything unrecognised — which
/// the API will refuse, and should: a file the archive cannot identify is a
/// file it has no business storing.
MediaType mimeTypeFor(String filename) {
  return MediaType.parse(mimeStringFor(filename));
}

/// The MIME type for a filename, as a string.
String mimeStringFor(String filename) {
  final int dot = filename.lastIndexOf('.');
  if (dot < 0 || dot == filename.length - 1) return 'application/octet-stream';

  final String extension = filename.substring(dot + 1).toLowerCase();
  return _byExtension[extension] ?? 'application/octet-stream';
}

/// Whether the archive will accept a file with this name at all.
///
/// Used to tell somebody before they wait for an upload that is going to be
/// refused — the server decides, but there is no reason to make them find out
/// the slow way.
bool isAcceptableFilename(String filename) =>
    mimeStringFor(filename) != 'application/octet-stream';

/// What kind of thing a stored file is, from its MIME type.
///
/// The archive shows a photograph and a video differently — one is an image
/// element, the other needs a player and a poster frame — so the distinction
/// has to survive the trip back from the API. `media_kind.dart` is where that
/// decision is made for records already stored; this is the same question
/// asked about a file that has not been uploaded yet.
bool isVideoFilename(String filename) => mimeStringFor(filename).startsWith('video/');

/// Extensions the archive accepts, grouped so a file picker can be scoped to
/// what the chosen folder will actually take.
///
/// Kept beside the map above deliberately: a type added there and forgotten
/// here is a file the API would accept but nobody can select.
class UploadExtensions {
  const UploadExtensions._();

  static const List<String> images = <String>['jpg', 'jpeg', 'png', 'webp', 'gif', 'avif'];
  static const List<String> video = <String>['mp4', 'm4v', 'mov', '3gp', 'webm'];
  static const List<String> audio = <String>['mp3', 'm4a', 'aac', 'ogg', 'wav', 'weba'];
  static const List<String> documents = <String>['pdf', 'doc', 'docx', 'txt'];

  /// Photographs and clips together — what a gallery or festival album takes.
  static const List<String> gallery = <String>[...images, ...video];
}
