import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/core/theme/theme.dart';
import 'package:roadpack/features/emergency_profile/models/models.dart';
import 'package:roadpack/features/emergency_profile/providers/providers.dart';
import 'package:roadpack/features/emergency_profile/widgets/widgets.dart';

const _data = IceCardData(
  ownerName: 'Rishi',
  bloodGroup: 'O+',
  medicalNotes: 'Penicillin allergy',
  contacts: [
    EmergencyContact(
      id: 'ec1',
      userId: 'user_1',
      name: 'Amma',
      phone: '+919876543210',
      relationship: 'Mother',
      priority: 1,
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  required bool incident,
  required bool commute,
  bool optIn = true,
  bool sunlight = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        iceIncidentActiveProvider.overrideWithValue(incident),
        iceCommuteActiveProvider.overrideWithValue(commute),
        iceCommuteExposureOptInProvider.overrideWithValue(optIn),
      ],
      child: MaterialApp(
        theme: sunlight ? AppTheme.light : AppTheme.dark,
        home: const Scaffold(body: IceCard(data: _data)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('IceCard exposure gating (FR-023 / SG-08)', () {
    testWidgets('renders nothing when no incident or commute is active', (
      tester,
    ) async {
      await _pump(tester, incident: false, commute: false);

      expect(find.text('O+'), findsNothing);
      expect(find.text('Penicillin allergy'), findsNothing);
      expect(find.text('Amma'), findsNothing);
      expect(find.text('+919876543210'), findsNothing);
      expect(find.byType(IceCardBody), findsNothing);
    });

    testWidgets('renders during an active incident', (tester) async {
      await _pump(tester, incident: true, commute: false);

      expect(find.byType(IceCardBody), findsOneWidget);
      expect(find.text('O+'), findsOneWidget);
      expect(find.text('Penicillin allergy'), findsOneWidget);
      expect(find.text('Amma'), findsOneWidget);
    });

    testWidgets('renders during an opted-in active commute', (tester) async {
      await _pump(tester, incident: false, commute: true);
      expect(find.byType(IceCardBody), findsOneWidget);
    });

    testWidgets('stays hidden during a commute the user did not opt in to', (
      tester,
    ) async {
      await _pump(tester, incident: false, commute: true, optIn: false);
      expect(find.byType(IceCardBody), findsNothing);
      expect(find.text('O+'), findsNothing);
    });

    testWidgets('tears itself down when the incident resolves mid-render', (
      tester,
    ) async {
      final incident = StateProvider<bool>((ref) => true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            iceIncidentActiveProvider.overrideWith((ref) => ref.watch(incident)),
            iceCommuteActiveProvider.overrideWithValue(false),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(body: IceCard(data: _data)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(IceCardBody), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(IceCard)),
      );
      container.read(incident.notifier).state = false;
      await tester.pumpAndSettle();

      expect(find.byType(IceCardBody), findsNothing);
      expect(find.text('+919876543210'), findsNothing);
    });

    testWidgets('renders in sunlight mode too', (tester) async {
      await _pump(tester, incident: true, commute: false, sunlight: true);
      expect(find.byType(IceCardBody), findsOneWidget);
      expect(find.text('O+'), findsOneWidget);
    });
  });
}
