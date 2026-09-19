import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/core/theme/theme.dart';
import 'package:roadpack/features/pack/models/pack_status.dart';
import 'package:roadpack/features/pack/widgets/pack_status_chip.dart';

void main() {
  const night = AppSemantics.night;

  Future<void> pump(
    WidgetTester tester,
    PackStatus status, {
    bool isAutomatic = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: PackStatusChip(status: status, isAutomatic: isAutomatic),
        ),
      ),
    );
  }

  group('unreachable and stopped are different situations', () {
    test('and are drawn differently on every channel', () {
      final unreachable = PackStatusChip.visualFor(
        PackStatus.unreachable,
        true,
        night,
      );
      final stopped = PackStatusChip.visualFor(
        PackStatus.stopped,
        false,
        night,
      );

      // Different words is not enough — a rider glancing down reads shape and
      // colour before they read text.
      expect(unreachable.label, isNot(stopped.label));
      expect(unreachable.icon, isNot(stopped.icon));
      expect(unreachable.foreground, isNot(stopped.foreground));

      // Outline versus fill: the separation that survives greyscale, glare,
      // and red-green colour vision deficiency.
      expect(unreachable.isFilled, isFalse);
      expect(stopped.isFilled, isTrue);

      // A dead zone is something to act on; a parked rider is not.
      expect(unreachable.foreground, night.attentionAccent);
      expect(unreachable.isAutomatic, isTrue);
      expect(stopped.isAutomatic, isFalse);
    });

    testWidgets('and render distinct icons', (tester) async {
      await pump(tester, PackStatus.unreachable, isAutomatic: true);
      expect(find.byIcon(Icons.signal_cellular_off), findsOneWidget);
      expect(find.text('No signal'), findsOneWidget);

      await pump(tester, PackStatus.stopped);
      expect(find.byIcon(Icons.signal_cellular_off), findsNothing);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.text('Stopped'), findsOneWidget);
    });
  });

  group('automatic statuses render distinctly from manual ones (PM-43)', () {
    testWidgets('an automatic status is tagged AUTO', (tester) async {
      await pump(tester, PackStatus.unexplainedStop, isAutomatic: true);
      expect(find.byKey(const Key('pack-status-auto-tag')), findsOneWidget);
    });

    testWidgets('a rider-set status is not', (tester) async {
      await pump(tester, PackStatus.takingBreak);
      expect(find.byKey(const Key('pack-status-auto-tag')), findsNothing);
    });

    test('unexplained_stop and stopped are not the same claim', () {
      final auto = PackStatusChip.visualFor(
        PackStatus.unexplainedStop,
        true,
        night,
      );
      final manual = PackStatusChip.visualFor(PackStatus.stopped, false, night);

      expect(auto.icon, isNot(manual.icon));
      expect(auto.fill, isNot(manual.fill));
      expect(auto.fill, night.attentionAccent);
      expect(manual.fill, night.surface2);
    });
  });

  group('the emergency tier is reserved', () {
    test('possible_incident is the only pack state that reaches it', () {
      for (final status in PackStatus.values) {
        final v = PackStatusChip.visualFor(
          status,
          status.isAutomaticOnly,
          night,
        );
        final usesEmergency =
            v.fill == night.emergency || v.foreground == night.emergency;
        expect(
          usesEmergency,
          status == PackStatus.possibleIncident,
          reason: '${status.wire} must not borrow the emergency tier',
        );
      }
    });

    testWidgets('and it renders as a filled emergency field', (tester) async {
      await pump(tester, PackStatus.possibleIncident, isAutomatic: true);
      expect(find.byIcon(Icons.crisis_alert), findsOneWidget);
      expect(find.text('Possible incident'), findsOneWidget);
      expect(find.byKey(const Key('pack-status-auto-tag')), findsOneWidget);
    });
  });

  group('gaps and presence stay in their own tiers', () {
    test('no status borrows the watch tier — watchers are not status', () {
      for (final status in PackStatus.values) {
        final v = PackStatusChip.visualFor(status, false, night);
        expect(v.fill, isNot(night.watchAccent));
        expect(v.foreground, isNot(night.watchAccent));
      }
    });
  });
}
