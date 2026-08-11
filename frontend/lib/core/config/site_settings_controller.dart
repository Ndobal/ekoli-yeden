import 'package:flutter/foundation.dart';

import '../../repositories/settings_repository.dart';

/// Holds the public site settings for the whole application.
///
/// Loaded once at startup. If the Worker cannot be reached the site still
/// renders using the built-in defaults — a visitor who arrives during a
/// deployment sees the archive, not an error page.
class SiteSettingsController extends ChangeNotifier {
  SiteSettingsController(this._repository);

  final SettingsRepository _repository;

  SiteSettings _settings = SiteSettings.empty;
  bool _loaded = false;
  bool _apiReachable = true;

  SiteSettings get settings => _settings;
  bool get isLoaded => _loaded;

  /// False when the Worker did not answer. Shown as a banner in development so
  /// a contributor knows to start `wrangler dev`, and used to decide whether to
  /// offer the contribution form at all.
  bool get isApiReachable => _apiReachable;

  Future<void> load() async {
    try {
      _settings = await _repository.publicSettings();
      _apiReachable = true;
    } catch (_) {
      _settings = SiteSettings.empty;
      _apiReachable = false;
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _loaded = false;
    notifyListeners();
    await load();
  }
}
