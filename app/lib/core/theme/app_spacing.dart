import 'package:flutter/material.dart';

/// Spacing scale.
///
/// 4px base, doubling at the top. Not a decorative rhythm -- [tapTarget] and
/// [gloveTarget] are the load-bearing values. A rider in winter gloves has an
/// effective touch radius closer to 12mm than the 9mm Material assumes, so any
/// control that can be pressed while kitted up uses [gloveTarget].
abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
  static const double huge = 64;

  /// Standard minimum touch target.
  static const double tapTarget = 48;

  /// Minimum touch target for anything reachable with gloves on.
  static const double gloveTarget = 64;

  /// Screen gutter. Wide enough that content clears a phone held one-handed
  /// in a handlebar mount.
  static const double gutter = 20;

  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: gutter);
  static const EdgeInsets card = EdgeInsets.all(lg);
}

/// Corner radii.
///
/// One family, one exception. The exception is [milestoneCap]: the home
/// screen's status slab borrows the rounded-top silhouette of an Indian
/// highway kilometre stone, so its top radius is half its width, not a token.
abstract final class AppRadius {
  static const double none = 0;
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  /// Kilometre-stone cap: rounded top, square base.
  static BorderRadius milestoneCap(double width) =>
      BorderRadius.vertical(top: Radius.circular(width / 2));
}

/// Border weights.
///
/// Sunlight doubles every stroke. Under glare a 1px hairline disappears while
/// a 2px edge survives, which is why the sunlight path defines structure with
/// borders rather than elevation.
abstract final class AppStroke {
  static const double hairline = 1;
  static const double regular = 1.5;
  static const double heavy = 2;
  static const double emphatic = 3;

  static double resolve(double base, {required bool sunlight}) =>
      sunlight ? base * 2 : base;
}

/// Elevation.
///
/// Dark mode elevates with lightness, not shadow (see the surface ladder in
/// [AppColors]). Shadow values here exist only for genuinely floating things:
/// sheets, dialogs, and the SOS control.
abstract final class AppElevation {
  static const double flat = 0;
  static const double raised = 1;
  static const double floating = 3;
  static const double overlay = 8;

  /// Shadows are invisible in direct sun; the sunlight path returns none.
  static List<BoxShadow> shadow(double level, {required bool sunlight}) {
    if (sunlight || level <= flat) return const [];
    return [
      BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.32),
        blurRadius: level * 6,
        offset: Offset(0, level * 2),
      ),
    ];
  }
}
