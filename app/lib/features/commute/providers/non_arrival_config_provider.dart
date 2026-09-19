import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/user_profile_provider.dart';
import '../models/grace_window.dart';
import '../models/non_arrival_config.dart';

/// The rider's non-arrival settings, derived from the `users` row.
///
/// Read-through rather than a second copy of the truth: the profile provider
/// already owns `non_arrival_enabled` / `non_arrival_delay_min`, and two
/// caches of a safety setting is one cache too many.
final nonArrivalConfigProvider = Provider<NonArrivalConfig>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  if (profile == null) return NonArrivalConfig.initial;
  return NonArrivalConfig(
    enabled: profile.nonArrivalEnabled ?? true,
    window: GraceWindow.fromMinutes(profile.nonArrivalDelayMin),
  );
});

/// Writes the settings back. Kept next to the reader so a screen never has to
/// know that the storage is the `users` row.
final nonArrivalConfigControllerProvider = Provider<NonArrivalConfigController>(
  NonArrivalConfigController.new,
);

class NonArrivalConfigController {
  NonArrivalConfigController(this._ref);

  final Ref _ref;

  NonArrivalConfig get current => _ref.read(nonArrivalConfigProvider);

  Future<void> setWindow(GraceWindow window) =>
      _write(current.copyWith(window: window));

  Future<void> setEnabled(bool enabled) =>
      _write(current.copyWith(enabled: enabled));

  Future<void> _write(NonArrivalConfig config) {
    return _ref
        .read(userProfileProvider.notifier)
        .updateNonArrivalSettings(
          enabled: config.enabled,
          delayMin: config.window.minutes,
        );
  }
}
