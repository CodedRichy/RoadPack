import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

// Aliased: `supabase_flutter` exports its own AuthException, and silently
// catching the wrong one would swallow a real auth failure.
import '../../../core/errors/errors.dart' as errors;
import '../../auth/providers/authenticated_supabase_provider.dart';
import '../models/pack_gap.dart';
import '../models/pack_member.dart';
import '../models/pack_ride.dart';
import '../models/pack_status.dart';

final packRepositoryProvider = Provider<PackRepository?>((ref) {
  final client = ref.watch(authenticatedSupabaseProvider);
  if (client == null) return null;
  return PackRepository(client);
});

/// Thin wrapper over the pack RPCs (migrations 00017 / 00018).
///
/// Every mutating call goes through a database function rather than a table
/// write, because the lifecycle rules — a share link dying with its ride, the
/// leader being unable to walk away from a live feed — are enforced there and
/// nowhere else. The one exception is [setStatus], which the TRD (§5.1)
/// specifies as a direct member-row write under RLS.
class PackRepository {
  const PackRepository(this._client);

  final SupabaseClient _client;

  /// EWKT for a point, in the order PostGIS reads it: longitude first.
  static String pointWkt({required double lat, required double lng}) =>
      'SRID=4326;POINT($lng $lat)';

  /// EWKT for a route polyline. `points` is (lat, lng) pairs in travel order.
  static String lineWkt(List<({double lat, double lng})> points) {
    final coords = points.map((p) => '${p.lng} ${p.lat}').join(',');
    return 'SRID=4326;LINESTRING($coords)';
  }

  Future<PackRide> createRide({
    required String destinationWkt,
    required String routeLineWkt,
    required String routeSource,
    String? name,
    String? circleId,
    Duration ttl = const Duration(hours: 12),
  }) async {
    final row = await _rpc('fn_pack_create_ride', {
      'p_destination': destinationWkt,
      'p_route_line': routeLineWkt,
      'p_route_source': routeSource,
      'p_name': name,
      'p_circle_id': circleId,
      'p_ttl': '${ttl.inSeconds} seconds',
    });
    return PackRide.fromJson(_single(row));
  }

  Future<PackMember> joinRide(String shareToken) async {
    final row = await _rpc('fn_pack_join_ride', {
      'p_share_token': shareToken.trim(),
    });
    return PackMember.fromJson(_single(row));
  }

  Future<PackRide> startRide(String rideId) async {
    final row = await _rpc('fn_pack_start_ride', {'p_ride_id': rideId});
    return PackRide.fromJson(_single(row));
  }

  Future<PackRide> endRide(String rideId) async {
    final row = await _rpc('fn_pack_end_ride', {'p_ride_id': rideId});
    return PackRide.fromJson(_single(row));
  }

  Future<PackRide> revokeShare(String rideId) async {
    final row = await _rpc('fn_pack_revoke_share', {'p_ride_id': rideId});
    return PackRide.fromJson(_single(row));
  }

  Future<void> leaveRide(String rideId) async {
    await _rpc('fn_pack_leave_ride', {'p_ride_id': rideId});
  }

  Future<PackMember> setRole({
    required String rideId,
    required String userId,
    required PackRole role,
  }) async {
    final row = await _rpc('fn_pack_set_role', {
      'p_ride_id': rideId,
      'p_user_id': userId,
      'p_role': role.wire,
    });
    return PackMember.fromJson(_single(row));
  }

  /// The gap table. This is the only source of [PackGap.displayState].
  Future<List<PackGap>> memberGaps(String rideId) async {
    final rows = await _rpc('fn_pack_member_gaps', {'p_ride_id': rideId});
    if (rows is! List) return const [];
    return rows
        .cast<Map<String, dynamic>>()
        .map(PackGap.fromJson)
        .toList(growable: false);
  }

  /// The rider's own status. Automatic-only values are refused here as well as
  /// server-side: a client that can write `possible_incident` can fake a crash.
  Future<void> setStatus({
    required String rideId,
    required String userId,
    required PackStatus status,
    String? note,
  }) async {
    if (status.isAutomaticOnly) {
      throw errors.DomainException(
        '${status.wire} is set automatically and cannot be '
        'chosen by a rider',
      );
    }
    final trimmed = note?.trim();
    await _guard(
      () => _client
          .from('pack_ride_members')
          .update({
            'status_code': status.wire,
            'status_note': (trimmed == null || trimmed.isEmpty)
                ? null
                : trimmed.substring(0, trimmed.length.clamp(0, 140)),
            'status_at': DateTime.now().toUtc().toIso8601String(),
            'status_auto': false,
          })
          .eq('ride_id', rideId)
          .eq('user_id', userId),
    );
  }

  /// The ride this user is currently in, if any. RLS scopes the read to rides
  /// they are a member of, so no user id filter is needed or wanted.
  Future<PackRide?> fetchActiveRide() async {
    final rows = await _guard(
      () => _client
          .from('pack_rides')
          .select()
          .neq('status', 'ended')
          .order('created_at', ascending: false)
          .limit(1),
    );
    if (rows.isEmpty) return null;
    return PackRide.fromJson(rows.first);
  }

  Future<PackRide> fetchRide(String rideId) async {
    final row = await _guard(
      () => _client.from('pack_rides').select().eq('id', rideId).single(),
    );
    return PackRide.fromJson(row);
  }

  /// Members with their display names. The gap RPC returns ids only; names
  /// live here so the gap query stays a single cheap aggregate.
  Future<List<PackMember>> fetchMembers(String rideId) async {
    final rows = await _guard(
      () => _client
          .from('pack_ride_members')
          .select('*, users(name)')
          .eq('ride_id', rideId)
          .isFilter('left_at', null)
          .order('joined_at'),
    );
    return rows.map(PackMember.fromJson).toList(growable: false);
  }

  Future<dynamic> _rpc(String fn, Map<String, dynamic> params) =>
      _guard(() => _client.rpc(fn, params: params));

  Map<String, dynamic> _single(dynamic row) {
    if (row is List) {
      if (row.isEmpty) throw const errors.NetworkException('Empty response');
      return (row.first as Map).cast<String, dynamic>();
    }
    return (row as Map).cast<String, dynamic>();
  }

  /// Postgres and transport errors become something a screen can show.
  ///
  /// The RPCs raise plain-language exceptions ("this ride has ended", "only
  /// the ride leader can end the ride"), so those are surfaced verbatim rather
  /// than flattened into a generic failure — the rider needs to know which of
  /// the several ways a share link can die actually happened.
  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on PostgrestException catch (e) {
      final message = e.message.replaceFirst(RegExp(r'^.*?:\s*'), '');
      if (e.code == '42501' ||
          e.code == 'PGRST301' ||
          message.contains('not authenticated')) {
        throw errors.AuthException(message.isEmpty ? 'Sign in again' : message);
      }
      throw errors.DomainException(
        message.isEmpty ? 'Pack request failed' : message,
        code: e.code,
      );
    } on SocketException {
      throw const errors.NetworkException();
    } on http.ClientException {
      throw const errors.NetworkException();
    }
  }
}
