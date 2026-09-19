import 'dart:math' as math;

import '../models/geo_point.dart';
import '../models/offline_region.dart';

/// Which map tiles a known route plus its safety buffer occupies.
///
/// FR-052 asks for "known routes + 5 km buffer". This class answers *which
/// tiles that is* — pure arithmetic, no network, no plugin — so the coverage
/// question is settled and testable independently of whether any tile source
/// will actually hand us bytes. See [OfflineTileCache.limitationNotice] for
/// what is and is not fetchable today.
class RouteTileCoverage {
  const RouteTileCoverage({
    required this.tiles,
    required this.zoomLevels,
    required this.bufferMeters,
  });

  final Set<TileCoordinate> tiles;
  final List<int> zoomLevels;
  final double bufferMeters;

  /// FR-052's buffer.
  static const double defaultBufferMeters = 5000;

  /// Zooms worth holding for a roadside: enough to see the corridor and enough
  /// to read a junction. Anything deeper explodes the tile count.
  static const List<int> defaultZoomLevels = [10, 12, 14];

  /// Rough average weight of a vector-lite raster tile. Deliberately coarse —
  /// exposed only through [estimatedBytes], which is flagged as an estimate.
  static const int assumedBytesPerTile = 18 * 1024;

  int get estimatedBytes => tiles.length * assumedBytesPerTile;

  /// Always true. Nothing here has been downloaded or measured.
  bool get bytesAreEstimated => true;

  /// Tiles covering every segment of [route], widened by [bufferMeters].
  ///
  /// The route is treated as a polyline: each segment's bounding box is
  /// expanded by the buffer and converted to a tile range, then unioned.
  /// Segments are handled independently so a route that crosses the
  /// antimeridian produces two narrow strips rather than one world-wide span.
  static RouteTileCoverage forRoute({
    required List<GeoPoint> route,
    double bufferMeters = defaultBufferMeters,
    List<int> zoomLevels = defaultZoomLevels,
  }) {
    final tiles = <TileCoordinate>{};
    if (route.isEmpty) {
      return RouteTileCoverage(
        tiles: tiles,
        zoomLevels: List.unmodifiable(zoomLevels),
        bufferMeters: bufferMeters,
      );
    }

    final segments = <List<GeoPoint>>[];
    if (route.length == 1) {
      segments.add([route.first, route.first]);
    } else {
      for (var i = 0; i < route.length - 1; i++) {
        final a = route[i];
        final b = route[i + 1];
        // A segment spanning more than half the globe in longitude is the
        // antimeridian wrap, not a real corridor: split it at the seam.
        if ((a.longitude - b.longitude).abs() > 180) {
          final seamA = a.longitude >= 0 ? 180.0 : -180.0;
          final seamB = -seamA;
          segments.add([a, GeoPoint(a.latitude, seamA)]);
          segments.add([GeoPoint(b.latitude, seamB), b]);
        } else {
          segments.add([a, b]);
        }
      }
    }

    for (final z in zoomLevels) {
      for (final seg in segments) {
        tiles.addAll(_tilesForSegment(seg[0], seg[1], bufferMeters, z));
      }
    }

    return RouteTileCoverage(
      tiles: tiles,
      zoomLevels: List.unmodifiable(zoomLevels),
      bufferMeters: bufferMeters,
    );
  }

  static Iterable<TileCoordinate> _tilesForSegment(
    GeoPoint a,
    GeoPoint b,
    double bufferMeters,
    int z,
  ) {
    final minLat = math.min(a.latitude, b.latitude);
    final maxLat = math.max(a.latitude, b.latitude);
    final minLng = math.min(a.longitude, b.longitude);
    final maxLng = math.max(a.longitude, b.longitude);

    final latPad = _metersToLatDegrees(bufferMeters);
    // Longitude degrees shrink with latitude; pad using the widest latitude in
    // the segment so the buffer is never narrower than asked for.
    final widest = math.max(minLat.abs(), maxLat.abs());
    final lngPad = _metersToLngDegrees(bufferMeters, widest);

    final south = (minLat - latPad).clamp(-85.05112878, 85.05112878);
    final north = (maxLat + latPad).clamp(-85.05112878, 85.05112878);
    final west = (minLng - lngPad).clamp(-180.0, 180.0);
    final east = (maxLng + lngPad).clamp(-180.0, 180.0);

    final max = (1 << z) - 1;
    final xMin = _lngToTileX(west, z).clamp(0, max);
    final xMax = _lngToTileX(east, z).clamp(0, max);
    // Tile Y grows southwards, so north is the low index.
    final yMin = _latToTileY(north, z).clamp(0, max);
    final yMax = _latToTileY(south, z).clamp(0, max);

    final out = <TileCoordinate>[];
    for (var x = xMin; x <= xMax; x++) {
      for (var y = yMin; y <= yMax; y++) {
        out.add(TileCoordinate(x: x, y: y, z: z));
      }
    }
    return out;
  }

  static double _metersToLatDegrees(double meters) =>
      meters / 111_320.0;

  static double _metersToLngDegrees(double meters, double atLatitude) {
    final cos = math.cos(atLatitude * math.pi / 180).abs();
    if (cos < 1e-6) return 180;
    return meters / (111_320.0 * cos);
  }

  static int _lngToTileX(double lng, int z) =>
      ((lng + 180.0) / 360.0 * (1 << z)).floor();

  static int _latToTileY(double lat, int z) {
    final rad = lat * math.pi / 180.0;
    return ((1 - math.log(math.tan(rad) + 1 / math.cos(rad)) / math.pi) /
            2 *
            (1 << z))
        .floor();
  }
}

/// A named region the user has asked to keep offline, plus its computed
/// coverage. [status] is the truthful download state, not an aspiration.
class OfflineRegionPlan {
  const OfflineRegionPlan({
    required this.regionId,
    required this.name,
    required this.coverage,
    this.status = OfflineRegionStatus.notDownloaded,
    this.storedTiles = 0,
    this.storedBytes = 0,
  });

  final String regionId;
  final String name;
  final RouteTileCoverage coverage;
  final OfflineRegionStatus status;
  final int storedTiles;
  final int storedBytes;

  int get plannedTiles => coverage.tiles.length;

  double get completion =>
      plannedTiles == 0 ? 0 : (storedTiles / plannedTiles).clamp(0.0, 1.0);

  OfflineRegionPlan copyWith({
    OfflineRegionStatus? status,
    int? storedTiles,
    int? storedBytes,
  }) => OfflineRegionPlan(
    regionId: regionId,
    name: name,
    coverage: coverage,
    status: status ?? this.status,
    storedTiles: storedTiles ?? this.storedTiles,
    storedBytes: storedBytes ?? this.storedBytes,
  );
}
