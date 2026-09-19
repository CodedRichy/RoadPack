import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tracking/providers/known_routes_provider.dart';
import '../models/geo_point.dart';
import '../models/offline_region.dart';
import '../services/offline_tile_cache.dart';
import '../services/route_tile_coverage.dart';
import '../services/tile_store.dart';

/// The tile store backing the offline cache.
///
/// [InMemoryTileStore] is the honest default: the app has no filesystem plugin
/// dependency yet, so nothing written here survives a restart. Override this
/// provider once a durable store exists.
final tileStoreProvider = Provider<TileStore>((ref) => InMemoryTileStore());

final offlineTileCacheProvider = Provider<OfflineTileCache>(
  (ref) => OfflineTileCache(store: ref.watch(tileStoreProvider)),
);

/// Measured occupancy of the cache. Real bytes, not a projection.
final tileCacheStatsProvider = FutureProvider.autoDispose<TileCacheStats>(
  (ref) => ref.watch(offlineTileCacheProvider).stats(),
);

/// One offline region per learned route, each with its 5 km buffer coverage.
///
/// Known routes currently store no polyline geometry (`route_geometry` is
/// never populated by the route learner), so the corridor is approximated by
/// the origin-destination line. That approximation is surfaced in the UI
/// rather than hidden: see [OfflineRegionPlanView.isApproximateCorridor].
final offlineRegionPlansProvider =
    FutureProvider.autoDispose<List<OfflineRegionPlanView>>((ref) async {
      final routes = await ref.watch(knownRoutesProvider.future);
      final cache = ref.watch(offlineTileCacheProvider);

      final views = <OfflineRegionPlanView>[];
      for (final route in routes) {
        final geometry = _parseGeometry(route.routeGeometry);
        final corridor =
            geometry ??
            [
              GeoPoint(route.originLat, route.originLng),
              GeoPoint(route.destLat, route.destLng),
            ];

        final plan = await cache.reconcile(
          cache.planFor(
            regionId: route.id,
            name: route.name ?? 'Route ${route.id.substring(0, 6)}',
            route: corridor,
          ),
        );

        views.add(
          OfflineRegionPlanView(
            plan: plan,
            isApproximateCorridor: geometry == null,
          ),
        );
      }
      return views;
    });

/// A plan plus the caveats the UI has to state.
class OfflineRegionPlanView {
  const OfflineRegionPlanView({
    required this.plan,
    required this.isApproximateCorridor,
  });

  final OfflineRegionPlan plan;

  /// True when the corridor is a straight origin-destination line rather than
  /// the road actually travelled. Estimated values must be marked estimated.
  final bool isApproximateCorridor;
}

List<GeoPoint>? _parseGeometry(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final matches = RegExp(
    r'(-?\d+\.\d+)\s*,\s*(-?\d+\.\d+)',
  ).allMatches(raw).toList();
  if (matches.length < 2) return null;
  return [
    for (final m in matches)
      GeoPoint(double.parse(m.group(1)!), double.parse(m.group(2)!)),
  ];
}
