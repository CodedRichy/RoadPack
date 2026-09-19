import 'package:flutter/material.dart';

/// Typography.
///
/// Two families, bundled rather than fetched -- this app has to render on a
/// dead network at the roadside.
///
/// * **Space Grotesk** (display, readouts). Wide apertures, a single-storey
///   'a', and numerals with enough personality to be told apart at a glance.
///   Used for anything read in under a second: countdowns, distances, state.
/// * **IBM Plex Sans** (body, UI). Drawn for interface legibility rather than
///   for branding. It is also one of the very few open families with matching
///   Devanagari, Tamil and Bengali cuts -- for an India-first product that is
///   a structural choice, not a taste one. Devanagari is already bundled as a
///   fallback so Hindi renders instead of tofu before i18n lands.
abstract final class AppType {
  static const String display = 'SpaceGrotesk';
  static const String body = 'IBMPlexSans';
  /// Script fallbacks, bundled not fetched. Hindi resolves through Plex
  /// Devanagari; Malayalam through Noto, because IBM Plex ships no Malayalam
  /// cut and Kerala is the pilot region -- the bystander screen, read by a
  /// stranger at a crash site, is the last place tofu is acceptable.
  static const List<String> fallback = [
    'IBMPlexSansDevanagari',
    'NotoSansMalayalam',
  ];

  // --- Weights ----------------------------------------------------------
  // Variable fonts: set fontVariations alongside fontWeight so the wght axis
  // is driven directly rather than snapped to a bundled static instance.
  static List<FontVariation> _wght(double w) => [FontVariation('wght', w)];

  /// Type scale: major third (1.25) off a 16px base, as in the vault
  /// reference. Readouts break out of the scale on purpose -- see [readout].
  static const double _base = 16;

  static const double labelSm = 11; // 0.688rem
  static const double labelMd = 13; // 0.813rem
  static const double bodySm = 14;
  static const double bodyMd = _base;
  static const double bodyLg = 20; // base * 1.25
  static const double titleSm = 20;
  static const double titleMd = 25; // base * 1.25^2
  static const double titleLg = 31; // base * 1.25^3
  static const double displaySm = 39; // base * 1.25^4
  static const double displayMd = 49; // base * 1.25^5
  static const double displayLg = 61; // base * 1.25^6

  /// Flutter's answer to `clamp()`: interpolate a size against the viewport's
  /// short edge, between a 360dp budget phone and a 480dp large phone, then
  /// stop. Nothing keeps growing on a tablet.
  static double fluid(
    BuildContext context, {
    required double min,
    required double max,
  }) {
    final width = MediaQuery.sizeOf(context).shortestSide;
    final t = ((width - 360) / (480 - 360)).clamp(0.0, 1.0);
    return min + (max - min) * t;
  }

  /// Caps the user's text scale factor. Riders do run their phones at 1.5x --
  /// but a countdown that reflows off-screen is worse than one that is merely
  /// large, so emergency surfaces clamp rather than obey without limit.
  static TextScaler clampScale(
    BuildContext context, {
    double min = 1.0,
    double max = 1.3,
  }) {
    return MediaQuery.textScalerOf(
      context,
    ).clamp(minScaleFactor: min, maxScaleFactor: max);
  }

  // --- Roles ------------------------------------------------------------

  /// The big number. Countdowns, distance to the pack, minutes since check-in.
  ///
  /// Tabular figures so digits do not jitter as they tick, and negative
  /// tracking because at this size default spacing reads as gappy.
  static TextStyle readout(double size) => TextStyle(
    fontFamily: display,
    fontFamilyFallback: fallback,
    fontSize: size,
    fontWeight: FontWeight.w700,
    fontVariations: _wght(700),
    height: 0.92,
    letterSpacing: size * -0.035,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// A readout sized against the viewport.
  static TextStyle fluidReadout(
    BuildContext context, {
    double min = 72,
    double max = 104,
  }) => readout(fluid(context, min: min, max: max));

  /// Screen and section headings.
  static TextStyle displayStyle(double size, {FontWeight? weight}) => TextStyle(
    fontFamily: display,
    fontFamilyFallback: fallback,
    fontSize: size,
    fontWeight: weight ?? FontWeight.w600,
    fontVariations: _wght((weight ?? FontWeight.w600).value.toDouble()),
    height: size >= displaySm ? 1.05 : 1.15,
    letterSpacing: size >= titleMd ? -0.02 * size : -0.01 * size,
  );

  /// Running text and controls.
  static TextStyle bodyStyle(double size, {FontWeight? weight}) => TextStyle(
    fontFamily: body,
    fontFamilyFallback: fallback,
    fontSize: size,
    fontWeight: weight ?? FontWeight.w400,
    fontVariations: _wght((weight ?? FontWeight.w400).value.toDouble()),
    height: 1.45,
  );

  /// Micro labels above a value. Uppercase, tracked out -- cramped uppercase
  /// is one of the clearest tells of type that was never spaced by hand.
  static TextStyle eyebrow(double size) => TextStyle(
    fontFamily: body,
    fontFamilyFallback: fallback,
    fontSize: size,
    fontWeight: FontWeight.w600,
    fontVariations: _wght(600),
    height: 1.2,
    letterSpacing: 0.11 * size / 2,
  );

  /// Numbers inside running UI -- counts, distances, times. Same tabular
  /// discipline as [readout] at text sizes.
  static TextStyle figure(double size, {FontWeight? weight}) => TextStyle(
    fontFamily: display,
    fontFamilyFallback: fallback,
    fontSize: size,
    fontWeight: weight ?? FontWeight.w600,
    fontVariations: _wght((weight ?? FontWeight.w600).value.toDouble()),
    height: 1.1,
    letterSpacing: -0.01 * size,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Material's [TextTheme], so the twelve screens that were never restyled
  /// still inherit the right faces, weights and rhythm.
  static TextTheme textTheme(Color primary) {
    return TextTheme(
      displayLarge: displayStyle(displayLg, weight: FontWeight.w700),
      displayMedium: displayStyle(displayMd, weight: FontWeight.w700),
      displaySmall: displayStyle(displaySm, weight: FontWeight.w600),
      headlineLarge: displayStyle(titleLg, weight: FontWeight.w600),
      headlineMedium: displayStyle(titleMd, weight: FontWeight.w600),
      headlineSmall: displayStyle(titleSm, weight: FontWeight.w600),
      titleLarge: displayStyle(titleSm, weight: FontWeight.w600),
      titleMedium: bodyStyle(bodyMd, weight: FontWeight.w600),
      titleSmall: bodyStyle(bodySm, weight: FontWeight.w600),
      bodyLarge: bodyStyle(bodyLg),
      bodyMedium: bodyStyle(bodyMd),
      bodySmall: bodyStyle(bodySm),
      labelLarge: bodyStyle(bodySm, weight: FontWeight.w600),
      labelMedium: eyebrow(labelMd),
      labelSmall: eyebrow(labelSm),
    ).apply(bodyColor: primary, displayColor: primary);
  }
}
