import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/tracking/db/tracking_database.dart';
import 'package:roadpack/features/tracking/models/tracking_state.dart';
import 'package:roadpack/features/tracking/services/trip_detector.dart';

void main() {
  late TrackingDatabase db;
  late TripDetector detector;

  setUp(() {
    db = TrackingDatabase(NativeDatabase.memory());
    detector = TripDetector(db);
  });

  tearDown(() async {
    detector.dispose();
    await db.close();
  });

  test('starts in idle state', () {
    expect(detector.currentState, TripState.idle);
  });

  test('transitions to recording on sustained speed > 5 km/h for 60s',
      () async {
    final start = DateTime(2026, 7, 12, 8, 0);

    // Simulate 70 seconds of movement (8 points, 10s apart)
    for (var i = 0; i < 8; i++) {
      detector.onLocationUpdate(LocationPoint(
        latitude: 9.93 + (i * 0.0001),
        longitude: 76.26,
        speed: 8.0, // m/s ~ 29 km/h
        timestamp: start.add(Duration(seconds: i * 10)),
      ));
    }

    // Allow async trip creation to complete
    await Future<void>.delayed(Duration.zero);

    expect(detector.currentState, TripState.recording);
    expect(detector.activeTrip, isNotNull);
  });

  test('stays idle on brief movement (< 60s)', () async {
    final start = DateTime(2026, 7, 12, 8, 0);

    // Only 30 seconds of movement
    for (var i = 0; i < 4; i++) {
      detector.onLocationUpdate(LocationPoint(
        latitude: 9.93 + (i * 0.0001),
        longitude: 76.26,
        speed: 8.0,
        timestamp: start.add(Duration(seconds: i * 10)),
      ));
    }

    await Future<void>.delayed(Duration.zero);
    expect(detector.currentState, TripState.idle);
  });

  test('transitions to recording on geofence exit', () async {
    detector.onGeofenceEvent(GeofenceExitEvent(
      identifier: 'home',
      timestamp: DateTime(2026, 7, 12, 8, 0),
      latitude: 9.93,
      longitude: 76.26,
    ));

    await Future<void>.delayed(Duration.zero);
    expect(detector.currentState, TripState.recording);
  });

  test('completes trip after sustained low speed (> 3 min)', () async {
    final start = DateTime(2026, 7, 12, 8, 0);

    // Start trip via geofence
    detector.onGeofenceEvent(GeofenceExitEvent(
      identifier: 'home',
      timestamp: start,
      latitude: 9.93,
      longitude: 76.26,
    ));
    await Future<void>.delayed(Duration.zero);

    // Travel > 500m (each 0.005 degree ~550m)
    for (var i = 0; i < 10; i++) {
      detector.onLocationUpdate(LocationPoint(
        latitude: 9.93 + (i * 0.005),
        longitude: 76.26,
        speed: 10.0,
        timestamp: start.add(Duration(seconds: 30 + (i * 15))),
      ));
    }

    // Stop for > 3 min (4 points, 1 min apart, speed ~0)
    for (var i = 0; i < 4; i++) {
      detector.onLocationUpdate(LocationPoint(
        latitude: 9.975,
        longitude: 76.26,
        speed: 0.3,
        timestamp: start.add(Duration(minutes: 5 + i)),
      ));
    }

    await Future<void>.delayed(Duration.zero);
    expect(detector.currentState, TripState.idle);

    final completedTrips = await db.getCompletedTrips();
    expect(completedTrips.length, 1);
    expect(completedTrips.first.distanceMeters, greaterThan(500));
  });

  test('discards trip under 500m', () async {
    final start = DateTime(2026, 7, 12, 8, 0);

    // Start trip via geofence
    detector.onGeofenceEvent(GeofenceExitEvent(
      identifier: 'home',
      timestamp: start,
      latitude: 9.93,
      longitude: 76.26,
    ));
    await Future<void>.delayed(Duration.zero);

    // Move only ~100m (0.001 degree ~ 111m)
    detector.onLocationUpdate(LocationPoint(
      latitude: 9.9301,
      longitude: 76.26,
      speed: 5.0,
      timestamp: start.add(const Duration(seconds: 30)),
    ));

    // Stop for > 3 min
    for (var i = 0; i < 4; i++) {
      detector.onLocationUpdate(LocationPoint(
        latitude: 9.9301,
        longitude: 76.26,
        speed: 0.0,
        timestamp: start.add(Duration(minutes: 3 + i)),
      ));
    }

    await Future<void>.delayed(Duration.zero);
    expect(detector.currentState, TripState.idle);

    final completedTrips = await db.getCompletedTrips();
    expect(completedTrips, isEmpty);
  });

  test('emits state changes on stream', () async {
    final states = <TripState>[];
    final sub = detector.stateStream.listen(states.add);

    detector.onGeofenceEvent(GeofenceExitEvent(
      identifier: 'home',
      timestamp: DateTime(2026, 7, 12, 8, 0),
      latitude: 9.93,
      longitude: 76.26,
    ));

    await Future<void>.delayed(Duration.zero);
    expect(states, contains(TripState.recording));

    await sub.cancel();
  });

  test('emits completed trips on stream', () async {
    final start = DateTime(2026, 7, 12, 8, 0);
    final completedTrips = <Trip>[];
    final sub = detector.tripCompletedStream.listen(completedTrips.add);

    detector.onGeofenceEvent(GeofenceExitEvent(
      identifier: 'home',
      timestamp: start,
      latitude: 9.93,
      longitude: 76.26,
    ));
    await Future<void>.delayed(Duration.zero);

    // Travel > 500m
    for (var i = 0; i < 10; i++) {
      detector.onLocationUpdate(LocationPoint(
        latitude: 9.93 + (i * 0.005),
        longitude: 76.26,
        speed: 10.0,
        timestamp: start.add(Duration(seconds: 30 + (i * 15))),
      ));
    }

    // Stop > 3 min
    for (var i = 0; i < 4; i++) {
      detector.onLocationUpdate(LocationPoint(
        latitude: 9.975,
        longitude: 76.26,
        speed: 0.3,
        timestamp: start.add(Duration(minutes: 5 + i)),
      ));
    }

    await Future<void>.delayed(Duration.zero);
    expect(completedTrips.length, 1);

    await sub.cancel();
  });
}
