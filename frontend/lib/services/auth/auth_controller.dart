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

  /// Restores a session from storage on startup.
  Future<void> restore() async {
    final AppUser? restored = await _service.currentUser();
    _user = restored;
    _status = restored == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    notifyListeners();
  }

  Future<bool> signIn({required String email, required String password}) async {
    _setBusy(true);
    try {
      _user = await _service.login(email: email, password: password);
      _status = AuthStatus.signedIn;
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
    _status = AuthStatus.signedOut;
    _errorMessage = null;
    notifyListeners();
  }

  /// Called by the API client when a session could not be refreshed.
  void onSessionExpired() {
    if (_status == AuthStatus.signedOut) return;
    _user = null;
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
