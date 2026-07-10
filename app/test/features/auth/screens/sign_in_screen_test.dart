import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/auth/models/auth_state.dart';
import 'package:roadpack/features/auth/providers/clerk_auth_provider.dart';
import 'package:roadpack/features/auth/screens/sign_in_screen.dart';

void main() {
  group('SignInScreen', () {
    testWidgets('renders phone input by default', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clerkAuthProvider.overrideWith(() => _IdleAuthNotifier()),
          ],
          child: const MaterialApp(home: SignInScreen()),
        ),
      );
      expect(find.text('+91'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('can switch to email input', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clerkAuthProvider.overrideWith(() => _IdleAuthNotifier()),
          ],
          child: const MaterialApp(home: SignInScreen()),
        ),
      );
      await tester.tap(find.text('Use email instead'));
      await tester.pump();
      expect(find.text('Email address'), findsOneWidget);
    });
  });
}

class _IdleAuthNotifier extends AsyncNotifier<AuthState>
    implements ClerkAuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState();
  @override
  Future<void> startPhoneSignIn(String phone) async {}
  @override
  Future<void> startEmailSignIn(String email) async {}
  @override
  Future<void> verifyCode(String code) async {}
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signOut() async {}
}
