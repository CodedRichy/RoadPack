import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/core/theme/theme.dart';
import 'package:roadpack/features/auth/providers/user_profile_provider.dart';
import 'package:roadpack/features/bystander/models/ice_profile.dart';
import 'package:roadpack/features/bystander/screens/bystander_screen.dart';
import 'package:roadpack/features/emergency_profile/models/emergency_contact.dart';
import 'package:roadpack/features/emergency_profile/providers/emergency_contacts_provider.dart';
import 'package:roadpack/features/settings/screens/bystander_preview_screen.dart';

class _FakeProfileNotifier extends UserProfileNotifier {
  _FakeProfileNotifier(this.profile);

  final UserProfile? profile;

  @override
  Future<UserProfile?> build() async => profile;
}

class _FakeContactsNotifier extends EmergencyContactsNotifier {
  _FakeContactsNotifier(this.contacts);

  final List<EmergencyContact> contacts;

  @override
  Future<List<EmergencyContact>> build() async => contacts;
}

EmergencyContact _contact() => const EmergencyContact(
  id: 'c1',
  userId: 'user_1',
  name: 'Asha',
  phone: '+919400000000',
  priority: 1,
);

Future<void> _pump(
  WidgetTester tester, {
  UserProfile? profile,
  List<EmergencyContact> contacts = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userProfileProvider.overrideWith(() => _FakeProfileNotifier(profile)),
        emergencyContactsProvider.overrideWith(
          () => _FakeContactsNotifier(contacts),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const BystanderPreviewScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the sample session', () {
    test('is not an active incident and carries no ICE data', () {
      final session = BystanderPreviewScreen.sampleSession(
        name: 'Rishi',
        contact: _contact(),
      );

      expect(session.incidentActive, isFalse);
      expect(session.ice, isNull);
      // The gate stays shut on its own terms — nothing here weakens it.
      expect(IceQrPayload.forSession(session), isNull);
    });

    test('invents no location', () {
      final session = BystanderPreviewScreen.sampleSession(name: 'Rishi');
      expect(session.hasLocation, isFalse);
    });

    test('shows the rider their real contact state, not a placeholder', () {
      expect(
        BystanderPreviewScreen.sampleSession(name: 'Rishi').hasContact,
        isFalse,
      );
      expect(
        BystanderPreviewScreen.sampleSession(
          name: 'Rishi',
          contact: _contact(),
        ).hasContact,
        isTrue,
      );
    });
  });

  testWidgets('the preview is unmistakably a preview', (tester) async {
    await _pump(tester);

    expect(find.byKey(BystanderPreviewScreen.bannerKey), findsOneWidget);
    expect(
      find.textContaining('No emergency is in progress'),
      findsWidgets,
    );
  });

  testWidgets('the preview renders the real bystander screen', (tester) async {
    await _pump(
      tester,
      profile: const UserProfile(userId: 'user_1', name: 'Rishi'),
      contacts: [_contact()],
    );

    expect(find.byType(BystanderScreen), findsOneWidget);
    expect(find.byKey(BystanderScreen.dial112Key), findsOneWidget);
  });

  testWidgets('the ICE card is sealed, and the preview says why', (
    tester,
  ) async {
    await _pump(
      tester,
      profile: const UserProfile(
        userId: 'user_1',
        name: 'Rishi',
        bloodGroup: 'O+',
      ),
      contacts: [_contact()],
    );

    // The real card is absent because the gate is shut, not because the
    // preview hid it.
    expect(find.byKey(BystanderScreen.iceKey), findsNothing);

    final sealed = find.byKey(BystanderPreviewScreen.sealedIceKey);
    await tester.scrollUntilVisible(
      sealed,
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(sealed, findsOneWidget);
  });

  test('the preview launcher refuses every intent', () async {
    // A preview that can dial 112 is worse than no preview.
    expect(
      await BystanderPreviewScreen.inertLauncher(Uri.parse('tel:112')),
      isFalse,
    );
    expect(
      await BystanderPreviewScreen.inertLauncher(
        Uri.parse('https://maps.example'),
      ),
      isFalse,
    );
  });

  testWidgets('tapping a preview action does nothing at all', (tester) async {
    await _pump(tester, profile: const UserProfile(userId: 'user_1'));

    await tester.tap(find.byKey(BystanderScreen.dial112Key));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
