import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roadpack/features/auth/services/clerk_service.dart';

// The real clerk_flutter (0.0.16-beta) SDK does not expose a `ClerkAuth`
// class, and `Client` has no `activeSessions` getter. The headless client is
// `clerk.Auth` (from the `clerk_auth` package clerk_flutter is built on),
// which exposes `isSignedIn`, `session` and `user` directly — so that's what
// is mocked here instead of the plan's hypothetical types.
class MockAuth extends Mock implements clerk.Auth {}

class MockSession extends Mock implements clerk.Session {}

class MockUser extends Mock implements clerk.User {}

class MockSessionToken extends Mock implements clerk.SessionToken {}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class MockGoogleSignInAuthentication extends Mock
    implements GoogleSignInAuthentication {}

void main() {
  late MockAuth mockAuth;
  late MockGoogleSignIn mockGoogleSignIn;
  late ClerkService service;

  setUpAll(() {
    registerFallbackValue(clerk.Strategy.unknown);
    registerFallbackValue(clerk.IdTokenProvider.google);
  });

  setUp(() {
    mockAuth = MockAuth();
    mockGoogleSignIn = MockGoogleSignIn();
    service = ClerkService(mockAuth, googleSignIn: mockGoogleSignIn);
  });

  group('ClerkService', () {
    test('initialize delegates to Auth.initialize', () async {
      when(() => mockAuth.initialize()).thenAnswer((_) async {});
      await service.initialize();
      verify(() => mockAuth.initialize()).called(1);
    });

    test('isSignedIn returns false when no active session', () {
      when(() => mockAuth.isSignedIn).thenReturn(false);
      expect(service.isSignedIn, isFalse);
    });

    test('isSignedIn returns true with active session', () {
      when(() => mockAuth.isSignedIn).thenReturn(true);
      expect(service.isSignedIn, isTrue);
    });

    test('currentSession returns Auth.session', () {
      final session = MockSession();
      when(() => mockAuth.session).thenReturn(session);
      expect(service.currentSession, same(session));
    });

    test('currentSession returns null when no session', () {
      when(() => mockAuth.session).thenReturn(null);
      expect(service.currentSession, isNull);
    });

    test('userId returns Auth.user.id when signed in', () {
      final user = MockUser();
      when(() => user.id).thenReturn('user_123');
      when(() => mockAuth.user).thenReturn(user);
      expect(service.userId, 'user_123');
    });

    test('userId returns null when signed out', () {
      when(() => mockAuth.user).thenReturn(null);
      expect(service.userId, isNull);
    });

    test('startPhoneSignIn calls attemptSignIn with phoneCode strategy', () async {
      when(
        () => mockAuth.attemptSignIn(
          strategy: any(named: 'strategy'),
          identifier: any(named: 'identifier'),
        ),
      ).thenAnswer((_) async {});

      await service.startPhoneSignIn('+911234567890');

      verify(
        () => mockAuth.attemptSignIn(
          strategy: clerk.Strategy.phoneCode,
          identifier: '+911234567890',
        ),
      ).called(1);
    });

    test('startEmailSignIn calls attemptSignIn with emailCode strategy', () async {
      when(
        () => mockAuth.attemptSignIn(
          strategy: any(named: 'strategy'),
          identifier: any(named: 'identifier'),
        ),
      ).thenAnswer((_) async {});

      await service.startEmailSignIn('a@b.com');

      verify(
        () => mockAuth.attemptSignIn(
          strategy: clerk.Strategy.emailCode,
          identifier: 'a@b.com',
        ),
      ).called(1);
    });

    test('verifyCode returns false when no sign-in is in progress', () async {
      final result = await service.verifyCode('123456');
      expect(result, isFalse);
      verifyNever(
        () => mockAuth.attemptSignIn(strategy: any(named: 'strategy')),
      );
    });

    test('verifyCode returns true and completes on success', () async {
      when(
        () => mockAuth.attemptSignIn(
          strategy: any(named: 'strategy'),
          identifier: any(named: 'identifier'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockAuth.attemptSignIn(
          strategy: any(named: 'strategy'),
          code: any(named: 'code'),
        ),
      ).thenAnswer((_) async {});

      await service.startPhoneSignIn('+911234567890');

      when(() => mockAuth.isSignedIn).thenReturn(true);
      final result = await service.verifyCode('123456');

      expect(result, isTrue);
      verify(
        () => mockAuth.attemptSignIn(
          strategy: clerk.Strategy.phoneCode,
          code: '123456',
        ),
      ).called(1);

      // A second call with no fresh startXSignIn has nothing pending.
      final second = await service.verifyCode('654321');
      expect(second, isFalse);
    });

    test('verifyCode returns false when code is rejected', () async {
      when(
        () => mockAuth.attemptSignIn(
          strategy: any(named: 'strategy'),
          identifier: any(named: 'identifier'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockAuth.attemptSignIn(
          strategy: any(named: 'strategy'),
          code: any(named: 'code'),
        ),
      ).thenAnswer((_) async {});

      await service.startEmailSignIn('a@b.com');

      when(() => mockAuth.isSignedIn).thenReturn(false);
      final result = await service.verifyCode('000000');

      expect(result, isFalse);
    });

    test('signInWithGoogle does nothing when user cancels', () async {
      when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async => null);

      await service.signInWithGoogle();

      verifyNever(
        () => mockAuth.idTokenSignIn(
          provider: any(named: 'provider'),
          token: any(named: 'token'),
        ),
      );
    });

    test('signInWithGoogle signs in with idTokenSignIn on success', () async {
      final account = MockGoogleSignInAccount();
      final auth = MockGoogleSignInAuthentication();
      when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async => account);
      when(() => account.authentication).thenAnswer((_) async => auth);
      when(() => auth.idToken).thenReturn('id_token_abc');
      when(
        () => mockAuth.idTokenSignIn(
          provider: any(named: 'provider'),
          token: any(named: 'token'),
        ),
      ).thenAnswer((_) async {});

      await service.signInWithGoogle();

      verify(
        () => mockAuth.idTokenSignIn(
          provider: clerk.IdTokenProvider.google,
          token: 'id_token_abc',
        ),
      ).called(1);
    });

    test('signInWithGoogle throws when no ID token is returned', () async {
      final account = MockGoogleSignInAccount();
      final auth = MockGoogleSignInAuthentication();
      when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async => account);
      when(() => account.authentication).thenAnswer((_) async => auth);
      when(() => auth.idToken).thenReturn(null);

      await expectLater(service.signInWithGoogle(), throwsStateError);
    });

    test('getSupabaseToken returns null when not signed in', () async {
      when(() => mockAuth.isSignedIn).thenReturn(false);
      final token = await service.getSupabaseToken();
      expect(token, isNull);
    });

    test('getSupabaseToken returns the jwt when signed in', () async {
      final sessionToken = MockSessionToken();
      when(() => mockAuth.isSignedIn).thenReturn(true);
      when(() => sessionToken.jwt).thenReturn('jwt.value.here');
      when(
        () => mockAuth.sessionToken(templateName: 'supabase'),
      ).thenAnswer((_) async => sessionToken);

      final token = await service.getSupabaseToken();

      expect(token, 'jwt.value.here');
    });

    test('getSupabaseToken returns null when Auth throws', () async {
      when(() => mockAuth.isSignedIn).thenReturn(true);
      when(() => mockAuth.sessionToken(templateName: 'supabase')).thenThrow(
        const clerk.ClerkError(
          code: clerk.ClerkErrorCode.noSessionTokenRetrieved,
          message: 'No session token retrieved',
        ),
      );

      final token = await service.getSupabaseToken();

      expect(token, isNull);
    });

    test('signOut delegates to Auth.signOut and clears pending sign-in', () async {
      when(
        () => mockAuth.attemptSignIn(
          strategy: any(named: 'strategy'),
          identifier: any(named: 'identifier'),
        ),
      ).thenAnswer((_) async {});
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      await service.startPhoneSignIn('+911234567890');
      await service.signOut();

      verify(() => mockAuth.signOut()).called(1);

      // pending sign-in was cleared, so verifyCode now has nothing to do
      final result = await service.verifyCode('123456');
      expect(result, isFalse);
    });
  });
}
