import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/live_map/live_map.dart';

void main() {
  // Muvattupuzha -> Ernakulam, roughly.
  const route = <GeoPoint>[
    GeoPoint(9.9758, 76.5786),
    GeoPoint(9.9900, 76.4500),
    GeoPoint(9.9816, 76.2999),
  ];

  group('RouteTileCoverage', () {
    test('a wider buffer never covers fewer tiles', () {
      final tight = RouteTileCoverage.forRoute(
        route: route,
        bufferMeters: 0,
        zoomLevels: const [12],
      );
      final buffered = RouteTileCoverage.forRoute(
        route: route,
        bufferMeters: 5000,
        zoomLevels: const [12],
      );
      expect(buffered.tiles.length, greaterThan(tight.tiles.length));
      expect(tight.tiles.every(buffered.tiles.contains), isTrue);
    });

    test('the 5 km buffer is the FR-052 default', () {
      expect(RouteTileCoverage.defaultBufferMeters, 5000);
    });

    test('covers every zoom asked for and stays inside the tile grid', () {
      final cov = RouteTileCoverage.forRoute(
        route: route,
        bufferMeters: RouteTileCoverage.defaultBufferMeters,
        zoomLevels: const [10, 12, 14],
      );
      expect(cov.zoomLevels, const [10, 12, 14]);
      for (final t in cov.tiles) {
        final max = 1 << t.z;
        expect(t.x, inInclusiveRange(0, max - 1));
        expect(t.y, inInclusiveRange(0, max - 1));
      }
      // Higher zoom must contribute strictly more tiles than lower zoom.
      final z10 = cov.tiles.where((t) => t.z == 10).length;
      final z14 = cov.tiles.where((t) => t.z == 14).length;
      expect(z14, greaterThan(z10));
    });

    test('an empty route yields no tiles rather than the whole world', () {
      final cov = RouteTileCoverage.forRoute(
        route: const [],
        bufferMeters: 5000,
        zoomLevels: const [12],
      );
      expect(cov.tiles, isEmpty);
      expect(cov.estimatedBytes, 0);
    });

    test('byte figures are explicitly estimates, not measurements', () {
      final cov = RouteTileCoverage.forRoute(
        route: route,
        bufferMeters: 5000,
        zoomLevels: const [12],
      );
      expect(cov.estimatedBytes, greaterThan(0));
      expect(cov.bytesAreEstimated, isTrue);
    });

    test('a route crossing the antimeridian does not wrap into a world-wide span', () {
      final cov = RouteTileCoverage.forRoute(
        route: const [GeoPoint(0, 179.99), GeoPoint(0, -179.99)],
        bufferMeters: 1000,
        zoomLevels: const [8],
      );
      // 2 narrow strips, not the full 256-wide row.
      expect(cov.tiles.length, lessThan(1 << 8));
    });
  });
}
