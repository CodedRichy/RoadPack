import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/core/theme/theme.dart';
import 'package:roadpack/features/commute/models/commute_watch.dart';
import 'package:roadpack/features/commute/widgets/check_in_countdown.dart';
import 'package:roadpack/features/commute/widgets/running_late_button.dart';

void main() {
  Future<List<RunningLateSnooze>> pumpButton(
    WidgetTester tester, {
    ThemeData? theme,
  }) async {
    final pressed = <RunningLateSnooze>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.dark,
        home: Scaffold(body: RunningLateButton(onSnooze: pressed.add)),
      ),
    );
    return pressed;
  }

  testWidgets('extends by 30 minutes in a single tap (FR-044)', (tester) async {
    final pressed = await pumpButton(tester);

    await tester.tap(find.byKey(const Key('running-late-30')));
    await tester.pump();

    // One tap, no dialog, no confirmation step.
    expect(pressed, [RunningLateSnooze.thirty]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('offers an hour without hiding it behind a picker', (
    tester,
  ) async {
    final pressed = await pumpButton(tester);

    await tester.tap(find.byKey(const Key('running-late-60')));
    await tester.pump();

    expect(pressed, [RunningLateSnooze.sixty]);
  });

  testWidgets('the primary control meets the glove target', (tester) async {
    await pumpButton(tester);

    final size = tester.getSize(find.byKey(const Key('running-late-30')));
    expect(size.height, greaterThanOrEqualTo(AppSpace.gloveTarget));
  });

  testWidgets('promises, in words, that nobody is told', (tester) async {
    await pumpButton(tester);

    expect(find.text("I'm running late"), findsOneWidget);
    expect(find.text('+30 min'), findsOneWidget);
    expect(find.text('Nobody is told when you press this.'), findsOneWidget);
  });

  testWidgets('is inert while a response is in flight', (tester) async {
    final pressed = <RunningLateSnooze>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: RunningLateButton(enabled: false, onSnooze: pressed.add),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('running-late-30')));
    await tester.pump();
    expect(pressed, isEmpty);
  });

  for (final entry in {
    'night': AppTheme.dark,
    'sunlight': AppTheme.light,
  }.entries) {
    testWidgets('renders in ${entry.key} without exception', (tester) async {
      await pumpButton(tester, theme: entry.value);
      expect(tester.takeException(), isNull);
    });

    testWidgets('countdown renders in ${entry.key} with tabular digits', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: entry.value,
          home: const Scaffold(
            body: CheckInCountdown(
              remaining: Duration(minutes: 3, seconds: 7),
              total: CommuteWatch.escalationDelay,
              caption: 'If you do not answer, your circle is told.',
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('3:07'), findsOneWidget);
      expect(find.text('TIME TO ANSWER'), findsOneWidget);

      final digits = tester.widget<Text>(find.text('3:07'));
      expect(
        digits.style?.fontFeatures?.map((f) => f.feature),
        contains('tnum'),
      );
      expect(digits.style?.fontFamily, AppType.display);
    });
  }
}
