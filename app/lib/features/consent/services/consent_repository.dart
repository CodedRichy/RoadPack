import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/authenticated_supabase_provider.dart';
import '../../auth/providers/clerk_auth_provider.dart';
import '../models/consent_record.dart';
import '../models/consent_type.dart';

/// The wording version every consent written by this build refers to.
///
/// Bump this whenever the consent copy changes materially. The old records
/// keep the old version — that is the entire point of storing it.
const String kConsentWordingVersion = 'v1';

/// Data access for the `consents` ledger (migration 00009).
///
/// An interface, not a bare Supabase class, because the FR-003 age gate and
/// the fail-closed behaviour are correctness requirements that must be
/// provable against an in-memory double. (Supabase's fluent builders
/// implement `Future` at every step and cannot be mocked — see the note in
/// `test/features/circles/services/circle_repository_test.dart`.)
abstract interface class ConsentGateway {
  /// Every consent row for the signed-in user, granted and withdrawn alike.
  Future<List<ConsentRecord>> fetchConsents();

  /// Appends a new consent row. Never updates an existing one: re-granting
  /// after a withdrawal writes a second record, so the ledger keeps both
  /// the yes and the later no.
  Future<ConsentRecord> grant({
    required ConsentType type,
    required ConsentMethod method,
    required String grantedBy,
    String version,
  });

  /// Sets `revoked_at` on one record. This is the only mutation the table
  /// permits (trigger `consents_restrict_update`), and the only one this
  /// interface offers.
  Future<void> revoke(String consentId);
}

final consentGatewayProvider = Provider<ConsentGateway?>((ref) {
  final client = ref.watch(authenticatedSupabaseProvider);
  final userId = ref.watch(clerkAuthProvider).valueOrNull?.userId;
  if (client == null || userId == null) return null;
  return ConsentRepository(client, userId);
});

class ConsentRepository implements ConsentGateway {
  ConsentRepository(this._client, this._userId);

  final SupabaseClient _client;
  final String _userId;

  static const _table = 'consents';

  @override
  Future<List<ConsentRecord>> fetchConsents() async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', _userId)
        .order('granted_at', ascending: false);

    // Rows this build cannot parse are dropped rather than guessed at. A
    // dropped row can only remove a permission, never add one.
    return [
      for (final row in rows)
        if (ConsentRecord.tryFromJson(row) case final r?) r,
    ];
  }

  @override
  Future<ConsentRecord> grant({
    required ConsentType type,
    required ConsentMethod method,
    required String grantedBy,
    String version = kConsentWordingVersion,
  }) async {
    final row = await _client
        .from(_table)
        .insert({
          'user_id': _userId,
          'consent_type': type.wireValue,
          'granted_by': grantedBy,
          'method': method.wireValue,
          'version': version,
        })
        .select()
        .single();

    final parsed = ConsentRecord.tryFromJson(row);
    if (parsed == null) {
      // The insert succeeded but we cannot read back what we wrote. Do not
      // pretend consent was recorded in a usable form.
      throw StateError('Consent row written but not readable: $row');
    }
    return parsed;
  }

  @override
  Future<void> revoke(String consentId) async {
    await _client
        .from(_table)
        .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', consentId)
        .eq('user_id', _userId);
  }
}
