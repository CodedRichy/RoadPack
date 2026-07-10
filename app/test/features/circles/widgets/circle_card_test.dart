import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/circles/models/circle.dart';
import 'package:roadpack/features/circles/models/circle_member.dart';
import 'package:roadpack/features/circles/widgets/circle_card.dart';

void main() {
  final testCircle = Circle(
    id: 'c1',
    name: 'My Family',
    type: CircleType.family,
    createdBy: 'u1',
    inviteCode: 'abc123',
    maxMembers: 15,
    createdAt: DateTime(2026, 7, 11),
  );

  testWidgets('CircleCard renders name, type, count, role', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CircleCard(
            circle: testCircle,
            memberCount: 3,
            userRole: CircleRole.admin,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('My Family'), findsOneWidget);
    expect(find.text('Family -- 3 members'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    await tester.tap(find.byType(ListTile));
    expect(tapped, isTrue);
  });
}
