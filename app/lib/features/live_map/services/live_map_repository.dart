import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/authenticated_supabase_provider.dart';
import '../models/member_position.dart';

final liveMapRepositoryProvider = Provider<LiveMapRepository?>((ref) {
  final client = ref.watch(authenticatedSupabaseProvider);
  if (client == null) return null;
  return LiveMapRepository(client);
});

/// Reads circle-member positions, gated the same way the database gates them.
///
/// `can_view_location(viewer, target)` (migration 00005) is the authority: it
/// requires a shared circle whose `settings->>'location_sharing'` is true. RLS
/// already enforces that server-side, but the client repeats the entitlement
/// check locally so a membership row can never leak a marker through a widened
/// query or a cached response. A member the viewer is not entitled to see is
/// never constructed, so there is nothing on the screen to hide.
class LiveMapRepository {
  LiveMapRepository(this._client);

  final SupabaseClient _client;

  /// How far back a fix may be and still be worth plotting at all. Anything
  /// older is not shown as a faint dot — it is simply not a position any more.
  static const Duration lookback = Duration(hours: 2);

  /// Members of the viewer's circles whose circles enable location sharing.
  Future<List<MapMember>> fetchEntitledMembers(String viewerId) async {
    final myCircles = await _client
        .from('circle_members')
        .select('circle_id')
        .eq('user_id', viewerId);

    final circleIds = myCircles
        .map((r) => r['circle_id'] as String?)
        .whereType<String>()
        .toList();
    if (circleIds.isEmpty) return const [];

    final rows = await _client
        .from('circle_members')
        .select('circle_id, user_id, circles!inner(id, settings), users(name)')
        .inFilter('circle_id', circleIds);

    return entitledFromRows(
      viewerId: viewerId,
      rows: rows.cast<Map<String, dynamic>>(),
    );
  }

  /// Entitled members plus their latest fix, for one viewer.
  Future<List<MapMember>> fetchVisibleMembers(String viewerId) async {
    final entitled = await fetchEntitledMembers(viewerId);
    if (entitled.isEmpty) return const [];

    final since = DateTime.now().toUtc().subtract(lookback);
    final rows = await _client
        .from('location_history')
        .select('user_id, point, speed, heading, accuracy, battery_level, '
            'recorded_at, source')
        .inFilter('user_id', entitled.map((m) => m.userId).toList())
        .gte('recorded_at', since.toIso8601String())
        .order('recorded_at');

    return assemble(
      entitled: entitled,
      locationRows: rows.cast<Map<String, dynamic>>(),
    );
  }

  /// Pure entitlement filter, mirroring `can_view_location`.
  ///
  /// A row only yields a watchable member when the shared circle actually has
  /// `location_sharing` on. Missing or false settings mean no. The viewer is
  /// never returned as one of their own watched members.
  static List<MapMember> entitledFromRows({
    required String viewerId,
    required List<Map<String, dynamic>> rows,
  }) {
    final seen = <String>{};
    final out = <MapMember>[];

    for (final row in rows) {
      final userId = row['user_id'] as String?;
      if (userId == null || userId == viewerId) continue;

      final circle = row['circles'];
      if (circle is! Map) continue;
      final settings = circle['settings'];
      final sharing = settings is Map ? settings['location_sharing'] : null;
      if (sharing != true && sharing != 'true') continue;

      if (!seen.add(userId)) continue;

      final user = row['users'];
      final name = user is Map ? user['name'] as String? : null;

      out.add(
        MapMember(
          userId: userId,
          displayName: (name == null || name.isEmpty) ? 'Member' : name,
          circleId: (circle['id'] as String?) ?? row['circle_id'] as String,
        ),
      );
    }

    return out;
  }

  /// Joins location rows onto the entitled set.
  ///
  /// Rows for anyone outside [entitled] are discarded rather than rendered:
  /// entitlement decides who exists on this screen, data availability does not.
  /// An entitled member with no row survives with a null position, which the
  /// UI reports as "locating" — absence of a fix is information too.
  static List<MapMember> assemble({
    required List<MapMember> entitled,
    required List<Map<String, dynamic>> locationRows,
  }) {
    final allowed = {for (final m in entitled) m.userId};
    final latest = <String, MemberPosition>{};

    for (final row in locationRows) {
      final position = MemberPosition.tryFromRow(row);
      if (position == null) continue;
      if (!allowed.contains(position.userId)) continue;

      final existing = latest[position.userId];
      if (existing == null ||
          position.recordedAt.isAfter(existing.recordedAt)) {
        latest[position.userId] = position;
      }
    }

    return [
      for (final m in entitled) m.copyWith(position: latest[m.userId]),
    ];
  }
}
