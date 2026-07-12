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
  Future<int> insertTrip(TripsCompanion trip) => into(trips).insert(trip);

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
