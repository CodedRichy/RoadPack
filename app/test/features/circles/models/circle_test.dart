import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/circles/models/circle.dart';

void main() {
  group('CircleType', () {
    test('fromString round-trips all types', () {
      for (final t in CircleType.values) {
        expect(CircleType.fromString(t.value), t);
      }
    });

    test('displayName returns human-readable text', () {
      expect(CircleType.family.displayName, 'Family');
      expect(CircleType.convoy.displayName, 'Convoy');
    });

    test('defaultName returns pre-fill text', () {
      expect(CircleType.family.defaultName, 'My Family');
      expect(CircleType.commute.defaultName, 'Commute Group');
    });
  });

  group('Circle', () {
    final json = {
      'id': 'c1',
      'name': 'Test Circle',
      'type': 'family',
      'created_by': 'user_1',
      'invite_code': 'abc123',
      'max_members': 15,
      'settings': <String, dynamic>{},
      'created_at': '2026-07-11T10:00:00Z',
      'expires_at': null,
    };

    test('fromJson parses a circle row', () {
      final circle = Circle.fromJson(json);
      expect(circle.id, 'c1');
      expect(circle.name, 'Test Circle');
      expect(circle.type, CircleType.family);
      expect(circle.createdBy, 'user_1');
      expect(circle.inviteCode, 'abc123');
      expect(circle.maxMembers, 15);
      expect(circle.isFamily, isTrue);
    });

    test('isExpired is false when expiresAt is null', () {
      final circle = Circle.fromJson(json);
      expect(circle.isExpired, isFalse);
    });

    test('isExpired is true when expiresAt is in the past', () {
      final circle = Circle.fromJson({
        ...json,
        'expires_at': '2020-01-01T00:00:00Z',
      });
      expect(circle.isExpired, isTrue);
    });

    test('equality works via Freezed', () {
      final a = Circle.fromJson(json);
      final b = Circle.fromJson(json);
      expect(a, equals(b));
    });

    test('copyWith updates name', () {
      final circle = Circle.fromJson(json);
      final renamed = circle.copyWith(name: 'New Name');
      expect(renamed.name, 'New Name');
      expect(renamed.id, circle.id);
    });
  });
}
