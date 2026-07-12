import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/impact_event.dart';
import 'ring_buffer.dart';

class CrashSensorService {
  CrashSensorService({
    required double impactThresholdG,
    this.debounceMs = 20,
  }) : _impactThresholdG = impactThresholdG;

  final double _impactThresholdG;
  final int debounceMs;

  final RingBuffer<AccelSample> _accelBuffer = RingBuffer(500);
  final RingBuffer<GyroSample> _gyroBuffer = RingBuffer(250);

  final _impactController = StreamController<ImpactEvent>.broadcast();
  Stream<ImpactEvent> get impactStream => _impactController.stream;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  double _lastSpeedKmh = 0;
  bool _running = false;
  DateTime? _lastImpactTime;

  double get lastSpeedKmh => _lastSpeedKmh;

  void updateSpeed(double speedKmh) {
    _lastSpeedKmh = speedKmh;
  }

  void start() {
    if (_running) return;
    _running = true;
    _accelBuffer.clear();
    _gyroBuffer.clear();

    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 10),
    ).listen(_onAccel);

    _gyroSub = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 20),
    ).listen(_onGyro);

    debugPrint('[CrashSensor] Started (threshold: ${_impactThresholdG}g)');
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _accelSub?.cancel();
    _accelSub = null;
    _gyroSub?.cancel();
    _gyroSub = null;
    debugPrint('[CrashSensor] Stopped');
  }

  void _onAccel(AccelerometerEvent event) {
    final sample = AccelSample(
      x: event.x,
      y: event.y,
      z: event.z,
      timestamp: DateTime.now(),
    );
    _accelBuffer.add(sample);

    if (sample.magnitudeInG >= _impactThresholdG) {
      _checkImpact(sample);
    }
  }

  void _onGyro(GyroscopeEvent event) {
    final sample = GyroSample(
      x: event.x,
      y: event.y,
      z: event.z,
      timestamp: DateTime.now(),
    );
    _gyroBuffer.add(sample);
  }

  void _checkImpact(AccelSample trigger) {
    final now = trigger.timestamp;
    if (_lastImpactTime != null &&
        now.difference(_lastImpactTime!).inMilliseconds < debounceMs) {
      return;
    }

    if (_lastSpeedKmh < 10) return;

    _lastImpactTime = now;

    final accelWindow = _accelBuffer.toList();
    final gyroWindow = _gyroBuffer.toList();

    double peakG = 0;
    for (final s in accelWindow) {
      if (s.magnitudeInG > peakG) peakG = s.magnitudeInG;
    }

    double peakRotation = 0;
    for (final s in gyroWindow) {
      final degS = s.magnitudeInDegS;
      if (degS > peakRotation) peakRotation = degS;
    }

    final impact = ImpactEvent(
      peakG: peakG,
      peakRotationDegS: peakRotation,
      accelWindow: List.unmodifiable(accelWindow),
      gyroWindow: List.unmodifiable(gyroWindow),
      timestamp: now,
      speedBeforeKmh: _lastSpeedKmh,
    );

    _impactController.add(impact);
    debugPrint('[CrashSensor] Impact detected: ${peakG.toStringAsFixed(1)}g');
  }

  void dispose() {
    stop();
    _impactController.close();
  }
}
