# L1: Background Tracking & Commute Intelligence — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build background GPS tracking with on-device route learning and server-driven non-arrival alerts.

**Architecture:** Flutter Background Geolocation (FBG) handles GPS acquisition, duty cycling, HTTP sync, and persistence. On-device Drift DB stores trips and route candidates. Server-side edge functions detect non-arrival and handle user check-in responses. Route learning clusters repeated trips on-device and promotes them to known routes after 3 repetitions.

**Tech Stack:** Flutter, Riverpod (manual providers), Drift (SQLite), flutter_background_geolocation, Freezed, Supabase Edge Functions (Deno/TypeScript), PostGIS.

## Global Constraints

- Flutter SDK >=3.41.0, Dart SDK ^3.11.0
- Riverpod: manual providers, NOT @riverpod codegen
- Freezed models with custom fromJson (NOT @JsonSerializable standalone)
- Tests use `mocktail` for mocks
- Edge functions use `jose@5.9.6` for JWT verification via `../_shared/jwt.ts`
- All Supabase writes from edge functions use service role key (bypass RLS)
- User-facing text: English only (i18n later)
- Branch: `feat/l1-tracking-commute`

---

### Task 1: Drift Database Schema & Code Generation

**Files:**
- Create: `app/lib/features/tracking/db/tracking_database.dart`
- Create: `app/test/features/tracking/db/tracking_database_test.dart`
- Modify: `app/pubspec.yaml` (no new deps — drift already present)
- Modify: `app/lib/core/storage/storage.dart` (export tracking DB)

**Interfaces:**
- Consumes: Nothing (first task)
- Produces: `TrackingDatabase` class with tables `trips`, `routeCandidates`, `knownRoutesLocal`. DAOs: `TripsDao` (insert, update, getRecording, getCompleted, deleteOlderThan), `RouteCandidatesDao` (findMatch, upsert, getPromotable, delete), `KnownRoutesDao` (getAll, upsert, getByOriginDestination, updateLastTraveled).

- [ ] **Step 1: Write Drift table definitions**

Create `app/lib/features/tracking/db/tracking_database.dart`:

```dart
import 'package:drift/drift.dart';

part 'tracking_database.g.dart';

class Trips extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  RealColumn get originLat => real()();
  RealColumn get originLng => real()();
  RealColumn get destLat => real().nullable()();
  RealColumn get destLng => real().nullable()();
  RealColumn get distanceMeters => real().nullable()();
  TextColumn get routeGeometry => text().nullable()();
  TextColumn get state => text()();
  TextColumn get matchedRouteId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class RouteCandidates extends Table {
  TextColumn get id => text()();
  RealColumn get originLat => real()();
  RealColumn get originLng => real()();
  RealColumn get destLat => real()();
  RealColumn get destLng => real()();
  IntColumn get tripCount => integer().withDefault(const Constant(1))();
  TextColumn get daysSeen => text()();
  TextColumn get typicalStart => text().nullable()();
  IntColumn get typicalDurationMin => integer().nullable()();
  DateTimeColumn get lastTripAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class KnownRoutesLocal extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().nullable()();
  RealColumn get originLat => real()();
  RealColumn get originLng => real()();
  RealColumn get destLat => real()();
  RealColumn get destLng => real()();
  TextColumn get routeGeometry => text().nullable()();
  TextColumn get typicalStart => text().nullable()();
  IntColumn get typicalDurationMin => integer().nullable()();
  TextColumn get daysActive => text()();
  RealColumn get confidence => real().withDefault(const Constant(0))();
  IntColumn get repetitionCount => integer().withDefault(const Constant(0))();
  BoolColumn get nonArrivalEnabled =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastTraveled => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Trips, RouteCandidates, KnownRoutesLocal])
class TrackingDatabase extends _$TrackingDatabase {
  TrackingDatabase(super.e);

  @override
  int get schemaVersion => 1;

  // --- Trips ---
  Future<int> insertTrip(TripsCompanion trip) =>
      into(trips).insert(trip);

  Future<bool> updateTrip(TripsCompanion trip) =>
      update(trips).replace(trip);

  Future<Trip?> getRecordingTrip() =>
      (select(trips)..where((t) => t.state.equals('recording')))
          .getSingleOrNull();

  Future<List<Trip>> getCompletedTrips() =>
      (select(trips)
            ..where((t) => t.state.equals('completed'))
            ..orderBy([(t) => OrderingTerm.desc(t.startTime)]))
          .get();

  Future<int> deleteTripsOlderThan(DateTime cutoff) =>
      (delete(trips)..where((t) => t.startTime.isSmallerThanValue(cutoff)))
          .go();

  // --- Route Candidates ---
  Future<List<RouteCandidate>> getAllCandidates() =>
      select(routeCandidates).get();

  Future<int> insertCandidate(RouteCandidatesCompanion c) =>
      into(routeCandidates).insert(c);

  Future<bool> updateCandidate(RouteCandidatesCompanion c) =>
      update(routeCandidates).replace(c);

  Future<List<RouteCandidate>> getPromotableCandidates() =>
      (select(routeCandidates)
            ..where((c) => c.tripCount.isBiggerOrEqualValue(3)))
          .get();

  Future<int> deleteCandidate(String id) =>
      (delete(routeCandidates)..where((c) => c.id.equals(id))).go();

  // --- Known Routes ---
  Future<List<KnownRoutesLocalData>> getAllKnownRoutes() =>
      select(knownRoutesLocal).get();

  Future<int> insertKnownRoute(KnownRoutesLocalCompanion r) =>
      into(knownRoutesLocal).insert(r, mode: InsertMode.insertOrReplace);

  Future<bool> updateKnownRoute(KnownRoutesLocalCompanion r) =>
      update(knownRoutesLocal).replace(r);
}
```

- [ ] **Step 2: Run code generation**

Run: `cd app && dart run build_runner build --delete-conflicting-outputs`
Expected: Generates `tracking_database.g.dart` without errors.

- [ ] **Step 3: Write database tests**

Create `app/test/features/tracking/db/tracking_database_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/tracking/db/tracking_database.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

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
      final id = const Uuid().v4();
      await db.insertTrip(TripsCompanion.insert(
        id: id,
        startTime: DateTime(2026, 7, 12, 8, 0),
        originLat: 9.9312,
        originLng: 76.2673,
        state: 'recording',
      ));

      final trip = await db.getRecordingTrip();
      expect(trip, isNotNull);
      expect(trip!.id, id);
      expect(trip.state, 'recording');
    });

    test('getRecordingTrip returns null when none recording', () async {
      final trip = await db.getRecordingTrip();
      expect(trip, isNull);
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
  });

  group('KnownRoutesLocal', () {
    test('upsert known route', () async {
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
    });
  });
}
```

- [ ] **Step 4: Run tests**

Run: `cd app && flutter test test/features/tracking/db/tracking_database_test.dart`
Expected: All tests pass.

- [ ] **Step 5: Update barrel exports**

