import 'dart:math';

import '../models/impact_event.dart';

double getImpactThresholdForMount(String? mount) {
  return switch (mount) {
    'handlebar' => 4.0,
    'pocket' => 6.0,
    'bag' => 7.0,
    _ => 5.0,
  };
}

double getSensitivityThreshold(String? sensitivity) {
  return switch (sensitivity) {
    'high' => 0.45,
    'low' => 0.75,
    _ => 0.60,
  };
}

double calculateCrashScore({
  required ImpactEvent impact,
  required double mountThreshold,
  required double currentSpeedKmh,
  required double speedAfterKmh,
  required double peakRotationDegS,
  required bool isStillAfterImpact,
}) {
  final impactScore = min(
    1.0,
    (impact.peakG / mountThreshold - 1.0) * 0.5 + 0.5,
  );

  final double speedScore;
  if (currentSpeedKmh > 0) {
    final speedDrop = (currentSpeedKmh - speedAfterKmh) / currentSpeedKmh;
    speedScore = min(1.0, speedDrop / 0.5);
  } else {
    speedScore = 0.0;
  }

  final double rotationScore;
  if (peakRotationDegS > 300) {
    rotationScore = 1.0;
  } else if (peakRotationDegS > 150) {
    rotationScore = 0.5;
  } else {
    rotationScore = 0.0;
  }

  final stillnessScore = isStillAfterImpact ? 1.0 : 0.0;

  return impactScore * 0.4 +
      speedScore * 0.3 +
      rotationScore * 0.15 +
      stillnessScore * 0.15;
}

String deriveSeverity(double peakG) {
  if (peakG >= 12) return 'critical';
  if (peakG >= 8) return 'high';
  if (peakG >= 5) return 'medium';
  return 'low';
}
