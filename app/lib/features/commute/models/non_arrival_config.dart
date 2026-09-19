import 'grace_window.dart';

/// The rider's non-arrival settings, mirroring the two columns migration
/// 00016 added to `users`.
///
/// Per-user, not per-route: the `non-arrival-check` edge function reads
/// `users.non_arrival_delay_min` once per route it evaluates and skips the
/// user entirely when `users.non_arrival_enabled` is false. A per-route grace
/// window would be silently ignored by the server, so this model does not
/// pretend to offer one — `known_routes.non_arrival_enabled` is the only
/// per-route switch, and it lives on [CommuteRoute].
class NonArrivalConfig {
  const NonArrivalConfig({
    required this.enabled,
    this.window = GraceWindow.defaultWindow,
  });

  /// The state a rider has before the profile has loaded: watched, on the
  /// default window. Erring towards watching is the safe default here.
  static const NonArrivalConfig initial = NonArrivalConfig(enabled: true);

  final bool enabled;
  final GraceWindow window;

  Duration get grace => window.duration;

  NonArrivalConfig copyWith({bool? enabled, GraceWindow? window}) {
    return NonArrivalConfig(
      enabled: enabled ?? this.enabled,
      window: window ?? this.window,
    );
  }

  factory NonArrivalConfig.fromJson(Map<String, dynamic> json) {
    return NonArrivalConfig(
      enabled: json['non_arrival_enabled'] as bool? ?? true,
      window: GraceWindow.fromMinutes(json['non_arrival_delay_min'] as int?),
    );
  }

  Map<String, dynamic> toJson() => {
    'non_arrival_enabled': enabled,
    'non_arrival_delay_min': window.minutes,
  };

  @override
  bool operator ==(Object other) =>
      other is NonArrivalConfig &&
      other.enabled == enabled &&
      other.window == window;

  @override
  int get hashCode => Object.hash(enabled, window);

  @override
  String toString() =>
      'NonArrivalConfig(enabled: $enabled, window: ${window.minutes}m)';
}
