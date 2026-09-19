import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/authenticated_supabase_provider.dart';
import '../../auth/providers/clerk_auth_provider.dart';
import '../models/emergency_contact.dart';

/// Data access for `emergency_contacts` (migration 00004).
///
/// Declared as an interface so the FR-024 once-only notice logic and the
/// FR-020 count constraints can be tested against an in-memory double —
/// these are correctness requirements, not UI polish, and must not depend on
/// a live Supabase to be verified.
abstract interface class EmergencyContactGateway {
  Future<List<EmergencyContact>> fetchContacts();

  Future<EmergencyContact> insertContact({
    required String name,
    required String phone,
    String? relationship,
    required int priority,
    required Set<AlertMethod> alertMethods,
  });

  Future<void> updateContact({
    required String contactId,
    String? name,
    String? phone,
    String? relationship,
    Set<AlertMethod>? alertMethods,
  });

  Future<void> deleteContact(String contactId);

  /// Rewrites `priority` for the given ids in one pass.
  Future<void> applyPriorities(Map<String, int> priorityById);

  /// Atomically claims the right to send the FR-024 listed notice.
  ///
  /// Implemented as a conditional UPDATE guarded on `notified_at IS NULL`, so
  /// only one caller can ever win for a given contact even if two devices (or
  /// two app launches) race. Returns true if this caller won the claim and
  /// must now send.
  Future<bool> claimNotice(String contactId);

  /// Undoes a claim whose send failed, so the notice can be retried later.
  Future<void> releaseNotice(String contactId);
}

final emergencyContactGatewayProvider = Provider<EmergencyContactGateway?>((
  ref,
) {
  final client = ref.watch(authenticatedSupabaseProvider);
  final userId = ref.watch(clerkAuthProvider).valueOrNull?.userId;
  if (client == null || userId == null) return null;
  return EmergencyContactRepository(client, userId);
});

class EmergencyContactRepository implements EmergencyContactGateway {
  EmergencyContactRepository(this._client, this._userId);

  final SupabaseClient _client;
  final String _userId;

  static const _table = 'emergency_contacts';

  @override
  Future<List<EmergencyContact>> fetchContacts() async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', _userId)
        .order('priority');
    return rows.map(EmergencyContact.fromJson).toList();
  }

  @override
  Future<EmergencyContact> insertContact({
    required String name,
    required String phone,
    String? relationship,
    required int priority,
    required Set<AlertMethod> alertMethods,
  }) async {
    final row = await _client
        .from(_table)
        .insert({
          'user_id': _userId,
          'name': name,
          'phone': phone,
          'relationship': relationship,
          'priority': priority,
          'alert_method': AlertMethod.values
              .where(alertMethods.contains)
              .map((m) => m.wire)
              .toList(),
        })
        .select()
        .single();
    return EmergencyContact.fromJson(row);
  }

  @override
  Future<void> updateContact({
    required String contactId,
    String? name,
    String? phone,
    String? relationship,
    Set<AlertMethod>? alertMethods,
  }) async {
    final patch = <String, dynamic>{
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (relationship != null) 'relationship': relationship,
      if (alertMethods != null)
        'alert_method': AlertMethod.values
            .where(alertMethods.contains)
            .map((m) => m.wire)
            .toList(),
    };
    if (patch.isEmpty) return;
    await _client
        .from(_table)
        .update(patch)
        .eq('id', contactId)
        .eq('user_id', _userId);
  }

  @override
  Future<void> deleteContact(String contactId) async {
    await _client
        .from(_table)
        .delete()
        .eq('id', contactId)
        .eq('user_id', _userId);
  }

  @override
  Future<void> applyPriorities(Map<String, int> priorityById) async {
    for (final entry in priorityById.entries) {
      await _client
          .from(_table)
          .update({'priority': entry.value})
          .eq('id', entry.key)
          .eq('user_id', _userId);
    }
  }

  @override
  Future<bool> claimNotice(String contactId) async {
    final claimed = await _client
        .from(_table)
        .update({'notified_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', contactId)
        .eq('user_id', _userId)
        .isFilter('notified_at', null)
        .select('id');
    return claimed.isNotEmpty;
  }

  @override
  Future<void> releaseNotice(String contactId) async {
    await _client
        .from(_table)
        .update({'notified_at': null})
        .eq('id', contactId)
        .eq('user_id', _userId);
  }
}
