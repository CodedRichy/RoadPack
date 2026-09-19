import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/auth/models/auth_state.dart';
import 'package:roadpack/features/auth/providers/clerk_auth_provider.dart';
import 'package:roadpack/features/auth/providers/user_profile_provider.dart';
import 'package:roadpack/features/consent/models/consent_type.dart';
import 'package:roadpack/features/consent/models/tracking_gate.dart';
import 'package:roadpack/features/consent/providers/consent_provider.dart';
import 'package:roadpack/features/consent/services/consent_repository.dart';
import 'package:roadpack/features/emergency_profile/providers/emergency_contacts_provider.dart';
import 'package:roadpack/features/pack/providers/pack_actions_provider.dart';

import '../fakes.dart';

final _minorDob = DateTime(DateTime.now().year - 16, 1, 1);
final _adultDob = DateTime(DateTime.now().year - 30, 1, 1);

Future<ProviderContainer> _container({
  required FakeConsentGateway gateway,
  DateTime? dateOfBirth,
}) async {
  final container = ProviderContainer(
    overrides: [
      userProfileProvider.overrideWith(
        () => FakeProfileNotifier(
          UserProfile(
            userId: 'u1',
            name: 'Asha',
            dateOfBirth: dateOfBirth ?? _adultDob,
          ),
        ),
      ),
      clerkAuthProvider.overrideWith(
        () => FakeAuthNotifier(
          const AuthState(
            status: AuthStatus.authenticated,
            userId: 'u1',
            phone: '+919876500000',
          ),
        ),
      ),
      emergencyProfileReadyProvider.overrideWithValue(true),
      consentGatewayProvider.overrideWithValue(gateway),
    ],
  );
  addTearDown(container.dispose);
  await container.read(clerkAuthProvider.future);
  try {
    await container.read(consentRecordsProvider.future);
  } catch (_) {}
  return container;
}

void main() {
  group('pack rides answer to the same gate as background tracking', () {
    test(
      'a minor with no parental consent cannot create a pack ride',
      () async {
        final c = await _container(
          gateway: FakeConsentGateway(
            records: [fakeConsent(ConsentType.tracking)],
          ),
          dateOfBirth: _minorDob,
        );

        expect(
          () => c
              .read(packActionsProvider)
              .createRide(
                destinationWkt: 'POINT(76.6 9.9)',
                routeLineWkt: 'LINESTRING(76.6 9.9, 76.7 10.0)',
                routeSource: 'test',
              ),
          throwsA(isA<TrackingNotPermitted>()),
        );
      },
    );

    test('joining a ride is refused when consent was never given', () async {
      final c = await _container(gateway: FakeConsentGateway());

      expect(
        () => c.read(packActionsProvider).joinRide('tok'),
        throwsA(
          isA<TrackingNotPermitted>().having(
            (e) => e.gate.has(TrackingBlocker.trackingConsentMissing),
            'names the missing consent',
            isTrue,
          ),
        ),
      );
    });

    test(
      'an unreadable consent ledger refuses a ride, failing closed',
      () async {
        final c = await _container(
          gateway: FakeConsentGateway(failFetch: true),
        );

        expect(
          () => c.read(packActionsProvider).startRide('r1'),
          throwsA(
            isA<TrackingNotPermitted>().having(
              (e) => e.gate.has(TrackingBlocker.consentStateUnknown),
              'names the unknown state',
              isTrue,
            ),
          ),
        );
      },
    );

    test('the refusal carries a blocker the UI can name', () async {
      final c = await _container(gateway: FakeConsentGateway());
      try {
        await c.read(packActionsProvider).joinRide('tok');
        fail('expected a refusal');
      } on TrackingNotPermitted catch (e) {
        expect(e.gate.primary, isNotNull);
        expect(e.toString(), isNotEmpty);
      }
    });

    test(
      'leaving and ending are never gated, so consent cannot trap anyone',
      () async {
        // A withdrawn consent must not become a locked door: the ways out
        // stay reachable. These fail on the missing repository, not the gate.
        final c = await _container(
          gateway: FakeConsentGateway(failFetch: true),
        );
        expect(
          () => c.read(packActionsProvider).leaveRide('r1'),
          throwsA(isNot(isA<TrackingNotPermitted>())),
        );
        expect(
          () => c.read(packActionsProvider).endRide('r1'),
          throwsA(isNot(isA<TrackingNotPermitted>())),
        );
      },
    );
  });
}
