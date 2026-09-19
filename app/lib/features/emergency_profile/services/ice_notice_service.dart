import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/authenticated_supabase_provider.dart';
import '../models/emergency_contact.dart';
import 'emergency_contact_repository.dart';

/// Sends the FR-024 "you have been listed" SMS.
abstract interface class IceNoticeSender {
  Future<void> sendListedNotice({
    required EmergencyContact contact,
    required String listedByName,
  });
}

/// Supabase edge-function backed sender.
///
/// The SMS itself is dispatched server-side: the client never holds an SMS
/// provider credential, and the opt-out reply is handled by the existing
/// `sms-webhook` function, which sets `opted_out` on the row.
class EdgeFunctionNoticeSender implements IceNoticeSender {
  const EdgeFunctionNoticeSender(this._client);

  static const functionName = 'emergency-contact-notice';

  final SupabaseClient _client;

  @override
  Future<void> sendListedNotice({
    required EmergencyContact contact,
    required String listedByName,
  }) async {
    final res = await _client.functions.invoke(
      functionName,
      body: {
        'contact_id': contact.id,
        'phone': contact.phone,
        'name': contact.name,
        'listed_by': listedByName,
      },
    );
    if (res.status >= 400) {
      throw StateError(
        'emergency-contact-notice failed with status ${res.status}',
      );
    }
  }
}

/// Fires the one-time listed notice, exactly once per contact.
///
/// Ordering matters: the notice is *claimed* (`notified_at` set under an
/// `IS NULL` guard) before it is sent, so two racing callers can never both
/// send. A failed send releases the claim so it can be retried — the failure
/// mode we choose is "possibly late", never "possibly twice", because a
/// duplicate unsolicited SMS to someone who did not sign up for this product
/// is a consent problem, not an inconvenience.
///
/// This never runs on the incident path. It is a profile-editing side effect
/// and its failures are contained here.
class IceNoticeService {
  const IceNoticeService({
    required EmergencyContactGateway gateway,
    required IceNoticeSender sender,
  }) : _gateway = gateway,
       _sender = sender;

  final EmergencyContactGateway _gateway;
  final IceNoticeSender _sender;

  /// Returns how many notices were actually sent.
  Future<int> sendPendingNotices({
    required String listedByName,
    List<EmergencyContact>? contacts,
  }) async {
    final list = contacts ?? await _gateway.fetchContacts();
    var sent = 0;

    for (final contact in list) {
      if (!contact.needsListedNotice) continue;
      if (contact.isAppUser) continue;

      final claimed = await _gateway.claimNotice(contact.id);
      if (!claimed) continue;

      try {
        await _sender.sendListedNotice(
          contact: contact,
          listedByName: listedByName,
        );
        sent++;
      } catch (e) {
        // Hand the claim back so a later run can retry.
        try {
          await _gateway.releaseNotice(contact.id);
        } catch (releaseError) {
          debugPrint('ICE notice release failed for ${contact.id}: '
              '$releaseError');
        }
        debugPrint('ICE notice send failed for ${contact.id}: $e');
      }
    }

    return sent;
  }
}

final iceNoticeSenderProvider = Provider<IceNoticeSender?>((ref) {
  final client = ref.watch(authenticatedSupabaseProvider);
  if (client == null) return null;
  return EdgeFunctionNoticeSender(client);
});

final iceNoticeServiceProvider = Provider<IceNoticeService?>((ref) {
  final gateway = ref.watch(emergencyContactGatewayProvider);
  final sender = ref.watch(iceNoticeSenderProvider);
  if (gateway == null || sender == null) return null;
  return IceNoticeService(gateway: gateway, sender: sender);
});
