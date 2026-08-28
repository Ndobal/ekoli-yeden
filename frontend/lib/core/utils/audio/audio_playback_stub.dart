/// Audio playback where there is no browser.
///
/// The archive is a web application, so this exists for the test runner and
/// for any future non-web target. It reports that it cannot play rather than
/// pretending to, which lets the interface offer the recording as a link
/// instead of showing a play button that silently does nothing.
class ArchiveAudio {
  const ArchiveAudio._();

  /// Whether a recording can be played in place.
  static bool get isSupported => false;

  /// Starts playing, replacing whatever was playing before.
  ///
  /// Returns false where playback is unavailable, so the caller can fall back
  /// to offering the file rather than leaving a dead control on the page.
  static bool play(String url) => false;

  static void stop() {}

  /// The URL currently playing, or null.
  static String? get playing => null;
}
