import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/commute/models/commute_route.dart';
import 'package:roadpack/features/commute/services/commute_route_repository.dart';
import 'package:roadpack/features/tracking/db/tracking_database.dart';

void main() {
  late TrackingDatabase db;
  late CommuteRouteRepository repo;

  setUp(() {
    db = TrackingDatabase(NativeDatabase.memory());
    repo = CommuteRouteRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<CommuteRoute> makeManual({String name = 'Home to college'}) {
    return repo.createManual(
      name: name,
      originLat: 9.93,
      originLng: 76.26,
      destLat: 10.0,
      destLng: 76.3,
      typicalStart: '08:15',
      typicalDurationMin: 45,
      daysActive: const [1, 2, 3, 4, 5],
    );
  }

  test('starts empty', () async {
    expect(await repo.list(), isEmpty);
  });

  test('creates a manual route that is known immediately (FR-041)', () async {
    final created = await makeManual();

    expect(created.source, RouteSource.manual);
    expect(created.isKnown, isTrue);
    expect(created.repetitionCount, 0);

    final all = await repo.list();
    expect(all.length, 1);
    expect(all.single.name, 'Home to college');
    expect(all.single.daysActive, const [1, 2, 3, 4, 5]);
    expect(all.single.typicalDurationMin, 45);
  });

  test('surfaces a learned route with its repetition count (FR-040)', () async {
    await repo.upsert(
      const CommuteRoute(
        id: 'learned-1',
        originLat: 9.9,
        originLng: 76.2,
        destLat: 10.1,
        destLng: 76.4,
        typicalStart: '07:30',
        typicalDurationMin: 25,
        daysActive: [1, 2, 3, 4, 5],
        confidence: 0.4,
        repetitionCount: 4,
        source: RouteSource.learned,
      ),
    );

    final route = (await repo.list()).single;
    expect(route.source, RouteSource.learned);
    expect(route.repetitionCount, 4);
    expect(route.isKnown, isTrue);
    expect(route.confidence, closeTo(0.4, 1e-6));
  });

  test('edits an existing route without changing its identity', () async {
    final created = await makeManual(name: 'Old name');

    await repo.upsert(
      created.copyWith(name: 'New name', typicalStart: '09:00'),
    );

    final route = (await repo.list()).single;
    expect(route.id, created.id);
    expect(route.name, 'New name');
    expect(route.typicalStart, '09:00');
  });

  test('toggling non-arrival persists and does not delete the route', () async {
    final created = await makeManual();
    expect(created.nonArrivalEnabled, isTrue);

    await repo.setNonArrivalEnabled(created.id, false);
    expect((await repo.list()).single.nonArrivalEnabled, isFalse);

    await repo.setNonArrivalEnabled(created.id, true);
    expect((await repo.list()).single.nonArrivalEnabled, isTrue);
  });

  test('deletes a route', () async {
    final created = await makeManual();
    await repo.delete(created.id);
    expect(await repo.list(), isEmpty);
  });

  test(
    'a route with an unparseable days list degrades to no active days',
    () async {
      await db.insertKnownRoute(
        KnownRoutesLocalCompanion.insert(
          id: 'broken',
          originLat: 9.9,
          originLng: 76.2,
          destLat: 10.1,
          destLng: 76.4,
          daysActive: 'not-json',
        ),
      );
      final route = (await repo.list()).single;
      expect(route.daysActive, isEmpty);
      expect(route.canWatch, isFalse);
    },
  );
}
