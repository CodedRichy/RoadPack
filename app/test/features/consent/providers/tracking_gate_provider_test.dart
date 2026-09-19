import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/auth/models/auth_state.dart';
import 'package:roadpack/features/auth/providers/clerk_auth_provider.dart';
import 'package:roadpack/features/auth/providers/user_profile_provider.dart';
import 'package:roadpack/features/consent/models/consent_record.dart';
import 'package:roadpack/features/consent/models/consent_type.dart';
import 'package:roadpack/features/consent/models/tracking_gate.dart';
import 'package:roadpack/features/consent/providers/consent_provider.dart';
import 'package:roadpack/features/consent/providers/tracking_gate_provider.dart';
import 'package:roadpack/features/consent/services/consent_repository.dart';
import 'package:roadpack/features/emergency_profile/providers/emergency_contacts_provider.dart';

import '../fakes.dart';

/// Dates of birth that stay on the correct side of 18 whenever this runs.
final _minorDob = DateTime(DateTime.now().year - 16, 1, 1);
final _adultDob = DateTime(DateTime.now().year - 30, 1, 1);

Future<ProviderContainer> _container({
  DateTime? dateOfBirth,
  String? name = 'Asha',
  String? phone = '+919876500000',
  bool hasEmergencyContact = true,
  required FakeConsentGateway gateway,
}) async {
  final container = ProviderContainer(
    overrides: [
      userProfileProvider.overrideWith(
        () => FakeProfileNotifier(
          UserProfile(userId: 'u1', name: name, dateOfBirth: dateOfBirth),
        ),
      ),
      clerkAuthProvider.overrideWith(
        () => FakeAuthNotifier(
          AuthState(
            status: AuthStatus.authenticated,
            userId: 'u1',
            phone: phone,
          ),
        ),
      ),
      emergencyProfileReadyProvider.overrideWithValue(hasEmergencyContact),
      consentGatewayProvider.overrideWithValue(gateway),
    ],
  );
  addTearDown(container.dispose);

  await container.read(userProfileProvider.future);
  await container.read(clerkAuthProvider.future);
  try {
    await container.read(consentRecordsProvider.future);
  } catch (_) {
    // An unreadable ledger is a state under test, not a test failure.
  }
  return container;
}

