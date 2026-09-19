import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roadpack/features/commute/models/commute_route.dart';
import 'package:roadpack/features/commute/models/commute_watch.dart';
import 'package:roadpack/features/commute/models/grace_window.dart';
import 'package:roadpack/features/commute/models/non_arrival_config.dart';
import 'package:roadpack/features/commute/providers/commute_watch_provider.dart';
import 'package:roadpack/features/commute/providers/non_arrival_config_provider.dart';
import 'package:roadpack/features/commute/services/commute_service.dart';

void main() {
  late List<http.Request> sent;

  ProviderContainer makeContainer({
    NonArrivalConfig config = const NonArrivalConfig(enabled: true),
  }) {
    sent = [];
    final container = ProviderContainer(
      overrides: [
        nonArrivalConfigProvider.overrideWithValue(config),
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
    return container;
  }

  CommuteRoute knownRoute({
    int repetitionCount = 4,
    bool nonArrivalEnabled = true,
    List<int> daysActive = const [1, 2, 3, 4, 5, 6, 7],
  }) {
    return CommuteRoute(
      id: 'route-1',
      name: 'Home to college',
      originLat: 9.93,
      originLng: 76.26,
      destLat: 10.0,
      destLng: 76.3,
      typicalStart: '08:00',
      typicalDurationMin: 30,
      daysActive: daysActive,
      repetitionCount: repetitionCount,
      nonArrivalEnabled: nonArrivalEnabled,
    );
  }

  group('starting a watch', () {
    test('opens a watch on a known route using the configured window', () {
      final container = makeContainer(
        config: const NonArrivalConfig(enabled: true, window: GraceWindow.ten),
      );
      final notifier = container.read(commuteWatchProvider.notifier);

      final watch = notifier.startFor(knownRoute(), day: DateTime(2026, 9, 7));

      expect(watch, isNotNull);
      expect(watch!.window, GraceWindow.ten);
      expect(watch.expectedArrivalAt, DateTime(2026, 9, 7, 8, 30));
      expect(watch.deadline, DateTime(2026, 9, 7, 8, 40));
      expect(container.read(commuteWatchProvider), watch);
    });

    test('refuses a route still below the repetition threshold', () {
      final container = makeContainer();
      final notifier = container.read(commuteWatchProvider.notifier);

      expect(
        notifier.startFor(knownRoute(repetitionCount: 2)),
        isNull,
        reason: 'a route the app has not learned must not raise alarms',
      );
      expect(container.read(commuteWatchProvider), isNull);
    });

    test('refuses when non-arrival is off for the user or for the route', () {
      final off = makeContainer(config: const NonArrivalConfig(enabled: false));
      expect(
        off.read(commuteWatchProvider.notifier).startFor(knownRoute()),
        isNull,
      );

      final routeOff = makeContainer();
      expect(
        routeOff
            .read(commuteWatchProvider.notifier)
            .startFor(knownRoute(nonArrivalEnabled: false)),
        isNull,
      );
    });

    test('refuses on a day the route does not run', () {
      final container = makeContainer();
      final watch = container
          .read(commuteWatchProvider.notifier)
          .startFor(
            knownRoute(daysActive: const [1]),
            day: DateTime(2026, 9, 12), // Saturday
          );
      expect(watch, isNull);
    });
  });

  group('I am running late (FR-044)', () {
    test(
      'extends the window and tells the server it is a false alarm',
      () async {
        final container = makeContainer();
        final notifier = container.read(commuteWatchProvider.notifier);
        notifier.adopt(
          CommuteWatch(
            routeId: 'route-1',
            expectedArrivalAt: DateTime(2026, 9, 7, 8, 30),
            incidentId: 'incident-1',
          ),
        );

        await notifier.imRunningLate(RunningLateSnooze.thirty);

        final watch = container.read(commuteWatchProvider)!;
        expect(watch.deadline, DateTime(2026, 9, 7, 9, 15)); // +15 grace +30
        expect(
          watch.phaseAt(DateTime(2026, 9, 7, 8, 50)),
          CommuteWatchPhase.travelling,
        );

        expect(sent.length, 1);
        expect(sent.single.url.path, endsWith('check-in-response'));
        expect(jsonDecode(sent.single.body)['response'], 'running_late');
      },
    );

    test('never marks the circle as notified', () async {
      final container = makeContainer();
      final notifier = container.read(commuteWatchProvider.notifier);
      notifier.adopt(
        CommuteWatch(
          routeId: 'route-1',
          expectedArrivalAt: DateTime(2026, 9, 7, 8, 30),
          incidentId: 'incident-1',
        ),
      );

      await notifier.imRunningLate(RunningLateSnooze.sixty);

      expect(container.read(commuteWatchProvider)!.hasNotifiedCircle, isFalse);
      final paths = sent.map((r) => r.url.path);
      expect(paths.any((p) => p.contains('cascade')), isFalse);
      expect(paths.any((p) => p.contains('incident-receive')), isFalse);
    });

    test('extends locally even with no incident to answer', () async {
      final container = makeContainer();
      final notifier = container.read(commuteWatchProvider.notifier);
      notifier.adopt(
        CommuteWatch(
          routeId: 'route-1',
          expectedArrivalAt: DateTime(2026, 9, 7, 8, 30),
        ),
      );

      await notifier.imRunningLate(RunningLateSnooze.thirty);

      expect(
        container.read(commuteWatchProvider)!.extension,
        const Duration(minutes: 30),
      );
      expect(sent, isEmpty);
    });
  });

  group('answering', () {
    test('"I am fine" resolves and cancels the incident', () async {
      final container = makeContainer();
      final notifier = container.read(commuteWatchProvider.notifier);
      notifier.adopt(
        CommuteWatch(
          routeId: 'route-1',
          expectedArrivalAt: DateTime(2026, 9, 7, 8, 30),
          incidentId: 'incident-1',
        ),
      );

      await notifier.imFine();

      expect(container.read(commuteWatchProvider)!.isResolved, isTrue);
      expect(jsonDecode(sent.single.body)['response'], 'fine');
    });

    test('"I need help" hands over to the cascade', () async {
      final container = makeContainer();
      final notifier = container.read(commuteWatchProvider.notifier);
      notifier.adopt(
        CommuteWatch(
          routeId: 'route-1',
          expectedArrivalAt: DateTime(2026, 9, 7, 8, 30),
          incidentId: 'incident-1',
        ),
      );

      await notifier.needHelp();

      final watch = container.read(commuteWatchProvider)!;
      expect(
        watch.phaseAt(DateTime(2026, 9, 7, 8, 31)),
        CommuteWatchPhase.escalated,
      );
      expect(jsonDecode(sent.single.body)['response'], 'need_help');
    });

    test('the prompt time is recorded once and not moved by later frames', () {
      final container = makeContainer();
      final notifier = container.read(commuteWatchProvider.notifier);
      notifier.adopt(
        CommuteWatch(
          routeId: 'route-1',
          expectedArrivalAt: DateTime(2026, 9, 7, 8, 30),
        ),
      );

      final first = DateTime(2026, 9, 7, 8, 47);
      notifier.markPrompted(at: first);
      notifier.markPrompted(at: DateTime(2026, 9, 7, 8, 49));

      expect(container.read(commuteWatchProvider)!.checkInPromptedAt, first);
      expect(
        container.read(commuteWatchProvider)!.escalatesAt,
        DateTime(2026, 9, 7, 8, 52),
      );
    });

    test('an already-escalated watch is not revived by a late prompt', () {
      final container = makeContainer();
      final notifier = container.read(commuteWatchProvider.notifier);
      notifier.adopt(
        CommuteWatch(
          routeId: 'route-1',
          expectedArrivalAt: DateTime(2026, 9, 7, 8, 30),
        ),
      );

      // The rider opens the screen an hour after the circle was told.
      notifier.markPrompted(at: DateTime(2026, 9, 7, 9, 50));

      final watch = container.read(commuteWatchProvider)!;
      expect(watch.checkInPromptedAt, isNull);
      expect(
        watch.phaseAt(DateTime(2026, 9, 7, 9, 50)),
        CommuteWatchPhase.escalated,
      );
    });

    test('arriving ends the watch before anything escalates', () {
      final container = makeContainer();
      final notifier = container.read(commuteWatchProvider.notifier);
      notifier.adopt(
        CommuteWatch(
          routeId: 'route-1',
          expectedArrivalAt: DateTime(2026, 9, 7, 8, 30),
        ),
      );

      notifier.arrived(at: DateTime(2026, 9, 7, 8, 40));

      final watch = container.read(commuteWatchProvider)!;
      expect(
        watch.phaseAt(DateTime(2026, 9, 7, 10, 0)),
        CommuteWatchPhase.resolved,
      );
      expect(sent, isEmpty);
    });
  });
}
