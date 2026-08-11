import '../core/constants/app_constants.dart';

/// Helpers for reading the editorial workflow field off any record.
///
/// The server decides what a visitor may see; these helpers only decide how the
/// interface labels what it was given.
extension ContentStatusX on String {
  bool get isPublished => this == ContentStatus.published;
  bool get isAwaitingReview => this == ContentStatus.pendingReview;
  bool get isDraft => this == ContentStatus.draft;
  bool get isRejected => this == ContentStatus.rejected;

  String get statusLabel => ContentStatus.label(this);
}

/// Safe readers for the loosely-typed JSON the API returns.
///
/// The archive is full of records that are deliberately incomplete — a
/// photograph with no date, a word with no confirmed meaning — so every reader
/// here tolerates a missing or null field instead of throwing.
class Json {
  const Json._();

  static String str(Map<String, dynamic> json, String key, {String fallback = ''}) {
    final dynamic value = json[key];
    if (value == null) return fallback;
    final String text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static String? strOrNull(Map<String, dynamic> json, String key) {
    final dynamic value = json[key];
    if (value == null) return null;
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int intVal(Map<String, dynamic> json, String key, {int fallback = 0}) {
    final dynamic value = json[key];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static int? intOrNull(Map<String, dynamic> json, String key) {
    final dynamic value = json[key];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? doubleOrNull(Map<String, dynamic> json, String key) {
    final dynamic value = json[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// SQLite has no boolean type, so flags arrive as 0/1 integers.
  static bool boolVal(Map<String, dynamic> json, String key, {bool fallback = false}) {
    final dynamic value = json[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value == 'true' || value == '1';
    return fallback;
  }

  static List<Map<String, dynamic>> objectList(Map<String, dynamic> json, String key) {
    final dynamic value = json[key];
    if (value is! List) return const <Map<String, dynamic>>[];
    return value.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  static List<String> stringList(Map<String, dynamic> json, String key) {
    final dynamic value = json[key];
    if (value is! List) return const <String>[];
    return value.map((dynamic item) => item.toString()).toList(growable: false);
  }
}