void main() {
  group('trackingGateProvider - FR-003 age gate', () {
    test(
      'an under-18 user with no parental consent cannot start tracking',
      () async {
        final gw = FakeConsentGateway(
          records: [fakeConsent(ConsentType.tracking)],
        );
        final c = await _container(dateOfBirth: _minorDob, gateway: gw);

        final gate = c.read(trackingGateProvider);
        expect(gate.mayStart, isFalse);
        expect(gate.has(TrackingBlocker.parentalConsentMissing), isTrue);
        expect(gate.needsParentalConsent, isTrue);
        expect(c.read(mayStartTrackingProvider), isFalse);
      },
    );

    test('an under-18 user with a live parental consent may start', () async {
      final gw = FakeConsentGateway(
        records: [
          fakeConsent(ConsentType.tracking),
          fakeConsent(ConsentType.parental, id: 'p1', grantedBy: 'parent1'),
        ],
      );
      final c = await _container(dateOfBirth: _minorDob, gateway: gw);
      expect(c.read(trackingGateProvider).mayStart, isTrue);
    });

    test('a revoked parental consent stops tracking again', () async {
      final gw = FakeConsentGateway(
        records: [
          fakeConsent(ConsentType.tracking),
          fakeConsent(ConsentType.parental, id: 'p1', grantedBy: 'parent1'),
        ],
      );
      final c = await _container(dateOfBirth: _minorDob, gateway: gw);
      expect(c.read(trackingGateProvider).mayStart, isTrue);

      await c
          .read(consentRecordsProvider.notifier)
          .revokeAll(ConsentType.parental);

      final gate = c.read(trackingGateProvider);
      expect(gate.mayStart, isFalse);
      expect(gate.has(TrackingBlocker.parentalConsentMissing), isTrue);
    });

    test('an adult needs no parental consent', () async {
      final gw = FakeConsentGateway(
        records: [fakeConsent(ConsentType.tracking)],
      );
      final c = await _container(dateOfBirth: _adultDob, gateway: gw);
      expect(c.read(trackingGateProvider).mayStart, isTrue);
    });

    test('a missing date of birth blocks and reads as under-18', () async {
      final gw = FakeConsentGateway(
        records: [fakeConsent(ConsentType.tracking)],
      );
      final c = await _container(dateOfBirth: null, gateway: gw);
      final gate = c.read(trackingGateProvider);
      expect(gate.mayStart, isFalse);
      expect(gate.has(TrackingBlocker.dateOfBirthMissing), isTrue);
      expect(gate.has(TrackingBlocker.parentalConsentMissing), isTrue);
    });
  });

  group('trackingGateProvider - fail closed', () {
    test('an unreadable consent ledger blocks tracking', () async {
      final gw = FakeConsentGateway(failFetch: true);
      final c = await _container(dateOfBirth: _adultDob, gateway: gw);

      final gate = c.read(trackingGateProvider);
      expect(gate.mayStart, isFalse);
      expect(gate.has(TrackingBlocker.consentStateUnknown), isTrue);
      expect(
        gate.has(TrackingBlocker.trackingConsentMissing),
        isFalse,
        reason: 'unknown is one blocker, not a pile the user cannot fix',
      );
    });

    test('a revoked tracking consent stops tracking', () async {
      final gw = FakeConsentGateway(
        records: [fakeConsent(ConsentType.tracking)],
      );
      final c = await _container(dateOfBirth: _adultDob, gateway: gw);
      expect(c.read(trackingGateProvider).mayStart, isTrue);

      await c
          .read(consentRecordsProvider.notifier)
          .revokeAll(ConsentType.tracking);

      final gate = c.read(trackingGateProvider);
      expect(gate.mayStart, isFalse);
      expect(gate.has(TrackingBlocker.trackingConsentMissing), isTrue);
    });

    test('granting tracking consent opens the gate', () async {
      final gw = FakeConsentGateway();
      final c = await _container(dateOfBirth: _adultDob, gateway: gw);
      expect(c.read(trackingGateProvider).mayStart, isFalse);

      await c
          .read(consentRecordsProvider.notifier)
          .grantSelf(ConsentType.tracking);

      expect(c.read(trackingGateProvider).mayStart, isTrue);
    });
  });

  group('trackingGateProvider - FR-004 profile completeness', () {
    test('no name blocks', () async {
      final gw = FakeConsentGateway(
        records: [fakeConsent(ConsentType.tracking)],
      );
      final c = await _container(
        dateOfBirth: _adultDob,
        name: '   ',
        gateway: gw,
      );
      expect(
        c.read(trackingGateProvider).has(TrackingBlocker.nameMissing),
        isTrue,
      );
    });

    test('no phone blocks', () async {
      final gw = FakeConsentGateway(
        records: [fakeConsent(ConsentType.tracking)],
      );
      final c = await _container(
        dateOfBirth: _adultDob,
        phone: null,
        gateway: gw,
      );
      expect(
        c.read(trackingGateProvider).has(TrackingBlocker.phoneMissing),
        isTrue,
      );
    });

    test('no emergency contact blocks', () async {
      final gw = FakeConsentGateway(
        records: [fakeConsent(ConsentType.tracking)],
      );
      final c = await _container(
        dateOfBirth: _adultDob,
        hasEmergencyContact: false,
        gateway: gw,
      );
      expect(
        c.read(trackingGateProvider).has(TrackingBlocker.noEmergencyContact),
        isTrue,
      );
    });

    test(
      'the first blocker is the one to fix first, and it explains itself',
      () async {
        final gw = FakeConsentGateway();
        final c = await _container(
          dateOfBirth: null,
          name: null,
          phone: null,
          hasEmergencyContact: false,
          gateway: gw,
        );
        final gate = c.read(trackingGateProvider);
        expect(gate.primary, TrackingBlocker.nameMissing);
        expect(gate.blockers.first.title, isNotEmpty);
        expect(gate.blockers.first.explanation, isNotEmpty);
      },
    );
  });

  group('consent ledger writes stay append-only', () {
    test('revoking changes nothing but revoked_at', () async {
      final gw = FakeConsentGateway(
        records: [fakeConsent(ConsentType.tracking)],
      );
      final c = await _container(dateOfBirth: _adultDob, gateway: gw);
      final before = gw.records.single;

      await c
          .read(consentRecordsProvider.notifier)
          .revokeAll(ConsentType.tracking);

      final after = gw.records.single;
      expect(after.id, before.id);
      expect(after.type, before.type);
      expect(after.grantedAt, before.grantedAt);
      expect(after.grantedBy, before.grantedBy);
      expect(after.method, before.method);
      expect(after.version, before.version);
      expect(after.revokedAt, isNotNull);
    });

    test('a re-grant appends rather than resurrecting the old row', () async {
      final gw = FakeConsentGateway(
        records: [fakeConsent(ConsentType.tracking)],
      );
      final c = await _container(dateOfBirth: _adultDob, gateway: gw);
      final notifier = c.read(consentRecordsProvider.notifier);

      await notifier.revokeAll(ConsentType.tracking);
      await notifier.grantSelf(ConsentType.tracking);

      expect(gw.records, hasLength(2));
      expect(gw.records.where((ConsentRecord r) => r.isActive), hasLength(1));
      expect(gw.records.first.revokedAt, isNotNull);
      expect(gw.records.last.version, kConsentWordingVersion);
    });
  });
}
