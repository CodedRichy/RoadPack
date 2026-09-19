import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/core/theme/theme.dart';
import 'package:roadpack/features/auth/providers/user_profile_provider.dart';
import 'package:roadpack/features/emergency_profile/models/emergency_contact.dart';
import 'package:roadpack/features/emergency_profile/providers/emergency_contacts_provider.dart';
import 'package:roadpack/features/emergency_profile/providers/ice_gate_provider.dart';
import 'package:roadpack/features/settings/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeProfileNotifier extends UserProfileNotifier {
  @override
  Future<UserProfile?> build() async => const UserProfile(userId: 'user_1');
}

class _FakeContactsNotifier extends EmergencyContactsNotifier {
  _FakeContactsNotifier(this.contacts);

  final List<EmergencyContact> contacts;

  @override
  Future<List<EmergencyContact>> build() async => contacts;
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  List<EmergencyContact> contacts = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userProfileProvider.overrideWith(_FakeProfileNotifier.new),
        emergencyContactsProvider.overrideWith(
          () => _FakeContactsNotifier(contacts),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Settings is a long list; scroll a row into view before asserting on it.
Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<SwitchListTile> _iceToggle(WidgetTester tester) async {
  await _reveal(tester, find.byKey(SettingsScreen.iceExposureToggleKey));
  return tester.widget<SwitchListTile>(
    find.byKey(SettingsScreen.iceExposureToggleKey),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('every emergency surface is reachable from settings', (
    tester,
  ) async {
    await _pumpSettings(tester);

    for (final row in const [
      'Commute routes',
      'Emergency contacts',
      'ICE card',
      'Offline maps',
    ]) {
      await _reveal(tester, find.text(row));
      expect(find.text(row), findsOneWidget, reason: row);
    }
  });

  testWidgets('an empty contact list is not dressed up as configured', (
    tester,
  ) async {
    await _pumpSettings(tester);

    final empty = find.text('None yet — alerts have nobody to reach');
    await _reveal(tester, empty);
    expect(empty, findsOneWidget);
  });

  testWidgets('the ICE commute-exposure opt-in is off by default', (
    tester,
  ) async {
    await _pumpSettings(tester);

    expect((await _iceToggle(tester)).value, isFalse);
  });

  testWidgets('toggling the ICE opt-in persists it', (tester) async {
    await _pumpSettings(tester);
    await _reveal(tester, find.byKey(SettingsScreen.iceExposureToggleKey));

    await tester.tap(find.byKey(SettingsScreen.iceExposureToggleKey));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(IceCommuteExposureNotifier.prefsKey), isTrue);
  });

  testWidgets('a stored opt-out keeps the card shut', (tester) async {
    SharedPreferences.setMockInitialValues({
      IceCommuteExposureNotifier.prefsKey: false,
    });
    await _pumpSettings(tester);

    expect((await _iceToggle(tester)).value, isFalse);
  });
}
