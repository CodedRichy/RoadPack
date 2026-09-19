import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/core/theme/theme.dart';
import 'package:roadpack/features/home/screens/home_screen.dart';
import 'package:roadpack/features/home/widgets/milestone.dart';

void main() {
  for (final theme in {
    'night': AppTheme.dark,
    'sunlight': AppTheme.light,
  }.entries) {
    for (final level in ProtectionLevel.values) {
      testWidgets('milestone renders ${level.name} in ${theme.key}', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme.value,
            home: Scaffold(
              body: Milestone(
                status: ProtectionStatus(
                  level: level,
                  crashDetection: level == ProtectionLevel.armed,
                  tracking: level == ProtectionLevel.armed,
                  nonArrival: level == ProtectionLevel.armed,
                  emergencyContact: level == ProtectionLevel.armed,
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('PROTECTION'), findsOneWidget);
      });
    }
  }
}
