import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/live_map/live_map.dart';

void main() {
  late InMemoryTileStore store;
  late OfflineTileCache cache;

  setUp(() {
    store = InMemoryTileStore();
    cache = OfflineTileCache(store: store);
  });

  test('the cache reports honestly that it cannot serve the base map', () {
    expect(OfflineTileCache.servesBaseMapOffline, isFalse);
    expect(OfflineTileCache.limitationNotice, isNotEmpty);
  });

  test('stats start empty', () async {
    final stats = await cache.stats();
    expect(stats.tileCount, 0);
    expect(stats.bytes, 0);
    expect(stats.isEmpty, isTrue);
  });

  test('stored tiles are counted and measured, not estimated', () async {
    await cache.store(
      const TileCoordinate(x: 1, y: 2, z: 12),
      List<int>.filled(1024, 7),
    );
    await cache.store(
      const TileCoordinate(x: 1, y: 3, z: 12),
      List<int>.filled(512, 7),
    );
    final stats = await cache.stats();
    expect(stats.tileCount, 2);
    expect(stats.bytes, 1536);
    expect(stats.bytesAreEstimated, isFalse);
    expect(stats.formattedSize, '1.5 KB');
  });

  test('re-storing the same tile replaces rather than double counts', () async {
    const t = TileCoordinate(x: 1, y: 2, z: 12);
    await cache.store(t, List<int>.filled(1024, 1));
    await cache.store(t, List<int>.filled(2048, 1));
    final stats = await cache.stats();
    expect(stats.tileCount, 1);
    expect(stats.bytes, 2048);
  });

  test('clear empties the cache', () async {
    await cache.store(
      const TileCoordinate(x: 1, y: 2, z: 12),
      List<int>.filled(1024, 1),
    );
    await cache.clear();
    final stats = await cache.stats();
    expect(stats.isEmpty, isTrue);
  });

  test('clearing one region leaves the others intact', () async {
    await cache.store(
      const TileCoordinate(x: 1, y: 2, z: 12),
      List<int>.filled(100, 1),
      regionId: 'r1',
    );
    await cache.store(
      const TileCoordinate(x: 9, y: 9, z: 12),
      List<int>.filled(200, 1),
      regionId: 'r2',
    );
    await cache.clearRegion('r1');
    final stats = await cache.stats();
    expect(stats.tileCount, 1);
    expect(stats.bytes, 200);
  });

  test('a prefetch plan is produced without pretending the tiles are downloaded', () {
    final plan = cache.planFor(
      regionId: 'home-commute',
      name: 'Home commute',
      route: const [GeoPoint(9.9758, 76.5786), GeoPoint(9.9816, 76.2999)],
    );
    expect(plan.regionId, 'home-commute');
    expect(plan.coverage.tiles, isNotEmpty);
    expect(plan.coverage.bytesAreEstimated, isTrue);
    expect(plan.status, OfflineRegionStatus.notDownloaded);
  });

  test('formattedSize reads in tabular-friendly units', () {
    expect(const TileCacheStats(tileCount: 0, bytes: 0).formattedSize, '0 KB');
    expect(const TileCacheStats(tileCount: 1, bytes: 900).formattedSize, '0.9 KB');
    expect(
      const TileCacheStats(tileCount: 1, bytes: 5 * 1024 * 1024).formattedSize,
      '5.0 MB',
    );
  });
}
