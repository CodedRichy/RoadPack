import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/core/theme/app_theme.dart';
import 'package:roadpack/features/circles/models/circle.dart';
import 'package:roadpack/features/circles/providers/circle_actions_provider.dart';
import 'package:roadpack/features/circles/screens/create_circle_screen.dart';
import 'package:roadpack/features/consent/models/visibility_report.dart';

/// Records what the screen asked for, without touching Supabase.
class _RecordingActions implements CircleActions {
  bool? lastLocationSharing;

  @override
  Future<Circle> createCircle({
    required String name,
    required CircleType type,
    required bool locationSharing,
    int? maxMembers,
    DateTime? expiresAt,
  }) async {
    lastLocationSharing = locationSharing;
    return Circle(
      id: 'c1',
      name: name,
      type: type,
      createdBy: 'me',
      settings: {'location_sharing': locationSharing},
      createdAt: DateTime(2026, 1, 1),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '${invocation.memberName} not used by this test',
  );
}

Future<void> _pump(WidgetTester tester, _RecordingActions actions) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [circleActionsProvider.overrideWithValue(actions)],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const CreateCircleScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Family'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('live location sharing starts off and is a visible choice', (
    tester,
  ) async {
    final actions = _RecordingActions();
    await _pump(tester, actions);

    expect(find.text('Let this circle see live location'), findsOneWidget);
    final sharingSwitch = tester.widget<Switch>(find.byType(Switch));
    expect(
      sharingSwitch.value,
      isFalse,
      reason: 'sharing is a consent decision, not a creation-time default',
    );
    expect(
      find.textContaining('Members still get alerted if someone crashes'),
      findsOneWidget,
      reason: 'off must not read as "unprotected"',
    );
  });

  testWidgets('creating without touching the switch writes an explicit false', (
    tester,
  ) async {
    final actions = _RecordingActions();
    await _pump(tester, actions);

    await tester.ensureVisible(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(
      actions.lastLocationSharing,
      isFalse,
      reason: 'an absent key is indistinguishable from the bug we just fixed',
    );
  });

  testWidgets('turning the switch on carries through to the circle', (
    tester,
  ) async {
    final actions = _RecordingActions();
    await _pump(tester, actions);

    await tester.ensureVisible(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(actions.lastLocationSharing, isTrue);
  });

  test('the value written is the value can_view_location reads', () {
    // Round-trip: what createCircle puts in settings must be what the
    // visibility rule pulls back out.
    expect(
      VisibilityReport.readSharingFlag(const {'location_sharing': false}),
      isFalse,
    );
    expect(
      VisibilityReport.readSharingFlag(const {'location_sharing': true}),
      isTrue,
    );
  });
}
