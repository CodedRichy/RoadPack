import 'package:flutter/material.dart';

/// Motion tokens.
///
/// Motion in RoadPack carries one of two meanings and nothing else:
/// a state changed, or time is running out. Decorative animation is banned --
/// on a budget Android phone it costs frames the crash detector needs, and a
/// moving screen is harder to read at a glance.
abstract final class AppMotion {
  /// Toggles, chips, pressed states.
  static const Duration instant = Duration(milliseconds: 120);

  /// The default. State changes on a card or tile.
  static const Duration quick = Duration(milliseconds: 220);

  /// Surface-level transitions, sheets, expanding sections.
  static const Duration settled = Duration(milliseconds: 340);

  /// Theme crossfade between night and sunlight.
  static const Duration deliberate = Duration(milliseconds: 500);

  /// One beat of the countdown. Deliberately 1Hz -- it matches a resting
  /// pulse, which is the only tempo a panicking rider can still count against.
  static const Duration pulse = Duration(milliseconds: 1000);

  /// Entrances.
  static const Curve enter = Curves.easeOutCubic;

  /// Exits.
  static const Curve exit = Curves.easeInCubic;

  /// State changes that should feel mechanical rather than soft -- protection
  /// arming, tracking starting.
  static const Curve mechanical = Curves.easeInOutQuart;

  /// The emergency pulse. Sharp attack, slow release, like a strobe.
  static const Curve alarm = Curves.easeOutExpo;

  /// Stagger between siblings in a list entrance.
  static const Duration stagger = Duration(milliseconds: 60);

  /// Honours the platform's reduced-motion setting. Emergency screens still
  /// pulse -- the countdown's beat is information, not decoration -- but every
  /// other animation collapses.
  static Duration respectReducedMotion(
    BuildContext context,
    Duration duration,
  ) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
  }
}
