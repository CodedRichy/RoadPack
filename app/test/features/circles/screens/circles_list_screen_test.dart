import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/circles/models/circle.dart';
import 'package:roadpack/features/circles/providers/circles_provider.dart';
import 'package:roadpack/features/circles/screens/circles_list_screen.dart';

void main() {
  final testCircles = [
    Circle(
      id: 'c1',
      name: 'My Family',
      type: CircleType.family,
      createdBy: 'u1',
      inviteCode: 'abc123',
      maxMembers: 15,
      createdAt: DateTime(2026, 7, 11),
    ),
  ];

  testWidgets('shows empty state when no circles', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          circlesProvider.overrideWith(() => _FixedCirclesNotifier([])),
        ],
        child: const MaterialApp(home: CirclesListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create your first Safety Circle'), findsOneWidget);
  });

  testWidgets('shows circle card when circles exist', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          circlesProvider.overrideWith(
            () => _FixedCirclesNotifier(testCircles),
          ),
        ],
        child: const MaterialApp(home: CirclesListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Family'), findsOneWidget);
  });
}

class _FixedCirclesNotifier extends CirclesNotifier {
  _FixedCirclesNotifier(this._circles);
  final List<Circle> _circles;

  @override
  Future<List<Circle>> build() async => _circles;
}
