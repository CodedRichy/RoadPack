import '../models/geo_point.dart';
import '../models/offline_region.dart';
import 'route_tile_coverage.dart';
import 'tile_store.dart';

/// Offline tile caching for known routes (FR-052).
///
/// READ THIS BEFORE TRUSTING THE FEATURE NAME.
///
/// What this class genuinely does:
///   * computes exactly which tiles a known route plus its 5 km buffer needs,
///     at each zoom level, as testable arithmetic ([planFor]);
///   * stores and retrieves tile bytes through a [TileStore];
///   * reports measured cache occupancy and clears it, whole or per region.
///
/// What it does NOT do, and cannot do today:
///   * make the Google base map render without a network. `google_maps_flutter`
///     draws its base map inside the native Google Maps SDK. That SDK manages
///     its own private tile cache and exposes no supported API for seeding it.
///     `TileOverlay` can only draw *on top of* the base map, so a cached
///     overlay over a blank base map is not a usable map.
///   * fetch tiles. Google's tile endpoints may not be scraped or stored under
///     the Maps Platform terms, so there is deliberately no download routine
///     pointed at them. Wiring the fetch requires an alternative raster source
///     (self-hosted OSM/PMTiles, as the PRD §4.4 already prefers) and a map
///     widget that can render it.
///
/// So: the caching layer, the route-buffer computation and the cache
/// management UI are real; offline base-map rendering is not yet reachable.
class OfflineTileCache {
  OfflineTileCache({required TileStore store}) : _store = store;

  final TileStore _store;

  /// Hard, checkable statement of the limitation above.
  static const bool servesBaseMapOffline = false;

  static const String limitationNotice =
      'Offline areas are planned and measured, but the base map still needs a '
      'connection. Google Maps draws tiles inside its own SDK and gives the app '
      'no way to pre-load them. Switching to a self-hosted OSM tile source is '
      'what makes offline maps actually work.';

  bool get isDurable => _store.isDurable;

  Future<TileCacheStats> stats() => _store.stats();

  Future<void> store(
    TileCoordinate tile,
    List<int> bytes, {
    String? regionId,
  }) => _store.put(tile, bytes, regionId: regionId);

  Future<List<int>?> read(TileCoordinate tile) => _store.get(tile);

  Future<bool> hasTile(TileCoordinate tile) => _store.contains(tile);

  Future<void> clear() => _store.clear();

  Future<void> clearRegion(String regionId) => _store.clearRegion(regionId);

  /// Computes the coverage a route needs. Returns a plan in
  /// [OfflineRegionStatus.notDownloaded] because nothing has been fetched —
  /// the UI must not imply otherwise.
  OfflineRegionPlan planFor({
    required String regionId,
    required String name,
    required List<GeoPoint> route,
    double bufferMeters = RouteTileCoverage.defaultBufferMeters,
    List<int> zoomLevels = RouteTileCoverage.defaultZoomLevels,
  }) {
    final coverage = RouteTileCoverage.forRoute(
      route: route,
      bufferMeters: bufferMeters,
      zoomLevels: zoomLevels,
    );
    return OfflineRegionPlan(
      regionId: regionId,
      name: name,
      coverage: coverage,
      status: OfflineRegionStatus.notDownloaded,
    );
  }

  /// How much of a plan is actually on device. Counts real stored tiles, so a
  /// plan with no fetcher behind it reports 0 rather than "ready".
  Future<OfflineRegionPlan> reconcile(OfflineRegionPlan plan) async {
    var stored = 0;
    for (final tile in plan.coverage.tiles) {
      if (await _store.contains(tile)) stored++;
    }
    final status = stored == 0
        ? OfflineRegionStatus.notDownloaded
        : (stored == plan.plannedTiles
              ? OfflineRegionStatus.downloaded
              : OfflineRegionStatus.downloading);
    return plan.copyWith(storedTiles: stored, status: status);
  }
}
