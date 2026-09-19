import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/consent/models/consent_ledger.dart';
import 'package:roadpack/features/consent/models/consent_record.dart';
import 'package:roadpack/features/consent/models/consent_type.dart';

ConsentRecord _record(
  ConsentType type, {
  String id = 'c1',
  DateTime? grantedAt,
  DateTime? revokedAt,
}) => ConsentRecord(
  id: id,
  userId: 'u1',
  type: type,
  grantedAt: grantedAt ?? DateTime(2026, 1, 1),
  revokedAt: revokedAt,
);

void main() {
  group('ConsentLedger', () {
    test('an unknown ledger grants nothing', () {
      const ledger = ConsentLedger.unknown();
      expect(ledger.isKnown, isFalse);
      for (final type in ConsentType.values) {
        expect(ledger.isGranted(type), isFalse, reason: type.wireValue);
        expect(ledger.activeFor(type), isNull);
      }
    });

    test('an empty known ledger grants nothing but is known', () {
      const ledger = ConsentLedger([]);
      expect(ledger.isKnown, isTrue);
      expect(ledger.isGranted(ConsentType.tracking), isFalse);
    });

    test('a live record grants', () {
      final ledger = ConsentLedger([_record(ConsentType.tracking)]);
      expect(ledger.isGranted(ConsentType.tracking), isTrue);
      expect(ledger.isGranted(ConsentType.parental), isFalse);
    });

    test('a revoked record does not grant', () {
      final ledger = ConsentLedger([
        _record(ConsentType.tracking, revokedAt: DateTime(2026, 2, 1)),
      ]);
      expect(ledger.isGranted(ConsentType.tracking), isFalse);
      expect(ledger.historyFor(ConsentType.tracking), hasLength(1));
    });

    test('a re-grant after a revocation grants again, keeping both rows', () {
      final ledger = ConsentLedger([
        _record(
          ConsentType.tracking,
          id: 'old',
          grantedAt: DateTime(2026, 1, 1),
          revokedAt: DateTime(2026, 2, 1),
        ),
        _record(
          ConsentType.tracking,
          id: 'new',
          grantedAt: DateTime(2026, 3, 1),
        ),
      ]);
      expect(ledger.isGranted(ConsentType.tracking), isTrue);
      expect(ledger.activeFor(ConsentType.tracking)!.id, 'new');
      expect(ledger.historyFor(ConsentType.tracking), hasLength(2));
      expect(ledger.records.first.id, 'new', reason: 'newest first');
    });
  });

  group('ConsentRecord', () {
    test('drops a row with a consent type this build does not know', () {
      expect(
        ConsentRecord.tryFromJson({
          'id': 'x',
          'user_id': 'u1',
          'consent_type': 'mind_reading',
          'granted_at': '2026-01-01T00:00:00Z',
        }),
        isNull,
      );
    });

    test('parses a full row', () {
      final r = ConsentRecord.tryFromJson({
        'id': 'x',
        'user_id': 'u1',
        'consent_type': 'parental',
        'granted_by': 'parent1',
        'method': 'parent_otp',
        'granted_at': '2026-01-01T00:00:00Z',
        'revoked_at': null,
        'version': 'v1',
      })!;
      expect(r.type, ConsentType.parental);
      expect(r.grantedBy, 'parent1');
      expect(r.method, ConsentMethod.parentOtp);
      expect(r.isActive, isTrue);
    });

    test('revoked() changes only revoked_at, matching the DB trigger', () {
      final original = _record(ConsentType.tracking);
      final revoked = original.revoked(DateTime(2026, 5, 1));
      expect(revoked.id, original.id);
      expect(revoked.type, original.type);
      expect(revoked.grantedAt, original.grantedAt);
      expect(revoked.grantedBy, original.grantedBy);
      expect(revoked.method, original.method);
      expect(revoked.version, original.version);
      expect(revoked.isActive, isFalse);
    });
  });
}
