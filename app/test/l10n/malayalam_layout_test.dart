import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/core/theme/theme.dart';
import 'package:roadpack/features/home/screens/home_screen.dart';
import 'package:roadpack/features/home/widgets/milestone.dart';
import 'package:roadpack/l10n/l10n.dart';

/// Malayalam and Hindi run longer than English. A translated label that
/// overflows its control is not a cosmetic bug here — the milestone is the
/// front door's whole message, and a clipped "fix this" button is a rider who
/// never closes the gap.
///
/// Rendered on the smallest budget-phone width the pilot targets, at the
/// largest text scale a rider is likely to set.
void main() {
  Widget harness(Locale locale, Widget child, {ThemeData? theme}) {
    return MaterialApp(
      locale: locale,
      theme: theme ?? AppTheme.dark,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: kSupportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  ProtectionStatus status(ProtectionLevel level) => ProtectionStatus(
    level: level,
    crashDetection: level == ProtectionLevel.armed,
    tracking: level == ProtectionLevel.armed,
    nonArrival: level == ProtectionLevel.armed,
    emergencyContact: level == ProtectionLevel.armed,
  );

  for (final code in ['en', 'hi', 'ml']) {
    for (final level in ProtectionLevel.values) {
      testWidgets('milestone renders ${level.name} in $code without overflow', (
        tester,
      ) async {
        // 320dp: narrower than the Snapdragon 680-class handsets the pilot
        // targets, so passing here leaves headroom.
        tester.view.physicalSize = const Size(320 * 3, 640 * 3);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          harness(
            Locale(code),
            MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: Milestone(status: status(level)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the Malayalam fix-this button stays glove-sized', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      harness(const Locale('ml'), Milestone(status: status(ProtectionLevel.off))),
    );
    await tester.pumpAndSettle();

    final action = find.byKey(Milestone.gapActionKey);
    expect(action, findsOneWidget);
    expect(tester.getSize(action).height, AppSpace.gloveTarget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Malayalam copy actually reaches the milestone', (tester) async {
    late AppLocalizations ml;
    await tester.pumpWidget(
      harness(
        const Locale('ml'),
        Builder(
          builder: (context) {
            ml = context.l10n;
            return Milestone(status: status(ProtectionLevel.off));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    // A rider with no contact is never told they are covered, so the named
    // gap outranks the per-level headline — in every language.
    expect(find.text(ml.gapNoContactHeadline), findsOneWidget);
    expect(find.text(ml.gapNoContactAction), findsOneWidget);
    expect(find.text(ml.protectionEyebrow), findsOneWidget);
    // And is genuinely different from the English it replaced.
    expect(find.text('Nobody to call'), findsNothing);
    expect(find.text('PROTECTION'), findsNothing);
  });
}
