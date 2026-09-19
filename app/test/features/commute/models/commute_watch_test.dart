import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/commute/models/commute_watch.dart';
import 'package:roadpack/features/commute/models/grace_window.dart';

final arrival = DateTime.utc(2026, 9, 7, 8, 45);

CommuteWatch watch({
  GraceWindow window = GraceWindow.fifteen,
  Duration extension = Duration.zero,
  DateTime? checkInPromptedAt,
  CheckInResponse? response,
  DateTime? arrivedAt,
}) {
  return CommuteWatch(
    routeId: 'r1',
    expectedArrivalAt: arrival,
    window: window,
    extension: extension,
    checkInPromptedAt: checkInPromptedAt,
    response: response,
    arrivedAt: arrivedAt,
  );
}

void main() {
  group('grace window (FR-042)', () {
    test('the deadline is expected arrival plus the default 15 minutes', () {
      expect(watch().deadline, arrival.add(const Duration(minutes: 15)));
    });

    test('honours a 10 or 30 minute window', () {
      expect(
        watch(window: GraceWindow.ten).deadline,
        arrival.add(const Duration(minutes: 10)),
      );
      expect(
        watch(window: GraceWindow.thirty).deadline,
        arrival.add(const Duration(minutes: 30)),
      );
    });
  });

  group('phases', () {
    test('travelling until the grace window lapses', () {
      final w = watch();
      expect(w.phaseAt(arrival), CommuteWatchPhase.travelling);
      expect(
        w.phaseAt(w.deadline.subtract(const Duration(seconds: 1))),
        CommuteWatchPhase.travelling,
      );
    });

    test('a lapsed window asks the user first, it does not escalate', () {
      final w = watch();
      expect(w.phaseAt(w.deadline), CommuteWatchPhase.pendingCheckIn);
      expect(
        w.phaseAt(w.deadline.add(const Duration(minutes: 4, seconds: 59))),
        CommuteWatchPhase.pendingCheckIn,
      );
    });

    test('escalates only after the check-in goes unanswered (FR-043)', () {
      final w = watch();
      expect(CommuteWatch.escalationDelay, const Duration(minutes: 5));
      expect(w.escalatesAt, w.deadline.add(const Duration(minutes: 5)));
      expect(w.phaseAt(w.escalatesAt), CommuteWatchPhase.escalated);
      expect(
        w.phaseAt(w.escalatesAt.add(const Duration(hours: 1))),
        CommuteWatchPhase.escalated,
      );
    });

    test('escalation counts from the prompt, not the deadline, when the '
        'prompt was delivered late', () {
      final prompted = arrival.add(const Duration(minutes: 20));
      final w = watch(checkInPromptedAt: prompted);
      expect(w.escalatesAt, prompted.add(const Duration(minutes: 5)));
      expect(
        w.phaseAt(prompted.add(const Duration(minutes: 4))),
        CommuteWatchPhase.pendingCheckIn,
      );
    });

    test('arriving resolves the watch and nothing escalates', () {
      final w = watch(arrivedAt: arrival.add(const Duration(minutes: 2)));
      expect(
        w.phaseAt(w.escalatesAt.add(const Duration(days: 1))),
        CommuteWatchPhase.resolved,
      );
      expect(w.isResolved, isTrue);
    });

    test('"I am fine" resolves the watch', () {
      final w = watch(response: CheckInResponse.fine);
      expect(w.phaseAt(w.escalatesAt), CommuteWatchPhase.resolved);
    });

    test('"I need help" escalates immediately, without waiting', () {
      final w = watch(response: CheckInResponse.needHelp);
      expect(w.phaseAt(arrival), CommuteWatchPhase.escalated);
    });
  });

  group('I am running late (FR-044)', () {
    test('extends the window by the chosen snooze', () {
      final extended = watch().extendBy(RunningLateSnooze.thirty);
      expect(
        extended.deadline,
        arrival.add(const Duration(minutes: 45)), // 15 grace + 30 snooze
      );
      expect(extended.extension, const Duration(minutes: 30));
    });

    test('offers exactly 30 and 60 minutes', () {
      expect(RunningLateSnooze.values.map((s) => s.minutes).toList(), [30, 60]);
    });

    test('returns a lapsed watch to travelling instead of escalating', () {
      final lapsed = watch(
        checkInPromptedAt: arrival.add(const Duration(minutes: 15)),
      );
      final now = lapsed.deadline.add(const Duration(minutes: 1));
      expect(lapsed.phaseAt(now), CommuteWatchPhase.pendingCheckIn);

      final extended = lapsed.extendBy(RunningLateSnooze.thirty);
      expect(extended.phaseAt(now), CommuteWatchPhase.travelling);
      expect(extended.checkInPromptedAt, isNull);
    });

    test('never notifies the circle', () {
      final extended = watch().extendBy(RunningLateSnooze.sixty);
      expect(extended.hasNotifiedCircle, isFalse);
      expect(
        extended.phaseAt(extended.deadline.subtract(const Duration(hours: 1))),
        CommuteWatchPhase.travelling,
      );
    });

    test('snoozes stack rather than replace', () {
      final twice = watch()
          .extendBy(RunningLateSnooze.thirty)
          .extendBy(RunningLateSnooze.thirty);
      expect(twice.extension, const Duration(minutes: 60));
    });
  });

  group('countdown', () {
    test('reports time left before the check-in is due', () {
      final w = watch();
      expect(
        w.remainingAt(arrival.add(const Duration(minutes: 5))),
        const Duration(minutes: 10),
      );
      expect(w.remainingAt(w.deadline), Duration.zero);
      expect(
        w.remainingAt(w.deadline.add(const Duration(minutes: 5))),
        Duration.zero,
      );
    });

    test('reports time left to answer before escalation', () {
      final w = watch();
      expect(
        w.remainingToEscalationAt(w.deadline.add(const Duration(minutes: 2))),
        const Duration(minutes: 3),
      );
      expect(w.remainingToEscalationAt(arrival), const Duration(minutes: 20));
    });
  });
}