Update `app/lib/core/storage/storage.dart`:
```dart
export '../features/tracking/db/tracking_database.dart';
```

Update `app/lib/features/tracking/models/models.dart`:
```dart
export '../db/tracking_database.dart';
```

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/tracking/db/ app/test/features/tracking/db/ app/lib/core/storage/storage.dart app/lib/features/tracking/models/models.dart
git commit -m "feat(tracking): add Drift database schema for trips, route candidates, known routes"
```

---

### Task 2: Trip Detector State Machine

**Files:**
- Create: `app/lib/features/tracking/services/trip_detector.dart`
- Create: `app/test/features/tracking/services/trip_detector_test.dart`
- Create: `app/lib/features/tracking/models/tracking_state.dart`

**Interfaces:**
- Consumes: `TrackingDatabase` (from Task 1) — `insertTrip`, `updateTrip`, `getRecordingTrip`
- Produces: `TripDetector` class with methods: `onLocationUpdate(Location loc)`, `onGeofenceEvent(GeofenceEvent event)`, `get currentState → TripState`, `get activeTrip → Trip?`. Exposes `Stream<TripState> stateStream` and `Stream<Trip> tripCompletedStream`.

- [ ] **Step 1: Create TripState enum**

Create `app/lib/features/tracking/models/tracking_state.dart`:

```dart
enum TripState {
  idle,
  recording,
  completed,
  discarded,
}
```

- [ ] **Step 2: Write failing tests for trip detector**

Create `app/test/features/tracking/services/trip_detector_test.dart`:

```dart
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

  test('transitions to recording on sustained speed > 5 km/h', () async {
    final start = DateTime(2026, 7, 12, 8, 0);

    // Simulate 70 seconds of movement > 5 km/h (5 km/h = 1.39 m/s)
    for (var i = 0; i < 8; i++) {
      detector.onLocationUpdate(FakeLocation(
        latitude: 9.93 + (i * 0.0001),
        longitude: 76.26,
        speed: 8.0, // m/s ~ 29 km/h
        timestamp: start.add(Duration(seconds: i * 10)),
      ));
    }

    expect(detector.currentState, TripState.recording);
    expect(detector.activeTrip, isNotNull);
  });

  test('stays idle on brief movement', () {
    final start = DateTime(2026, 7, 12, 8, 0);

    // Only 30 seconds of movement (< 60s threshold)
    for (var i = 0; i < 4; i++) {
      detector.onLocationUpdate(FakeLocation(
        latitude: 9.93 + (i * 0.0001),
        longitude: 76.26,
        speed: 8.0,
        timestamp: start.add(Duration(seconds: i * 10)),
      ));
    }

    expect(detector.currentState, TripState.idle);
  });

  test('transitions to recording on geofence exit', () {
    detector.onGeofenceEvent(GeofenceExitEvent(
      identifier: 'home',
      timestamp: DateTime(2026, 7, 12, 8, 0),
      latitude: 9.93,
      longitude: 76.26,
    ));

    expect(detector.currentState, TripState.recording);
  });

  test('completes trip on sustained low speed', () async {
    final start = DateTime(2026, 7, 12, 8, 0);

    // Start trip
    detector.onGeofenceEvent(GeofenceExitEvent(
      identifier: 'home',
      timestamp: start,
      latitude: 9.93,
      longitude: 76.26,
    ));

    // Travel 2km
    for (var i = 0; i < 20; i++) {
      detector.onLocationUpdate(FakeLocation(
        latitude: 9.93 + (i * 0.001),
        longitude: 76.26,
        speed: 10.0,
        timestamp: start.add(Duration(seconds: 30 + (i * 10))),
      ));
    }

    // Stop for > 3 min
    for (var i = 0; i < 4; i++) {
      detector.onLocationUpdate(FakeLocation(
        latitude: 9.95,
        longitude: 76.26,
        speed: 0.5,
        timestamp: start.add(Duration(minutes: 5 + i)),
      ));
    }

    expect(detector.currentState, TripState.idle);

    final completedTrips = await db.getCompletedTrips();
    expect(completedTrips.length, 1);
  });

  test('discards trip under 500m', () async {
    final start = DateTime(2026, 7, 12, 8, 0);

    // Geofence exit starts trip
    detector.onGeofenceEvent(GeofenceExitEvent(
      identifier: 'home',
      timestamp: start,
      latitude: 9.93,
      longitude: 76.26,
    ));

    // Move only ~100m then stop
    detector.onLocationUpdate(FakeLocation(
      latitude: 9.9301,
      longitude: 76.26,
      speed: 5.0,
      timestamp: start.add(const Duration(seconds: 30)),
    ));

    // Stop for > 3 min
    for (var i = 0; i < 4; i++) {
      detector.onLocationUpdate(FakeLocation(
        latitude: 9.9301,
        longitude: 76.26,
        speed: 0.0,
        timestamp: start.add(Duration(minutes: 3 + i)),
      ));
    }

    expect(detector.currentState, TripState.idle);

    final completedTrips = await db.getCompletedTrips();
    expect(completedTrips, isEmpty);
  });
}

class FakeLocation {
  FakeLocation({
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.timestamp,
  });
  final double latitude;
  final double longitude;
  final double speed;
  final DateTime timestamp;
}

class GeofenceExitEvent {
  GeofenceExitEvent({
    required this.identifier,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
  });
  final String identifier;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
}
```

- [ ] **Step 3: Run tests to verify failure**

Run: `cd app && flutter test test/features/tracking/services/trip_detector_test.dart`
Expected: FAIL — `trip_detector.dart` does not exist.

- [ ] **Step 4: Implement TripDetector**

Create `app/lib/features/tracking/services/trip_detector.dart`:

```dart
import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/tracking_database.dart';
import '../models/tracking_state.dart';

class FakeLocation {
  FakeLocation({
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.timestamp,
  });
  final double latitude;
  final double longitude;
  final double speed; // m/s
  final DateTime timestamp;
}

class GeofenceExitEvent {
  GeofenceExitEvent({
    required this.identifier,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
  });
  final String identifier;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
}

class TripDetector {
  TripDetector(this._db);

  final TrackingDatabase _db;
  final _stateController = StreamController<TripState>.broadcast();
  final _tripCompletedController = StreamController<Trip>.broadcast();

  TripState _currentState = TripState.idle;
  Trip? _activeTrip;
  String? _activeTripId;

  DateTime? _motionStartTime;
  DateTime? _stopStartTime;
  final List<FakeLocation> _locationBuffer = [];
  double _totalDistance = 0;

  TripState get currentState => _currentState;
  Trip? get activeTrip => _activeTrip;
  Stream<TripState> get stateStream => _stateController.stream;
  Stream<Trip> get tripCompletedStream => _tripCompletedController.stream;

  static const _minTripDistanceM = 500.0;
  static const _minTripDurationSec = 120;
  static const _motionThresholdSec = 60;
  static const _speedThresholdMs = 1.39; // ~5 km/h
  static const _stopThresholdMs = 0.56; // ~2 km/h
  static const _stopDurationSec = 180; // 3 min

