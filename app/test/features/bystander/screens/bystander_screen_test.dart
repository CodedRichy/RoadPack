import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/core/theme/theme.dart';
import 'package:roadpack/features/bystander/bystander.dart';

const _ice = IceProfile(
  bloodGroup: 'O+',
  allergies: ['Penicillin'],
  contacts: [IceContact(name: 'Asha', phone: '+919847012345', relation: 'Wife')],
);

BystanderSession _session({bool active = true}) => BystanderSession(
  incidentId: 'i1',
  incidentActive: active,
  victimDisplayName: 'Rahul',
  lat: 9.9816,
  lng: 76.2999,
  locationAt: DateTime.utc(2026, 9, 8, 10),
  contactName: 'Asha',
  contactPhone: '+919847012345',
  ice: _ice,
);

Future<List<Uri>> _pump(
  WidgetTester tester, {
  required BystanderSession session,
  bool sunlight = false,
}) async {
  final launched = <Uri>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bystanderSessionProvider.overrideWithValue(session),
        bystanderActionsProvider.overrideWithValue(
          BystanderActions(
            launcher: (uri) async {
              launched.add(uri);
              return true;
            },
          ),
        ),
        hospitalRepositoryProvider.overrideWithValue(
          HospitalRepository(store: InMemoryHospitalCacheStore()),
        ),
      ],
      child: MaterialApp(
        theme: sunlight ? AppTheme.light : AppTheme.dark,
        home: const BystanderScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return launched;
}

void main() {
  testWidgets('renders exactly the three bystander actions', (tester) async {
    await _pump(tester, session: _session());

    expect(find.byKey(BystanderScreen.dial112Key), findsOneWidget);
    expect(find.byKey(BystanderScreen.dialContactKey), findsOneWidget);
    expect(find.byKey(BystanderScreen.directionsKey), findsOneWidget);
  });

  testWidgets('dial 112 dispatches a tel: intent', (tester) async {
    final launched = await _pump(tester, session: _session());
    await tester.tap(find.byKey(BystanderScreen.dial112Key));
    await tester.pump();
    expect(launched.single, Uri.parse('tel:112'));
  });

  testWidgets('contact button dials contact one', (tester) async {
    final launched = await _pump(tester, session: _session());
    await tester.tap(find.byKey(BystanderScreen.dialContactKey));
    await tester.pump();
    expect(launched.single, Uri.parse('tel:+919847012345'));
  });

  testWidgets('directions opens a maps intent for the nearest hospital', (
    tester,
  ) async {
    final launched = await _pump(tester, session: _session());
    await tester.tap(find.byKey(BystanderScreen.directionsKey));
    await tester.pump();
    expect(launched.single.queryParameters['destination'], isNotNull);
  });

  testWidgets('shows readable coordinates and makes no 112 data-push claim', (
    tester,
  ) async {
    await _pump(tester, session: _session());
    expect(find.text('9.98160 N, 76.29990 E'), findsOneWidget);
    expect(
      find.textContaining('Read this out', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets('shows the Good Samaritan notice', (tester) async {
    await _pump(tester, session: _session());
    expect(find.textContaining('134A'), findsWidgets);
  });

  testWidgets('exposes ICE details only during an active incident', (
    tester,
  ) async {
    await _pump(tester, session: _session());
    expect(find.byKey(BystanderScreen.iceKey), findsOneWidget);
    expect(find.textContaining('O+'), findsWidgets);
  });

  testWidgets('withholds ICE details when the incident is not active', (
    tester,
  ) async {
    await _pump(tester, session: _session(active: false));
    expect(find.byKey(BystanderScreen.iceKey), findsNothing);
    expect(find.textContaining('O+'), findsNothing);
    expect(find.textContaining('Penicillin'), findsNothing);
  });

  testWidgets('switches to Malayalam with a Malayalam-capable font', (
    tester,
  ) async {
    await _pump(tester, session: _session());
    await tester.tap(find.text(BystanderLang.ml.chip));
    await tester.pumpAndSettle();

    final title = find.text(BystanderCopy.title(BystanderLang.ml));
    expect(title, findsOneWidget);
    expect(
      tester.widget<Text>(title).style!.fontFamilyFallback,
      contains('NotoSansMalayalam'),
      reason: 'Malayalam would render as tofu without the fallback',
    );
    // The English copy is gone: this is a switch, not a stack.
    expect(find.text(BystanderCopy.title(BystanderLang.en)), findsNothing);
  });

  testWidgets('the ICE symbol is scannable only during an active incident', (
    tester,
  ) async {
    await _pump(tester, session: _session());
    expect(find.byType(IceQrSymbol), findsOneWidget);

    await _pump(tester, session: _session(active: false));
    expect(find.byType(IceQrSymbol), findsNothing);
  });

  testWidgets('every action meets the glove touch target', (tester) async {
    await _pump(tester, session: _session());
    for (final key in [
      BystanderScreen.dial112Key,
      BystanderScreen.dialContactKey,
      BystanderScreen.directionsKey,
    ]) {
      expect(
        tester.getSize(find.byKey(key)).height,
        greaterThanOrEqualTo(AppSpace.gloveTarget),
        reason: '$key is smaller than the glove target',
      );
    }
  });

  testWidgets('renders in sunlight mode without shadows', (tester) async {
    await _pump(tester, session: _session(), sunlight: true);
    final decorated = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
    for (final d in decorated) {
      final deco = d.decoration;
      if (deco is BoxDecoration) {
        expect(deco.boxShadow ?? const [], isEmpty);
      }
    }
  });

  testWidgets('first aid guidance is marked as pending medical review', (
    tester,
  ) async {
    await _pump(tester, session: _session());
    expect(find.textContaining('medical review'), findsWidgets);
    expect(find.textContaining('Do not move'), findsWidgets);
  });
}
