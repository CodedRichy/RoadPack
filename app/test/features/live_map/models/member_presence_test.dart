import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/live_map/models/member_position.dart';
import 'package:roadpack/features/live_map/models/member_presence.dart';
import 'package:roadpack/l10n/app_localizations_en.dart';

MemberPosition _pos({
  required DateTime at,
  double? speedKmh,
  int? battery,
}) => MemberPosition(
  userId: 'u1',
  latitude: 9.9816,
  longitude: 76.2999,
  recordedAt: at,
  speedKmh: speedKmh,
  batteryLevel: battery,
);

void main() {
  final now = DateTime.utc(2026, 9, 8, 12, 0, 0);

  group('MemberPresence.resolve', () {
    test('no position at all is locating, never live', () {
      final p = MemberPresence.resolve(position: null, now: now);
      expect(p.state, MemberDisplayState.locating);
      expect(p.isLive, isFalse);
      expect(p.age, isNull);
    });

    test('fix inside the live window with motion is live', () {
      final p = MemberPresence.resolve(
        position: _pos(at: now.subtract(const Duration(seconds: 20)), speedKmh: 48),
        now: now,
      );
      expect(p.state, MemberDisplayState.live);
      expect(p.isLive, isTrue);
      expect(p.isStale, isFalse);
    });

    test('fresh fix with no motion is stationary, NOT unreachable', () {
      final p = MemberPresence.resolve(
        position: _pos(at: now.subtract(const Duration(seconds: 10)), speedKmh: 0),
        now: now,
      );
      expect(p.state, MemberDisplayState.stationary);
      expect(p.isLive, isTrue, reason: 'we are still hearing from the device');
      expect(p.hasSignal, isTrue);
    });

    test('exactly 60s old is already stale (boundary is inclusive of staleness)', () {
      final p = MemberPresence.resolve(
        position: _pos(at: now.subtract(const Duration(seconds: 60)), speedKmh: 40),
        now: now,
      );
      expect(p.state, MemberDisplayState.stale);
      expect(p.isLive, isFalse);
    });

    test('older than 60s is stale, greyed, age-labelled, never live', () {
      final p = MemberPresence.resolve(
        position: _pos(at: now.subtract(const Duration(minutes: 4)), speedKmh: 61),
        now: now,
      );
      expect(p.state, MemberDisplayState.stale);
      expect(p.isStale, isTrue);
      expect(p.isLive, isFalse);
      expect(p.age, const Duration(minutes: 4));
      expect(p.ageLabel(AppLocalizationsEn()), 'last seen 4m ago');
    });

    test('a device silent past the unreachable window reads as no signal', () {
      final p = MemberPresence.resolve(
        position: _pos(at: now.subtract(const Duration(minutes: 22)), speedKmh: 0),
        now: now,
      );
      expect(p.state, MemberDisplayState.unreachable);
      expect(p.hasSignal, isFalse);
      expect(p.isLive, isFalse);
    });

    test('stopped and unreachable are different states', () {
      final stopped = MemberPresence.resolve(
        position: _pos(at: now.subtract(const Duration(seconds: 5)), speedKmh: 0),
        now: now,
      );
      final unreachable = MemberPresence.resolve(
        position: _pos(at: now.subtract(const Duration(minutes: 30)), speedKmh: 0),
        now: now,
      );
      expect(stopped.state, isNot(unreachable.state));
      expect(stopped.hasSignal, isNot(unreachable.hasSignal));
      expect(
        stopped.headline(AppLocalizationsEn()),
        isNot(unreachable.headline(AppLocalizationsEn())),
      );
    });

    test('a clock skewed fix from the future is not treated as more live than now', () {
      final p = MemberPresence.resolve(
        position: _pos(at: now.add(const Duration(minutes: 5)), speedKmh: 30),
        now: now,
      );
      expect(p.age, Duration.zero);
      expect(p.state, MemberDisplayState.live);
    });

    test('speed is only trusted while the fix is fresh', () {
      final stale = MemberPresence.resolve(
        position: _pos(at: now.subtract(const Duration(minutes: 3)), speedKmh: 72),
        now: now,
      );
      expect(stale.trustedSpeedKmh, isNull);
      final fresh = MemberPresence.resolve(
        position: _pos(at: now.subtract(const Duration(seconds: 8)), speedKmh: 72),
        now: now,
      );
      expect(fresh.trustedSpeedKmh, 72);
    });
  });

  group('MemberPresence.formatAge', () {
    test('formats seconds, minutes and hours without jitter', () {
      expect(MemberPresence.formatAge(const Duration(seconds: 45)), '45s');
      expect(MemberPresence.formatAge(const Duration(minutes: 9, seconds: 30)), '9m');
      expect(MemberPresence.formatAge(const Duration(hours: 2, minutes: 5)), '2h 05m');
      expect(MemberPresence.formatAge(const Duration(days: 1, hours: 3)), '27h 00m');
    });
  });
}
