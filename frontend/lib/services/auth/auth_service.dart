import '../../models/user.dart';
import '../api/api_client.dart';
import '../storage/token_storage.dart';

/// Talks to the Worker's authentication endpoints.
///
/// This holds no authorisation logic of its own. It exchanges credentials for a
/// session and reports what the server says the user may do; every one of those
/// permissions is checked again by the Worker on every request.
class AuthService {
  AuthService(this._api);

  final ApiClient _api;

  Future<AppUser> login({required String email, required String password}) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/auth/login',
      authenticated: false,
      body: <String, dynamic>{'email': email, 'password': password},
    );

    await _saveSession(data);
    return _resolveUser(data);
  }

  /// Creates an account and signs into it.
  ///
  /// A new account gets the Contributor role and nothing more: it may submit
  /// material for review, and cannot publish anything.
  ///
  /// SIGNED IN IMMEDIATELY, rather than returned to a sign-in form. Somebody
  /// who has just chosen a password and typed it correctly has proved exactly
  /// what the sign-in form would ask them to prove thirty seconds later, from
  /// memory. That step only loses people — and what they need next is their
  /// dashboard, which is where the membership is actually completed.
  Future<AppUser> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/auth/register',
      authenticated: false,
      body: <String, dynamic>{
        'email': email,
        'password': password,
        'display_name': displayName,
      },
    );

    await _saveSession(data);
    return _resolveUser(data);
  }

  /// The user a session belongs to, confirmed against the server.
  ///
  /// Sign-in and registration both used to trust the `user` object in their own
  /// response and stop there. `/api/auth/me` was the only endpoint that
  /// reported membership, so somebody who had just signed in was, as far as the
  /// interface was concerned, not a member — and was invited to become one when
  /// they tried to post an opportunity. Reloading the page fixed it, because
  /// session restore calls `/me`.
  ///
  /// The Worker now returns the same shape from all three. This second call
  /// stays as the belt to that braces: whatever `/me` learns to report next
  /// reaches a freshly signed-in member without a second round of this bug.
  Future<AppUser> _resolveUser(Map<String, dynamic> data) async {
    try {
      final Map<String, dynamic> me = await _api.get('/api/auth/me');
      return AppUser.fromJson(me);
    } catch (_) {
      // The session is already saved and valid; a failed refresh should not
      // turn a successful sign-in into an error.
      return AppUser.fromJson((data['user'] as Map<String, dynamic>?) ?? <String, dynamic>{});
    }
  }

  /// Signs in using a reset token, for somebody who has just changed their
  /// password — including after an administrator issued a temporary one.
  Future<AppUser> completePasswordReset({
    required String token,
    required String password,
  }) async {
    final Map<String, dynamic> data = await _api.post(
      '/api/auth/reset-password',
      authenticated: false,
      body: <String, dynamic>{'token': token, 'password': password},
    );

    await _saveSession(data);
    final Map<String, dynamic> me = await _api.get('/api/auth/me');
    return AppUser.fromJson(me);
  }

  /// The signed-in user, or `null` when there is no valid session.
  Future<AppUser?> currentUser() async {
    final TokenStorage storage = await TokenStorage.instance();
    if (!storage.hasSession) return null;

    try {
      final Map<String, dynamic> data = await _api.get('/api/auth/me');
      return AppUser.fromJson(data);
    } catch (_) {
      // A token that no longer resolves is not an error state to show — the
      // session has simply ended, so clear it and continue as a visitor.
      await storage.clear();
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _api.post('/api/auth/logout');
    } catch (_) {
      // Even if the Worker cannot be reached, the local session must go —
      // otherwise "sign out" would silently do nothing on a bad connection.
    }
    final TokenStorage storage = await TokenStorage.instance();
    await storage.clear();
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    final TokenStorage storage = await TokenStorage.instance();
    await storage.save(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      expiresInSeconds: (data['expiresIn'] as num).toInt(),
    );
  }
}
