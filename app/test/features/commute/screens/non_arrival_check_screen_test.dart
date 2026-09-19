import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roadpack/core/theme/theme.dart';
import 'package:roadpack/features/commute/models/commute_watch.dart';
import 'package:roadpack/features/commute/providers/commute_watch_provider.dart';
import 'package:roadpack/features/commute/screens/non_arrival_check_screen.dart';
import 'package:roadpack/features/commute/services/commute_service.dart';

void main() {
  late List<http.Request> sent;

  Future<ProviderContainer> pumpScreen(
    WidgetTester tester, {
    required CommuteWatch watch,
    ThemeData? theme,
  }) async {
    sent = [];
    final container = ProviderContainer(
      overrides: [
        commuteServiceProvider.overrideWithValue(
          CommuteService(
            () async => 'jwt',
            client: MockClient((request) async {
              sent.add(request);
              return http.Response('{"status":"ok"}', 200);
            }),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(commuteWatchProvider.notifier).adopt(watch);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme ?? AppTheme.dark,
          home: const NonArrivalCheckScreen(),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  CommuteWatch pendingWatch() => CommuteWatch(
    routeId: 'route-1',
    // Past the 15-minute grace window but inside the 5 minutes to answer,
    // so the screen opens in the pending check-in state.
    expectedArrivalAt: DateTime.now().subtract(const Duration(minutes: 17)),
    incidentId: 'incident-1',
  );

  testWidgets('reads as a question, not an emergency', (tester) async {
    await pumpScreen(tester, watch: pendingWatch());

    expect(find.text('Everything okay?'), findsOneWidget);
    expect(find.text('CHECKING IN'), findsOneWidget);
    expect(find.textContaining('Nobody has been told yet'), findsOneWidget);
    expect(find.text('YOUR CIRCLE HAS BEEN TOLD'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"I\'m running late" is one tap from the countdown', (
    tester,
  ) async {
    final container = await pumpScreen(tester, watch: pendingWatch());

    expect(find.text('TIME TO ANSWER'), findsOneWidget);
    await tester.tap(find.byKey(const Key('running-late-30')));
    await tester.pump();

    final watch = container.read(commuteWatchProvider)!;
    expect(watch.extension, const Duration(minutes: 30));
    expect(watch.phaseAt(DateTime.now()), CommuteWatchPhase.travelling);
    expect(watch.hasNotifiedCircle, isFalse);
  });

  testWidgets('running late answers the incident and nothing else', (
    tester,
  ) async {
    await pumpScreen(tester, watch: pendingWatch());

    await tester.tap(find.byKey(const Key('running-late-30')));
    await tester.pump();

    expect(sent.length, 1);
    expect(sent.single.url.path, endsWith('check-in-response'));
    expect(sent.single.body, contains('running_late'));
  });

  testWidgets('records when the rider was actually asked', (tester) async {
    final container = await pumpScreen(tester, watch: pendingWatch());
    expect(container.read(commuteWatchProvider)!.checkInPromptedAt, isNotNull);
  });

  testWidgets('an escalated watch says so and drops the snooze', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      watch: CommuteWatch(
        routeId: 'route-1',
        expectedArrivalAt: DateTime.now().subtract(const Duration(hours: 2)),
        incidentId: 'incident-1',
      ),
    );

    expect(find.text('YOUR CIRCLE HAS BEEN TOLD'), findsOneWidget);
    expect(find.byKey(const Key('running-late-30')), findsNothing);
    expect(find.byKey(const Key('check-in-need-help')), findsOneWidget);
  });

  testWidgets('renders in sunlight without exception', (tester) async {
    await pumpScreen(tester, watch: pendingWatch(), theme: AppTheme.light);
    expect(tester.takeException(), isNull);
  });
}
