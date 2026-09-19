import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Locale? locale, void Function(AppLocalizations) onBuild) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: kSupportedLocales,
    home: Builder(
      builder: (context) {
        onBuild(context.l10n);
        return Scaffold(body: Text(context.l10n.commonImOkay));
      },
    ),
  );
}

void main() {
  group('locale resolution', () {
    for (final code in ['en', 'hi', 'ml']) {
      testWidgets('$code resolves and renders', (tester) async {
        late AppLocalizations l10n;
        await tester.pumpWidget(_app(Locale(code), (v) => l10n = v));
        expect(tester.takeException(), isNull);
        expect(l10n.localeName, code);
        expect(find.text(l10n.commonImOkay), findsOneWidget);
      });
    }

    testWidgets('the three pilot languages differ from one another', (
      tester,
    ) async {
      final byLocale = <String, String>{};
      for (final code in ['en', 'hi', 'ml']) {
        await tester.pumpWidget(
          _app(Locale(code), (l10n) => byLocale[code] = l10n.crashDetectedTitle),
        );
      }
      expect(byLocale.values.toSet().length, 3);
    });

    testWidgets('an unsupported device locale falls back to English', (
      tester,
    ) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(_app(const Locale('ta'), (v) => l10n = v));
      expect(l10n.localeName, 'en');
    });

    test('the delegate accepts exactly the pilot languages', () {
      const delegate = AppLocalizations.delegate;
      expect(delegate.isSupported(const Locale('en')), isTrue);
      expect(delegate.isSupported(const Locale('hi')), isTrue);
      expect(delegate.isSupported(const Locale('ml')), isTrue);
      expect(delegate.isSupported(const Locale('ta')), isFalse);
    });
  });

  group('context.l10n without a delegate', () {
    // A roadside screen that renders foreign-but-readable text beats a screen
    // that renders a red error box, so the lookup degrades to English rather
    // than throwing when localisation is not wired up.
    testWidgets('degrades to English instead of throwing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Text(context.l10n.crashDetectedTitle),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('CRASH DETECTED'), findsOneWidget);
    });
  });

  group('plurals go through intl, not concatenation', () {
    testWidgets('English distinguishes one from many', (tester) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(_app(const Locale('en'), (v) => l10n = v));
      expect(l10n.crashCountdownBody(1), contains('1 second'));
      expect(l10n.crashCountdownBody(5), contains('5 seconds'));
      expect(l10n.circleCountWord(1), 'circle');
      expect(l10n.circleCountWord(3), 'circles');
    });

    testWidgets('Malayalam resolves the same plurals without falling back', (
      tester,
    ) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(_app(const Locale('ml'), (v) => l10n = v));
      final one = l10n.crashCountdownBody(1);
      final many = l10n.crashCountdownBody(9);
      expect(one, isNot(contains('Alerting')));
      expect(many, contains('9'));
    });
  });

  group('appLocaleProvider', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('defaults to null, which means follow the device', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(appLocaleProvider), isNull);
    });

    test('a stored language is restored', () async {
      SharedPreferences.setMockInitialValues({
        AppLocaleNotifier.prefsKey: 'ml',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(appLocaleProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(appLocaleProvider), const Locale('ml'));
    });

    test('a language we no longer ship is discarded, not honoured', () async {
      SharedPreferences.setMockInitialValues({
        AppLocaleNotifier.prefsKey: 'ta',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(appLocaleProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(appLocaleProvider), isNull);
    });

    test('setting a language persists it, and clearing it removes it',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(appLocaleProvider.notifier);

      await notifier.set(const Locale('hi'));
      expect(container.read(appLocaleProvider), const Locale('hi'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppLocaleNotifier.prefsKey), 'hi');

      await notifier.set(null);
      expect(container.read(appLocaleProvider), isNull);
      expect(prefs.getString(AppLocaleNotifier.prefsKey), isNull);
    });

    test('an unsupported language cannot be set at all', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(appLocaleProvider.notifier).set(const Locale('ta'));
      expect(container.read(appLocaleProvider), isNull);
    });
  });
}
