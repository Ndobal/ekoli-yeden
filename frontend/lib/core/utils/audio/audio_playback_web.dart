import 'package:web/web.dart' as web;

/// Audio playback in the browser.
///
/// Preserving the sound of the language is the point of the dictionary. A link
/// to an audio file that a visitor has to open in a second tab is not the same
/// as hearing an elder say the word, so the recording plays where it sits.
///
/// One element is reused for every recording on the page rather than one per
/// chip. A dictionary page can carry a hundred recordings, and a hundred audio
/// elements is a hundred things for the browser to hold; reusing one also
/// means starting a second recording stops the first, which is what somebody
/// comparing two pronunciations actually wants.
class ArchiveAudio {
  const ArchiveAudio._();

  static web.HTMLAudioElement? _element;
  static String? _playing;

  static bool get isSupported => true;

  static bool play(String url) {
    if (url.isEmpty) return false;

    final web.HTMLAudioElement element =
        _element ??= web.HTMLAudioElement()..preload = 'none';

    // Reassigning `src` to the same file restarts it, which is the useful
    // behaviour when somebody taps a word twice to hear it again.
    element.src = url;
    _playing = url;
    element.currentTime = 0;

    // `play()` returns a promise that rejects when the browser blocks
    // autoplay or cannot decode the file. Ignored deliberately: the failure is
    // the browser's to report, and there is nothing useful the archive can do
    // about it beyond leaving the recording available as a file.
    element.play();
    return true;
  }

  static void stop() {
    _element?.pause();
    _playing = null;
  }

  static String? get playing => _playing;
}
