import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/authenticated_supabase_provider.dart';
import '../db/tracking_database.dart';
import '../services/tracking_service.dart';

final knownRoutesProvider =
    AsyncNotifierProvider<KnownRoutesNotifier, List<KnownRoutesLocalData>>(
  KnownRoutesNotifier.new,
);

class KnownRoutesNotifier extends AsyncNotifier<List<KnownRoutesLocalData>> {
  TrackingDatabase get _db => ref.read(trackingDatabaseProvider);
  SupabaseClient? get _supabase => ref.read(authenticatedSupabaseProvider);

  @override
  Future<List<KnownRoutesLocalData>> build() async {
    return _db.getAllKnownRoutes();
  }

  Future<void> syncFromServer() async {
    final supabase = _supabase;
    if (supabase == null) return;

    try {
      final response = await supabase.from('known_routes').select();
      final serverRoutes = response as List<dynamic>;

      for (final r in serverRoutes) {
        final map = r as Map<String, dynamic>;
        final origin = _parsePoint(map['origin']);
        final dest = _parsePoint(map['destination']);
        if (origin == null || dest == null) continue;

        final durationInterval = map['typical_duration'] as String?;
        int? durationMin;
        if (durationInterval != null) {
          final match = RegExp(r'(\d+):(\d+)').firstMatch(durationInterval);
          if (match != null) {
            durationMin =
                int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
          }
        }

        await _db.insertKnownRoute(KnownRoutesLocalCompanion.insert(
          id: map['id'] as String,
          originLat: origin.lat,
          originLng: origin.lng,
          destLat: dest.lat,
          destLng: dest.lng,
          daysActive:
              map['days_active'] != null ? map['days_active'].toString() : '[]',
          name: Value(map['name'] as String?),
          typicalStart: Value(map['typical_start'] as String?),
          typicalDurationMin: Value(durationMin),
          confidence: Value((map['confidence'] as num?)?.toDouble() ?? 0),
          repetitionCount: Value(map['repetition_count'] as int? ?? 0),
          nonArrivalEnabled:
              Value(map['non_arrival_enabled'] as bool? ?? true),
          lastTraveled: Value(
            map['last_traveled'] != null
                ? DateTime.parse(map['last_traveled'] as String)
                : null,
          ),
          syncedAt: Value(DateTime.now()),
        ));
      }

      state = AsyncData(await _db.getAllKnownRoutes());
    } catch (e) {
      debugPrint('[KnownRoutes] Sync from server failed: $e');
    }
  }

  Future<void> syncToServer(String routeId) async {
    final supabase = _supabase;
    if (supabase == null) return;

    final routes = await _db.getAllKnownRoutes();
    final local = routes.where((r) => r.id == routeId).firstOrNull;
    if (local == null) return;

    try {
      await supabase.from('known_routes').upsert({
        'id': local.id,
        'name': local.name,
        'origin': 'POINT(${local.originLng} ${local.originLat})',
        'destination': 'POINT(${local.destLng} ${local.destLat})',
        'typical_start': local.typicalStart,
        'typical_duration': local.typicalDurationMin != null
            ? '${local.typicalDurationMin} minutes'
            : null,
        'days_active': local.daysActive,
        'confidence': local.confidence,
        'repetition_count': local.repetitionCount,
        'non_arrival_enabled': local.nonArrivalEnabled,
        'last_traveled': local.lastTraveled?.toIso8601String(),
      });

      await _db.updateKnownRoute(KnownRoutesLocalCompanion(
        id: Value(local.id),
        originLat: Value(local.originLat),
        originLng: Value(local.originLng),
        destLat: Value(local.destLat),
        destLng: Value(local.destLng),
        daysActive: Value(local.daysActive),
        syncedAt: Value(DateTime.now()),
      ));
    } catch (e) {
      debugPrint('[KnownRoutes] Sync to server failed: $e');
    }
  }

  Future<void> toggleNonArrival(String routeId, bool enabled) async {
    final routes = await _db.getAllKnownRoutes();
    final route = routes.where((r) => r.id == routeId).firstOrNull;
    if (route == null) return;

    await _db.updateKnownRoute(KnownRoutesLocalCompanion(
      id: Value(route.id),
      originLat: Value(route.originLat),
      originLng: Value(route.originLng),
      destLat: Value(route.destLat),
      destLng: Value(route.destLng),
      daysActive: Value(route.daysActive),
      nonArrivalEnabled: Value(enabled),
    ));

    state = AsyncData(await _db.getAllKnownRoutes());
  }

  ({double lat, double lng})? _parsePoint(dynamic point) {
    if (point == null) return null;
    if (point is String) {
      final match =
          RegExp(r'POINT\(([-\d.]+)\s+([-\d.]+)\)').firstMatch(point);
      if (match != null) {
        return (
          lat: double.parse(match.group(2)!),
          lng: double.parse(match.group(1)!),
        );
      }
    }
    return null;
  }
}
