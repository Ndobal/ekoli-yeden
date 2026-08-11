import 'package:shared_preferences/shared_preferences.dart';

/// Session token storage.
///
/// On web this is browser local storage. That is a deliberate, documented
/// trade-off: it survives a page reload, which the archive's editors need, and
/// it is what `shared_preferences` provides on this platform.
///
/// It holds session tokens and nothing else. No Cloudflare credential, no API
/// key and no D1 or R2 detail is ever stored on the client — those live only in
/// the Worker, as Cloudflare secrets.
class TokenStorage {
  TokenStorage._(this._preferences);

  static const String _accessTokenKey = 'ekoli.access_token';
  static const String _refreshTokenKey = 'ekoli.refresh_token';
  static const String _expiresAtKey = 'ekoli.expires_at';

  final SharedPreferences _preferences;

  static TokenStorage? _instance;

  static Future<TokenStorage> instance() async {
    return _instance ??= TokenStorage._(await SharedPreferences.getInstance());
  }

  String? get accessToken => _preferences.getString(_accessTokenKey);
  String? get refreshToken => _preferences.getString(_refreshTokenKey);

  DateTime? get expiresAt {
    final int? millis = _preferences.getInt(_expiresAtKey);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  bool get hasSession => accessToken != null && accessToken!.isNotEmpty;

  /// True once the access token is within a minute of expiring.
  ///
  /// The margin means a request that is about to be sent does not arrive with
  /// a token that expired in flight.
  bool get isExpiring {
    final DateTime? expiry = expiresAt;
    if (expiry == null) return false;
    return DateTime.now().isAfter(expiry.subtract(const Duration(seconds: 60)));
  }

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    required int expiresInSeconds,
  }) async {
    await _preferences.setString(_accessTokenKey, accessToken);
    await _preferences.setString(_refreshTokenKey, refreshToken);
    await _preferences.setInt(
      _expiresAtKey,
      DateTime.now().add(Duration(seconds: expiresInSeconds)).millisecondsSinceEpoch,
    );
  }

  Future<void> clear() async {
    await _preferences.remove(_accessTokenKey);
    await _preferences.remove(_refreshTokenKey);
    await _preferences.remove(_expiresAtKey);
  }
}
