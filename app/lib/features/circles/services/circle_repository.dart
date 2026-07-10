import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/authenticated_supabase_provider.dart';
import '../models/circle.dart';
import '../models/circle_member.dart';

final circleRepositoryProvider = Provider<CircleRepository?>((ref) {
  final client = ref.watch(authenticatedSupabaseProvider);
  if (client == null) return null;
  return CircleRepository(client);
});

class CircleRepository {
  CircleRepository(this._client);

  final SupabaseClient _client;

  static const _chars = 'abcdefghijklmnopqrstuvwxyz0123456789';

  static String generateInviteCode() {
    final rng = Random.secure();
    return List.generate(6, (_) => _chars[rng.nextInt(_chars.length)]).join();
  }

  Future<List<Circle>> fetchCircles() async {
    final data = await _client
        .from('circles')
        .select()
        .order('created_at');
    return data.map((row) => Circle.fromJson(row)).toList();
  }

  Future<Circle> createCircle({
    required String name,
    required CircleType type,
    required String userId,
    int? maxMembers,
    DateTime? expiresAt,
  }) async {
    String inviteCode = generateInviteCode();
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final row = await _client.from('circles').insert({
          'name': name,
          'type': type.value,
          'created_by': userId,
          'invite_code': inviteCode,
          'max_members': maxMembers,
          'expires_at': expiresAt?.toIso8601String(),
        }).select().single();

        await _client.from('circle_members').insert({
          'circle_id': row['id'],
          'user_id': userId,
          'role': CircleRole.admin.value,
          'accepted_at': DateTime.now().toIso8601String(),
        });

        return Circle.fromJson(row);
      } on PostgrestException catch (e) {
        if (e.code == '23505' && attempt < 2) {
          inviteCode = generateInviteCode();
          continue;
        }
        rethrow;
      }
    }
    throw StateError('Failed to generate unique invite code after 3 attempts');
  }

  Future<Circle?> findByInviteCode(String code) async {
    final row = await _client
        .from('circles')
        .select()
        .eq('invite_code', code.toLowerCase())
        .maybeSingle();
    if (row == null) return null;
    final circle = Circle.fromJson(row);
    if (circle.isExpired) return null;
    return circle;
  }

  Future<int> memberCount(String circleId) async {
    final data = await _client
        .from('circle_members')
        .select('user_id')
        .eq('circle_id', circleId);
    return data.length;
  }

  Future<void> joinCircle({
    required String circleId,
    required String userId,
  }) async {
    await _client.from('circle_members').insert({
      'circle_id': circleId,
      'user_id': userId,
      'role': CircleRole.member.value,
      'accepted_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<CircleMember>> fetchMembers(String circleId) async {
    final data = await _client
        .from('circle_members')
        .select('*, users(name)')
        .eq('circle_id', circleId)
        .order('joined_at');
    return data.map((row) => CircleMember.fromJson(row)).toList();
  }

  Future<List<EmergencyContact>> fetchObservers(String circleId) async {
    final data = await _client
        .from('emergency_contacts')
        .select()
        .eq('circle_id', circleId)
        .eq('is_app_user', false);
    return data.map((row) => EmergencyContact.fromJson(row)).toList();
  }

  Future<void> addObserver({
    required String circleId,
    required String userId,
    required String name,
    required String phone,
    String? relationship,
  }) async {
    final nextPriority = await _nextEcPriority(userId);
    await _client.from('emergency_contacts').insert({
      'user_id': userId,
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'priority': nextPriority,
      'alert_method': ['sms'],
      'is_app_user': false,
      'circle_id': circleId,
    });
  }

  Future<void> removeObserver({required String ecId}) async {
    await _client.from('emergency_contacts').delete().eq('id', ecId);
  }

  Future<void> removeMember({
    required String circleId,
    required String userId,
  }) async {
    await _client
        .from('circle_members')
        .delete()
        .eq('circle_id', circleId)
        .eq('user_id', userId);
  }

  Future<void> updateMemberRole({
    required String circleId,
    required String userId,
    required CircleRole role,
  }) async {
    await _client
        .from('circle_members')
        .update({'role': role.value})
        .eq('circle_id', circleId)
        .eq('user_id', userId);
  }

  Future<void> syncFamilyEc({
    required String circleId,
    required String newUserId,
    required List<CircleMember> existingMembers,
  }) async {
    for (final member in existingMembers) {
      if (member.userId == newUserId) continue;

      final priorityForMember = await _nextEcPriority(member.userId);
      final priorityForNew = await _nextEcPriority(newUserId);

      await _client.from('emergency_contacts').insert({
        'user_id': member.userId,
        'app_user_id': newUserId,
        'name': '',
        'phone': '',
        'priority': priorityForMember,
        'alert_method': ['push', 'sms'],
        'is_app_user': true,
        'circle_id': circleId,
      });

      await _client.from('emergency_contacts').insert({
        'user_id': newUserId,
        'app_user_id': member.userId,
        'name': member.userName ?? '',
        'phone': '',
        'priority': priorityForNew,
        'alert_method': ['push', 'sms'],
        'is_app_user': true,
        'circle_id': circleId,
      });
    }
  }

  Future<void> removeFamilyEc({
    required String circleId,
    required String userId,
  }) async {
    await _client
        .from('emergency_contacts')
        .delete()
        .eq('circle_id', circleId)
        .or('user_id.eq.$userId,app_user_id.eq.$userId');
  }

  Future<void> toggleEc({
    required String circleId,
    required String ownerUserId,
    required String targetUserId,
    required String targetName,
    required bool enable,
  }) async {
    if (enable) {
      final priority = await _nextEcPriority(ownerUserId);
      await _client.from('emergency_contacts').insert({
        'user_id': ownerUserId,
        'app_user_id': targetUserId,
        'name': targetName,
        'phone': '',
        'priority': priority,
        'alert_method': ['push', 'sms'],
        'is_app_user': true,
        'circle_id': circleId,
      });
    } else {
      await _client
          .from('emergency_contacts')
          .delete()
          .eq('circle_id', circleId)
          .eq('user_id', ownerUserId)
          .eq('app_user_id', targetUserId);
    }
  }

  Future<void> leaveCircle({
    required String circleId,
    required String userId,
  }) async {
    await _client
        .from('circle_members')
        .delete()
        .eq('circle_id', circleId)
        .eq('user_id', userId);
  }

  Future<void> deleteCircle(String circleId) async {
    await _client.from('circles').delete().eq('id', circleId);
  }

  Future<void> regenerateInviteCode({
    required String circleId,
    required String newCode,
  }) async {
    await _client
        .from('circles')
        .update({'invite_code': newCode})
        .eq('id', circleId);
  }

  Future<bool> hasExistingFamilyCircle(String userId) async {
    final data = await _client
        .from('circle_members')
        .select('circles!inner(id)')
        .eq('user_id', userId)
        .eq('circles.type', 'family')
        .limit(1);
    return data.isNotEmpty;
  }

  Future<int> _nextEcPriority(String userId) async {
    final data = await _client
        .from('emergency_contacts')
        .select('priority')
        .eq('user_id', userId)
        .order('priority', ascending: false)
        .limit(1);
    if (data.isEmpty) return 1;
    return (data.first['priority'] as int) + 1;
  }
}
