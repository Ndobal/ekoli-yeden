import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/errors/app_exception.dart';
import '../../models/user.dart';
import 'auth_service.dart';

/// Who is signed in, for the whole application.
///
/// The router listens to this so that an admin route redirects to sign-in the
/// moment a session ends, rather than showing an empty screen behind a 401.
enum AuthStatus { unknown, signedOut, signedIn }

class AuthController extends ChangeNotifier {
  AuthController(this._service);

  final AuthService _service;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  String? _errorMessage;
  bool _busy = false;
  Timer? _identityPoll;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _busy;
  bool get isSignedIn => _status == AuthStatus.signedIn && _user != null;

  /// True while the app is still working out whether a stored session is valid.
  /// The router waits on this so it does not bounce an editor to sign-in during
  /// a page refresh.
  bool get isResolving => _status == AuthStatus.unknown;

  bool can(String permission) => _user?.can(permission) ?? false;
  bool canAny(Iterable<String> permissions) => _user?.canAny(permissions) ?? false;
  bool hasRole(String role) => _user?.hasRole(role) ?? false;

  /// Administration: users, roles, security, audit, settings.
  bool get canAccessAdmin => _user?.canAccessAdmin ?? false;

  /// The Editorial Team's area: the content of the website.
  bool get canAccessEditorial => _user?.canAccessEditorial ?? false;

  bool get canPublish => _user?.canPublish ?? false;
  bool get canReview => _user?.canReview ?? false;

  /// Whether this account has completed its Okoli membership.
  bool get isMember => _user?.isMember ?? false;

  /// Whether this account may send material to the archive.
  ///
  /// Contributing requires a membership. Reading never does.
  bool get canContribute => _user?.canContribute ?? false;

  /// RE-ASKS THE SERVER WHO THIS PERSON IS.
  ///
  /// Roles and permissions are resolved fresh on the server for every request,
  /// so a promotion takes effect there immediately. The client, though, holds
  /// the answer it was given when the session started — and the router decides
  /// whether to admit somebody to the administration area from that copy.
  ///
  /// So promoting a member while they were signed in did nothing they could
  /// see: they were bounced out of `/admin` by a permission list from before
  /// the promotion, and the only cure was to sign out and back in, which
  /// nobody thinks to suggest.
  ///
  /// This re-reads it — on a timer while signed in, and immediately whenever
  /// somebody calls it. Failure is silent: a refresh that cannot reach the
  /// server must never sign anybody out.
  Future<void> refreshIdentity() async {
    if (!isSignedIn) return;
    try {
      final AppUser? fresh = await _service.currentUser();
      if (fresh == null) return;
      _user = fresh;
      notifyListeners();
    } catch (_) {
      // A stale identity is better than a false sign-out.
    }
  }

  void _startIdentityPoll() {
    _identityPoll?.cancel();
    // Five minutes: long enough to be invisible, short enough that an
    // administrator who has just promoted somebody can tell them to wait a
    // moment rather than to sign out.
    _identityPoll = Timer.periodic(
      const Duration(minutes: 5),
      (_) => refreshIdentity(),
    );
  }

  @override
  void dispose() {
    _identityPoll?.cancel();
    super.dispose();
  }

  /// Restores a session from storage on startup.
  Future<void> restore() async {
    final AppUser? restored = await _service.currentUser();
    _user = restored;
    _status = restored == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    if (restored != null) _startIdentityPoll();
    notifyListeners();
  }

  Future<bool> signIn({required String email, required String password}) async {
    _setBusy(true);
    try {
      _user = await _service.login(email: email, password: password);
      _status = AuthStatus.signedIn;
      _startIdentityPoll();
      _errorMessage = null;
      return true;
    } on AppException catch (error) {
      _errorMessage = error.message;
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _setBusy(true);
    try {
      _user = await _service.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      _status = AuthStatus.signedIn;
      _startIdentityPoll();
      _errorMessage = null;
      return true;
    } on AppException catch (error) {
      _errorMessage = error.message;
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signOut() async {
    await _service.logout();
    _user = null;
    _identityPoll?.cancel();
    _status = AuthStatus.signedOut;
    _errorMessage = null;
    notifyListeners();
  }

  /// Called by the API client when a session could not be refreshed.
  void onSessionExpired() {
    if (_status == AuthStatus.signedOut) return;
    _user = null;
    _identityPoll?.cancel();
    _status = AuthStatus.signedOut;
    _errorMessage = 'Your session has ended. Please sign in again.';
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }
}
