import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../auth/services/clerk_service.dart';
import '../../sos/services/sos_service.dart';
import '../../tracking/services/tracking_service.dart';
import '../models/crash_state.dart';
import '../models/impact_event.dart';
import '../services/crash_detection_service.dart';
import '../services/crash_sensor_service.dart';

final crashSensorServiceProvider = Provider<CrashSensorService?>((ref) {
  final clerkService = ref.watch(clerkServiceProvider);
  if (!clerkService.isSignedIn) return null;

  final threshold = getImpactThresholdForMount(null);
  final service = CrashSensorService(impactThresholdG: threshold);
  ref.onDispose(() => service.dispose());
  return service;
});

final crashDetectionProvider =
    StateNotifierProvider<CrashDetectionNotifier, CrashDetectionState>(
  (ref) => CrashDetectionNotifier(ref),
);

class CrashDetectionNotifier extends StateNotifier<CrashDetectionState> {
  CrashDetectionNotifier(this._ref) : super(const CrashDetectionState());

  final Ref _ref;
  Timer? _countdownTimer;
  StreamSubscription<ImpactEvent>? _impactSub;
  DateTime? _lastDetectionTime;

  static const _cooldownDuration = Duration(seconds: 60);

  CrashSensorService? get _sensorService =>
      _ref.read(crashSensorServiceProvider);
  SosService? get _sosService => _ref.read(sosServiceProvider);
  TrackingService? get _trackingService =>
      _ref.read(trackingServiceProvider);

  void startMonitoring() {
    if (state.status == CrashDetectionStatus.monitoring) return;

    final sensor = _sensorService;
    if (sensor == null) return;

    _impactSub?.cancel();
    _impactSub = sensor.impactStream.listen(_onImpact);
    sensor.start();

    state = state.copyWith(status: CrashDetectionStatus.monitoring);
    debugPrint('[CrashDetection] Monitoring started');
  }

  void stopMonitoring() {
    if (state.status == CrashDetectionStatus.disabled) return;
    if (state.status == CrashDetectionStatus.countdown ||
        state.status == CrashDetectionStatus.dispatching ||
        state.status == CrashDetectionStatus.active) {
      return;
    }

    _impactSub?.cancel();
    _impactSub = null;
    _sensorService?.stop();

    state = const CrashDetectionState();
    debugPrint('[CrashDetection] Monitoring stopped');
  }

  void _onImpact(ImpactEvent impact) {
    if (state.status != CrashDetectionStatus.monitoring) return;

    if (_lastDetectionTime != null &&
        DateTime.now().difference(_lastDetectionTime!) < _cooldownDuration) {
      debugPrint('[CrashDetection] In cooldown, ignoring impact');
      return;
    }

    final sensitivity = getSensitivityThreshold(null);
    final mountThreshold = getImpactThresholdForMount(null);

    final score = calculateCrashScore(
      impact: impact,
      mountThreshold: mountThreshold,
      currentSpeedKmh: impact.speedBeforeKmh,
      speedAfterKmh: _sensorService?.lastSpeedKmh ?? 0,
      peakRotationDegS: impact.peakRotationDegS,
      isStillAfterImpact: (_sensorService?.lastSpeedKmh ?? 0) < 5,
    );

    debugPrint(
      '[CrashDetection] Impact score: ${score.toStringAsFixed(2)} '
      '(threshold: $sensitivity)',
    );

    if (score >= sensitivity) {
      _startCountdown(impact);
    }
  }

  void _startCountdown(ImpactEvent impact) {
    _lastDetectionTime = DateTime.now();
    _trackingService?.setSOSMode(true);

    state = state.copyWith(
      status: CrashDetectionStatus.countdown,
      countdownRemaining: AppConstants.crashCountdownDuration.inSeconds,
      impactEvent: impact,
    );

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void _tick(Timer timer) {
    final remaining = state.countdownRemaining - 1;
    if (remaining <= 0) {
      timer.cancel();
      _countdownTimer = null;
      _dispatch();
    } else {
      state = state.copyWith(countdownRemaining: remaining);
    }
  }

  void cancel(String reason) {
    if (!state.canCancel) return;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _trackingService?.setSOSMode(false);

    state = state.copyWith(
      status: CrashDetectionStatus.cancelled,
      cancelledReason: reason,
    );

    debugPrint('[CrashDetection] Cancelled: $reason');

    unawaited(Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        state = state.copyWith(
          status: CrashDetectionStatus.monitoring,
          cancelledReason: null,
          impactEvent: null,
        );
        _sensorService?.start();
      }
    }));
  }

  Future<void> _dispatch() async {
    state = state.copyWith(status: CrashDetectionStatus.dispatching);
    final impact = state.impactEvent;
    if (impact == null) return;

    try {
      final service = _sosService;
      if (service == null) {
        state = state.copyWith(
          status: CrashDetectionStatus.monitoring,
          errorMessage: 'Not signed in',
        );
        return;
      }

      final sensorWindow = {
        'accel_samples': impact.accelWindow.length,
        'gyro_samples': impact.gyroWindow.length,
        'peak_g': impact.peakG,
        'peak_rotation_deg_s': impact.peakRotationDegS,
      };

      final incident = await service.dispatchCrash(
        peakG: impact.peakG,
        confidence: calculateCrashScore(
          impact: impact,
          mountThreshold: getImpactThresholdForMount(null),
          currentSpeedKmh: impact.speedBeforeKmh,
          speedAfterKmh: _sensorService?.lastSpeedKmh ?? 0,
          peakRotationDegS: impact.peakRotationDegS,
          isStillAfterImpact: (_sensorService?.lastSpeedKmh ?? 0) < 5,
        ),
        speedAtEvent: impact.speedBeforeKmh,
        sensorWindow: sensorWindow,
      );

      state = state.copyWith(
        status: CrashDetectionStatus.active,
        activeIncident: incident,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: CrashDetectionStatus.monitoring,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> resolve() async {
    final incident = state.activeIncident;
    if (incident == null) return;
    try {
      await _sosService?.resolveIncident(incident.id);
      state = state.copyWith(status: CrashDetectionStatus.resolved);
      await _trackingService?.setSOSMode(false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  void reset() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _trackingService?.setSOSMode(false);
    state = state.copyWith(
      status: CrashDetectionStatus.monitoring,
      impactEvent: null,
      activeIncident: null,
      cancelledReason: null,
      errorMessage: null,
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _impactSub?.cancel();
    super.dispose();
  }
}