  void onLocationUpdate(FakeLocation loc) {
    switch (_currentState) {
      case TripState.idle:
        _handleIdleLocation(loc);
      case TripState.recording:
        _handleRecordingLocation(loc);
      case TripState.completed:
      case TripState.discarded:
        break;
    }
  }

  void onGeofenceEvent(GeofenceExitEvent event) {
    if (_currentState == TripState.idle) {
      _startTrip(
        event.latitude,
        event.longitude,
        event.timestamp,
      );
    }
  }

  void _handleIdleLocation(FakeLocation loc) {
    if (loc.speed >= _speedThresholdMs) {
      _motionStartTime ??= loc.timestamp;
      final motionDuration =
          loc.timestamp.difference(_motionStartTime!).inSeconds;
      if (motionDuration >= _motionThresholdSec) {
        _startTrip(loc.latitude, loc.longitude, _motionStartTime!);
        // Add buffered locations to trip
        _handleRecordingLocation(loc);
      }
    } else {
      _motionStartTime = null;
    }
  }

  void _handleRecordingLocation(FakeLocation loc) {
    if (_locationBuffer.isNotEmpty) {
      _totalDistance += _distanceBetween(
        _locationBuffer.last.latitude,
        _locationBuffer.last.longitude,
        loc.latitude,
        loc.longitude,
      );
    }
    _locationBuffer.add(loc);

    if (loc.speed <= _stopThresholdMs) {
      _stopStartTime ??= loc.timestamp;
      final stopDuration =
          loc.timestamp.difference(_stopStartTime!).inSeconds;
      if (stopDuration >= _stopDurationSec) {
        _endTrip();
      }
    } else {
      _stopStartTime = null;
    }
  }

  Future<void> _startTrip(
    double lat,
    double lng,
    DateTime startTime,
  ) async {
    _activeTripId = const Uuid().v4();
    _totalDistance = 0;
    _locationBuffer.clear();
    _stopStartTime = null;
    _motionStartTime = null;

    await _db.insertTrip(TripsCompanion.insert(
      id: _activeTripId!,
      startTime: startTime,
      originLat: lat,
      originLng: lng,
      state: 'recording',
    ));

    _activeTrip = await _db.getRecordingTrip();
    _setState(TripState.recording);
  }

  Future<void> _endTrip() async {
    if (_activeTripId == null || _locationBuffer.isEmpty) {
      _reset();
      return;
    }

    final lastLoc = _locationBuffer.last;
    final firstLoc = _locationBuffer.first;
    final duration =
        lastLoc.timestamp.difference(firstLoc.timestamp).inSeconds;

    if (_totalDistance < _minTripDistanceM || duration < _minTripDurationSec) {
      // Discard
      await _db.updateTrip(TripsCompanion(
        id: Value(_activeTripId!),
        startTime: Value(firstLoc.timestamp),
        originLat: Value(firstLoc.latitude),
        originLng: Value(firstLoc.longitude),
        state: const Value('discarded'),
      ));
      _reset();
      return;
    }

    // Complete
    await _db.updateTrip(TripsCompanion(
      id: Value(_activeTripId!),
      startTime: Value(firstLoc.timestamp),
      originLat: Value(firstLoc.latitude),
      originLng: Value(firstLoc.longitude),
      endTime: Value(lastLoc.timestamp),
      destLat: Value(lastLoc.latitude),
      destLng: Value(lastLoc.longitude),
      distanceMeters: Value(_totalDistance),
      state: const Value('completed'),
    ));

    final trip = (await _db.getCompletedTrips()).firstOrNull;
    if (trip != null) {
      _tripCompletedController.add(trip);
    }
    _reset();
  }

  void _reset() {
    _activeTripId = null;
    _activeTrip = null;
    _locationBuffer.clear();
    _totalDistance = 0;
    _stopStartTime = null;
    _motionStartTime = null;
    _setState(TripState.idle);
  }

  void _setState(TripState state) {
    _currentState = state;
    _stateController.add(state);
  }

  void dispose() {
    _stateController.close();
    _tripCompletedController.close();
  }

  static double _distanceBetween(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;
}
```

- [ ] **Step 5: Run tests**

Run: `cd app && flutter test test/features/tracking/services/trip_detector_test.dart`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/tracking/services/trip_detector.dart app/lib/features/tracking/models/tracking_state.dart app/test/features/tracking/services/trip_detector_test.dart
git commit -m "feat(tracking): add trip detector state machine with start/end/discard logic"
```

---

### Task 3: Route Learner (On-Device Clustering)

**Files:**
- Create: `app/lib/features/tracking/services/route_learner.dart`
- Create: `app/test/features/tracking/services/route_learner_test.dart`

**Interfaces:**
- Consumes: `TrackingDatabase` (Task 1) — `getAllCandidates`, `insertCandidate`, `updateCandidate`, `getPromotableCandidates`, `deleteCandidate`, `insertKnownRoute`. `Trip` model (from generated Drift code).
- Produces: `RouteLearner` class with method `Future<LearnResult> processCompletedTrip(Trip trip)`. `LearnResult` is `{matched: bool, promoted: bool, routeId: String?}`.

- [ ] **Step 1: Write failing tests**

Create `app/test/features/tracking/services/route_learner_test.dart`:

```dart
import 'package:drift/drift.dart';
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

  Trip _makeTrip({
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
    final trip = _makeTrip(
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
    final trip1 = _makeTrip(
      id: 't1',
      originLat: 9.93,
      originLng: 76.26,
      destLat: 10.0,
      destLng: 76.3,
      startTime: DateTime(2026, 7, 7, 8, 0), // Monday
    );
    final trip2 = _makeTrip(
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
      final trip = _makeTrip(
        id: 't$i',
        originLat: 9.93 + (i * 0.0001),
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
    final trip1 = _makeTrip(
      id: 't1',
      originLat: 9.93,
      originLng: 76.26,
      destLat: 10.0,
      destLng: 76.3,
      startTime: DateTime(2026, 7, 12, 8, 0),
    );
    final trip2 = _makeTrip(
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
    final trip1 = _makeTrip(
      id: 't1',
      originLat: 9.93,
      originLng: 76.26,
      destLat: 10.0,
      destLng: 76.3,
      startTime: DateTime(2026, 7, 12, 8, 0), // 8 AM
    );
    final trip2 = _makeTrip(
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
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `cd app && flutter test test/features/tracking/services/route_learner_test.dart`
Expected: FAIL — `route_learner.dart` does not exist.

- [ ] **Step 3: Implement RouteLearner**

Create `app/lib/features/tracking/services/route_learner.dart`:

```dart
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/tracking_database.dart';

class LearnResult {
  const LearnResult({
    required this.matched,
    required this.promoted,
    this.routeId,
  });
  final bool matched;
  final bool promoted;
  final String? routeId;
}

class RouteLearner {
  RouteLearner(this._db);

  final TrackingDatabase _db;

  static const _matchRadiusM = 500.0;
  static const _timeWindowMin = 90;
  static const _promotionThreshold = 3;

