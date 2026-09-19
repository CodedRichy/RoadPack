import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../tracking/db/tracking_database.dart';
import '../models/commute_route.dart';

/// Reads and writes commute routes.
///
/// Local-first, deliberately: `known_routes` rows are written to drift and the
/// Supabase mirror is best-effort. A rider in a Kerala dead zone must still be
/// able to add the commute they are about to make, and the alternative — a
/// creation flow that fails without a network — would mean the routes most
/// worth watching are the ones that never get created.
///
/// The local table lives in `tracking/`, which owns route *learning*. This
/// class only reads and edits those rows; it does not duplicate the learner.
class CommuteRouteRepository {
  CommuteRouteRepository(this._db, {SupabaseClient? supabase})
    : _supabase = supabase;

  final TrackingDatabase _db;
  final SupabaseClient? _supabase;

  /// Every route, learned or manual, newest activity first.
  Future<List<CommuteRoute>> list() async {
    final rows = await _db.getAllKnownRoutes();
    final routes = rows.map(CommuteRoute.fromLocal).toList();
    routes.sort((a, b) {
      final at = a.lastTraveled;
      final bt = b.lastTraveled;
      if (at == null && bt == null) {
        return a.displayName.compareTo(b.displayName);
      }
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return routes;
  }

  /// Creates a route by hand (FR-041), for a commute the app has not learned.
  ///
  /// Stored with a zero repetition count, which is what marks it as
  /// [RouteSource.manual] — see [RouteSource.fromRepetitions]. Confidence is 1:
  /// the rider told us, so there is nothing left to infer.
  Future<CommuteRoute> createManual({
    required String name,
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required String typicalStart,
    required int typicalDurationMin,
    required List<int> daysActive,
    bool nonArrivalEnabled = true,
    String? id,
  }) async {
    final route = CommuteRoute(
      id: id ?? const Uuid().v4(),
      name: name,
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
      typicalStart: typicalStart,
      typicalDurationMin: typicalDurationMin,
      daysActive: daysActive,
      confidence: 1,
      repetitionCount: 0,
      nonArrivalEnabled: nonArrivalEnabled,
      source: RouteSource.manual,
    );
    await upsert(route);
    return route;
  }

  /// Writes a route locally, then mirrors it to the server best-effort.
  Future<void> upsert(CommuteRoute route) async {
    await _db.insertKnownRoute(route.toCompanion());
    await _push(route);
  }

  Future<void> setNonArrivalEnabled(String routeId, bool enabled) async {
    final rows = await _db.getAllKnownRoutes();
    final row = rows.where((r) => r.id == routeId).firstOrNull;
    if (row == null) return;
    await upsert(
      CommuteRoute.fromLocal(row).copyWith(nonArrivalEnabled: enabled),
    );
  }

  Future<void> delete(String routeId) async {
    await (_db.delete(
      _db.knownRoutesLocal,
    )..where((r) => r.id.equals(routeId))).go();

    final supabase = _supabase;
    if (supabase == null) return;
    try {
      await supabase.from('known_routes').delete().eq('id', routeId);
    } catch (e) {
      debugPrint('[Commute] Server delete failed for $routeId: $e');
    }
  }

  /// Pulls the server's routes into the local table.
  ///
  /// Server rows win on conflict: `non-arrival-check` reads the server copy,
  /// so the server's view is the one that decides whether anybody is watched,
  /// and the screen must not show a different schedule from the one being
  /// enforced.
  Future<void> pull() async {
    final supabase = _supabase;
    if (supabase == null) return;
    try {
      final rows = await supabase.from('known_routes').select();
      for (final row in rows) {
        final route = _fromServerRow(row);
        if (route == null) continue;
        await _db.insertKnownRoute(route.toCompanion());
      }
    } catch (e) {
      debugPrint('[Commute] Route pull failed: $e');
    }
  }

  Future<void> _push(CommuteRoute route) async {
    final supabase = _supabase;
    if (supabase == null) return;
    try {
      await supabase.from('known_routes').upsert(route.toServerJson());
    } catch (e) {
      debugPrint('[Commute] Route push failed for ${route.id}: $e');
    }
  }

  CommuteRoute? _fromServerRow(Map<String, dynamic> row) {
    final origin = _parsePoint(row['origin']);
    final dest = _parsePoint(row['destination']);
    if (origin == null || dest == null) return null;

    final repetitionCount = (row['repetition_count'] as num?)?.toInt() ?? 0;
    return CommuteRoute(
      id: row['id'] as String,
      name: row['name'] as String?,
      originLat: origin.lat,
      originLng: origin.lng,
      destLat: dest.lat,
      destLng: dest.lng,
      typicalStart: _hhmm(row['typical_start'] as String?),
      typicalDurationMin: _intervalMinutes(row['typical_duration']),
      daysActive: CommuteRoute.parseDays(row['days_active']),
      confidence: (row['confidence'] as num?)?.toDouble() ?? 0,
      repetitionCount: repetitionCount,
      nonArrivalEnabled: row['non_arrival_enabled'] as bool? ?? true,
      source: RouteSource.fromRepetitions(repetitionCount),
      lastTraveled: row['last_traveled'] == null
          ? null
          : DateTime.tryParse(row['last_traveled'] as String),
    );
  }

  /// Postgres `TIME` arrives as `HH:mm:ss`; the app stores `HH:mm`.
  static String? _hhmm(String? time) {
    if (time == null) return null;
    final parts = time.split(':');
    if (parts.length < 2) return null;
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }

  static int? _intervalMinutes(Object? interval) {
    if (interval == null) return null;
    final match = RegExp(r'(\d+):(\d+)').firstMatch(interval.toString());
    if (match == null) {
      final mins = RegExp(r'(\d+)\s*min').firstMatch(interval.toString());
      return mins == null ? null : int.tryParse(mins.group(1)!);
    }
    return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  }

  static ({double lat, double lng})? _parsePoint(Object? point) {
    if (point is! String) return null;
    final match = RegExp(
      r'POINT\s*\(\s*([-\d.]+)\s+([-\d.]+)\s*\)',
    ).firstMatch(point);
    if (match == null) return null;
    final lng = double.tryParse(match.group(1)!);
    final lat = double.tryParse(match.group(2)!);
    if (lat == null || lng == null) return null;
    return (lat: lat, lng: lng);
  }
}
