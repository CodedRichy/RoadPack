import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/circles/models/circle_member.dart';

void main() {
  group('CircleRole', () {
    test('fromString round-trips all roles', () {
      for (final r in CircleRole.values) {
        expect(CircleRole.fromString(r.value), r);
      }
    });
  });

  group('CircleMember', () {
    final json = {
      'circle_id': 'c1',
      'user_id': 'user_1',
      'role': 'admin',
      'permissions': <String, dynamic>{},
      'accepted_at': '2026-07-11T10:00:00Z',
      'joined_at': '2026-07-11T10:00:00Z',
      'users': {'name': 'Alice'},
    };

    test('fromJson parses a member row with joined user name', () {
      final member = CircleMember.fromJson(json);
      expect(member.circleId, 'c1');
      expect(member.userId, 'user_1');
      expect(member.role, CircleRole.admin);
      expect(member.userName, 'Alice');
      expect(member.isAdmin, isTrue);
    });

    test('fromJson handles missing users join', () {
      final member = CircleMember.fromJson({
        ...json,
        'users': null,
      });
      expect(member.userName, isNull);
    });
  });

  group('EmergencyContact', () {
    final json = {
      'id': 'ec1',
      'user_id': 'user_1',
      'name': 'Mom',
      'phone': '+911234567890',
      'relationship': 'parent',
      'priority': 1,
      'alert_method': ['push', 'sms'],
      'opted_out': false,
      'is_app_user': true,
      'app_user_id': 'user_2',
      'circle_id': 'c1',
    };

    test('fromJson parses an EC row', () {
      final ec = EmergencyContact.fromJson(json);
      expect(ec.id, 'ec1');
      expect(ec.name, 'Mom');
      expect(ec.alertMethod, ['push', 'sms']);
      expect(ec.isAppUser, isTrue);
      expect(ec.circleId, 'c1');
    });

    test('fromJson defaults when nullable fields are null', () {
      final ec = EmergencyContact.fromJson({
        ...json,
        'relationship': null,
        'app_user_id': null,
        'circle_id': null,
        'opted_out': null,
        'is_app_user': null,
      });
      expect(ec.relationship, isNull);
      expect(ec.optedOut, isFalse);
      expect(ec.isAppUser, isFalse);
    });
  });
}
