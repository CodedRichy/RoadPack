import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/core/theme/theme.dart';
import 'package:roadpack/features/pack/models/pack_status.dart';
import 'package:roadpack/features/pack/screens/pack_status_sheet.dart';

void main() {
  Future<void> pump(WidgetTester tester, {PackStatus? current}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: PackStatusSheet(current: current)),
      ),
    );
  }

  testWidgets('offers every rider-settable status and no automatic ones', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: SizedBox(height: 900, child: PackStatusSheet()),
        ),
      ),
    );

    for (final status in PackStatus.values) {
      final finder = find.byKey(Key('pack-status-pick-${status.wire}'));
      expect(
        finder,
        status.userSettable ? findsOneWidget : findsNothing,
        reason: '${status.wire} settable=${status.userSettable}',
      );
    }
  });

  testWidgets('a rider cannot declare a possible incident by tapping', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Possible incident'), findsNothing);
    expect(find.text('No signal'), findsNothing);
    expect(find.text('Stopped, unexplained'), findsNothing);
  });

  testWidgets('picking a status commits in one tap (PM-32)', (tester) async {
    PackStatusChoice? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await PackStatusSheet.show(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    // Tap one: open the sheet. Tap two: commit. That is the whole budget.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pack-status-pick-refueling')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.status, PackStatus.refueling);
    expect(result!.note, isNull);
  });

  testWidgets('every target is glove-sized', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: SizedBox(height: 900, child: PackStatusSheet()),
        ),
      ),
    );

    for (final status in PackStatus.settable) {
      final size = tester.getSize(
        find.byKey(Key('pack-status-pick-${status.wire}')),
      );
      expect(
        size.height,
        greaterThanOrEqualTo(AppSpace.gloveTarget),
        reason: '${status.wire} must be pressable in gloves',
      );
      expect(size.width, greaterThanOrEqualTo(AppSpace.gloveTarget));
    }
  });

  testWidgets('the note is optional and capped at 140 characters', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Add a note (optional)'), findsOneWidget);
    await tester.tap(find.text('Add a note (optional)'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.maxLength, 140);
  });

  testWidgets('does not claim to summon help', (tester) async {
    await pump(tester);
    expect(find.textContaining('dial 112'), findsOneWidget);
  });
}
