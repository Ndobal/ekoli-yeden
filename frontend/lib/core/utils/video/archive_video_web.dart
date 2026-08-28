import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Video playback in the browser.
///
/// A clip of the Mr and Miss Leboku crowning belongs in that year's album next
/// to the photographs, and it should play where it sits. Sending somebody to a
/// second tab to watch four seconds of a crowning is how nobody watches it.
///
/// Flutter draws to a canvas and cannot decode video itself, so the browser's
/// own `<video>` element is placed into the widget tree as a platform view.
/// That also means the archive inherits the browser's controls, its codec
/// support and its full-screen button for free — all of which would otherwise
/// have to be rebuilt.
class ArchiveVideo {
  const ArchiveVideo._();

  static bool get isSupported => true;

  /// View types already registered with the engine.
  ///
  /// Registering the same type twice is an error, and a grid that rebuilds on
  /// every scroll would do exactly that. The type is derived from the URL so a
  /// video keeps its element across rebuilds instead of being torn down and
  /// re-fetched.
  static final Set<String> _registered = <String>{};

  /// A player for [url].
  ///
  /// With [controls] false this is a still preview rather than a player: the
  /// element is muted, shows its first frame and — importantly — ignores
  /// pointer events, so a tap lands on the Flutter tile underneath it and
  /// opens the video properly. Without that the element would swallow the tap
  /// and the tile would appear dead.
  static Widget player(String url, {bool controls = true}) {
    if (url.isEmpty) return const SizedBox.shrink();

    final String viewType = 'archive-video-${controls ? 'play' : 'still'}-${url.hashCode}';

    if (_registered.add(viewType)) {
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
        final web.HTMLVideoElement element = web.HTMLVideoElement()
          // `#t=0.1` asks the browser to seek a fraction of a second in, which
          // is what makes it paint a frame instead of a black rectangle.
          // Videos frequently open on a dark frame, and a black tile reads as
          // a broken picture.
          ..src = controls ? url : '$url#t=0.1'
          ..controls = controls
          // Metadata only: a gallery page can carry several clips, and
          // downloading all of them before anybody has asked to watch one
          // would cost a visitor on a phone connection dearly.
          ..preload = 'metadata'
          ..playsInline = true
          ..muted = !controls;

        element.style
          ..width = '100%'
          ..height = '100%'
          ..objectFit = controls ? 'contain' : 'cover'
          ..border = 'none'
          ..backgroundColor = '#000'
          ..pointerEvents = controls ? 'auto' : 'none';

        return element;
      });
    }

    return HtmlElementView(viewType: viewType);
  }
}
