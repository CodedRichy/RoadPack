import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/emergency_profile/models/models.dart';
import 'package:roadpack/features/emergency_profile/services/services.dart';

/// In-memory stand-in for the Supabase-backed gateway. [claimNotice] models
/// the real conditional UPDATE (`SET notified_at = now() WHERE notified_at IS
/// NULL`): it succeeds exactly once per contact.
class _FakeGateway implements EmergencyContactGateway {
  _FakeGateway(this.rows);

  final List<EmergencyContact> rows;
  final List<String> claimCalls = [];
  final List<String> releaseCalls = [];

  @override
  Future<bool> claimNotice(String contactId) async {
    claimCalls.add(contactId);
    final i = rows.indexWhere((c) => c.id == contactId);
    if (i < 0) return false;
    if (rows[i].notifiedAt != null) return false;
    rows[i] = rows[i].copyWith(notifiedAt: DateTime.utc(2026, 9, 8));
    return true;
  }

  @override
  Future<void> releaseNotice(String contactId) async {
    releaseCalls.add(contactId);
    final i = rows.indexWhere((c) => c.id == contactId);
    if (i >= 0) rows[i] = rows[i].copyWith(notifiedAt: null);
  }

  @override
  Future<List<EmergencyContact>> fetchContacts() async => List.of(rows);

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _RecordingSender implements IceNoticeSender {
  final List<String> sentTo = [];
  bool fail = false;

  @override
  Future<void> sendListedNotice({
    required EmergencyContact contact,
    required String listedByName,
  }) async {
    if (fail) throw StateError('sms gateway down');
    sentTo.add(contact.phone);
  }
}

EmergencyContact _c({
  required String id,
  String phone = '+919876543210',
  DateTime? notifiedAt,
  bool optedOut = false,
}) => EmergencyContact(
  id: id,
  userId: 'user_1',
  name: 'Contact $id',
  phone: phone,
  priority: 1,
  notifiedAt: notifiedAt,
  optedOut: optedOut,
);

void main() {
  group('IceNoticeService (FR-024 one-time listed notice)', () {
    test('sends the notice exactly once across repeated runs', () async {
      final gateway = _FakeGateway([
        _c(id: 'a', phone: '+919000000001'),
        _c(id: 'b', phone: '+919000000002'),
      ]);
      final sender = _RecordingSender();
      final service = IceNoticeService(gateway: gateway, sender: sender);

      final first = await service.sendPendingNotices(listedByName: 'Rishi');
      expect(first, 2);
      expect(sender.sentTo, ['+919000000001', '+919000000002']);

      final second = await service.sendPendingNotices(listedByName: 'Rishi');
      expect(second, 0, reason: 'notified_at already set');
      expect(sender.sentTo, hasLength(2));
    });

    test('concurrent runs still send only once per contact', () async {
      final gateway = _FakeGateway([_c(id: 'a')]);
      final sender = _RecordingSender();
      final service = IceNoticeService(gateway: gateway, sender: sender);

      final results = await Future.wait([
        service.sendPendingNotices(listedByName: 'Rishi'),
        service.sendPendingNotices(listedByName: 'Rishi'),
      ]);

      expect(results.reduce((a, b) => a + b), 1);
      expect(sender.sentTo, hasLength(1));
    });

    test('never re-notifies a contact that already has notified_at', () async {
      final gateway = _FakeGateway([
        _c(id: 'a', notifiedAt: DateTime.utc(2026, 1, 1)),
      ]);
      final sender = _RecordingSender();

      final sent = await IceNoticeService(
        gateway: gateway,
        sender: sender,
      ).sendPendingNotices(listedByName: 'Rishi');

      expect(sent, 0);
      expect(sender.sentTo, isEmpty);
      expect(gateway.claimCalls, isEmpty);
    });

    test('skips opted-out contacts without claiming them', () async {
      final gateway = _FakeGateway([_c(id: 'a', optedOut: true)]);
      final sender = _RecordingSender();

      final sent = await IceNoticeService(
        gateway: gateway,
        sender: sender,
      ).sendPendingNotices(listedByName: 'Rishi');

      expect(sent, 0);
      expect(sender.sentTo, isEmpty);
      expect(gateway.claimCalls, isEmpty);
    });

    test('releases the claim when the send fails so it can be retried', () async {
      final gateway = _FakeGateway([_c(id: 'a')]);
      final sender = _RecordingSender()..fail = true;
      final service = IceNoticeService(gateway: gateway, sender: sender);

      expect(await service.sendPendingNotices(listedByName: 'Rishi'), 0);
      expect(gateway.releaseCalls, ['a']);

      sender.fail = false;
      expect(await service.sendPendingNotices(listedByName: 'Rishi'), 1);
      expect(sender.sentTo, hasLength(1));
    });
  });
}
