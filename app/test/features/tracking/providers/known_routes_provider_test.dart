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

  test('insertKnownRoute with all fields', () async {
    await db.insertKnownRoute(KnownRoutesLocalCompanion.insert(
      id: 'r1',
      originLat: 9.93,
      originLng: 76.26,
      destLat: 10.0,
      destLng: 76.3,
      daysActive: '[1,2,3,4,5]',
      name: const Value('Home to Work'),
      typicalStart: const Value('08:30'),
      typicalDurationMin: const Value(25),
      confidence: const Value(0.7),
      repetitionCount: const Value(7),
      nonArrivalEnabled: const Value(true),
      lastTraveled: Value(DateTime(2026, 7, 11)),
      syncedAt: Value(DateTime(2026, 7, 11, 9, 0)),
    ));

    final routes = await db.getAllKnownRoutes();
    expect(routes.length, 1);
    expect(routes.first.name, 'Home to Work');
    expect(routes.first.typicalStart, '08:30');
    expect(routes.first.typicalDurationMin, 25);
    expect(routes.first.confidence, 0.7);
    expect(routes.first.repetitionCount, 7);
  });
}
