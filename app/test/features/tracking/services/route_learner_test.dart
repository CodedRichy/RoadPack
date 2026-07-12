import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/tracking/db/tracking_database.dart';
import 'package:roadpack/features/tracking/services/route_learner.dart';

void main() {
  late TrackingDatabase db;
  late RouteLearner learner;

  setUp(() {
    db = TrackingDatabase(NativeDatabase.memory());
    learner = RouteLearner(db);
  });

  tearDown(() async {
    await db.close();
  });

  Trip makeTrip({
    required String id,
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required DateTime startTime,
    int durationMin = 30,
  }) {
    return Trip(
      id: id,
      startTime: startTime,
      endTime: startTime.add(Duration(minutes: durationMin)),
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
      distanceMeters: 5000,
      routeGeometry: null,
      state: 'completed',
      matchedRouteId: null,
    );
  }

  test('first trip creates new route candidate', () async {
    final trip = makeTrip(
      id: 't1',
      originLat: 9.93,
      originLng: 76.26,
      destLat: 10.0,
      destLng: 76.3,
      startTime: DateTime(2026, 7, 12, 8, 0),
    );

    final result = await learner.processCompletedTrip(trip);
    expect(result.matched, false);
    expect(result.promoted, false);

    final candidates = await db.getAllCandidates();
    expect(candidates.length, 1);
    expect(candidates.first.tripCount, 1);
  });

  test('similar trip increments existing candidate', () async {
    final trip1 = makeTrip(
      id: 't1',
      originLat: 9.93,
      originLng: 76.26,
      destLat: 10.0,
      destLng: 76.3,
      startTime: DateTime(2026, 7, 7, 8, 0), // Monday
    );
    final trip2 = makeTrip(
      id: 't2',
      originLat: 9.9302, // ~20m away
      originLng: 76.2601,
      destLat: 10.0001,
      destLng: 76.3001,
      startTime: DateTime(2026, 7, 8, 8, 15), // Tuesday, similar time
    );

    await learner.processCompletedTrip(trip1);
    final result = await learner.processCompletedTrip(trip2);
    expect(result.matched, true);
    expect(result.promoted, false);

    final candidates = await db.getAllCandidates();
    expect(candidates.length, 1);
    expect(candidates.first.tripCount, 2);
  });

  test('third repetition promotes to known route', () async {
    for (var i = 0; i < 3; i++) {
      final trip = makeTrip(
        id: 't$i',
        originLat: 9.93 + (i * 0.0001), // within 500m
        originLng: 76.26,
        destLat: 10.0,
        destLng: 76.3,
        startTime: DateTime(2026, 7, 7 + i, 8, 0),
        durationMin: 25 + i,
      );
      await learner.processCompletedTrip(trip);
    }

    final routes = await db.getAllKnownRoutes();
    expect(routes.length, 1);
    expect(routes.first.repetitionCount, 3);

    final candidates = await db.getAllCandidates();
    expect(candidates, isEmpty);
  });

  test('distant trip creates new candidate (not match)', () async {
    final trip1 = makeTrip(
      id: 't1',
      originLat: 9.93,
      originLng: 76.26,
      destLat: 10.0,
      destLng: 76.3,
      startTime: DateTime(2026, 7, 12, 8, 0),
    );
    final trip2 = makeTrip(
      id: 't2',
      originLat: 9.0, // very far away
      originLng: 77.0,
      destLat: 9.5,
      destLng: 77.5,
      startTime: DateTime(2026, 7, 12, 8, 0),
    );

    await learner.processCompletedTrip(trip1);
    await learner.processCompletedTrip(trip2);

    final candidates = await db.getAllCandidates();
    expect(candidates.length, 2);
  });

  test('different time window creates new candidate', () async {
    final trip1 = makeTrip(
      id: 't1',
      originLat: 9.93,
      originLng: 76.26,
      destLat: 10.0,
      destLng: 76.3,
      startTime: DateTime(2026, 7, 12, 8, 0), // 8 AM
    );
    final trip2 = makeTrip(
      id: 't2',
      originLat: 9.93,
      originLng: 76.26,
      destLat: 10.0,
      destLng: 76.3,
      startTime: DateTime(2026, 7, 12, 20, 0), // 8 PM — 12h diff > 90 min
    );

    await learner.processCompletedTrip(trip1);
    await learner.processCompletedTrip(trip2);

    final candidates = await db.getAllCandidates();
    expect(candidates.length, 2);
  });

  test('trip without destination is ignored', () async {
    final trip = Trip(
      id: 't1',
      startTime: DateTime(2026, 7, 12, 8, 0),
      endTime: null,
      originLat: 9.93,
      originLng: 76.26,
      destLat: null,
      destLng: null,
      distanceMeters: null,
      routeGeometry: null,
      state: 'completed',
      matchedRouteId: null,
    );

    final result = await learner.processCompletedTrip(trip);
    expect(result.matched, false);
    expect(result.promoted, false);

    final candidates = await db.getAllCandidates();
    expect(candidates, isEmpty);
  });

  test('promoted route has correct confidence', () async {
    for (var i = 0; i < 3; i++) {
      final trip = makeTrip(
        id: 't$i',
        originLat: 9.93,
        originLng: 76.26,
        destLat: 10.0,
        destLng: 76.3,
        startTime: DateTime(2026, 7, 7 + i, 8, 0),
      );
      await learner.processCompletedTrip(trip);
    }

    final routes = await db.getAllKnownRoutes();
    // confidence = min(1.0, 3/10) = 0.3
    expect(routes.first.confidence, closeTo(0.3, 0.01));
  });
}
