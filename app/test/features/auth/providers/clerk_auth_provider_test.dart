import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roadpack/features/auth/models/auth_state.dart';
import 'package:roadpack/features/auth/providers/clerk_auth_provider.dart';
import 'package:roadpack/features/auth/services/clerk_service.dart';

class MockClerkService extends Mock implements ClerkService {}

void main() {
  late ProviderContainer container;
  late MockClerkService mockService;

  setUp(() {
    mockService = MockClerkService();
    container = ProviderContainer(
      overrides: [clerkServiceProvider.overrideWithValue(mockService)],
    );
  });

  tearDown(() => container.dispose());

  group('ClerkAuthNotifier', () {
    test('initial state checks existing session — not signed in', () async {
      when(() => mockService.isSignedIn).thenReturn(false);

      final state = await container.read(clerkAuthProvider.future);
      expect(state.status, AuthStatus.idle);
      expect(state.isAuthenticated, isFalse);
    });

    test('initial state checks existing session — already signed in', () async {
      when(() => mockService.isSignedIn).thenReturn(true);
      when(() => mockService.userId).thenReturn('user_abc');

      final state = await container.read(clerkAuthProvider.future);
      expect(state.status, AuthStatus.authenticated);
      expect(state.userId, 'user_abc');
    });

    test('startPhoneSignIn transitions to codeSent', () async {
      when(() => mockService.isSignedIn).thenReturn(false);
      when(() => mockService.startPhoneSignIn(any())).thenAnswer((_) async {});

      await container.read(clerkAuthProvider.future);
      final notifier = container.read(clerkAuthProvider.notifier);
      await notifier.startPhoneSignIn('+911234567890');

      final state = container.read(clerkAuthProvider).value!;
      expect(state.status, AuthStatus.codeSent);
      expect(state.phone, '+911234567890');
    });

    test('verifyCode transitions to authenticated on success', () async {
      when(() => mockService.isSignedIn).thenReturn(false);
      when(() => mockService.startPhoneSignIn(any())).thenAnswer((_) async {});
      when(() => mockService.verifyCode(any())).thenAnswer((_) async => true);
      when(() => mockService.userId).thenReturn('user_xyz');

      await container.read(clerkAuthProvider.future);
      final notifier = container.read(clerkAuthProvider.notifier);
      await notifier.startPhoneSignIn('+911234567890');
      await notifier.verifyCode('123456');

      final state = container.read(clerkAuthProvider).value!;
      expect(state.status, AuthStatus.authenticated);
      expect(state.userId, 'user_xyz');
    });

    test('verifyCode sets error on failure', () async {
      when(() => mockService.isSignedIn).thenReturn(false);
      when(() => mockService.startPhoneSignIn(any())).thenAnswer((_) async {});
      when(() => mockService.verifyCode(any())).thenAnswer((_) async => false);

      await container.read(clerkAuthProvider.future);
      final notifier = container.read(clerkAuthProvider.notifier);
      await notifier.startPhoneSignIn('+911234567890');
      await notifier.verifyCode('000000');

      final state = container.read(clerkAuthProvider).value!;
      expect(state.status, AuthStatus.codeSent);
      expect(state.errorMessage, isNotNull);
    });

    test('signOut transitions back to idle', () async {
      when(() => mockService.isSignedIn).thenReturn(true);
      when(() => mockService.userId).thenReturn('user_abc');
      when(() => mockService.signOut()).thenAnswer((_) async {});

      await container.read(clerkAuthProvider.future);
      final notifier = container.read(clerkAuthProvider.notifier);
      await notifier.signOut();

      final state = container.read(clerkAuthProvider).value!;
      expect(state.status, AuthStatus.idle);
      expect(state.userId, isNull);
    });
  });
}
