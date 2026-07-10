import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/auth/widgets/phone_input.dart';

void main() {
  group('PhoneInput', () {
    testWidgets('shows +91 prefix', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PhoneInput(onSubmit: (_) {}),
          ),
        ),
      );
      expect(find.text('+91'), findsOneWidget);
    });

    testWidgets('calls onSubmit with prefixed phone number', (tester) async {
      String? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PhoneInput(onSubmit: (phone) => submitted = phone),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '9876543210');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(submitted, '+919876543210');
    });
  });
}
