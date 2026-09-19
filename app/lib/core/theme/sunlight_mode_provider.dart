import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the rider has switched to the sunlight (high-contrast) path.
///
/// Deliberately a manual switch rather than an ambient-light sensor reading.
/// Auto-switching would flip the whole interface while a rider is mid-glance
/// under a flyover, and a screen that changes on its own is a screen you stop
/// trusting. The rider decides once, at the start of a ride.
final sunlightModeProvider = NotifierProvider<SunlightModeNotifier, bool>(
  SunlightModeNotifier.new,
);

class SunlightModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;

  void set(bool value) => state = value;
}

/// [ThemeMode] for the active path. Night is the default stance.
final appThemeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(sunlightModeProvider) ? ThemeMode.light : ThemeMode.dark;
});
