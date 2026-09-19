import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/core/theme/theme.dart';
import 'package:roadpack/features/pack/models/pack_ride.dart';
import 'package:roadpack/features/pack/models/pack_status.dart';
import 'package:roadpack/features/pack/widgets/share_link_card.dart';
import 'package:roadpack/features/pack/widgets/viewer_count_badge.dart';

void main() {
  final now = DateTime.utc(2026, 9, 8, 12);

  PackRide ride({
    PackRideStatus status = PackRideStatus.active,
    DateTime? revokedAt,
    DateTime? shareExpiresAt,
  }) => PackRide(
    id: 'r1',
    leaderId: 'u1',
    name: 'Munnar run',
    status: status,
    shareToken: 'tok-abc',
    shareExpiresAt: shareExpiresAt ?? DateTime.utc(2026, 9, 8, 18),
    shareRevokedAt: revokedAt,
    expiresAt: DateTime.utc(2026, 9, 8, 18),
  );

  Future<void> pump(WidgetTester tester, PackRide r, {int viewers = 0}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ShareLinkCard(ride: r, viewerCount: viewers, now: now),
        ),
      ),
    );
  }

  group('there is no covert mode', () {
    testWidgets('a live ride says so, unprompted', (tester) async {
      await pump(tester, ride(), viewers: 4);

      expect(find.text('This ride is being shared'), findsOneWidget);
      expect(find.byKey(ViewerCountBadge.badgeKey), findsOneWidget);
      expect(find.text('4 watching'), findsOneWidget);
    });

    testWidgets('the viewer count shows at zero too', (tester) async {
      await pump(tester, ride());

      // A badge that only appears when someone is looking teaches riders to
      // stop looking for it.
      expect(find.text('0 watching'), findsOneWidget);
    });

    testWidgets('a revoked link is described as off, not merely quiet', (
      tester,
    ) async {
      await pump(tester, ride(revokedAt: DateTime.utc(2026, 9, 8, 11)));

      expect(find.text('Sharing is off'), findsOneWidget);
      expect(find.text('not shared'), findsOneWidget);
      expect(find.byKey(const Key('pack-share-url')), findsNothing);
    });

    testWidgets('an ended ride cannot still be shared', (tester) async {
      await pump(tester, ride(status: PackRideStatus.ended));

      expect(find.text('Sharing is off'), findsOneWidget);
      expect(find.byKey(const Key('pack-share-url')), findsNothing);
    });
  });

  testWidgets('shows when the link dies on its own', (tester) async {
    await pump(tester, ride());
    expect(find.textContaining('expires in 6h'), findsOneWidget);
  });

  testWidgets('does not claim to summon help', (tester) async {
    await pump(tester, ride());
    expect(find.textContaining('does not call an ambulance'), findsNothing);
    // The disclaimer rides along with the shared message, not the card, so
    // the card must at least never overclaim.
    expect(find.textContaining('emergency services'), findsNothing);
  });
}
