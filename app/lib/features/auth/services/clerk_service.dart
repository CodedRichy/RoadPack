import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart' show ClerkAuthConfig;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/constants/app_constants.dart';

/// Riverpod provider exposing a singleton [ClerkService] for the app.
///
/// The service is not initialized here — callers (e.g. `ClerkAuthNotifier`)
/// must call [ClerkService.initialize] before using it.
final clerkServiceProvider = Provider<ClerkService>((ref) {
  final config = ClerkAuthConfig(
    publishableKey: AppConstants.clerkPublishableKey,
  );
  return ClerkService(clerk.Auth(config: config));
});

/// Thin, testable wrapper around the `clerk_auth` [clerk.Auth] client.
///
/// This is the sole point of contact between RoadPack and the Clerk SDK.
/// All `clerk_auth`/`clerk_flutter` types are confined to this file so that
/// a future SDK upgrade (this package is currently pre-release) only
/// requires changes here.
///
/// Note on the real SDK shape (0.0.16-beta): `clerk_flutter` is primarily a
/// widget library. The headless client used here — [clerk.Auth], [clerk
/// .Client], [clerk.Session], [clerk.SignIn], [clerk.Strategy] — actually
/// lives in the `clerk_auth` package, which `clerk_flutter` re-exports
/// widgets around (`ClerkAuthState extends clerk.Auth with ChangeNotifier`).
/// There is no `ClerkAuth` class and `Client` has no `activeSessions`
/// getter; sign-in is a single progressive `attemptSignIn(...)` call rather
/// than separate `SignIn.create()` / `prepareFirstFactor()` /
/// `attemptFirstFactor()` steps.
class ClerkService {
  ClerkService(this._auth, {GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: const ['email']);

  final clerk.Auth _auth;
  final GoogleSignIn _googleSignIn;

  /// The underlying Clerk [clerk.Auth] instance, exposed for callers that
  /// need lower-level access (e.g. listening to `sessionTokenStream`).
  clerk.Auth get auth => _auth;

  /// The strategy of the sign-in currently awaiting a code, if any.
  clerk.Strategy? _pendingStrategy;

  /// Must be called once before any other method is used.
  Future<void> initialize() => _auth.initialize();

  /// Whether there is a currently signed-in user.
  bool get isSignedIn => _auth.isSignedIn;

  /// The currently active session, or null if not signed in.
  clerk.Session? get currentSession => _auth.session;

  /// The id of the currently signed-in user, or null.
  String? get userId => _auth.user?.id;

  /// Starts a phone-number sign-in, sending a one-time code via SMS.
  ///
  /// Follow with [verifyCode] once the user has entered the code.
  Future<void> startPhoneSignIn(String phone) async {
    _pendingStrategy = clerk.Strategy.phoneCode;
    await _auth.attemptSignIn(
      strategy: clerk.Strategy.phoneCode,
      identifier: phone,
    );
  }

  /// Starts an email sign-in, sending a one-time code via email.
  ///
  /// Follow with [verifyCode] once the user has entered the code.
  Future<void> startEmailSignIn(String email) async {
    _pendingStrategy = clerk.Strategy.emailCode;
    await _auth.attemptSignIn(
      strategy: clerk.Strategy.emailCode,
      identifier: email,
    );
  }

  /// Verifies the one-time [code] sent by [startPhoneSignIn] or
  /// [startEmailSignIn].
  ///
  /// Returns true if sign-in is now complete. Returns false if there is no
  /// sign-in in progress or the code was rejected.
  Future<bool> verifyCode(String code) async {
    final strategy = _pendingStrategy;
    if (strategy == null) return false;

    await _auth.attemptSignIn(strategy: strategy, code: code);

    final success = _auth.isSignedIn;
    if (success) _pendingStrategy = null;
    return success;
  }

  /// Signs in with Google using a native ID token obtained via
  /// `google_sign_in`.
  ///
  /// This avoids the webview/redirect OAuth flow (which requires a
  /// `BuildContext`) and is not available on a headless service — Clerk
  /// supports it directly via `idTokenSignIn`.
  ///
  /// Returns normally (without signing in) if the user cancels the Google
  /// sign-in flow.
  Future<void> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return;

    final googleAuth = await account.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw StateError('Google sign-in did not return an ID token.');
    }

    await _auth.idTokenSignIn(
      provider: clerk.IdTokenProvider.google,
      token: idToken,
    );
  }

  /// Fetches a Supabase-templated session token for the active session.
  ///
  /// Returns null if not signed in, or if the token could not be retrieved.
  Future<String?> getSupabaseToken() async {
    if (!isSignedIn) return null;
    try {
      final token = await _auth.sessionToken(templateName: 'supabase');
      return token.jwt;
    } on Exception {
      return null;
    }
  }

  /// Signs out of the current session.
  Future<void> signOut() async {
    _pendingStrategy = null;
    await _auth.signOut();
  }
}
