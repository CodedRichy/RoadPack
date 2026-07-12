import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/auth/providers/user_profile_provider.dart';
import 'package:roadpack/features/auth/screens/onboarding_screen.dart';

void main() {
  group('OnboardingScreen', () {
    testWidgets('shows name page first', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith(() => _TestProfileNotifier()),
          ],
          child: const MaterialApp(home: OnboardingScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('What should we call you?'), findsOneWidget);
    });

    testWidgets('seeds the name field from the existing profile', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith(() => _TestProfileNotifier()),
          ],
          child: const MaterialApp(home: OnboardingScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('advances to the date of birth page on continue', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith(() => _TestProfileNotifier()),
          ],
          child: const MaterialApp(home: OnboardingScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Date of birth'), findsOneWidget);
    });

    testWidgets('final page shows a Finish button and a skip option', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith(() => _TestProfileNotifier()),
          ],
          child: const MaterialApp(home: OnboardingScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Name page -> DOB page.
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Accept the date picker's initial date, then DOB page -> vehicle
      // page.
      await tester.tap(find.text('Select date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Vehicle page -> location page.
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Location page -> emergency contact page (skip).
      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();

      expect(find.text('Emergency contact'), findsOneWidget);
      expect(find.text('Finish'), findsOneWidget);
      expect(find.text('Skip for now'), findsOneWidget);
    });
  });
}

class _TestProfileNotifier extends AsyncNotifier<UserProfile?>
    implements UserProfileNotifier {
  @override
  Future<UserProfile?> build() async =>
      const UserProfile(userId: 'u1', name: 'Test');
  @override
  Future<void> fetchProfile() async {}
  @override
  Future<void> updateName(String name) async {}
  @override
  Future<void> updateDateOfBirth(DateTime dob) async {}
  @override
  Future<void> updateVehicle(String? type, String? reg) async {}
  @override
  Future<void> addEmergencyContact({
    required String name,
    required String phone,
    required String relationship,
  }) async {}
}