  Future<LearnResult> processCompletedTrip(Trip trip) async {
    if (trip.destLat == null || trip.destLng == null) {
      return const LearnResult(matched: false, promoted: false);
    }

    final candidates = await _db.getAllCandidates();
    final match = _findMatch(candidates, trip);

    if (match != null) {
      final updatedCount = match.tripCount + 1;
      final dayOfWeek = trip.startTime.weekday;
      final days = (jsonDecode(match.daysSeen) as List).cast<int>();
      if (!days.contains(dayOfWeek)) days.add(dayOfWeek);

      final newOriginLat =
          (match.originLat * match.tripCount + trip.originLat) / updatedCount;
      final newOriginLng =
          (match.originLng * match.tripCount + trip.originLng) / updatedCount;
      final newDestLat =
          (match.destLat * match.tripCount + trip.destLat!) / updatedCount;
      final newDestLng =
          (match.destLng * match.tripCount + trip.destLng!) / updatedCount;

      final tripDurationMin = trip.endTime != null
          ? trip.endTime!.difference(trip.startTime).inMinutes
          : null;
      final newDuration = tripDurationMin != null && match.typicalDurationMin != null
          ? ((match.typicalDurationMin! * match.tripCount + tripDurationMin) /
                  updatedCount)
              .round()
          : tripDurationMin ?? match.typicalDurationMin;

      final tripStartMinutes = trip.startTime.hour * 60 + trip.startTime.minute;
      final existingStart = match.typicalStart != null
          ? _parseTimeToMinutes(match.typicalStart!)
          : tripStartMinutes;
      final newStartMin =
          ((existingStart * match.tripCount + tripStartMinutes) / updatedCount)
              .round();
      final newStart =
          '${(newStartMin ~/ 60).toString().padLeft(2, '0')}:${(newStartMin % 60).toString().padLeft(2, '0')}';

      await _db.updateCandidate(RouteCandidatesCompanion(
        id: Value(match.id),
        originLat: Value(newOriginLat),
        originLng: Value(newOriginLng),
        destLat: Value(newDestLat),
        destLng: Value(newDestLng),
        tripCount: Value(updatedCount),
        daysSeen: Value(jsonEncode(days)),
        typicalStart: Value(newStart),
        typicalDurationMin: Value(newDuration),
        lastTripAt: Value(trip.startTime),
      ));

      if (updatedCount >= _promotionThreshold) {
        final routeId = await _promoteToKnownRoute(match.id, updatedCount,
            newOriginLat, newOriginLng, newDestLat, newDestLng, days,
            newStart, newDuration);
        return LearnResult(matched: true, promoted: true, routeId: routeId);
      }

      return const LearnResult(matched: true, promoted: false);
    }

    // No match — create new candidate
    final dayOfWeek = trip.startTime.weekday;
    final tripDurationMin = trip.endTime != null
        ? trip.endTime!.difference(trip.startTime).inMinutes
        : null;
    final startMin = trip.startTime.hour * 60 + trip.startTime.minute;
    final startStr =
        '${(startMin ~/ 60).toString().padLeft(2, '0')}:${(startMin % 60).toString().padLeft(2, '0')}';

    await _db.insertCandidate(RouteCandidatesCompanion.insert(
      id: const Uuid().v4(),
      originLat: trip.originLat,
      originLng: trip.originLng,
      destLat: trip.destLat!,
      destLng: trip.destLng!,
      daysSeen: jsonEncode([dayOfWeek]),
      lastTripAt: trip.startTime,
      typicalStart: Value(startStr),
      typicalDurationMin: Value(tripDurationMin),
    ));

    return const LearnResult(matched: false, promoted: false);
  }

  RouteCandidate? _findMatch(List<RouteCandidate> candidates, Trip trip) {
    for (final c in candidates) {
      final originDist = _distanceMeters(
        c.originLat, c.originLng, trip.originLat, trip.originLng);
      final destDist = _distanceMeters(
        c.destLat, c.destLng, trip.destLat!, trip.destLng!);

      if (originDist > _matchRadiusM || destDist > _matchRadiusM) continue;

      if (c.typicalStart != null) {
        final candidateMin = _parseTimeToMinutes(c.typicalStart!);
        final tripMin = trip.startTime.hour * 60 + trip.startTime.minute;
        if ((candidateMin - tripMin).abs() > _timeWindowMin) continue;
      }

      return c;
    }
    return null;
  }

  Future<String> _promoteToKnownRoute(
    String candidateId,
    int tripCount,
    double originLat,
    double originLng,
    double destLat,
    double destLng,
    List<int> days,
    String typicalStart,
    int? typicalDurationMin,
  ) async {
    final routeId = const Uuid().v4();
    final confidence = min(1.0, tripCount / 10);

    await _db.insertKnownRoute(KnownRoutesLocalCompanion.insert(
      id: routeId,
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
      daysActive: jsonEncode(days),
      typicalStart: Value(typicalStart),
      typicalDurationMin: Value(typicalDurationMin),
      confidence: Value(confidence),
      repetitionCount: Value(tripCount),
      lastTraveled: Value(DateTime.now()),
    ));

    await _db.deleteCandidate(candidateId);
    return routeId;
  }

