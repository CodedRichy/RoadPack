import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/circles/screens/join_circle_screen.dart';
import 'package:roadpack/features/circles/widgets/invite_code_input.dart';

void main() {
  testWidgets('JoinCircleScreen shows invite code input', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: JoinCircleScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Enter invite code'), findsOneWidget);
    expect(find.byType(InviteCodeInput), findsOneWidget);
  });
}
