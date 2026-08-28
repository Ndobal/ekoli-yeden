import 'package:intl/intl.dart';

/// Display formatting.
///
/// The archive holds a lot of partial information — a photograph with no date,
/// a history entry with a period but no year. Every formatter here returns a
/// caller-supplied fallback rather than inventing a value or showing "null".
class Formatters {
  const Formatters._();

  static final DateFormat _longDate = DateFormat('d MMMM yyyy');
  static final DateFormat _shortDate = DateFormat('d MMM yyyy');
  static final DateFormat _dateTime = DateFormat('d MMM yyyy, HH:mm');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy');
  static final DateFormat _monthAbbrev = DateFormat('MMM');

  static DateTime? tryParse(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static String date(String? value, {String fallback = '—'}) {
    final DateTime? parsed = tryParse(value);
    return parsed == null ? fallback : _longDate.format(parsed.toLocal());
  }

  static String shortDate(String? value, {String fallback = '—'}) {
    final DateTime? parsed = tryParse(value);
    return parsed == null ? fallback : _shortDate.format(parsed.toLocal());
  }

  static String dateTime(String? value, {String fallback = '—'}) {
    final DateTime? parsed = tryParse(value);
    return parsed == null ? fallback : _dateTime.format(parsed.toLocal());
  }

  /// Just the month, abbreviated — for a date drawn as a calendar block.
  static String monthAbbreviation(DateTime date) => _monthAbbrev.format(date).toUpperCase();

  static String monthYear(String? value, {String fallback = '—'}) {
    final DateTime? parsed = tryParse(value);
    return parsed == null ? fallback : _monthYear.format(parsed.toLocal());
  }

  /// A date range, collapsing to a single date when start and end match.
  static String dateRange(String? start, String? end, {String fallback = 'Dates to be announced'}) {
    final DateTime? from = tryParse(start);
    final DateTime? to = tryParse(end);
    if (from == null && to == null) return fallback;
    if (from != null && to == null) return _longDate.format(from.toLocal());
    if (from == null && to != null) return 'Until ${_longDate.format(to.toLocal())}';
    if (from!.year == to!.year && from.month == to.month && from.day == to.day) {
      return _longDate.format(from.toLocal());
    }
    return '${_shortDate.format(from.toLocal())} – ${_shortDate.format(to.toLocal())}';
  }

  /// "3 days ago", for the admin activity feed.
  static String relative(String? value, {String fallback = '—'}) {
    final DateTime? parsed = tryParse(value);
    if (parsed == null) return fallback;

    final Duration difference = DateTime.now().difference(parsed.toLocal());
    if (difference.inSeconds < 60) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} h ago';
    if (difference.inDays < 30) return '${difference.inDays} d ago';
    return _shortDate.format(parsed.toLocal());
  }

  static final NumberFormat _decimal = NumberFormat.decimalPattern();

  static String number(num? value, {String fallback = '—'}) {
    return value == null ? fallback : _decimal.format(value);
  }

  static String currency(num? value, String currencyCode, {String fallback = '—'}) {
    if (value == null) return fallback;
    return NumberFormat.currency(
      name: currencyCode,
      symbol: currencyCode == 'NGN' ? '₦' : '$currencyCode ',
      decimalDigits: 0,
    ).format(value);
  }

  /// Human file size, used by the media library.
  static String fileSize(int? bytes, {String fallback = '—'}) {
    if (bytes == null || bytes <= 0) return fallback;
    const List<String> units = <String>['B', 'KB', 'MB', 'GB'];
    double size = bytes.toDouble();
    int unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit += 1;
    }
    // One decimal only where it adds information: "1.4 MB" is useful, "2.0 KB"
    // is just noise.
    final String rendered = size.toStringAsFixed(size >= 10 || unit == 0 ? 0 : 1);
    return '${rendered.endsWith('.0') ? rendered.substring(0, rendered.length - 2) : rendered} '
        '${units[unit]}';
  }

  /// Video duration as `h:mm:ss` or `m:ss`.
  static String duration(int? seconds, {String fallback = ''}) {
    if (seconds == null || seconds <= 0) return fallback;
    final int hours = seconds ~/ 3600;
    final int minutes = (seconds % 3600) ~/ 60;
    final int remaining = seconds % 60;
    final String paddedSeconds = remaining.toString().padLeft(2, '0');
    if (hours > 0) return '$hours:${minutes.toString().padLeft(2, '0')}:$paddedSeconds';
    return '$minutes:$paddedSeconds';
  }

  /// Shortens body text for a card, cutting at a word boundary.
  static String excerpt(String? value, {int maxLength = 160, String fallback = ''}) {
    if (value == null || value.trim().isEmpty) return fallback;
    final String clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= maxLength) return clean;
    final int cut = clean.lastIndexOf(' ', maxLength);
    return '${clean.substring(0, cut > 0 ? cut : maxLength)}…';
  }
}
