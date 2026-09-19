import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/core/theme/app_theme.dart';
import 'package:roadpack/features/live_map/live_map.dart';

MapMember _member({
  required DateTime at,
  double? speedKmh,
  int? battery,
  String name = 'Asha',
}) => MapMember(
  userId: 'u1',
  displayName: name,
  circleId: 'c1',
  position: MemberPosition(
    userId: 'u1',
    latitude: 9.9816,
    longitude: 76.2999,
    recordedAt: at,
    speedKmh: speedKmh,
    batteryLevel: battery,
  ),
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  final now = DateTime.utc(2026, 9, 8, 12, 0, 0);

  testWidgets('a fresh member shows name, live state, speed and battery', (
    tester,
  ) async {
    await _pump(
      tester,
      MemberDetailSheet(
        member: _member(
          at: now.subtract(const Duration(seconds: 15)),
          speedKmh: 48,
          battery: 72,
        ),
        now: now,
      ),
    );

    expect(find.text('Asha'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.textContaining('48'), findsOneWidget);
    expect(find.textContaining('72%'), findsOneWidget);
  });

  testWidgets('a >60s member is greyed, age-labelled and has no live affordance', (
    tester,
  ) async {
    await _pump(
      tester,
      MemberDetailSheet(
        member: _member(
          at: now.subtract(const Duration(minutes: 4)),
          speedKmh: 61,
          battery: 55,
        ),
        now: now,
      ),
    );

    expect(find.text('Live'), findsNothing);
    expect(find.text('last seen 4m ago'), findsNothing);
    expect(find.textContaining('4m ago'), findsWidgets);
    // Stale speed must not be presented at all.
    expect(find.textContaining('61'), findsNothing);

    final chip = tester.widget<FreshnessChip>(find.byType(FreshnessChip));
    expect(chip.presence.isLive, isFalse);
    expect(chip.presence.isStale, isTrue);
  });

  testWidgets('a stopped member and an unreachable member read differently', (
    tester,
  ) async {
    await _pump(
      tester,
      MemberDetailSheet(
        member: _member(
          at: now.subtract(const Duration(seconds: 20)),
          speedKmh: 0,
        ),
        now: now,
      ),
    );
    expect(find.text('Stopped'), findsOneWidget);
    expect(find.textContaining('No signal'), findsNothing);

    await _pump(
      tester,
      MemberDetailSheet(
        member: _member(
          at: now.subtract(const Duration(minutes: 30)),
          speedKmh: 0,
        ),
        now: now,
      ),
    );
    expect(find.text('Stopped'), findsNothing);
    expect(find.text('No signal'), findsOneWidget);
  });

  testWidgets('a member with no fix says locating and shows no coordinates', (
    tester,
  ) async {
    await _pump(
      tester,
      MemberDetailSheet(
        member: const MapMember(
          userId: 'u1',
          displayName: 'Asha',
          circleId: 'c1',
        ),
        now: now,
      ),
    );
    expect(find.text('Locating'), findsOneWidget);
    expect(find.textContaining('9.98'), findsNothing);
  });

  testWidgets('the sheet renders in sunlight mode too', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: MemberDetailSheet(
            member: _member(
              at: now.subtract(const Duration(seconds: 5)),
              speedKmh: 30,
            ),
            now: now,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Live'), findsOneWidget);
  });
}
