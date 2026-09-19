import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/core/theme/app_theme.dart';
import 'package:roadpack/features/circles/models/circle.dart';
import 'package:roadpack/features/circles/models/circle_member.dart';
import 'package:roadpack/features/circles/screens/who_can_see_me_screen.dart';
import 'package:roadpack/features/consent/models/visibility_report.dart';
import 'package:roadpack/features/consent/services/sharing_review_store.dart';
import 'package:roadpack/features/consent/providers/visibility_provider.dart';

import '../../consent/fakes.dart';

Circle _circle(
  String id, {
  required String name,
  CircleType type = CircleType.family,
  bool sharing = false,
}) => Circle(
  id: id,
  name: name,
  type: type,
  createdBy: 'me',
  settings: sharing ? const {'location_sharing': true} : const {},
  createdAt: DateTime(2026, 1, 1),
);

CircleMember _member(
  String circleId,
  String userId, {
  String? name,
  CircleRole role = CircleRole.member,
}) => CircleMember(
  circleId: circleId,
  userId: userId,
  role: role,
  userName: name,
  joinedAt: DateTime(2026, 1, 1),
);

Future<void> _pump(WidgetTester tester, VisibilityReport report) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        whoCanSeeMeProvider.overrideWith((ref) async => report),
        sharingReviewStoreProvider.overrideWithValue(FakeSharingReviewStore()),
      ],
      child: MaterialApp(theme: AppTheme.dark, home: const WhoCanSeeMeScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists exactly the people can_view_location would permit', (
    tester,
  ) async {
    final report = VisibilityReport.from(
      selfUserId: 'me',
      circles: [
        _circle('c1', name: 'Home', sharing: true),
        _circle('c2', name: 'College', type: CircleType.commute),
      ],
      membersByCircleId: {
        'c1': [
          _member('c1', 'me', name: 'Me', role: CircleRole.admin),
          _member('c1', 'amma', name: 'Amma'),
        ],
        'c2': [
          _member('c2', 'me', name: 'Me'),
          _member('c2', 'warden', name: 'Warden'),
        ],
      },
    );

    await _pump(tester, report);

    expect(find.textContaining('Amma'), findsOneWidget);
    expect(
      find.textContaining('Warden'),
      findsNothing,
      reason: 'the College circle has no location_sharing flag',
    );
    expect(find.textContaining('1 person can see'), findsOneWidget);
  });

  testWidgets('says plainly when nobody can see the user', (tester) async {
    final report = VisibilityReport.from(
      selfUserId: 'me',
      circles: [_circle('c1', name: 'Home')],
      membersByCircleId: {
        'c1': [_member('c1', 'me'), _member('c1', 'amma', name: 'Amma')],
      },
    );

    await _pump(tester, report);

    expect(find.text('Nobody can see your location'), findsOneWidget);
    expect(find.textContaining('Amma'), findsNothing);
  });

  testWidgets('offers the sharing switch only to a circle admin', (
    tester,
  ) async {
    final report = VisibilityReport.from(
      selfUserId: 'me',
      circles: [
        _circle('c1', name: 'Home', sharing: true),
        _circle('c2', name: 'Riders', sharing: true),
      ],
      membersByCircleId: {
        'c1': [_member('c1', 'me', role: CircleRole.admin)],
        'c2': [_member('c2', 'me', role: CircleRole.member)],
      },
    );

    await _pump(tester, report);

    // Three switches, because the server has two terms and the user's
    // relationship to them differs per circle: the circle-wide flag on the
    // circle they administer, plus their own opt-out on each sharing circle.
    expect(find.byType(Switch), findsNWidgets(3));
    expect(
      find.text('Share my location with this circle'),
      findsNWidgets(2),
      reason: 'the member-side opt-out needs no admin rights',
    );
    expect(
      find.textContaining('Only this circle\'s admin can change'),
      findsOneWidget,
    );
    expect(find.text('Leave this circle'), findsOneWidget);
  });

  testWidgets('a member opting out is told they keep the safety net', (
    tester,
  ) async {
    final report = VisibilityReport.from(
      selfUserId: 'me',
      circles: [_circle('c1', name: 'Home', sharing: true)],
      membersByCircleId: {
        'c1': [_member('c1', 'me'), _member('c1', 'amma', name: 'Amma')],
      },
    );

    await _pump(tester, report);

    // The copy must not read as "turn off protection": someone who believes
    // that will leave the circle instead, losing the alert cascade too.
    expect(
      find.textContaining('if you crash they are still alerted'),
      findsOneWidget,
    );
    expect(find.textContaining('You stay a member'), findsOneWidget);
  });

  testWidgets('a failed load never reassures the user', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          whoCanSeeMeProvider.overrideWith(
            (ref) async => throw StateError('offline'),
          ),
          sharingReviewStoreProvider.overrideWithValue(
            FakeSharingReviewStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const WhoCanSeeMeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('We could not load who can see you'), findsOneWidget);
    expect(find.text('Nobody can see your location'), findsNothing);
  });

  testWidgets('opening the screen counts as the monthly review', (
    tester,
  ) async {
    final store = FakeSharingReviewStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          whoCanSeeMeProvider.overrideWith(
            (ref) async => const VisibilityReport([]),
          ),
          sharingReviewStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const WhoCanSeeMeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(store.value, isNotNull);
  });
}
