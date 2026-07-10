import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/clerk_auth_provider.dart';
import '../models/circle.dart';
import '../models/circle_member.dart';
import '../services/circle_repository.dart';
import 'circles_provider.dart';

final circleActionsProvider = Provider<CircleActions>((ref) {
  return CircleActions(ref);
});

class CircleActions {
  CircleActions(this._ref);

  final Ref _ref;

  CircleRepository? get _repo => _ref.read(circleRepositoryProvider);
  String? get _userId => _ref.read(clerkAuthProvider).valueOrNull?.userId;

  Future<Circle> createCircle({
    required String name,
    required CircleType type,
    int? maxMembers,
    DateTime? expiresAt,
  }) async {
    final repo = _repo;
    final userId = _userId;
    if (repo == null || userId == null) {
      throw StateError('Not authenticated');
    }

    if (type == CircleType.family) {
      final exists = await repo.hasExistingFamilyCircle(userId);
      if (exists) {
        throw StateError('You already have a family circle');
      }
    }

    final circle = await repo.createCircle(
      name: name,
      type: type,
      userId: userId,
      maxMembers: maxMembers,
      expiresAt: expiresAt,
    );

    await _ref.read(circlesProvider.notifier).refresh();
    return circle;
  }

  Future<Circle?> lookupInviteCode(String code) async {
    final repo = _repo;
    if (repo == null) return null;
    return repo.findByInviteCode(code);
  }

  Future<void> joinCircle({required Circle circle}) async {
    final repo = _repo;
    final userId = _userId;
    if (repo == null || userId == null) {
      throw StateError('Not authenticated');
    }

    if (circle.maxMembers != null) {
      final count = await repo.memberCount(circle.id);
      if (count >= circle.maxMembers!) {
        throw StateError('Circle is full');
      }
    }

    await repo.joinCircle(circleId: circle.id, userId: userId);

    if (circle.isFamily) {
      final members = await repo.fetchMembers(circle.id);
      await repo.syncFamilyEc(
        circleId: circle.id,
        newUserId: userId,
        existingMembers: members,
      );
    }

    await _ref.read(circlesProvider.notifier).refresh();
  }

  Future<void> leaveCircle({
    required String circleId,
    required bool isFamily,
  }) async {
    final repo = _repo;
    final userId = _userId;
    if (repo == null || userId == null) return;

    if (isFamily) {
      await repo.removeFamilyEc(circleId: circleId, userId: userId);
    }

    final members = await repo.fetchMembers(circleId);
    CircleMember? myMembership;
    for (final member in members) {
      if (member.userId == userId) {
        myMembership = member;
        break;
      }
    }

    if (myMembership != null && myMembership.isAdmin) {
      final others = members.where((m) => m.userId != userId).toList();
      if (others.isEmpty) {
        await repo.deleteCircle(circleId);
        await _ref.read(circlesProvider.notifier).refresh();
        return;
      }
      final hasOtherAdmin = others.any((m) => m.isAdmin);
      if (!hasOtherAdmin) {
        others.sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
        await repo.updateMemberRole(
          circleId: circleId,
          userId: others.first.userId,
          role: CircleRole.admin,
        );
      }
    }

    await repo.leaveCircle(circleId: circleId, userId: userId);
    await _ref.read(circlesProvider.notifier).refresh();
  }

  Future<void> removeMember({
    required String circleId,
    required String userId,
    required bool isFamily,
  }) async {
    final repo = _repo;
    if (repo == null) return;

    if (isFamily) {
      await repo.removeFamilyEc(circleId: circleId, userId: userId);
    }

    await repo.removeMember(circleId: circleId, userId: userId);
  }

  Future<void> addObserver({
    required String circleId,
    required String name,
    required String phone,
    String? relationship,
  }) async {
    final repo = _repo;
    final userId = _userId;
    if (repo == null || userId == null) return;

    await repo.addObserver(
      circleId: circleId,
      userId: userId,
      name: name,
      phone: phone,
      relationship: relationship,
    );
  }

  Future<void> removeObserver({required String ecId}) async {
    final repo = _repo;
    if (repo == null) return;
    await repo.removeObserver(ecId: ecId);
  }

  Future<void> updateRole({
    required String circleId,
    required String userId,
    required CircleRole role,
  }) async {
    final repo = _repo;
    if (repo == null) return;
    await repo.updateMemberRole(
      circleId: circleId,
      userId: userId,
      role: role,
    );
  }

  Future<void> toggleEc({
    required String circleId,
    required String targetUserId,
    required String targetName,
    required bool enable,
  }) async {
    final repo = _repo;
    final userId = _userId;
    if (repo == null || userId == null) return;
    await repo.toggleEc(
      circleId: circleId,
      ownerUserId: userId,
      targetUserId: targetUserId,
      targetName: targetName,
      enable: enable,
    );
  }

  Future<void> deleteCircle(String circleId) async {
    final repo = _repo;
    if (repo == null) return;
    await repo.deleteCircle(circleId);
    await _ref.read(circlesProvider.notifier).refresh();
  }

  Future<String> regenerateInviteCode(String circleId) async {
    final repo = _repo;
    if (repo == null) throw StateError('Not authenticated');
    final newCode = CircleRepository.generateInviteCode();
    await repo.regenerateInviteCode(circleId: circleId, newCode: newCode);
    return newCode;
  }
}
