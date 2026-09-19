import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/emergency_profile/models/models.dart';
import 'package:roadpack/features/emergency_profile/services/services.dart';

EmergencyContact _contact({
  String id = 'ec1',
  String name = 'Amma',
  String phone = '+919876543210',
  int priority = 1,
}) => EmergencyContact(
  id: id,
  userId: 'user_1',
  name: name,
  phone: phone,
  priority: priority,
);

void main() {
  group('normalisePhone (Indian mobile format)', () {
    test('accepts the shapes people actually type', () {
      const expected = '+919876543210';
      for (final raw in [
        '9876543210',
        '09876543210',
        '+91 98765 43210',
        '+91-98765-43210',
        '919876543210',
        '0091 9876543210',
      ]) {
        expect(
          EmergencyContactValidator.normalisePhone(raw),
          expected,
          reason: raw,
        );
      }
    });

    test('rejects non-Indian-mobile shapes', () {
      for (final raw in [
        '',
        '12345',
        '1234567890', // must start 6-9
        '5876543210',
        '98765432101', // too long
        '+1 415 555 0100',
        'not a phone',
      ]) {
        expect(
          EmergencyContactValidator.normalisePhone(raw),
          isNull,
          reason: raw,
        );
      }
    });
  });

  group('validateAdd', () {
    test('accepts a valid first contact', () {
      expect(
        EmergencyContactValidator.validateAdd(
          existing: const [],
          name: 'Amma',
          phone: '9876543210',
          ownPhone: '+919000000000',
        ),
        isNull,
      );
    });

    test('rejects a 6th contact (FR-020 max is 5)', () {
      final existing = [
        for (var i = 1; i <= 5; i++)
          _contact(id: 'ec$i', phone: '+91987654321$i', priority: i),
      ];
      expect(
        EmergencyContactValidator.validateAdd(
          existing: existing,
          name: 'Extra',
          phone: '9000000001',
          ownPhone: null,
        ),
        EmergencyContactError.tooMany,
      );
    });

    test('accepts the 5th contact', () {
      final existing = [
        for (var i = 1; i <= 4; i++)
          _contact(id: 'ec$i', phone: '+91987654321$i', priority: i),
      ];
      expect(
        EmergencyContactValidator.validateAdd(
          existing: existing,
          name: 'Fifth',
          phone: '9000000001',
          ownPhone: null,
        ),
        isNull,
      );
    });

    test('rejects a blank name', () {
      expect(
        EmergencyContactValidator.validateAdd(
          existing: const [],
          name: '   ',
          phone: '9876543210',
          ownPhone: null,
        ),
        EmergencyContactError.missingName,
      );
    });

    test('rejects a malformed phone number', () {
      expect(
        EmergencyContactValidator.validateAdd(
          existing: const [],
          name: 'Amma',
          phone: '12345',
          ownPhone: null,
        ),
        EmergencyContactError.invalidPhone,
      );
    });

    test('rejects a duplicate number regardless of formatting', () {
      expect(
        EmergencyContactValidator.validateAdd(
          existing: [_contact()],
          name: 'Amma again',
          phone: '098765 43210',
          ownPhone: null,
        ),
        EmergencyContactError.duplicatePhone,
      );
    });

    test('rejects listing yourself', () {
      expect(
        EmergencyContactValidator.validateAdd(
          existing: const [],
          name: 'Me',
          phone: '9876543210',
          ownPhone: '+919876543210',
        ),
        EmergencyContactError.selfContact,
      );
    });

    test('excludeId lets an edit keep its own number', () {
      expect(
        EmergencyContactValidator.validateAdd(
          existing: [_contact()],
          name: 'Amma',
          phone: '9876543210',
          ownPhone: null,
          excludeId: 'ec1',
        ),
        isNull,
      );
    });
  });

  group('validateRemove', () {
    test('removing the last contact is allowed but flagged below minimum', () {
      expect(
        EmergencyContactValidator.validateRemove(existing: [_contact()]),
        isNull,
      );
      expect(EmergencyContactValidator.meetsMinimum(const []), isFalse);
      expect(EmergencyContactValidator.meetsMinimum([_contact()]), isTrue);
    });

    test('removing from an empty list is a state error', () {
      expect(
        EmergencyContactValidator.validateRemove(existing: const []),
        EmergencyContactError.tooFew,
      );
    });
  });
}
