import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/core/theme/theme.dart';
import 'package:roadpack/features/pack/screens/join_pack_ride_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, {String? initialToken}) {
    return tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: JoinPackRideScreen(initialToken: initialToken),
        ),
      ),
    );
  }

  group('token extraction', () {
    // Riders paste links, not tokens. Anything else is a support burden.
    test('accepts a bare token', () {
      expect(extractShareToken('AbC-123_xyz'), 'AbC-123_xyz');
    });

    test('accepts a full share URL', () {
      expect(
        extractShareToken('https://roadpack.app/p/AbC-123_xyz'),
        'AbC-123_xyz',
      );
    });

    test('strips query strings, fragments and trailing slashes', () {
      expect(
        extractShareToken(
          'https://roadpack.app/p/AbC-123_xyz/?utm=whatsapp#top',
        ),
        'AbC-123_xyz',
      );
    });

    test('trims the whitespace a paste drags along', () {
      expect(extractShareToken('  https://roadpack.app/p/tok  '), 'tok');
    });

    test('empty stays empty rather than becoming a bogus token', () {
      expect(extractShareToken('   '), '');
    });
  });

  testWidgets('states what joining actually starts, before the tap', (
    tester,
  ) async {
    await pump(tester);

    expect(find.textContaining('the pack sees where you are'), findsOneWidget);
    expect(find.textContaining('leaving removes you'), findsOneWidget);
  });

  testWidgets('pre-fills a token handed in from a deep link', (tester) async {
    await pump(tester, initialToken: 'tok-abc');

    final field = tester.widget<TextField>(
      find.byKey(const Key('pack-join-token')),
    );
    expect(field.controller!.text, 'tok-abc');
  });

  testWidgets('refuses an empty link with a usable message', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('pack-join-submit')));
    await tester.pump();

    expect(find.byKey(const Key('pack-join-error')), findsOneWidget);
    expect(find.text('Paste the link somebody sent you'), findsOneWidget);
  });

  testWidgets('the join button is glove-sized', (tester) async {
    await pump(tester);

    final size = tester.getSize(find.byKey(const Key('pack-join-submit')));
    expect(size.height, greaterThanOrEqualTo(AppSpace.gloveTarget));
  });
}
