import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/crash_detection/models/crash_state.dart';

void main() {
  group('CrashDetectionState', () {
    test('default state is disabled', () {
      const state = CrashDetectionState();
      expect(state.status, CrashDetectionStatus.disabled);
      expect(state.countdownRemaining, 30);
      expect(state.impactEvent, isNull);
      expect(state.activeIncident, isNull);
    });

    test('isMonitoring returns true when monitoring', () {
      const state = CrashDetectionState(
        status: CrashDetectionStatus.monitoring,
      );
      expect(state.isMonitoring, true);
    });

    test('canCancel returns true during countdown', () {
      const state = CrashDetectionState(
        status: CrashDetectionStatus.countdown,
      );
      expect(state.canCancel, true);
    });

    test('canCancel returns false when active', () {
      const state = CrashDetectionState(
        status: CrashDetectionStatus.active,
      );
      expect(state.canCancel, false);
    });
  });
}
