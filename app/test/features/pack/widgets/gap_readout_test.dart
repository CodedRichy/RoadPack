import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/core/theme/theme.dart';
import 'package:roadpack/features/pack/models/pack_gap.dart';
import 'package:roadpack/features/pack/models/pack_status.dart';
import 'package:roadpack/features/pack/widgets/gap_readout.dart';

/// The honesty rules, asserted.
///
/// These are the tests that matter in this feature. A gap number is a claim
/// about where a rider is right now; every case below is one where that claim
/// would be false, and the widget's job is to refuse rather than to soften.
void main() {
  PackGap gapWith({
    required PackDisplayState displayState,
    double? gapM = -1400,
    double? gapS = -180,
    bool gapEstimated = false,
    bool offRoute = false,
    bool stale = false,
    double? straightM,
    PackStatus status = PackStatus.riding,
  }) {
    return PackGap(
      userId: 'u1',
      role: PackRole.rider,
      chainageM: 4200,
      gapM: gapM,
      gapS: gapS,
      gapEstimated: gapEstimated,
      displayState: displayState,
      statusCode: status,
      statusAuto: false,
      offRoute: offRoute,
      straightM: straightM,
      stale: stale,
    );
  }

  Future<void> pump(
    WidgetTester tester,
    PackGap gap, {
    DateTime? lastSeenAt,
    DateTime? now,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: GapReadout(gap: gap, lastSeenAt: lastSeenAt, now: now),
        ),
      ),
    );
  }

  group('renders a gap only when the server says it may', () {
    testWidgets('ok state shows the distance behind', (tester) async {
      await pump(tester, gapWith(displayState: PackDisplayState.ok));

      expect(find.byKey(GapReadoutKeys.gapValue), findsOneWidget);
      expect(find.text('1.4 km'), findsOneWidget);
      expect(find.textContaining('BEHIND'), findsOneWidget);
      expect(find.byKey(GapReadoutKeys.estimateMarker), findsNothing);
    });

    testWidgets('the front rider is named, not given a gap of zero', (
      tester,
    ) async {
      await pump(
        tester,
        gapWith(displayState: PackDisplayState.ok, gapM: 0, gapS: 0),
      );

      expect(find.byKey(GapReadoutKeys.gapValue), findsNothing);
      expect(find.text('Front'), findsOneWidget);
    });
  });

  group('suppression', () {
    testWidgets('an off-route member never renders a gap number', (
      tester,
    ) async {
      // gap_m is deliberately non-null here: if the widget trusted the number
      // instead of display_state, this test would fail.
      await pump(
        tester,
        gapWith(
          displayState: PackDisplayState.offRoute,
          offRoute: true,
          gapM: -1400,
          straightM: 620,
        ),
      );

      expect(find.byKey(GapReadoutKeys.gapValue), findsNothing);
      expect(find.text('1.4 km'), findsNothing);
      expect(find.text('Off route'), findsOneWidget);
      // Straight-line distance replaces the gap, per the honesty rules.
      expect(find.text('620 m away'), findsOneWidget);
    });

    testWidgets('off route with no straight-line distance still shows none', (
      tester,
    ) async {
      await pump(
        tester,
        gapWith(
          displayState: PackDisplayState.offRoute,
          offRoute: true,
          straightM: null,
        ),
      );

      expect(find.byKey(GapReadoutKeys.gapValue), findsNothing);
      expect(find.text('straight line unknown'), findsOneWidget);
    });

    testWidgets('a stale member renders "last seen", never a gap', (
      tester,
    ) async {
      final seen = DateTime.utc(2026, 9, 8, 10);
      await pump(
        tester,
        gapWith(displayState: PackDisplayState.stale, stale: true),
        lastSeenAt: seen,
        now: seen.add(const Duration(minutes: 4)),
      );

      expect(find.byKey(GapReadoutKeys.gapValue), findsNothing);
      expect(find.text('1.4 km'), findsNothing);
      expect(find.text('Last seen'), findsOneWidget);
      expect(find.text('4m ago'), findsOneWidget);
    });

    testWidgets('stale with no fix at all does not invent a time', (
      tester,
    ) async {
      await pump(
        tester,
        gapWith(displayState: PackDisplayState.stale, stale: true),
      );

      expect(find.byKey(GapReadoutKeys.gapValue), findsNothing);
      expect(find.text('no fix yet'), findsOneWidget);
    });

    testWidgets('a member with no chainage yet shows "locating"', (
      tester,
    ) async {
      await pump(
        tester,
        gapWith(
          displayState: PackDisplayState.locating,
          gapM: null,
          gapS: null,
        ),
      );

      expect(find.byKey(GapReadoutKeys.gapValue), findsNothing);
      expect(find.text('Locating'), findsOneWidget);
    });

    testWidgets('display_state wins over a present gap_m in every suppressed '
        'state', (tester) async {
      for (final state in [
        PackDisplayState.offRoute,
        PackDisplayState.stale,
        PackDisplayState.locating,
      ]) {
        await pump(tester, gapWith(displayState: state, gapM: -2500));
        expect(
          find.byKey(GapReadoutKeys.gapValue),
          findsNothing,
          reason: '$state must not render a numeric gap',
        );
        expect(find.byKey(GapReadoutKeys.suppressed), findsOneWidget);
      }
    });
  });

  group('estimates', () {
    testWidgets('gap_estimated renders a visible estimate marker', (
      tester,
    ) async {
      await pump(
        tester,
        gapWith(
          displayState: PackDisplayState.estimated,
          gapEstimated: true,
          gapS: null,
        ),
      );

      expect(find.byKey(GapReadoutKeys.gapValue), findsOneWidget);
      expect(find.byKey(GapReadoutKeys.estimateMarker), findsOneWidget);
      expect(find.text('~'), findsOneWidget);
      expect(find.textContaining('EST'), findsOneWidget);
    });

    testWidgets('a measured gap carries no estimate marker', (tester) async {
      await pump(tester, gapWith(displayState: PackDisplayState.ok));

      expect(find.byKey(GapReadoutKeys.estimateMarker), findsNothing);
      expect(find.textContaining('EST'), findsNothing);
    });
  });

  group('formatting', () {
    test('distances read like a signboard', () {
      expect(formatDistance(0), '0 m');
      expect(formatDistance(-620), '620 m');
      expect(formatDistance(949), '949 m');
      expect(formatDistance(1400), '1.4 km');
      expect(formatDistance(24800), '25 km');
    });

    test('durations are coarsened to the precision the tick actually has', () {
      expect(formatDuration(const Duration(seconds: 45)), '45s');
      expect(formatDuration(const Duration(minutes: 4)), '4m');
      expect(formatDuration(const Duration(minutes: 90)), '1h 30m');
      expect(formatDuration(const Duration(hours: 2)), '2h');
    });
  });
}
