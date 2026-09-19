import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/clerk_auth_provider.dart';
import '../models/member_position.dart';
import '../services/live_map_repository.dart';

/// One shared clock for the whole map.
///
/// Ages must tick even when no new fix arrives — that is the entire point of
/// FR-053: a marker that sat still for four minutes has to *say so*, and it
/// can only say so if something re-evaluates the age. Every widget on the map
/// ages against this one instant so two members are never compared against two
/// different "now"s.
final mapClockProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now().toUtc();
  yield* Stream.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now().toUtc(),
  );
});

/// How often positions are re-fetched. Deliberately slower than the clock:
/// the age label must keep moving whether or not the network cooperates.
const Duration livePositionRefreshInterval = Duration(seconds: 15);

/// Circle members the viewer is entitled to see, with their last known fix.
final liveMembersProvider =
    AsyncNotifierProvider.autoDispose<LiveMembersNotifier, List<MapMember>>(
      LiveMembersNotifier.new,
    );

class LiveMembersNotifier extends AutoDisposeAsyncNotifier<List<MapMember>> {
  Timer? _timer;

  @override
  Future<List<MapMember>> build() async {
    final repo = ref.watch(liveMapRepositoryProvider);
    final viewerId = ref.watch(clerkAuthProvider).valueOrNull?.userId;
    if (repo == null || viewerId == null) return const [];

    _timer?.cancel();
    _timer = Timer.periodic(livePositionRefreshInterval, (_) => refresh());
    ref.onDispose(() => _timer?.cancel());

    return repo.fetchVisibleMembers(viewerId);
  }

  /// Re-fetches without clearing the current list.
  ///
  /// The previous list is intentionally kept on the screen during a failed
  /// refresh rather than blanked — but nothing about it is re-marked as fresh,
  /// so every member simply ages into staleness on the shared clock. A network
  /// failure degrades trust gradually and visibly instead of hiding the map.
  Future<void> refresh() async {
    final repo = ref.read(liveMapRepositoryProvider);
    final viewerId = ref.read(clerkAuthProvider).valueOrNull?.userId;
    if (repo == null || viewerId == null) return;

    final next = await AsyncValue.guard(
      () => repo.fetchVisibleMembers(viewerId),
    );
    if (next is AsyncError && state.hasValue) return;
    state = next;
  }
}

/// The member whose detail sheet is open, by user id.
final selectedMemberIdProvider = StateProvider.autoDispose<String?>((_) => null);
