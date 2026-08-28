import 'package:flutter/widgets.dart';

/// A YouTube player where there is no browser.
///
/// The archive is a web application, so this exists for the test runner and any
/// future non-web target. It reports that it cannot embed rather than
/// pretending to, which lets the interface show the still and an honest "Watch
/// on YouTube" link instead of an empty rectangle.
class YoutubeEmbed {
  const YoutubeEmbed._();

  static bool get isSupported => false;

  /// Never called where [isSupported] is false; returns an empty box so the
  /// class still satisfies its interface.
  static Widget player(String videoId, {String? title}) => const SizedBox.shrink();
}
