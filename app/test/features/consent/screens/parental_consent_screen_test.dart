import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/core/theme/app_theme.dart';
import 'package:roadpack/features/auth/models/auth_state.dart';
import 'package:roadpack/features/auth/providers/clerk_auth_provider.dart';
import 'package:roadpack/features/consent/models/consent_type.dart';
import 'package:roadpack/features/consent/screens/parental_consent_screen.dart';
import 'package:roadpack/features/consent/services/consent_repository.dart';
import 'package:roadpack/features/consent/services/parental_verification.dart';

import '../fakes.dart';

Future<void> _pump(
  WidgetTester tester, {
  required FakeConsentGateway gateway,
  ParentalVerifier? verifier,
  VoidCallback? onGranted,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clerkAuthProvider.overrideWith(
          () => FakeAuthNotifier(
            const AuthState(
              status: AuthStatus.authenticated,
              userId: 'u1',
              phone: '+919876500000',
            ),
          ),
        ),
        consentGatewayProvider.overrideWithValue(gateway),
        if (verifier != null)
          parentalVerifierProvider.overrideWithValue(verifier),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: ParentalConsentScreen(onGranted: onGranted),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _fillAndSubmit(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), 'Latha');
  await tester.enterText(find.byType(TextField).at(1), '+919876500001');
  await tester.enterText(find.byType(TextField).at(2), 'Mother');
  await tester.tap(find.text('Ask them to confirm'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the shipped build says plainly that it cannot verify a parent', (
    tester,
  ) async {
    final gw = FakeConsentGateway();
    var granted = false;
    await _pump(tester, gateway: gw, onGranted: () => granted = true);

    expect(
      find.textContaining('RoadPack will not track riders under 18'),
      findsWidgets,
      reason: 'the honest limitation is on screen before the user tries',
    );

    await _fillAndSubmit(tester);

    expect(gw.records, isEmpty, reason: 'no consent row on a refusal');
    expect(granted, isFalse);
    expect(
      find.textContaining('cannot confirm a parent or guardian yet'),
      findsOneWidget,
    );
  });

  testWidgets('with an approved verifier, the consent is recorded once', (
    tester,
  ) async {
    final gw = FakeConsentGateway();
    var granted = false;
    await _pump(
      tester,
      gateway: gw,
      verifier: const FakeApprovedVerifier(),
      onGranted: () => granted = true,
    );

    await _fillAndSubmit(tester);

    expect(granted, isTrue);
    expect(gw.records, hasLength(1));
    expect(gw.records.single.type, ConsentType.parental);
    expect(gw.records.single.grantedBy, 'parent1');
  });

  testWidgets('an empty form is refused before anything is written', (
    tester,
  ) async {
    final gw = FakeConsentGateway();
    await _pump(tester, gateway: gw, verifier: const FakeApprovedVerifier());

    await tester.tap(find.text('Ask them to confirm'));
    await tester.pumpAndSettle();

    expect(gw.grantCalls, 0);
    expect(find.textContaining('Please fill in'), findsOneWidget);
  });
}
