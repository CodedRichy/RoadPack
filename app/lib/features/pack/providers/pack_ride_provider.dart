import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pack_gap.dart';
import '../models/pack_member.dart';
import '../models/pack_ride.dart';
import '../services/pack_repository.dart';

/// How often the client re-reads the gap table.
///
/// Matched to the server tick (TRD §6.2). Polling rather than a Realtime
/// subscription for now: step 5 replaces this with the single aggregated
/// broadcast, and until that lands a poll is honest about its own latency
/// where a silent dead socket is not.
const packPollInterval = Duration(seconds: 5);

/// The ride this rider is currently in, if any.
final activePackRideProvider =
    AsyncNotifierProvider<ActivePackRideNotifier, PackRide?>(
      ActivePackRideNotifier.new,
    );

class ActivePackRideNotifier extends AsyncNotifier<PackRide?> {
  @override
  Future<PackRide?> build() async {
    final repo = ref.watch(packRepositoryProvider);
    if (repo == null) return null;
    return repo.fetchActiveRide();
  }

  Future<void> refresh() async {
    final repo = ref.read(packRepositoryProvider);
    if (repo == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(repo.fetchActiveRide);
  }

  /// Adopt a ride the caller already holds, without a round trip.
  void set(PackRide? ride) => state = AsyncData(ride);
}

/// The live gap table for one ride. This is the screen's spine.
///
/// Failures keep the previous data on screen rather than blanking it, but the
/// rows themselves carry their own staleness from the server — so a poll that
/// stops succeeding degrades into "last seen Xm ago" on its own rather than
/// into a frozen list that still looks live.
final packGapsProvider =
    AsyncNotifierProvider.family<PackGapsNotifier, List<PackGap>, String>(
      PackGapsNotifier.new,
    );

class PackGapsNotifier extends FamilyAsyncNotifier<List<PackGap>, String> {
  Timer? _timer;

  @override
  Future<List<PackGap>> build(String rideId) async {
    final repo = ref.watch(packRepositoryProvider);
    if (repo == null) return const [];

    _timer?.cancel();
    _timer = Timer.periodic(packPollInterval, (_) => _poll(repo, rideId));
    ref.onDispose(() => _timer?.cancel());

    return repo.memberGaps(rideId);
  }

  Future<void> _poll(PackRepository repo, String rideId) async {
    final next = await AsyncValue.guard(() => repo.memberGaps(rideId));
    // Keep the last good table visible on a failed poll; the rows will age
    // into their own stale states rather than disappearing.
    if (next is AsyncError && state.hasValue) return;
    state = next;
  }

  Future<void> refresh() async {
    final repo = ref.read(packRepositoryProvider);
    if (repo == null) return;
    state = await AsyncValue.guard(() => repo.memberGaps(arg));
  }
}

/// The roster: names, roles, `chainage_at`, status notes. Changes rarely, so
/// it is fetched separately from the gap table rather than joined into every
/// five-second poll.
final packMembersProvider =
    AsyncNotifierProvider.family<PackMembersNotifier, List<PackMember>, String>(
      PackMembersNotifier.new,
    );

class PackMembersNotifier
    extends FamilyAsyncNotifier<List<PackMember>, String> {
  @override
  Future<List<PackMember>> build(String rideId) async {
    final repo = ref.watch(packRepositoryProvider);
    if (repo == null) return const [];
    return repo.fetchMembers(rideId);
  }

  Future<void> refresh() async {
    final repo = ref.read(packRepositoryProvider);
    if (repo == null) return;
    state = await AsyncValue.guard(() => repo.fetchMembers(arg));
  }
}

/// Roster indexed by user id, for joining onto the gap table.
final packMemberDirectoryProvider =
    Provider.family<Map<String, PackMember>, String>((ref, rideId) {
      final members = ref.watch(packMembersProvider(rideId)).valueOrNull;
      if (members == null) return const {};
      return {for (final m in members) m.userId: m};
    });
