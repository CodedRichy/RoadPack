import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/bystander/models/hospital.dart';
import 'package:roadpack/features/bystander/services/geo_distance.dart';
import 'package:roadpack/features/bystander/services/hospital_repository.dart';

/// Muvattupuzha town square, roughly.
const _lat = 9.9800;
const _lng = 76.5800;

Hospital _h(
  String id,
  String name,
  double lat,
  double lng, {
  bool emergency = true,
  DateTime? verifiedAt,
}) => Hospital(
  id: id,
  name: name,
  lat: lat,
  lng: lng,
  type: HospitalType.district,
  hasEmergency: emergency,
  district: 'Ernakulam',
  verifiedAt: verifiedAt,
  source: 'test',
);

void main() {
  group('haversineMeters', () {
    test('is zero for the same point', () {
      expect(haversineMeters(_lat, _lng, _lat, _lng), 0);
    });

    test('matches a known separation within 1%', () {
      // Kalamassery medical college -> General Hospital Ernakulam, ~10.6 km.
      final d = haversineMeters(10.0600, 76.3200, 9.9760, 76.2830);
      expect(d, greaterThan(9000));
      expect(d, lessThan(12000));
    });
  });

  group('HospitalRepository offline lookup', () {
    late InMemoryHospitalCacheStore store;

    setUp(() => store = InMemoryHospitalCacheStore());

    test('returns nearest-first from cache with no network', () async {
      store.seedJson(
        HospitalRepository.encode([
          _h('far', 'Far Hospital', 10.0600, 76.3200),
          _h('near', 'Near Hospital', 9.9810, 76.5810),
          _h('mid', 'Mid Hospital', 9.9900, 76.6000),
        ]),
      );

      final repo = HospitalRepository(
        store: store,
        // Any remote call in this test is a failure of the offline path.
        fetcher: () async => throw StateError('network used while offline'),
      );

      final ranked = await repo.nearest(lat: _lat, lng: _lng);

      expect(ranked.map((r) => r.hospital.id), ['near', 'mid', 'far']);
      expect(ranked.first.distanceMeters, lessThan(200));
    });

    test('falls back to the bundled seed when the cache is empty', () async {
      final repo = HospitalRepository(
        store: store,
        fetcher: () async => throw StateError('network used while offline'),
      );

      final ranked = await repo.nearest(lat: _lat, lng: _lng, limit: 2);

      expect(ranked, isNotEmpty);
      expect(ranked.length, lessThanOrEqualTo(2));
      // Sorted ascending.
      if (ranked.length == 2) {
        expect(
          ranked[0].distanceMeters,
          lessThanOrEqualTo(ranked[1].distanceMeters),
        );
      }
    });

    test('excludes non-emergency facilities when emergencyOnly', () async {
      store.seedJson(
        HospitalRepository.encode([
          _h('clinic', 'Day Clinic', 9.9801, 76.5801, emergency: false),
          _h('casualty', 'Casualty', 9.9900, 76.6000),
        ]),
      );
      final repo = HospitalRepository(store: store);

      final ranked = await repo.nearest(lat: _lat, lng: _lng);
      expect(ranked.map((r) => r.hospital.id), ['casualty']);
    });

    test('never reports unverified seed data as verified', () async {
      final repo = HospitalRepository(store: store);
      final all = await repo.hospitals();
      expect(all, isNotEmpty);
      expect(all.every((h) => h.isVerified), isFalse);
    });

    test('refresh writes remote rows to the cache', () async {
      final repo = HospitalRepository(
        store: store,
        fetcher: () async => [_h('remote', 'Remote Hospital', 9.99, 76.59)],
      );

      await repo.refreshCache();
      final reloaded = HospitalRepository(store: store);
      final all = await reloaded.hospitals();
      expect(all.single.id, 'remote');
    });

    test('refresh swallows network failure and keeps the cache', () async {
      store.seedJson(HospitalRepository.encode([_h('a', 'A', 9.98, 76.58)]));
      final repo = HospitalRepository(
        store: store,
        fetcher: () async => throw Exception('offline'),
      );

      await repo.refreshCache();
      expect((await repo.hospitals()).single.id, 'a');
    });
  });
}
