import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/authenticated_supabase_provider.dart';
import '../../tracking/services/tracking_service.dart'
    show trackingDatabaseProvider;
import '../models/commute_route.dart';
import '../services/commute_route_repository.dart';

final commuteRouteRepositoryProvider = Provider<CommuteRouteRepository>((ref) {
  return CommuteRouteRepository(
    ref.watch(trackingDatabaseProvider),
    supabase: ref.watch(authenticatedSupabaseProvider),
  );
});

/// Every commute the app knows about, learned or manual (FR-040, FR-041).
final commuteRoutesProvider =
    AsyncNotifierProvider<CommuteRoutesNotifier, List<CommuteRoute>>(
      CommuteRoutesNotifier.new,
    );

class CommuteRoutesNotifier extends AsyncNotifier<List<CommuteRoute>> {
  CommuteRouteRepository get _repo => ref.read(commuteRouteRepositoryProvider);

  @override
  Future<List<CommuteRoute>> build() => _repo.list();

  /// Pulls the server's copy, then re-reads local. Failure is silent by
  /// design: the local list is still true, and an error banner over a correct
  /// list would only teach the rider to distrust it.
  Future<void> refresh() async {
    await _repo.pull();
    state = AsyncData(await _repo.list());
  }

  Future<CommuteRoute> createManual({
    required String name,
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required String typicalStart,
    required int typicalDurationMin,
    required List<int> daysActive,
  }) async {
    final route = await _repo.createManual(
      name: name,
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
      typicalStart: typicalStart,
      typicalDurationMin: typicalDurationMin,
      daysActive: daysActive,
    );
    state = AsyncData(await _repo.list());
    return route;
  }

  Future<void> save(CommuteRoute route) async {
    await _repo.upsert(route);
    state = AsyncData(await _repo.list());
  }

  Future<void> setNonArrivalEnabled(String routeId, bool enabled) async {
    await _repo.setNonArrivalEnabled(routeId, enabled);
    state = AsyncData(await _repo.list());
  }

  Future<void> delete(String routeId) async {
    await _repo.delete(routeId);
    state = AsyncData(await _repo.list());
  }
}

/// Routes that will actually raise a non-arrival check tonight.
///
/// Separate from the full list because the difference between "I have a route"
/// and "that route is watching me" is the whole product, and the UI must never
/// blur the two.
final watchedRoutesProvider = Provider<List<CommuteRoute>>((ref) {
  final routes = ref.watch(commuteRoutesProvider).valueOrNull ?? const [];
  return routes.where((r) => r.isWatched).toList(growable: false);
});
