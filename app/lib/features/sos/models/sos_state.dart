import 'package:freezed_annotation/freezed_annotation.dart';

import 'incident.dart';

part 'sos_state.freezed.dart';

enum SosStatus {
  idle,
  armed,
  countdown,
  dispatching,
  active,
  resolved,
  cancelled,
}

@freezed
class SosState with _$SosState {
  const SosState._();

  const factory SosState({
    @Default(SosStatus.idle) SosStatus status,
    @Default(5) int countdownRemaining,
    Incident? activeIncident,
    String? errorMessage,
  }) = _SosState;

  bool get isActive =>
      status == SosStatus.active || status == SosStatus.dispatching;

  bool get canCancel =>
      status == SosStatus.countdown || status == SosStatus.armed;
}
