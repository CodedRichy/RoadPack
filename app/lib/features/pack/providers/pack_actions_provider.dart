import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../auth/providers/clerk_auth_provider.dart';
import '../../consent/models/tracking_gate.dart';
import '../../consent/providers/tracking_gate_provider.dart';
import '../models/pack_member.dart';
import '../models/pack_ride.dart';
import '../models/pack_status.dart';
import '../services/pack_repository.dart';
import 'pack_ride_provider.dart';

final packActionsProvider = Provider<PackActions>(PackActions.new);

/// Every pack mutation, in one place, each one refreshing exactly what it
/// invalidated. Mirrors `CircleActions`.
class PackActions {
  PackActions(this._ref);

  final Ref _ref;

  PackRepository? get _repo => _ref.read(packRepositoryProvider);
  String? get _userId => _ref.read(clerkAuthProvider).valueOrNull?.userId;

  PackRepository get _requireRepo {
    final repo = _repo;
    if (repo == null) throw StateError('Not authenticated');
    return repo;
  }

  /// FR-003/FR-004. Joining or running a pack ride publishes the user's
  /// live position to everyone else in it, which is the same consent
  /// decision as background tracking and answers to the same single gate.
  ///
  /// Deliberately *not* applied to [endRide], [leaveRide] or [revokeShare]:
  /// the ways out must keep working even when the gate has shut, or a
  /// withdrawn consent would trap the user in a ride they cannot leave.
  void _requireTrackingAllowed() {
    final gate = _ref.read(trackingGateProvider);
    if (!gate.mayStart) throw TrackingNotPermitted(gate);
  }

  Future<PackRide> createRide({
    required String destinationWkt,
    required String routeLineWkt,
    required String routeSource,
    String? name,
    String? circleId,
    Duration ttl = const Duration(hours: 12),
  }) async {
    _requireTrackingAllowed();
    final ride = await _requireRepo.createRide(
      destinationWkt: destinationWkt,
      routeLineWkt: routeLineWkt,
      routeSource: routeSource,
      name: name,
      circleId: circleId,
      ttl: ttl,
    );
    _ref.read(activePackRideProvider.notifier).set(ride);
    return ride;
  }

  Future<PackMember> joinRide(String shareToken) async {
    _requireTrackingAllowed();
    final member = await _requireRepo.joinRide(shareToken);
    await _ref.read(activePackRideProvider.notifier).refresh();
    return member;
  }

  Future<PackRide> startRide(String rideId) async {
    _requireTrackingAllowed();
    final ride = await _requireRepo.startRide(rideId);
    _ref.read(activePackRideProvider.notifier).set(ride);
    return ride;
  }

  /// Ending the ride kills the share link in the same statement server-side.
  /// The local state is replaced with the returned row rather than optimistic
  /// values, so the UI cannot show sharing as off before it actually is.
  Future<PackRide> endRide(String rideId) async {
    final ride = await _requireRepo.endRide(rideId);
    _ref.read(activePackRideProvider.notifier).set(null);
    return ride;
  }

  Future<PackRide> revokeShare(String rideId) async {
    final ride = await _requireRepo.revokeShare(rideId);
    _ref.read(activePackRideProvider.notifier).set(ride);
    return ride;
  }

  Future<void> leaveRide(String rideId) async {
    await _requireRepo.leaveRide(rideId);
    _ref.read(activePackRideProvider.notifier).set(null);
  }

  Future<PackMember> setRole({
    required String rideId,
    required String userId,
    required PackRole role,
  }) async {
    final member = await _requireRepo.setRole(
      rideId: rideId,
      userId: userId,
      role: role,
    );
    await _ref.read(packMembersProvider(rideId).notifier).refresh();
    return member;
  }

  Future<void> setStatus({
    required String rideId,
    required PackStatus status,
    String? note,
  }) async {
    final userId = _userId;
    if (userId == null) throw StateError('Not authenticated');
    await _requireRepo.setStatus(
      rideId: rideId,
      userId: userId,
      status: status,
      note: note,
    );
    await _ref.read(packMembersProvider(rideId).notifier).refresh();
    await _ref.read(packGapsProvider(rideId).notifier).refresh();
  }
}

/// Thrown when a pack action would start sharing the user's location but the
/// FR-003/FR-004 gate is shut. Carries the gate so the UI can name the
/// blocker rather than showing a bare failure.
class TrackingNotPermitted implements Exception {
  const TrackingNotPermitted(this.gate);

  final TrackingGate gate;

  /// The refusal in the rider's language. `toString` stays a developer
  /// diagnostic — this is what a screen shows.
  String message(AppLocalizations l10n) =>
      gate.primary?.title(l10n) ?? l10n.consentTrackingNotPermitted;

  @override
  String toString() =>
      'TrackingNotPermitted(${gate.primary?.name ?? 'unknown'})';
}
