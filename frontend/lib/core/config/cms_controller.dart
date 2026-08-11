import 'package:flutter/foundation.dart';

import '../../repositories/cms_repository.dart';

/// Holds the website's text for the whole application.
///
/// THE CONTRACT THAT MAKES THE CMS SAFE:
///
///   Every call site supplies a fallback. The database value wins when it
///   exists; the fallback is used when it does not.
///
/// That single rule buys three things at once. The site renders correctly on a
/// fresh checkout before any migration has run. It survives the API being
/// briefly unreachable — a visitor arriving mid-deployment sees the archive,
/// not an error page or a screen of blank labels. And a new string can be added
/// in code and seeded later without a broken release in between.
///
/// Loaded once at startup, so reading a string is a synchronous map lookup and
/// costs nothing during a build.
class CmsController extends ChangeNotifier {
  CmsController(this._repository);

  final CmsRepository _repository;

  CmsBundle _bundle = CmsBundle.empty;
  bool _loaded = false;
  bool _reachable = true;

  CmsBundle get bundle => _bundle;
  bool get isLoaded => _loaded;

  /// False when the CMS could not be fetched. The site still renders from its
  /// fallbacks; this only drives the development-mode warning banner.
  bool get isApiReachable => _reachable;

  List<HeroSlide> get heroSlides => _bundle.hero;
  List<CmsNavItem> get primaryNavigation => _bundle.primaryNav;
  List<CmsNavItem> get footerNavigation => _bundle.footerNav;

  Future<void> load() async {
    try {
      _bundle = await _repository.bundle();
      _reachable = true;
    } catch (_) {
      _bundle = CmsBundle.empty;
      _reachable = false;
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await load();
  }

  /// Reads a string, falling back to the value compiled into the app.
  ///
  /// `fallback` is required rather than optional on purpose: it forces whoever
  /// adds a CMS key to decide what the page says when the key is missing,
  /// instead of leaving an empty gap or a raw key on screen.
  String text(String key, {required String fallback}) {
    final String? value = _bundle.strings[key];
    if (value == null || value.trim().isEmpty) return fallback;
    return value;
  }

  /// Reads a string that has no sensible fallback, e.g. an optional notice.
  String? optional(String key) {
    final String? value = _bundle.strings[key];
    return (value == null || value.trim().isEmpty) ? null : value;
  }

  bool has(String key) => _bundle.strings.containsKey(key);
}
