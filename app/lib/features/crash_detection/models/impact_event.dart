import 'dart:math';

class AccelSample {
  AccelSample({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  }) : magnitude = sqrt(x * x + y * y + z * z);

  final double x;
  final double y;
  final double z;
  final double magnitude;
  final DateTime timestamp;

  double get magnitudeInG => magnitude / 9.81;
}

class GyroSample {
  GyroSample({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  }) : magnitude = sqrt(x * x + y * y + z * z);

  final double x;
  final double y;
  final double z;
  final double magnitude;
  final DateTime timestamp;

  double get magnitudeInDegS => magnitude * (180 / pi);
}

class ImpactEvent {
  ImpactEvent({
    required this.peakG,
    required this.peakRotationDegS,
    required this.accelWindow,
    required this.gyroWindow,
    required this.timestamp,
    required this.speedBeforeKmh,
  });

  final double peakG;
  final double peakRotationDegS;
  final List<AccelSample> accelWindow;
  final List<GyroSample> gyroWindow;
  final DateTime timestamp;
  final double speedBeforeKmh;
}
