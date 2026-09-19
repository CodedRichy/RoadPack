import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/emergency_profile/models/models.dart';

void main() {
  group('AlertMethod', () {
    test('round-trips through wire values', () {
      for (final m in AlertMethod.values) {
        expect(AlertMethod.fromWire(m.wire), m);
      }
    });

    test('unknown wire value is dropped, not crashed on', () {
      expect(AlertMethod.fromWire('telepathy'), isNull);
    });
  });

  group('EmergencyContact', () {
    final json = <String, dynamic>{
      'id': 'ec1',
      'user_id': 'user_1',
      'name': 'Amma',
      'phone': '+919876543210',
      'relationship': 'Mother',
      'priority': 1,
      'alert_method': ['push', 'sms', 'call'],
      'notified_at': null,
      'opted_out': false,
      'is_app_user': false,
      'app_user_id': null,
    };

    test('fromJson parses a full row', () {
      final c = EmergencyContact.fromJson(json);
      expect(c.id, 'ec1');
      expect(c.name, 'Amma');
      expect(c.phone, '+919876543210');
      expect(c.relationship, 'Mother');
      expect(c.priority, 1);
      expect(c.alertMethods, AlertMethod.values.toSet());
      expect(c.isNotified, isFalse);
      expect(c.optedOut, isFalse);
    });

    test('fromJson tolerates a null alert_method and defaults to push+sms', () {
      final c = EmergencyContact.fromJson({...json, 'alert_method': null});
      expect(c.alertMethods, {AlertMethod.push, AlertMethod.sms});
    });

    test('fromJson drops unknown alert methods', () {
      final c = EmergencyContact.fromJson({
        ...json,
        'alert_method': ['sms', 'smoke_signal'],
      });
      expect(c.alertMethods, {AlertMethod.sms});
    });

    test('isNotified is true once notified_at is set', () {
      final c = EmergencyContact.fromJson({
        ...json,
        'notified_at': '2026-09-01T10:00:00Z',
      });
      expect(c.isNotified, isTrue);
      expect(c.notifiedAt, DateTime.parse('2026-09-01T10:00:00Z'));
    });

    test('toJson omits server-owned columns', () {
      final map = EmergencyContact.fromJson(json).toJson();
      expect(map.containsKey('id'), isFalse);
      expect(map.containsKey('notified_at'), isFalse);
      expect(map['alert_method'], ['push', 'sms', 'call']);
      expect(map['user_id'], 'user_1');
    });

    test('copyWith replaces only what is passed', () {
      final c = EmergencyContact.fromJson(json);
      final moved = c.copyWith(priority: 3);
      expect(moved.priority, 3);
      expect(moved.name, c.name);
      expect(moved, isNot(equals(c)));
      expect(c.copyWith(), equals(c));
    });

    test('equality is by value', () {
      expect(
        EmergencyContact.fromJson(json),
        equals(EmergencyContact.fromJson(json)),
      );
      expect(
        EmergencyContact.fromJson(json).hashCode,
        EmergencyContact.fromJson(json).hashCode,
      );
    });
  });
}
