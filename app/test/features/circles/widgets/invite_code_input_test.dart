import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/circles/widgets/invite_code_input.dart';

void main() {
  testWidgets('InviteCodeInput calls onCompleted after 6 chars', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InviteCodeInput(onCompleted: (code) => result = code),
        ),
      ),
    );

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(6));

    for (var i = 0; i < 6; i++) {
      await tester.enterText(fields.at(i), 'a');
      await tester.pump();
    }

    expect(result, 'aaaaaa');
  });

  testWidgets('InviteCodeInput shows error text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InviteCodeInput(onCompleted: (_) {}, errorText: 'Invalid code'),
        ),
      ),
    );

    expect(find.text('Invalid code'), findsOneWidget);
  });
}
