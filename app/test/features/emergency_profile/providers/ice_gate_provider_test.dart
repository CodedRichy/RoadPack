import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/emergency_profile/models/models.dart';
import 'package:roadpack/features/emergency_profile/providers/providers.dart';

ProviderContainer _container({
  bool incident = false,
  bool commute = false,
  bool optIn = true,
}) {
  final c = ProviderContainer(
    overrides: [
      iceIncidentActiveProvider.overrideWithValue(incident),
      iceCommuteActiveProvider.overrideWithValue(commute),
      iceCommuteExposureOptInProvider.overrideWithValue(optIn),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('IceAccess.resolve (FR-023 / SG-08 exposure gate)', () {
    test('grants nothing when neither an incident nor a commute is active', () {
      expect(
        IceAccess.resolve(
          incidentActive: false,
          commuteActive: false,
          commuteExposureOptIn: true,
        ),
        isNull,
      );
    });

    test('grants for an active incident', () {
      final access = IceAccess.resolve(
        incidentActive: true,
        commuteActive: false,
        commuteExposureOptIn: false,
      );
      expect(access, isNotNull);
      expect(access!.reason, IceExposureReason.activeIncident);
    });

    test('an incident overrides the commute opt-out', () {
      final access = IceAccess.resolve(
        incidentActive: true,
        commuteActive: true,
        commuteExposureOptIn: false,
      );
      expect(access!.reason, IceExposureReason.activeIncident);
    });

    test('grants for an active commute only when the user opted in', () {
      expect(
        IceAccess.resolve(
          incidentActive: false,
          commuteActive: true,
          commuteExposureOptIn: false,
        ),
        isNull,
        reason: 'commute exposure is opt-in per FR-094',
      );
      final access = IceAccess.resolve(
        incidentActive: false,
        commuteActive: true,
        commuteExposureOptIn: true,
      );
      expect(access!.reason, IceExposureReason.activeCommute);
    });
  });

  group('iceAccessProvider', () {
    test('is null in the idle state — the privacy default', () {
      expect(_container().read(iceAccessProvider), isNull);
    });

    test('is granted during an active incident', () {
      final access = _container(incident: true).read(iceAccessProvider);
      expect(access?.reason, IceExposureReason.activeIncident);
    });

    test('is granted during an opted-in active commute', () {
      final access = _container(commute: true).read(iceAccessProvider);
      expect(access?.reason, IceExposureReason.activeCommute);
    });

    test('is null during a commute the user did not opt in to', () {
      expect(
        _container(commute: true, optIn: false).read(iceAccessProvider),
        isNull,
      );
    });

    test('defaults to closed when no feature has published a signal', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(iceCommuteActiveProvider), isFalse);
      expect(c.read(iceAccessProvider), isNull);
    });
  });
}
