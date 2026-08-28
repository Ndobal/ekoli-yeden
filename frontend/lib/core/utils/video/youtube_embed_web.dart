import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// A YOUTUBE VIDEO, PLAYING WHERE IT SITS.
///
/// ---------------------------------------------------------------------------
/// WHY EMBED RATHER THAN LINK OUT
/// ---------------------------------------------------------------------------
///
/// A news story about a community meeting frequently is the recording of that
/// meeting. Sending somebody to a second tab to watch it is how nobody watches
/// it — and the archive's whole argument is that the story and its record
/// belong in one place that will still be there in twenty years.
///
/// The video itself stays on YouTube. This archive holds the catalogue record,
/// the photographs and the words; storage cost stays proportional to what only
/// exists here, and a video the community already published does not have to be
/// uploaded a second time to be organised.
///
/// ---------------------------------------------------------------------------
/// TWO THINGS THAT ARE NOT INCIDENTAL
/// ---------------------------------------------------------------------------
///
/// **`youtube-nocookie.com`.** The privacy policy tells visitors that nothing
/// here tracks them, and the one exception it names is a page carrying a video.
/// The no-cookie host is what keeps that exception as small as it can be, and
/// it is the reason this file does not use the ordinary embed host.
///
/// **Nothing loads until it is asked for.** The iframe is only created after a
/// visitor presses play — see `NewsVideo`, which shows the still until then. A
/// story with three videos would otherwise open three connections to Google
/// before anybody had decided to watch anything.
class YoutubeEmbed {
  const YoutubeEmbed._();

  static bool get isSupported => true;

  /// View types already registered with the engine.
  ///
  /// Registering the same type twice is an error, and a list that rebuilds on
  /// scroll would do exactly that. Derived from the video id so a player keeps
  /// its element across rebuilds rather than being torn down and restarted.
  static final Set<String> _registered = <String>{};

  static Widget player(String videoId, {String? title}) {
    if (videoId.isEmpty) return const SizedBox.shrink();

    final String viewType = 'youtube-$videoId';

    if (_registered.add(viewType)) {
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
        final web.HTMLIFrameElement element = web.HTMLIFrameElement()
          // `autoplay=1` because this element is only created once somebody has
          // pressed play. Without it they would have to press play twice.
          //
          // `rel=0` keeps the end-of-video suggestions to the same channel,
          // rather than closing a story about a community meeting with
          // whatever YouTube would like to show next.
          ..src =
              'https://www.youtube-nocookie.com/embed/$videoId'
              '?autoplay=1&rel=0&modestbranding=1&playsinline=1'
          ..allow = 'accelerometer; autoplay; encrypted-media; picture-in-picture; fullscreen'
          ..allowFullscreen = true
          ..title = title ?? 'Video';

        element.style
          ..width = '100%'
          ..height = '100%'
          ..border = 'none'
          ..backgroundColor = '#000';

        return element;
      });
    }

    return HtmlElementView(viewType: viewType);
  }
}
