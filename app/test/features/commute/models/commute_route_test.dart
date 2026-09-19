import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/commute/models/commute_route.dart';

CommuteRoute route({
  int repetitionCount = 3,
  RouteSource source = RouteSource.learned,
  String? typicalStart = '08:00',
  int? typicalDurationMin = 30,
  List<int> daysActive = const [1, 2, 3, 4, 5],
}) {
  return CommuteRoute(
    id: 'r1',
    name: 'Home to college',
    originLat: 9.93,
    originLng: 76.26,
    destLat: 10.0,
    destLng: 76.3,
    typicalStart: typicalStart,
    typicalDurationMin: typicalDurationMin,
    daysActive: daysActive,
    confidence: repetitionCount / 10,
    repetitionCount: repetitionCount,
    source: source,
  );
}

void main() {
  group('known-route threshold (FR-040)', () {
    test('a learned route below 3 repetitions is NOT known', () {
      expect(CommuteRoute.learningThreshold, 3);
      for (var n = 0; n < CommuteRoute.learningThreshold; n++) {
        final r = route(repetitionCount: n);
        expect(r.isKnown, isFalse, reason: '$n repetitions must not be known');
        expect(r.isLearning, isTrue);
        expect(r.repetitionsRemaining, CommuteRoute.learningThreshold - n);
      }
    });

    test('a learned route becomes known at 3 repetitions', () {
      final r = route(repetitionCount: 3);
      expect(r.isKnown, isTrue);
      expect(r.isLearning, isFalse);
      expect(r.repetitionsRemaining, 0);
    });

    test('confidence saturates at 5 repetitions', () {
      expect(route(repetitionCount: 4).isConfident, isFalse);
      expect(route(repetitionCount: 5).isConfident, isTrue);
      expect(CommuteRoute.confidentThreshold, 5);
    });

    test('a manually created route is known immediately (FR-041)', () {
      final r = route(repetitionCount: 0, source: RouteSource.manual);
      expect(r.isKnown, isTrue);
      expect(r.isLearning, isFalse);
    });

    test('a route without a start time or duration cannot be watched', () {
      expect(route(typicalStart: null).canWatch, isFalse);
      expect(route(typicalDurationMin: null).canWatch, isFalse);
      expect(route(daysActive: const []).canWatch, isFalse);
      expect(route().canWatch, isTrue);
    });
  });

  group('schedule', () {
    test('expected arrival is start plus typical duration on that day', () {
      final r = route(typicalStart: '08:15', typicalDurationMin: 45);
      final monday = DateTime(2026, 9, 7);
      expect(r.expectedArrivalOn(monday), DateTime(2026, 9, 7, 9, 0));
    });

    test('is only active on its learned weekdays', () {
      final r = route(daysActive: const [1, 3, 5]);
      expect(r.isActiveOn(DateTime(2026, 9, 7)), isTrue); // Monday
      expect(r.isActiveOn(DateTime(2026, 9, 8)), isFalse); // Tuesday
      expect(r.isActiveOn(DateTime(2026, 9, 12)), isFalse); // Saturday
    });

    test('returns null expected arrival when the schedule is incomplete', () {
      expect(route(typicalStart: null).expectedArrivalOn(DateTime(2026)), null);
    });
  });

  group('serialisation', () {
    test('round-trips through JSON', () {
      final r = route();
      expect(CommuteRoute.fromJson(r.toJson()), r);
    });

    test('reads a server known_routes row', () {
      final r = CommuteRoute.fromJson(const {
        'id': 'srv-1',
        'name': 'Work',
        'origin_lat': 9.9,
        'origin_lng': 76.2,
        'dest_lat': 10.1,
        'dest_lng': 76.4,
        'typical_start': '07:30',
        'typical_duration_min': 25,
        'days_active': [1, 2, 3],
        'confidence': 0.6,
        'repetition_count': 6,
        'non_arrival_enabled': false,
      });
      expect(r.repetitionCount, 6);
      expect(r.source, RouteSource.learned);
      expect(r.nonArrivalEnabled, isFalse);
      expect(r.daysActive, const [1, 2, 3]);
    });

    test('infers manual source from a zero repetition count', () {
      final r = CommuteRoute.fromJson(const {
        'id': 'm1',
        'origin_lat': 9.9,
        'origin_lng': 76.2,
        'dest_lat': 10.1,
        'dest_lng': 76.4,
        'repetition_count': 0,
      });
      expect(r.source, RouteSource.manual);
      expect(r.isKnown, isTrue);
    });
  });

  group('copyWith', () {
    test('replaces only what it is given', () {
      final r = route();
      final updated = r.copyWith(name: 'Renamed', nonArrivalEnabled: false);
      expect(updated.name, 'Renamed');
      expect(updated.nonArrivalEnabled, isFalse);
      expect(updated.id, r.id);
      expect(updated.repetitionCount, r.repetitionCount);
    });
  });
}
