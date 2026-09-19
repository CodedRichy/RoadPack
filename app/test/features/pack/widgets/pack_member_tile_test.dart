import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/core/theme/theme.dart';
import 'package:roadpack/features/pack/models/pack_gap.dart';
import 'package:roadpack/features/pack/models/pack_member.dart';
import 'package:roadpack/features/pack/models/pack_status.dart';
import 'package:roadpack/features/pack/widgets/gap_readout.dart';
import 'package:roadpack/features/pack/widgets/pack_member_tile.dart';

void main() {
  final seenAt = DateTime.utc(2026, 9, 8, 9, 30);
  final now = seenAt.add(const Duration(minutes: 7));

  PackGap gap({
    required PackDisplayState displayState,
    double? gapM = -800,
    PackStatus status = PackStatus.riding,
    bool statusAuto = false,
    bool offRoute = false,
    bool stale = false,
    double? straightM,
    PackRole role = PackRole.rider,
  }) => PackGap(
    userId: 'u9',
    role: role,
    chainageM: 3000,
    gapM: gapM,
    gapS: -95,
    displayState: displayState,
    statusCode: status,
    statusAuto: statusAuto,
    offRoute: offRoute,
    straightM: straightM,
    stale: stale,
  );

  PackMember member({
    PackStatus status = PackStatus.riding,
    bool statusAuto = false,
    DateTime? chainageAt,
  }) => PackMember(
    rideId: 'r1',
    userId: 'u9',
    displayName: 'Anoop',
    role: PackRole.rider,
    statusCode: status,
    statusAuto: statusAuto,
    chainageAt: chainageAt,
  );

  Future<void> pump(
    WidgetTester tester, {
    required PackGap g,
    PackMember? m,
    bool isCurrentUser = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: PackMemberTile(
            gap: g,
            member: m,
            isCurrentUser: isCurrentUser,
            now: now,
          ),
        ),
      ),
    );
  }

  testWidgets('shows the name and the gap for a located rider', (tester) async {
    await pump(
      tester,
      g: gap(displayState: PackDisplayState.ok),
      m: member(chainageAt: now),
    );

    expect(find.text('Anoop'), findsOneWidget);
    expect(find.byKey(GapReadoutKeys.gapValue), findsOneWidget);
    expect(find.text('800 m'), findsOneWidget);
  });

  testWidgets('marks the current user without hiding anyone else', (
    tester,
  ) async {
    await pump(
      tester,
      g: gap(displayState: PackDisplayState.ok),
      m: member(chainageAt: now),
      isCurrentUser: true,
    );

    expect(find.text('Anoop (you)'), findsOneWidget);
  });

  testWidgets('an off-route rider shows distance from the route, not a gap', (
    tester,
  ) async {
    await pump(
      tester,
      g: gap(
        displayState: PackDisplayState.offRoute,
        offRoute: true,
        straightM: 1250,
      ),
      m: member(chainageAt: now),
    );

    expect(find.byKey(GapReadoutKeys.gapValue), findsNothing);
    expect(find.text('800 m'), findsNothing);
    expect(find.text('Off route'), findsOneWidget);
    expect(find.text('1.3 km away'), findsOneWidget);
  });

  testWidgets('a stale rider shows how long ago they were last seen', (
    tester,
  ) async {
    await pump(
      tester,
      g: gap(displayState: PackDisplayState.stale, stale: true),
      m: member(chainageAt: seenAt),
    );

    expect(find.byKey(GapReadoutKeys.gapValue), findsNothing);
    expect(find.text('Last seen'), findsOneWidget);
    expect(find.text('7m ago'), findsOneWidget);
  });

  testWidgets('an unreachable rider and a stopped rider do not look alike', (
    tester,
  ) async {
    await pump(
      tester,
      g: gap(
        displayState: PackDisplayState.stale,
        status: PackStatus.unreachable,
        statusAuto: true,
        stale: true,
      ),
      m: member(status: PackStatus.unreachable, statusAuto: true),
    );
    expect(find.byIcon(Icons.signal_cellular_off), findsOneWidget);
    expect(find.byKey(const Key('pack-status-auto-tag')), findsOneWidget);
    expect(find.byKey(GapReadoutKeys.gapValue), findsNothing);

    await pump(
      tester,
      g: gap(displayState: PackDisplayState.ok, status: PackStatus.stopped),
      m: member(status: PackStatus.stopped, chainageAt: now),
    );
    expect(find.byIcon(Icons.signal_cellular_off), findsNothing);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.byKey(const Key('pack-status-auto-tag')), findsNothing);
    // A rider who chose to stop is still located; that gap is real.
    expect(find.byKey(GapReadoutKeys.gapValue), findsOneWidget);
  });

  testWidgets('falls back to the user id rather than blocking the gap', (
    tester,
  ) async {
    await pump(tester, g: gap(displayState: PackDisplayState.ok));

    expect(find.text('u9'), findsOneWidget);
    expect(find.byKey(GapReadoutKeys.gapValue), findsOneWidget);
  });

  testWidgets('rows clear the glove target', (tester) async {
    await pump(
      tester,
      g: gap(displayState: PackDisplayState.ok),
      m: member(chainageAt: now),
    );

    final size = tester.getSize(find.byType(PackMemberTile));
    expect(size.height, greaterThanOrEqualTo(AppSpace.gloveTarget));
  });
}
