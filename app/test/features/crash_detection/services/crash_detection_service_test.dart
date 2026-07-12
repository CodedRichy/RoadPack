import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/crash_detection/models/impact_event.dart';
import 'package:roadpack/features/crash_detection/services/crash_detection_service.dart';

void main() {
  group('getImpactThresholdForMount', () {
    test('handlebar returns 4g', () {
      expect(getImpactThresholdForMount('handlebar'), 4.0);
    });

    test('pocket returns 6g', () {
      expect(getImpactThresholdForMount('pocket'), 6.0);
    });

    test('bag returns 7g', () {
      expect(getImpactThresholdForMount('bag'), 7.0);
    });

    test('unknown returns 5g default', () {
      expect(getImpactThresholdForMount(null), 5.0);
      expect(getImpactThresholdForMount('unknown'), 5.0);
    });
  });

  group('getSensitivityThreshold', () {
    test('high sensitivity returns 0.45', () {
      expect(getSensitivityThreshold('high'), 0.45);
    });

    test('medium sensitivity returns 0.60', () {
      expect(getSensitivityThreshold('medium'), 0.60);
    });

    test('low sensitivity returns 0.75', () {
      expect(getSensitivityThreshold('low'), 0.75);
    });

    test('null defaults to medium', () {
      expect(getSensitivityThreshold(null), 0.60);
    });
  });

  group('calculateCrashScore', () {
    ImpactEvent makeImpact({double peakG = 6.0}) {
      return ImpactEvent(
        peakG: peakG,
        peakRotationDegS: 0,
        accelWindow: [],
        gyroWindow: [],
        timestamp: DateTime(2026),
        speedBeforeKmh: 40,
      );
    }

    test('full crash signature scores high', () {
      final score = calculateCrashScore(
        impact: makeImpact(peakG: 8.0),
        mountThreshold: 5.0,
        currentSpeedKmh: 40,
        speedAfterKmh: 5,
        peakRotationDegS: 400,
        isStillAfterImpact: true,
      );
      expect(score, greaterThan(0.8));
    });

    test('impact only without speed drop scores low', () {
      final score = calculateCrashScore(
        impact: makeImpact(peakG: 6.0),
        mountThreshold: 5.0,
        currentSpeedKmh: 40,
        speedAfterKmh: 38,
        peakRotationDegS: 50,
        isStillAfterImpact: false,
      );
      expect(score, lessThan(0.5));
    });

    test('zero speed before gives zero speed score', () {
      final score = calculateCrashScore(
        impact: makeImpact(peakG: 6.0),
        mountThreshold: 5.0,
        currentSpeedKmh: 0,
        speedAfterKmh: 0,
        peakRotationDegS: 400,
        isStillAfterImpact: true,
      );
      expect(score, lessThan(0.7));
    });

    test('score components are bounded 0-1', () {
      final score = calculateCrashScore(
        impact: makeImpact(peakG: 20.0),
        mountThreshold: 4.0,
        currentSpeedKmh: 80,
        speedAfterKmh: 0,
        peakRotationDegS: 1000,
        isStillAfterImpact: true,
      );
      expect(score, lessThanOrEqualTo(1.0));
      expect(score, greaterThanOrEqualTo(0.0));
    });

    test('moderate rotation gives lower score than high', () {
      final scoreMod = calculateCrashScore(
        impact: makeImpact(peakG: 6.0),
        mountThreshold: 5.0,
        currentSpeedKmh: 40,
        speedAfterKmh: 5,
        peakRotationDegS: 200,
        isStillAfterImpact: true,
      );
      final scoreHigh = calculateCrashScore(
        impact: makeImpact(peakG: 6.0),
        mountThreshold: 5.0,
        currentSpeedKmh: 40,
        speedAfterKmh: 5,
        peakRotationDegS: 400,
        isStillAfterImpact: true,
      );
      expect(scoreHigh, greaterThan(scoreMod));
    });
  });

  group('deriveSeverity', () {
    test('under 5g is low', () {
      expect(deriveSeverity(4.5), 'low');
    });

    test('5-8g is medium', () {
      expect(deriveSeverity(6.0), 'medium');
    });

    test('8-12g is high', () {
      expect(deriveSeverity(10.0), 'high');
    });

    test('over 12g is critical', () {
      expect(deriveSeverity(15.0), 'critical');
    });
  });
}
