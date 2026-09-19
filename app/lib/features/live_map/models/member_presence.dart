import 'member_position.dart';
import '../../../l10n/l10n.dart';

/// How a member's last known fix may be presented.
///
/// FR-053. The two axes that matter are *are we still hearing from this
/// device* and *is it moving*, and they are not the same question:
///
/// * [stationary] — we ARE hearing from the device; it simply is not moving.
/// * [unreachable] — we are NOT hearing from the device. Where it is now is
///   unknown; the dot on the map is history, not a location.
///
/// Conflating those two is a product failure: one means "they pulled over",
/// the other means "nobody knows".
enum MemberDisplayState {
  /// Entitled to see them, but no fix has ever arrived.
  locating,

  /// Fresh fix, device moving.
  live,

  /// Fresh fix, device not moving. Still in contact.
  stationary,

  /// Fix older than the live window. Greyed, age-labelled, never live.
  stale,

  /// Silent long enough that the device is presumed out of coverage or off.
  unreachable,
}

/// The presentation verdict for one member at one instant.
///
/// Everything the UI needs to decide colour, opacity and copy comes from here,
/// and nothing here extrapolates a position.
class MemberPresence {
  const MemberPresence._({
    required this.state,
    required this.position,
    required this.age,
  });

  final MemberDisplayState state;
  final MemberPosition? position;

  /// How old the fix is at the evaluated instant. Null when there is no fix.
  final Duration? age;

  /// A fix at or beyond this age can no longer be shown as live. FR-053.
  static const Duration liveWindow = Duration(seconds: 60);

  /// Silence beyond this means the device, not just the fix, is presumed gone.
  static const Duration unreachableWindow = Duration(minutes: 15);

  /// Below this the device is treated as parked rather than moving.
  static const double stationarySpeedKmh = 3;

  static MemberPresence resolve({
    required MemberPosition? position,
    required DateTime now,
  }) {
    if (position == null) {
      return const MemberPresence._(
        state: MemberDisplayState.locating,
        position: null,
        age: null,
      );
    }

    // A device clock ahead of ours must never buy extra freshness, and must
    // never produce a negative age that formats as nonsense.
    var age = now.difference(position.recordedAt);
    if (age.isNegative) age = Duration.zero;

    final MemberDisplayState state;
    if (age >= unreachableWindow) {
      state = MemberDisplayState.unreachable;
    } else if (age >= liveWindow) {
      state = MemberDisplayState.stale;
    } else if (position.speedKmh != null &&
        position.speedKmh! < stationarySpeedKmh) {
      state = MemberDisplayState.stationary;
    } else {
      state = MemberDisplayState.live;
    }

    return MemberPresence._(state: state, position: position, age: age);
  }

  /// True only while the fix is inside the live window. Being stationary is
  /// still live: we are in contact.
  bool get isLive =>
      state == MemberDisplayState.live ||
      state == MemberDisplayState.stationary;

  /// True when the device itself is still reporting.
  bool get hasSignal => isLive;

  bool get isStale =>
      state == MemberDisplayState.stale ||
      state == MemberDisplayState.unreachable;

  /// Speed is only meaningful while the fix is fresh. A speed attached to a
  /// four-minute-old fix describes the past, so it is withheld entirely.
  double? get trustedSpeedKmh => isLive ? position?.speedKmh : null;

  /// Battery is a device property, not a position, so it survives staleness —
  /// but it is still reported "as of" the fix age by the UI.
  int? get batteryLevel => position?.batteryLevel;

  /// Heading may only be drawn while live: an arrow on a stale marker reads as
  /// motion that is not happening.
  double? get trustedHeadingDegrees =>
      state == MemberDisplayState.live ? position?.headingDegrees : null;

  /// e.g. `last seen 4m ago`. Null when there is no fix to age.
  ///
  /// Takes the localisations rather than reading a context: freshness copy is
  /// the honesty layer, and a model that cannot be rendered in Malayalam is a
  /// model that renders English on a Malayalam handset.
  String? ageLabel(AppLocalizations l10n) {
    final a = age;
    if (a == null) return null;
    return l10n.mapAgeLabel(formatAge(a));
  }

  /// The one-line state, as shown on a chip or marker callout.
  String headline(AppLocalizations l10n) {
    switch (state) {
      case MemberDisplayState.locating:
        return l10n.mapPresenceLocating;
      case MemberDisplayState.live:
        return l10n.mapPresenceLive;
      case MemberDisplayState.stationary:
        return l10n.mapPresenceStopped;
      case MemberDisplayState.stale:
        return l10n.mapPresenceLastSeen(formatAge(age ?? Duration.zero));
      case MemberDisplayState.unreachable:
        return l10n.mapPresenceNoSignal;
    }
  }

  /// The supporting line. Says what we do and do not know — never reassures.
  String detail(AppLocalizations l10n) {
    switch (state) {
      case MemberDisplayState.locating:
        return l10n.mapPresenceDetailLocating;
      case MemberDisplayState.live:
        return l10n.mapPresenceDetailLive(formatAge(age ?? Duration.zero));
      case MemberDisplayState.stationary:
        return l10n.mapPresenceDetailStopped;
      case MemberDisplayState.stale:
        return l10n.mapPresenceDetailStale;
      case MemberDisplayState.unreachable:
        return l10n.mapPresenceDetailUnreachable(
          formatAge(age ?? Duration.zero),
        );
    }
  }

  /// Compact, jitter-free age. Tabular figures at the call site keep the digit
  /// columns from shifting as it ticks.
  static String formatAge(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    final hours = d.inMinutes ~/ 60;
    final minutes = d.inMinutes % 60;
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }
}
