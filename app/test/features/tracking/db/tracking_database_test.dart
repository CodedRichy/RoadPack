import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/tracking/db/tracking_database.dart';

void main() {
  late TrackingDatabase db;

  setUp(() {
    db = TrackingDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Trips', () {
    test('insert and retrieve recording trip', () async {
      await db.insertTrip(TripsCompanion.insert(
        id: 'trip-1',
        startTime: DateTime(2026, 7, 12, 8, 0),
        originLat: 9.9312,
        originLng: 76.2673,
        state: 'recording',
      ));

      final trip = await db.getRecordingTrip();
      expect(trip, isNotNull);
      expect(trip!.id, 'trip-1');
      expect(trip.state, 'recording');
    });

    test('getRecordingTrip returns null when none recording', () async {
      final trip = await db.getRecordingTrip();
      expect(trip, isNull);
    });

    test('getCompletedTrips returns only completed in desc order', () async {
      await db.insertTrip(TripsCompanion.insert(
        id: 'old',
        startTime: DateTime(2026, 7, 10, 8, 0),
        originLat: 9.93,
        originLng: 76.26,
        state: 'completed',
      ));
      await db.insertTrip(TripsCompanion.insert(
        id: 'new',
        startTime: DateTime(2026, 7, 12, 8, 0),
        originLat: 9.93,
        originLng: 76.26,
        state: 'completed',
      ));
      await db.insertTrip(TripsCompanion.insert(
        id: 'recording',
        startTime: DateTime(2026, 7, 12, 9, 0),
        originLat: 9.93,
        originLng: 76.26,
        state: 'recording',
      ));

      final completed = await db.getCompletedTrips();
      expect(completed.length, 2);
      expect(completed.first.id, 'new');
      expect(completed.last.id, 'old');
    });

    test('deleteTripsOlderThan removes old trips', () async {
      await db.insertTrip(TripsCompanion.insert(
        id: 'old',
        startTime: DateTime(2026, 1, 1),
        originLat: 0,
        originLng: 0,
        state: 'completed',
      ));
      await db.insertTrip(TripsCompanion.insert(
        id: 'new',
        startTime: DateTime(2026, 7, 12),
        originLat: 0,
        originLng: 0,
        state: 'completed',
      ));

      final deleted = await db.deleteTripsOlderThan(DateTime(2026, 6, 1));
      expect(deleted, 1);

      final remaining = await db.getCompletedTrips();
      expect(remaining.length, 1);
      expect(remaining.first.id, 'new');
    });
  });

  group('RouteCandidates', () {
    test('insert and retrieve promotable candidates', () async {
      await db.insertCandidate(RouteCandidatesCompanion.insert(
        id: 'c1',
        originLat: 9.93,
        originLng: 76.26,
        destLat: 10.0,
        destLng: 76.3,
        daysSeen: '[1,2,3]',
        lastTripAt: DateTime(2026, 7, 12),
        tripCount: const Value(3),
      ));
      await db.insertCandidate(RouteCandidatesCompanion.insert(
        id: 'c2',
        originLat: 9.93,
        originLng: 76.26,
        destLat: 10.0,
        destLng: 76.3,
        daysSeen: '[1]',
        lastTripAt: DateTime(2026, 7, 12),
        tripCount: const Value(1),
      ));

      final promotable = await db.getPromotableCandidates();
      expect(promotable.length, 1);
      expect(promotable.first.id, 'c1');
    });

    test('deleteCandidate removes specific candidate', () async {
      await db.insertCandidate(RouteCandidatesCompanion.insert(
        id: 'c1',
        originLat: 9.93,
        originLng: 76.26,
        destLat: 10.0,
        destLng: 76.3,
        daysSeen: '[1]',
        lastTripAt: DateTime(2026, 7, 12),
      ));

      await db.deleteCandidate('c1');
      final all = await db.getAllCandidates();
      expect(all, isEmpty);
    });
  });

  group('KnownRoutesLocal', () {
    test('insert and retrieve known route', () async {
      await db.insertKnownRoute(KnownRoutesLocalCompanion.insert(
        id: 'r1',
        originLat: 9.93,
        originLng: 76.26,
        destLat: 10.0,
        destLng: 76.3,
        daysActive: '[1,2,3,4,5]',
      ));

      final routes = await db.getAllKnownRoutes();
      expect(routes.length, 1);
      expect(routes.first.nonArrivalEnabled, true);
      expect(routes.first.confidence, 0);
    });

    test('upsert replaces existing route', () async {
      await db.insertKnownRoute(KnownRoutesLocalCompanion.insert(
        id: 'r1',
        originLat: 9.93,
        originLng: 76.26,
        destLat: 10.0,
        destLng: 76.3,
        daysActive: '[1,2,3,4,5]',
      ));
      await db.insertKnownRoute(KnownRoutesLocalCompanion.insert(
        id: 'r1',
        originLat: 9.94,
        originLng: 76.27,
        destLat: 10.1,
        destLng: 76.4,
        daysActive: '[1,2,3]',
        confidence: const Value(0.5),
      ));

      final routes = await db.getAllKnownRoutes();
      expect(routes.length, 1);
      expect(routes.first.originLat, 9.94);
      expect(routes.first.confidence, 0.5);
    });
  });
}
