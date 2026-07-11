import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/circles/screens/create_circle_screen.dart';
import 'package:roadpack/features/circles/widgets/circle_type_picker.dart';

void main() {
  testWidgets('CreateCircleScreen shows type picker', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CreateCircleScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircleTypePicker), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
    expect(find.text('Friends'), findsOneWidget);
  });

  testWidgets('selecting type pre-fills name field', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CreateCircleScreen())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField).first);
    expect(textField.controller?.text, 'My Family');
  });
}
