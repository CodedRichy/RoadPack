import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../models/sos_state.dart';
import '../services/sos_service.dart';

final sosStateProvider = StateNotifierProvider<SosStateNotifier, SosState>(
  (ref) => SosStateNotifier(ref),
);

class SosStateNotifier extends StateNotifier<SosState> {
  SosStateNotifier(this._ref) : super(const SosState());

  final Ref _ref;
  Timer? _countdownTimer;

  SosService? get _service => _ref.read(sosServiceProvider);

  void arm() {
    if (state.status != SosStatus.idle) return;
    state = state.copyWith(status: SosStatus.armed);
  }

  void startCountdown() {
    if (state.status != SosStatus.armed) return;
    state = state.copyWith(
      status: SosStatus.countdown,
      countdownRemaining: AppConstants.sosCountdownDuration.inSeconds,
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

  void cancel() {
    if (!state.canCancel) return;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    state = state.copyWith(
      status: SosStatus.cancelled,
      countdownRemaining: AppConstants.sosCountdownDuration.inSeconds,
    );
  }

  void reset() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    state = const SosState();
  }

  Future<void> _dispatch() async {
    state = state.copyWith(status: SosStatus.dispatching);
    try {
      final service = _service;
      if (service == null) {
        state = state.copyWith(
          status: SosStatus.idle,
          errorMessage: 'Not signed in',
        );
        return;
      }
      final incident = await service.dispatchSos();
      state = state.copyWith(
        status: SosStatus.active,
        activeIncident: incident,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: SosStatus.idle,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> resolve() async {
    final incident = state.activeIncident;
    if (incident == null) return;
    try {
      await _service?.resolveIncident(incident.id);
      state = state.copyWith(status: SosStatus.resolved);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}