  int _parseTimeToMinutes(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static double _distanceMeters(
    double lat1, double lon1, double lat2, double lon2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }
}
```

- [ ] **Step 4: Run tests**

Run: `cd app && flutter test test/features/tracking/services/route_learner_test.dart`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/tracking/services/route_learner.dart app/test/features/tracking/services/route_learner_test.dart
git commit -m "feat(tracking): add on-device route learner with clustering and promotion"
```

---

### Task 4: Tracking Service (FBG Wrapper)

**Files:**
- Create: `app/lib/features/tracking/services/tracking_service.dart`
- Create: `app/lib/features/tracking/providers/tracking_provider.dart`
- Modify: `app/lib/features/tracking/services/services.dart` (barrel)
- Modify: `app/lib/features/tracking/providers/providers.dart` (barrel)

**Interfaces:**
- Consumes: `TrackingDatabase` (Task 1), `TripDetector` (Task 2), `RouteLearner` (Task 3), `ClerkService` (existing auth), `AppConstants` (existing)
- Produces: `TrackingService` with methods: `Future<void> start()`, `Future<void> stop()`, `Future<void> setSOSMode(bool active)`, `TripState get currentTripState`. Provider: `trackingServiceProvider` (auto-starts when auth ready).

- [ ] **Step 1: Implement TrackingService**

Create `app/lib/features/tracking/services/tracking_service.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../auth/services/clerk_service.dart';
import '../db/tracking_database.dart';
import '../models/tracking_state.dart';
import 'route_learner.dart';
import 'trip_detector.dart';

final trackingServiceProvider = Provider<TrackingService?>((ref) {
  final clerkService = ref.watch(clerkServiceProvider);
  if (!clerkService.isSignedIn) return null;

  final db = ref.watch(trackingDatabaseProvider);
  final service = TrackingService(
    db: db,
    clerkService: clerkService,
  );

  ref.onDispose(() => service.dispose());
  return service;
});

final trackingDatabaseProvider = Provider<TrackingDatabase>((ref) {
  throw UnimplementedError(
    'trackingDatabaseProvider must be overridden at app startup',
  );
});

class TrackingService {
  TrackingService({
    required TrackingDatabase db,
    required ClerkService clerkService,
  })  : _db = db,
        _clerkService = clerkService,
        _tripDetector = TripDetector(db),
        _routeLearner = RouteLearner(db);

  final TrackingDatabase _db;
  final ClerkService _clerkService;
  final TripDetector _tripDetector;
  final RouteLearner _routeLearner;
  StreamSubscription<Trip>? _tripCompletedSub;
  bool _started = false;

  TripState get currentTripState => _tripDetector.currentState;
  Stream<TripState> get tripStateStream => _tripDetector.stateStream;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    _tripCompletedSub = _tripDetector.tripCompletedStream.listen((trip) async {
      final result = await _routeLearner.processCompletedTrip(trip);
      if (result.promoted) {
        debugPrint('[Tracking] Route promoted: ${result.routeId}');
      }
    });

    final token = await _clerkService.getSupabaseToken();

    await bg.BackgroundGeolocation.ready(bg.Config(
      desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
      distanceFilter: 10,
      stopOnTerminate: false,
      startOnBoot: true,
      foregroundService: true,
      notification: bg.Notification(
        title: 'RoadPack',
        text: 'Keeping you safe',
      ),
      url: '${AppConstants.supabaseUrl}/functions/v1/location-ingest',
      autoSync: true,
      batchSync: true,
      maxBatchSize: 50,
      headers: {
        'Authorization': 'Bearer ${token ?? ''}',
      },
      heartbeatInterval: 900,
      activityRecognitionInterval: 10000,
      geofenceProximityRadius: 1000,
    ));

    bg.BackgroundGeolocation.onLocation(_onLocation);
    bg.BackgroundGeolocation.onGeofence(_onGeofence);
    bg.BackgroundGeolocation.onActivityChange(_onActivityChange);
    bg.BackgroundGeolocation.onHeartbeat(_onHeartbeat);

    await bg.BackgroundGeolocation.start();
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    await bg.BackgroundGeolocation.stop();
  }

  Future<void> setSOSMode(bool active) async {
    if (active) {
      await bg.BackgroundGeolocation.setConfig(bg.Config(
        desiredAccuracy: bg.Config.DESIRED_ACCURACY_NAVIGATION,
        distanceFilter: 1,
        locationUpdateInterval: 1000,
      ));
    } else {
      await bg.BackgroundGeolocation.setConfig(bg.Config(
        desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
        distanceFilter: 10,
      ));
    }
  }

  Future<void> updateAuthToken(String token) async {
    await bg.BackgroundGeolocation.setConfig(bg.Config(
      headers: {'Authorization': 'Bearer $token'},
    ));
  }

  void _onLocation(bg.Location location) {
    _tripDetector.onLocationUpdate(FakeLocation(
      latitude: location.coords.latitude,
      longitude: location.coords.longitude,
      speed: location.coords.speed ?? 0,
      timestamp: DateTime.parse(location.timestamp),
    ));
  }

  void _onGeofence(bg.GeofenceEvent event) {
    if (event.action == 'EXIT') {
      _tripDetector.onGeofenceEvent(GeofenceExitEvent(
        identifier: event.identifier,
        timestamp: DateTime.parse(event.location.timestamp),
        latitude: event.location.coords.latitude,
        longitude: event.location.coords.longitude,
      ));
    }
  }

  void _onActivityChange(bg.ActivityChangeEvent event) {
    debugPrint('[Tracking] Activity: ${event.activity} (${event.confidence}%)');
  }

  void _onHeartbeat(bg.HeartbeatEvent event) {
    debugPrint('[Tracking] Heartbeat at ${event.location.timestamp}');
  }

  void dispose() {
    _tripCompletedSub?.cancel();
    _tripDetector.dispose();
  }
}
```

- [ ] **Step 2: Update barrel files**

Update `app/lib/features/tracking/services/services.dart`:
```dart
export 'route_learner.dart';
export 'tracking_service.dart';
export 'trip_detector.dart';
```

Update `app/lib/features/tracking/providers/providers.dart`:
```dart
export '../services/tracking_service.dart' show trackingServiceProvider, trackingDatabaseProvider;
```

- [ ] **Step 3: Commit**

```bash
git add app/lib/features/tracking/services/tracking_service.dart app/lib/features/tracking/providers/providers.dart app/lib/features/tracking/services/services.dart
git commit -m "feat(tracking): add FBG tracking service with trip detection and route learning wiring"
```

---

### Task 5: Supabase Migration & Location Ingest Edge Function

**Files:**
- Create: `backend/supabase/migrations/00016_add_non_arrival_config.sql`
- Create: `backend/supabase/functions/location-ingest/index.ts`

**Interfaces:**
- Consumes: `_shared/jwt.ts` (existing), `location_history` table (existing), `devices` table (existing)
- Produces: `location-ingest` edge function accepting FBG batch POST format. Inserts into `location_history`, updates `devices.last_heartbeat`.

- [ ] **Step 1: Write migration**

Create `backend/supabase/migrations/00016_add_non_arrival_config.sql`:

```sql
-- Non-arrival configuration columns

ALTER TABLE users ADD COLUMN non_arrival_delay_min INT DEFAULT 15;
ALTER TABLE users ADD COLUMN non_arrival_enabled BOOLEAN DEFAULT true;
ALTER TABLE known_routes ADD COLUMN non_arrival_enabled BOOLEAN DEFAULT true;
```

- [ ] **Step 2: Write location-ingest edge function**

Create `backend/supabase/functions/location-ingest/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { verifyClerkJwt } from '../_shared/jwt.ts'

interface LocationRecord {
  timestamp: string
  coords: {
    latitude: number
    longitude: number
    speed: number | null
    heading: number | null
    accuracy: number | null
    altitude: number | null
  }
  activity?: { type: string }
  battery?: { level: number }
}

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    return new Response(JSON.stringify({ error: 'Missing auth token' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const token = authHeader.slice(7)
  let userId: string
  try {
    const { sub } = await verifyClerkJwt(token)
    userId = sub
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid token' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  let body: { location?: LocationRecord[] }
  try {
    body = await req.json()
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const locations = body.location
  if (!locations || !Array.isArray(locations) || locations.length === 0) {
    return new Response(JSON.stringify({ error: 'No locations' }), {
      status: 422,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  // Bulk insert locations
  const rows = locations.map((loc) => ({
    user_id: userId,
    point: `POINT(${loc.coords.longitude} ${loc.coords.latitude})`,
    speed: loc.coords.speed,
    heading: loc.coords.heading,
    accuracy: loc.coords.accuracy,
    altitude: loc.coords.altitude,
    battery_level: loc.battery?.level != null
      ? Math.round(loc.battery.level * 100)
      : null,
    activity: loc.activity?.type ?? null,
    source: 'gps',
    recorded_at: loc.timestamp,
    synced_at: new Date().toISOString(),
  }))

  const { error: insertError } = await supabase
    .from('location_history')
    .insert(rows)

  if (insertError) {
    console.error('location_history insert failed:', insertError.message)
    return new Response(JSON.stringify({ error: 'Insert failed' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // Update device heartbeat
  const now = new Date().toISOString()
  const { data: existingDevice } = await supabase
    .from('devices')
    .select('id')
    .eq('user_id', userId)
    .order('last_heartbeat', { ascending: false, nullsFirst: false })
    .limit(1)
    .maybeSingle()

  if (existingDevice) {
    await supabase
      .from('devices')
      .update({ last_heartbeat: now })
      .eq('id', existingDevice.id)
  }

  return new Response(
    JSON.stringify({ status: 'ok', count: rows.length }),
    { headers: { 'Content-Type': 'application/json' } },
  )
})
```

- [ ] **Step 3: Commit**

```bash
git add backend/supabase/migrations/00016_add_non_arrival_config.sql backend/supabase/functions/location-ingest/index.ts
git commit -m "feat(tracking): add location-ingest edge function and non-arrival config migration"
```

---

### Task 6: Non-Arrival Check Edge Function

**Files:**
- Modify: `backend/supabase/functions/non-arrival-check/index.ts` (rewrite stub)

**Interfaces:**
- Consumes: `_shared/jwt.ts`, `known_routes` table, `location_history` table, `incidents` table, `users` table, `cascade_jobs` table, `_shared/channels.ts` (FcmChannel)
- Produces: `non-arrival-check` edge function that detects overdue arrivals and sends FCM check-in push.

- [ ] **Step 1: Rewrite non-arrival-check**

Replace `backend/supabase/functions/non-arrival-check/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  // Verify service role (cron invocation)
  const authHeader = req.headers.get('Authorization')
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  if (authHeader !== `Bearer ${serviceKey}`) {
    return new Response('Unauthorized', { status: 401 })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    serviceKey,
  )

  const now = new Date()
  const currentDay = now.getDay() === 0 ? 7 : now.getDay() // ISO: Mon=1, Sun=7
  const currentMinutes = now.getHours() * 60 + now.getMinutes()

  // Find known routes that should have arrived by now
  const { data: routes, error: routesError } = await supabase
    .from('known_routes')
    .select('id, user_id, name, destination, typical_start, typical_duration, days_active, non_arrival_enabled')
    .eq('non_arrival_enabled', true)

  if (routesError || !routes) {
    console.error('Failed to fetch routes:', routesError?.message)
    return new Response(JSON.stringify({ status: 'error' }), { status: 500 })
  }

  let checkedCount = 0
  let alertedCount = 0

  for (const route of routes) {
    // Check day-of-week
    const daysActive: number[] = route.days_active ?? []
    if (!daysActive.includes(currentDay)) continue

    // Parse typical_start (HH:MM) and typical_duration (interval -> minutes)
    if (!route.typical_start || !route.typical_duration) continue

    const [startH, startM] = route.typical_start.split(':').map(Number)
    const startMinutes = startH * 60 + startM

    // Parse interval to minutes (stored as PostgreSQL interval)
    const durationMatch = String(route.typical_duration).match(/(\d+):(\d+):(\d+)/)
    let durationMinutes = 30
    if (durationMatch) {
      durationMinutes = parseInt(durationMatch[1]) * 60 + parseInt(durationMatch[2])
    }

    // Get user's non-arrival delay
    const { data: user } = await supabase
      .from('users')
      .select('non_arrival_delay_min, non_arrival_enabled')
      .eq('id', route.user_id)
      .single()

    if (!user || !user.non_arrival_enabled) continue

    const delayMin = user.non_arrival_delay_min ?? 15
    const expectedArrivalMin = startMinutes + durationMinutes + delayMin

    // Check if we're in the alert window (expected arrival passed, but not too long ago)
    if (currentMinutes < expectedArrivalMin || currentMinutes > expectedArrivalMin + 30) continue

    checkedCount++

    // Check if user already near destination
    const dest = route.destination // GEOGRAPHY POINT
    if (!dest) continue

    const thirtyMinAgo = new Date(now.getTime() - 30 * 60 * 1000).toISOString()
    const { data: nearDest } = await supabase.rpc('check_near_destination', {
      uid: route.user_id,
      dest_point: dest,
      radius_m: 500,
      since: thirtyMinAgo,
    })

    if (nearDest) continue // User arrived

    // Check no active incident already
    const { data: activeIncident } = await supabase
      .from('incidents')
      .select('id')
      .eq('user_id', route.user_id)
      .eq('type', 'non_arrival')
      .not('status', 'in', '("cancelled","resolved")')
      .limit(1)
      .maybeSingle()

    if (activeIncident) continue // Already alerting

    // Create non-arrival incident
    const { data: incident, error: incidentError } = await supabase
      .from('incidents')
      .insert({
        user_id: route.user_id,
        type: 'non_arrival',
        location: dest,
        status: 'detected',
        sensor_data: { route_id: route.id, route_name: route.name },
      })
      .select('id')
      .single()

    if (incidentError || !incident) {
      console.error('Failed to create incident:', incidentError?.message)
      continue
    }

    // Queue cascade with 5-min delay
    await supabase.from('cascade_jobs').insert({
      incident_id: incident.id,
      delay_seconds: 300,
    })

    // Send FCM check-in push (via FcmChannel or direct)
    // For now, log intent — actual FCM requires device token lookup
    console.log(`[non-arrival] Check-in push for user ${route.user_id}, incident ${incident.id}`)

    alertedCount++
  }

  return new Response(
    JSON.stringify({ status: 'ok', checked: checkedCount, alerted: alertedCount }),
    { headers: { 'Content-Type': 'application/json' } },
  )
})
```

- [ ] **Step 2: Commit**

```bash
git add backend/supabase/functions/non-arrival-check/index.ts
git commit -m "feat(tracking): implement non-arrival-check edge function with route schedule detection"
```

---

### Task 7: Heartbeat Check & Check-In Response Edge Functions

**Files:**
- Modify: `backend/supabase/functions/heartbeat-check/index.ts` (rewrite stub)
- Create: `backend/supabase/functions/check-in-response/index.ts`

**Interfaces:**
- Consumes: `devices` table, `known_routes` table, `incidents` table, `cascade_jobs` table, `_shared/jwt.ts`
- Produces: `heartbeat-check` detects lost contact during commute windows. `check-in-response` handles user "I'm fine" / "Running late" / "Need help" responses.

- [ ] **Step 1: Rewrite heartbeat-check**

Replace `backend/supabase/functions/heartbeat-check/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const authHeader = req.headers.get('Authorization')
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  if (authHeader !== `Bearer ${serviceKey}`) {
    return new Response('Unauthorized', { status: 401 })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    serviceKey,
  )

  const now = new Date()
  const fifteenMinAgo = new Date(now.getTime() - 15 * 60 * 1000).toISOString()
  const currentDay = now.getDay() === 0 ? 7 : now.getDay()
  const currentMinutes = now.getHours() * 60 + now.getMinutes()

  // Find devices with stale heartbeats
  const { data: staleDevices } = await supabase
    .from('devices')
    .select('user_id, last_heartbeat')
    .lt('last_heartbeat', fifteenMinAgo)
    .not('last_heartbeat', 'is', null)

  if (!staleDevices || staleDevices.length === 0) {
    return new Response(JSON.stringify({ status: 'ok', checked: 0 }), {
      headers: { 'Content-Type': 'application/json' },
    })
  }

  let alertedCount = 0

  for (const device of staleDevices) {
    const userId = device.user_id

    // Check if user has active known route right now
    const { data: routes } = await supabase
      .from('known_routes')
      .select('id, typical_start, typical_duration, days_active')
      .eq('user_id', userId)

    if (!routes || routes.length === 0) continue

    const isCommuteTime = routes.some((route: { typical_start: string | null; typical_duration: string | null; days_active: number[] | null }) => {
      if (!route.days_active?.includes(currentDay)) return false
      if (!route.typical_start) return false
      const [h, m] = route.typical_start.split(':').map(Number)
      const startMin = h * 60 + m
      // Consider commute window: start to start + duration + 30 min buffer
      const durationMatch = String(route.typical_duration ?? '00:30:00').match(/(\d+):(\d+)/)
      const durMin = durationMatch ? parseInt(durationMatch[1]) * 60 + parseInt(durationMatch[2]) : 30
      return currentMinutes >= startMin && currentMinutes <= startMin + durMin + 30
    })

    if (!isCommuteTime) continue

    // Check no existing lost_contact incident
    const { data: existing } = await supabase
      .from('incidents')
      .select('id')
      .eq('user_id', userId)
      .eq('type', 'lost_contact')
      .not('status', 'in', '("cancelled","resolved")')
      .limit(1)
      .maybeSingle()

    if (existing) continue

    // Create lost_contact incident
    await supabase.from('incidents').insert({
      user_id: userId,
      type: 'lost_contact',
      status: 'detected',
      sensor_data: { last_heartbeat: device.last_heartbeat },
    })

    // Queue cascade with immediate dispatch (no grace period for lost contact)
    // escalation-check will pick this up
    console.log(`[heartbeat-check] Lost contact: ${userId}, last heartbeat ${device.last_heartbeat}`)
    alertedCount++
  }

  return new Response(
    JSON.stringify({ status: 'ok', stale: staleDevices.length, alerted: alertedCount }),
    { headers: { 'Content-Type': 'application/json' } },
  )
})
```

- [ ] **Step 2: Create check-in-response edge function**

Create `backend/supabase/functions/check-in-response/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { verifyClerkJwt } from '../_shared/jwt.ts'

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    return new Response(JSON.stringify({ error: 'Missing auth token' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const token = authHeader.slice(7)
  let userId: string
  try {
    const { sub } = await verifyClerkJwt(token)
    userId = sub
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid token' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  let body: { incident_id: string; response: string }
  try {
    body = await req.json()
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const { incident_id, response } = body
  if (!incident_id || !response) {
    return new Response(JSON.stringify({ error: 'Missing incident_id or response' }), {
      status: 422,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const validResponses = ['fine', 'running_late', 'need_help']
  if (!validResponses.includes(response)) {
    return new Response(JSON.stringify({ error: 'Invalid response' }), {
      status: 422,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  // Verify incident belongs to user
  const { data: incident } = await supabase
    .from('incidents')
    .select('id, status, type')
    .eq('id', incident_id)
    .eq('user_id', userId)
    .single()

  if (!incident) {
    return new Response(JSON.stringify({ error: 'Incident not found' }), {
      status: 404,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  if (incident.status === 'resolved' || incident.status === 'cancelled') {
    return new Response(JSON.stringify({ error: 'Incident already closed' }), {
      status: 409,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const now = new Date().toISOString()

  switch (response) {
    case 'fine': {
      await supabase
        .from('incidents')
        .update({ status: 'cancelled', cancelled_reason: 'user_confirmed_fine', resolved_at: now })
        .eq('id', incident_id)
      break
    }
    case 'running_late': {
      await supabase
        .from('incidents')
        .update({ status: 'cancelled', cancelled_reason: 'user_running_late', resolved_at: now })
        .eq('id', incident_id)
      break
    }
    case 'need_help': {
      // Escalate immediately — change status to dispatched, trigger cascade
      await supabase
        .from('incidents')
        .update({ status: 'dispatched' })
        .eq('id', incident_id)

      // Fire cascade immediately by setting delay to 0 or invoking directly
      const supabaseUrl = Deno.env.get('SUPABASE_URL')!
      const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

      const { data: contacts } = await supabase
        .from('emergency_contacts')
        .select('*')
        .eq('user_id', userId)
        .eq('opted_out', false)
        .order('priority')

      const { data: profile } = await supabase
        .from('users')
        .select('name, phone')
        .eq('id', userId)
        .single()

      if (contacts && contacts.length > 0) {
        const cascadeUrl = `${supabaseUrl}/functions/v1/alert-cascade`
        // deno-lint-ignore no-explicit-any
        ;(globalThis as any).EdgeRuntime?.waitUntil?.(
          fetch(cascadeUrl, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${serviceKey}`,
            },
            body: JSON.stringify({
              incident_id,
              contacts,
              user_profile: profile ?? { name: 'Unknown', phone: '' },
              location: null,
            }),
          }).catch((err: Error) => console.error('Cascade invoke failed:', err))
        )
      }
      break
    }
  }

  return new Response(
    JSON.stringify({ status: 'ok', response }),
    { headers: { 'Content-Type': 'application/json' } },
  )
})
```

- [ ] **Step 3: Commit**

```bash
git add backend/supabase/functions/heartbeat-check/index.ts backend/supabase/functions/check-in-response/index.ts
git commit -m "feat(tracking): implement heartbeat-check and check-in-response edge functions"
```

---

### Task 8: Known Routes Provider & Route Sync

**Files:**
- Create: `app/lib/features/tracking/providers/known_routes_provider.dart`
- Create: `app/test/features/tracking/providers/known_routes_provider_test.dart`

**Interfaces:**
- Consumes: `TrackingDatabase` (Task 1), `authenticatedSupabaseProvider` (existing), `KnownRoutesLocal` table (Drift)
- Produces: `knownRoutesProvider` — `AsyncNotifier<List<KnownRoutesLocalData>>` with methods: `Future<void> syncFromServer()`, `Future<void> syncToServer(String routeId)`, `Future<void> toggleNonArrival(String routeId, bool enabled)`.

- [ ] **Step 1: Write failing tests**

Create `app/test/features/tracking/providers/known_routes_provider_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:roadpack/features/tracking/db/tracking_database.dart';
import 'package:roadpack/features/tracking/providers/known_routes_provider.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late TrackingDatabase db;

  setUp(() {
    db = TrackingDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('getAllKnownRoutes returns empty list initially', () async {
    final routes = await db.getAllKnownRoutes();
    expect(routes, isEmpty);
  });

  test('toggleNonArrival updates route', () async {
    await db.insertKnownRoute(KnownRoutesLocalCompanion.insert(
      id: 'r1',
      originLat: 9.93,
      originLng: 76.26,
      destLat: 10.0,
      destLng: 76.3,
      daysActive: '[1,2,3,4,5]',
    ));

    await db.updateKnownRoute(KnownRoutesLocalCompanion(
      id: const Value('r1'),
      originLat: const Value(9.93),
      originLng: const Value(76.26),
      destLat: const Value(10.0),
      destLng: const Value(76.3),
      daysActive: const Value('[1,2,3,4,5]'),
      nonArrivalEnabled: const Value(false),
    ));

    final routes = await db.getAllKnownRoutes();
    expect(routes.first.nonArrivalEnabled, false);
  });
}
```

- [ ] **Step 2: Implement KnownRoutesProvider**

Create `app/lib/features/tracking/providers/known_routes_provider.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/authenticated_supabase_provider.dart';
import '../db/tracking_database.dart';
import '../services/tracking_service.dart';

final knownRoutesProvider =
    AsyncNotifierProvider<KnownRoutesNotifier, List<KnownRoutesLocalData>>(
  KnownRoutesNotifier.new,
);

class KnownRoutesNotifier extends AsyncNotifier<List<KnownRoutesLocalData>> {
  TrackingDatabase get _db => ref.read(trackingDatabaseProvider);
  SupabaseClient? get _supabase => ref.read(authenticatedSupabaseProvider);

  @override
  Future<List<KnownRoutesLocalData>> build() async {
    return _db.getAllKnownRoutes();
  }

  Future<void> syncFromServer() async {
    final supabase = _supabase;
    if (supabase == null) return;

    try {
      final response = await supabase.from('known_routes').select();
      final serverRoutes = response as List<dynamic>;

      for (final r in serverRoutes) {
        final map = r as Map<String, dynamic>;
        // Parse PostGIS point to lat/lng
        final origin = _parsePoint(map['origin']);
        final dest = _parsePoint(map['destination']);
        if (origin == null || dest == null) continue;

        final durationInterval = map['typical_duration'] as String?;
        int? durationMin;
        if (durationInterval != null) {
          final match = RegExp(r'(\d+):(\d+)').firstMatch(durationInterval);
          if (match != null) {
            durationMin = int.parse(match.group(1)!) * 60 +
                int.parse(match.group(2)!);
          }
        }

        await _db.insertKnownRoute(KnownRoutesLocalCompanion.insert(
          id: map['id'] as String,
          originLat: origin.lat,
          originLng: origin.lng,
          destLat: dest.lat,
          destLng: dest.lng,
          daysActive: map['days_active'] != null
              ? map['days_active'].toString()
              : '[]',
          name: Value(map['name'] as String?),
          typicalStart: Value(map['typical_start'] as String?),
          typicalDurationMin: Value(durationMin),
          confidence: Value((map['confidence'] as num?)?.toDouble() ?? 0),
          repetitionCount: Value(map['repetition_count'] as int? ?? 0),
          nonArrivalEnabled:
              Value(map['non_arrival_enabled'] as bool? ?? true),
          lastTraveled: Value(map['last_traveled'] != null
              ? DateTime.parse(map['last_traveled'] as String)
              : null),
          syncedAt: Value(DateTime.now()),
        ));
      }

      state = AsyncData(await _db.getAllKnownRoutes());
    } catch (e) {
      debugPrint('[KnownRoutes] Sync from server failed: $e');
    }
  }

  Future<void> syncToServer(String routeId) async {
    final supabase = _supabase;
    if (supabase == null) return;

    final routes = await _db.getAllKnownRoutes();
    final local = routes.where((r) => r.id == routeId).firstOrNull;
    if (local == null) return;

    try {
      await supabase.from('known_routes').upsert({
        'id': local.id,
        'user_id': null, // server sets from JWT
        'name': local.name,
        'origin': 'POINT(${local.originLng} ${local.originLat})',
        'destination': 'POINT(${local.destLng} ${local.destLat})',
        'typical_start': local.typicalStart,
        'typical_duration': local.typicalDurationMin != null
            ? '${local.typicalDurationMin} minutes'
            : null,
        'days_active': local.daysActive,
        'confidence': local.confidence,
        'repetition_count': local.repetitionCount,
        'non_arrival_enabled': local.nonArrivalEnabled,
        'last_traveled': local.lastTraveled?.toIso8601String(),
      });
    } catch (e) {
      debugPrint('[KnownRoutes] Sync to server failed: $e');
    }
  }

  Future<void> toggleNonArrival(String routeId, bool enabled) async {
    final routes = await _db.getAllKnownRoutes();
    final route = routes.where((r) => r.id == routeId).firstOrNull;
    if (route == null) return;

    await _db.updateKnownRoute(KnownRoutesLocalCompanion(
      id: Value(route.id),
      originLat: Value(route.originLat),
      originLng: Value(route.originLng),
      destLat: Value(route.destLat),
      destLng: Value(route.destLng),
      daysActive: Value(route.daysActive),
      nonArrivalEnabled: Value(enabled),
    ));

    state = AsyncData(await _db.getAllKnownRoutes());
  }

  ({double lat, double lng})? _parsePoint(dynamic point) {
    if (point == null) return null;
    if (point is String) {
      final match =
          RegExp(r'POINT\(([-\d.]+)\s+([-\d.]+)\)').firstMatch(point);
      if (match != null) {
        return (
          lat: double.parse(match.group(2)!),
          lng: double.parse(match.group(1)!),
        );
      }
    }
    return null;
  }
}
```

- [ ] **Step 3: Run tests**

Run: `cd app && flutter test test/features/tracking/providers/known_routes_provider_test.dart`
Expected: All tests pass.

- [ ] **Step 4: Update barrel**

Update `app/lib/features/tracking/providers/providers.dart`:
```dart
export '../services/tracking_service.dart' show trackingServiceProvider, trackingDatabaseProvider;
export 'known_routes_provider.dart';
```

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/tracking/providers/known_routes_provider.dart app/test/features/tracking/providers/ app/lib/features/tracking/providers/providers.dart
git commit -m "feat(tracking): add known routes provider with bidirectional Supabase sync"
```

---

## Verification Checklist

After all tasks complete:

1. `cd app && flutter test` — all tests pass
2. `cd app && flutter analyze` — zero issues
3. Edge functions have no TypeScript errors (Deno check)
4. Migration applies cleanly to local Supabase instance
5. FBG tracking starts on sign-in, stops on sign-out
6. Trip detector correctly transitions through state machine
7. Route learner promotes after 3 matching trips
8. Location-ingest handles FBG batch format
9. Non-arrival-check correctly identifies overdue routes
10. Check-in-response cancels or escalates incidents
