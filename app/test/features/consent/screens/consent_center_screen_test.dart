import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/core/theme/app_theme.dart';
import 'package:roadpack/features/auth/models/auth_state.dart';
import 'package:roadpack/features/auth/providers/clerk_auth_provider.dart';
import 'package:roadpack/features/auth/providers/user_profile_provider.dart';
import 'package:roadpack/features/consent/models/consent_type.dart';
import 'package:roadpack/features/consent/screens/consent_center_screen.dart';
import 'package:roadpack/features/consent/services/consent_repository.dart';
import 'package:roadpack/features/emergency_profile/providers/emergency_contacts_provider.dart';

import '../fakes.dart';

Future<void> _pump(
  WidgetTester tester, {
  required FakeConsentGateway gateway,
  DateTime? dateOfBirth,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userProfileProvider.overrideWith(
          () => FakeProfileNotifier(
            UserProfile(
              userId: 'u1',
              name: 'Asha',
              dateOfBirth:
                  dateOfBirth ?? DateTime(DateTime.now().year - 30, 1, 1),
            ),
          ),
        ),
        clerkAuthProvider.overrideWith(
          () => FakeAuthNotifier(
            const AuthState(
              status: AuthStatus.authenticated,
              userId: 'u1',
              phone: '+919876500000',
            ),
          ),
        ),
        emergencyProfileReadyProvider.overrideWithValue(true),
        consentGatewayProvider.overrideWithValue(gateway),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const ConsentCenterScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('offers a way to withdraw a consent that was given', (
    tester,
  ) async {
    final gw = FakeConsentGateway(records: [fakeConsent(ConsentType.tracking)]);
    await _pump(tester, gateway: gw);

    expect(find.text('RoadPack can look after you'), findsOneWidget);

    final trackingSwitch = find.byType(Switch).first;
    expect(tester.widget<Switch>(trackingSwitch).value, isTrue);

    await tester.tap(trackingSwitch);
    await tester.pumpAndSettle();

    expect(gw.revokeCalls, 1);
    expect(gw.records.single.revokedAt, isNotNull);
    expect(find.text('RoadPack is not tracking you yet'), findsOneWidget);
  });

  testWidgets('an unreadable ledger says so instead of showing toggles', (
    tester,
  ) async {
    await _pump(tester, gateway: FakeConsentGateway(failFetch: true));

    expect(find.text('We could not check your permissions'), findsWidgets);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('RoadPack is not tracking you yet'), findsOneWidget);
  });

  testWidgets('a minor sees the age gate named as the reason', (tester) async {
    final gw = FakeConsentGateway(records: [fakeConsent(ConsentType.tracking)]);
    await _pump(
      tester,
      gateway: gw,
      dateOfBirth: DateTime(DateTime.now().year - 16, 1, 1),
    );

    expect(find.text('Parent or guardian permission needed'), findsOneWidget);
  });

  testWidgets('a live parental consent can be withdrawn', (tester) async {
    final gw = FakeConsentGateway(
      records: [
        fakeConsent(ConsentType.tracking),
        fakeConsent(ConsentType.parental, id: 'p1', grantedBy: 'parent1'),
      ],
    );
    await _pump(
      tester,
      gateway: gw,
      dateOfBirth: DateTime(DateTime.now().year - 16, 1, 1),
    );

    final revoke = find.text('Withdraw parent permission');
    await tester.scrollUntilVisible(revoke, 200);
    await tester.pumpAndSettle();
    expect(revoke, findsOneWidget);

    await tester.tap(revoke);
    await tester.pumpAndSettle();

    expect(
      gw.records.firstWhere((r) => r.type == ConsentType.parental).revokedAt,
      isNotNull,
    );
    expect(
      find.text('Withdraw parent permission'),
      findsNothing,
      reason: 'the permission is gone, so the withdraw control goes with it',
    );

    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(
      find.text('Parent or guardian permission needed'),
      findsOneWidget,
      reason: 'withdrawing parental permission stops tracking again',
    );
  });
}
