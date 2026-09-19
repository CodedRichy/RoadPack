import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/core/theme/theme.dart';
import 'package:roadpack/features/home/screens/home_screen.dart';
import 'package:roadpack/features/home/widgets/milestone.dart';

Widget _host(ProtectionStatus status, ThemeData theme) => MaterialApp(
  theme: theme,
  home: Scaffold(body: Milestone(status: status)),
);

void main() {
  final noContact = ProtectionStatus.resolve(
    crashDetection: true,
    tracking: true,
    nonArrival: true,
    emergencyContact: false,
  );

  for (final theme in {
    'night': AppTheme.dark,
    'sunlight': AppTheme.light,
  }.entries) {
    testWidgets('a rider with no contact is never told they are covered '
        '(${theme.key})', (tester) async {
      await tester.pumpWidget(_host(noContact, theme.value));

      expect(tester.takeException(), isNull);
      expect(find.text('Covered'), findsNothing);
      expect(find.text('Nobody to call'), findsOneWidget);
    });

    testWidgets('the degraded state says how to fix it (${theme.key})', (
      tester,
    ) async {
      await tester.pumpWidget(_host(noContact, theme.value));

      expect(find.text('Add a contact'), findsOneWidget);
      // Pressable while kitted up in gloves.
      final size = tester.getSize(find.byKey(Milestone.gapActionKey));
      expect(size.height, greaterThanOrEqualTo(AppSpace.gloveTarget));
    });

    testWidgets('a gap wears the attention tier, never emergency '
        '(${theme.key})', (tester) async {
      await tester.pumpWidget(_host(noContact, theme.value));

      final s = theme.value.extension<AppSemantics>()!;
      final bands = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((w) => (w.decoration as BoxDecoration?)?.color)
          .whereType<Color>()
          .toList();
      expect(bands, contains(s.attentionAccent));
      expect(bands, isNot(contains(s.emergency)));
    });
  }

  testWidgets('a fully covered rider gets no fix prompt', (tester) async {
    await tester.pumpWidget(
      _host(
        ProtectionStatus.resolve(
          crashDetection: true,
          tracking: true,
          nonArrival: true,
          emergencyContact: true,
        ),
        AppTheme.dark,
      ),
    );

    expect(find.text('Covered'), findsOneWidget);
    expect(find.text('Add a contact'), findsNothing);
  });
}
