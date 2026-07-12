import 'package:freezed_annotation/freezed_annotation.dart';

import '../../sos/models/incident.dart';
import 'impact_event.dart';

part 'crash_state.freezed.dart';

enum CrashDetectionStatus {
  disabled,
  monitoring,
  detected,
  countdown,
  dispatching,
  active,
  resolved,
  cancelled,
}

@freezed
class CrashDetectionState with _$CrashDetectionState {
  const CrashDetectionState._();

  const factory CrashDetectionState({
    @Default(CrashDetectionStatus.disabled) CrashDetectionStatus status,
    @Default(30) int countdownRemaining,
    ImpactEvent? impactEvent,
    Incident? activeIncident,
    String? cancelledReason,
    String? errorMessage,
  }) = _CrashDetectionState;

  bool get isMonitoring => status == CrashDetectionStatus.monitoring;
  bool get isCountingDown => status == CrashDetectionStatus.countdown;
  bool get canCancel =>
      status == CrashDetectionStatus.countdown ||
      status == CrashDetectionStatus.detected;
}
