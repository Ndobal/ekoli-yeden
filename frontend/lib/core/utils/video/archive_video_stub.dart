import 'package:flutter/widgets.dart';

/// Video playback where there is no browser.
///
/// The archive is a web application, so this exists for the test runner and
/// any future non-web target. It reports that it cannot play rather than
/// pretending to, which lets the interface offer the file as a link instead of
/// leaving a play button that silently does nothing.
class ArchiveVideo {
  const ArchiveVideo._();

  /// Whether a video can be played in place.
  static bool get isSupported => false;

  /// A player for [url]. Never called where [isSupported] is false; returns an
  /// empty box so the class still satisfies its interface.
  static Widget player(String url, {bool controls = true}) => const SizedBox.shrink();
}
