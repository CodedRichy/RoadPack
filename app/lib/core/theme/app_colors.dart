import 'package:flutter/material.dart';

/// RoadPack colour tokens.
///
/// Direction: "kilometre stone". Every colour here is derived from something a
/// rider already reads on an Indian road -- instrument glass, a hi-viz vest, a
/// hazard band on a truck tailgate, a highway milestone cap.
///
/// Every value is authored in OKLCH and converted to sRGB, so lightness steps
/// are perceptually even rather than evenly spaced in hex. The OKLCH source is
/// recorded next to each token; change the OKLCH, then re-derive the hex.
///
/// Three rules hold this system together:
///
/// 1. Neutrals are tinted, never pure grey. Night neutrals carry H155 (the same
///    family as hi-viz), sunlight neutrals carry H95 (paper).
/// 2. The hazard tier is separated by *lightness*, not hue alone. Roughly 8% of
///    Indian men have red-green colour vision deficiency; hi-viz (Y 0.73),
///    watch (Y 0.46), attention (Y 0.36) and signal (Y 0.15) stay distinct in
///    greyscale.
/// 3. [signal] and [signalDeep] belong to the emergency tier and are reserved.
///    Nothing routine may use them. See [AppSemantics.emergency].
abstract final class AppColors {
  // --- Night neutrals -- instrument glass, H155 C0.008-0.014 -------------
  /// oklch(0.185 0.008 155)
  static const Color nightCanvas = Color(0xFF101411);

  /// oklch(0.235 0.008 155)
  static const Color nightSurface1 = Color(0xFF1B1F1C);

  /// oklch(0.280 0.009 155)
  static const Color nightSurface2 = Color(0xFF262A27);

  /// oklch(0.325 0.010 155)
  static const Color nightSurface3 = Color(0xFF303632);

  /// oklch(0.380 0.012 155)
  static const Color nightHairline = Color(0xFF3E4440);

  /// oklch(0.485 0.014 155)
  static const Color nightBorder = Color(0xFF59615C);

  /// oklch(0.620 0.012 155) -- 5.12:1 on canvas
  static const Color nightTextMuted = Color(0xFF818883);

  /// oklch(0.760 0.012 155) -- 8.66:1 on canvas
  static const Color nightTextSecondary = Color(0xFFABB3AE);

  /// oklch(0.940 0.010 155) -- 15.61:1 on canvas
  static const Color nightTextPrimary = Color(0xFFE6EDE8);

  // --- Sunlight neutrals -- paper, H95 ----------------------------------
  // At noon a dark screen becomes a mirror. The sunlight path is not a dimmer
  // dark theme, it is paper: maximum luminance, no mid-greys, borders instead
  // of shadows.

  /// oklch(0.985 0.003 95)
  static const Color sunCanvas = Color(0xFFFBFAF8);

  /// oklch(0.955 0.005 95)
  static const Color sunSurface1 = Color(0xFFF1F0EC);

  /// oklch(0.915 0.007 95)
  static const Color sunSurface2 = Color(0xFFE4E3DE);

  /// oklch(0.780 0.010 95)
  static const Color sunHairline = Color(0xFFB9B7B0);

  /// oklch(0.400 0.014 95)
  static const Color sunBorder = Color(0xFF4A483F);

  /// oklch(0.470 0.012 95) -- 6.52:1 on canvas
  static const Color sunTextMuted = Color(0xFF5D5B53);

  /// oklch(0.330 0.012 95) -- 11.75:1 on canvas
  static const Color sunTextSecondary = Color(0xFF37352F);

  /// oklch(0.170 0.010 95) -- 18.35:1 on canvas
  static const Color sunTextPrimary = Color(0xFF110F0B);

  // --- Hazard tier ------------------------------------------------------

  /// Hi-viz vest. Protection is on. oklch(0.885 0.205 128) -- 13.75:1 on night.
  static const Color hiViz = Color(0xFFB1F145);

  /// Hi-viz held back -- fills, tracks, inactive segments.
  /// oklch(0.700 0.150 128)
  static const Color hiVizDim = Color(0xFF83AF3E);

  /// Hi-viz dark enough to be text on paper. oklch(0.520 0.145 130) -- 5.04:1.
  static const Color hiVizInk = Color(0xFF4C7800);

  /// Something needs the rider's attention but nobody is hurt.
  /// oklch(0.720 0.165 72) -- 7.30:1 on night.
  static const Color attention = Color(0xFFE39000);

  /// Attention, legible as text on paper. oklch(0.560 0.155 65) -- 4.60:1.
  static const Color attentionInk = Color(0xFFB05C00);

  /// Cold, low chroma, deliberately outside the hazard family. Watchers are
  /// information, never status. oklch(0.760 0.105 215) -- 8.95:1 on night.
  static const Color watch = Color(0xFF54C2DB);

  /// oklch(0.520 0.075 215)
  static const Color watchDim = Color(0xFF2B7484);

  /// oklch(0.470 0.095 235) -- 6.45:1 on paper.
  static const Color watchInk = Color(0xFF0E6288);

  // --- Emergency tier -- RESERVED ---------------------------------------
  // Reserved for SOS, the crash countdown and off-route. Routine UI must never
  // reach into this block: if these colours appear anywhere else, they stop
  // meaning anything. Colour alone does not carry the tier -- emergency
  // surfaces are also full-bleed, chevron-banded and set in oversized tabular
  // numerals, so the tier survives greyscale, glare and gloved glances.

  /// Signal red field. oklch(0.555 0.225 27) -- paper on it is 5.10:1.
  static const Color signal = Color(0xFFD80318);

  /// Deeper red for the countdown field. oklch(0.430 0.190 27) -- 8.20:1.
  static const Color signalDeep = Color(0xFF9E0000);

  /// Signal red as text on paper. oklch(0.500 0.220 27) -- 6.11:1.
  static const Color signalInk = Color(0xFFC20000);

  /// Truck tailgate hazard band. oklch(0.845 0.185 92)
  static const Color hazardBand = Color(0xFFF7C600);

  /// Ink for anything sitting on [hazardBand] or [hiViz]. oklch(0.120 0.010 92)
  static const Color hazardInk = Color(0xFF070603);

  /// Text on any emergency field. oklch(0.985 0.004 95)
  static const Color paper = Color(0xFFFBFAF7);
}

/// Semantic colour roles, resolved per theme.
///
/// Screens read roles (`context.semantics.protectedAccent`), never raw tokens,
/// so the sunlight path swaps underneath without touching call sites.
@immutable
class AppSemantics extends ThemeExtension<AppSemantics> {
  const AppSemantics({
    required this.canvas,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.hairline,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.protectedAccent,
    required this.protectedFill,
    required this.attentionAccent,
    required this.watchAccent,
    required this.emergency,
    required this.emergencyDeep,
    required this.onEmergency,
    required this.hazardBand,
    required this.onHazard,
    required this.isSunlight,
  });

  /// Night: dark-first, the app's default. This is the stance because most
  /// riding that needs protection happens at dusk or after.
  static const AppSemantics night = AppSemantics(
    canvas: AppColors.nightCanvas,
    surface1: AppColors.nightSurface1,
    surface2: AppColors.nightSurface2,
    surface3: AppColors.nightSurface3,
    hairline: AppColors.nightHairline,
    border: AppColors.nightBorder,
    textPrimary: AppColors.nightTextPrimary,
    textSecondary: AppColors.nightTextSecondary,
    textMuted: AppColors.nightTextMuted,
    protectedAccent: AppColors.hiViz,
    protectedFill: AppColors.hiVizDim,
    attentionAccent: AppColors.attention,
    watchAccent: AppColors.watch,
    emergency: AppColors.signal,
    emergencyDeep: AppColors.signalDeep,
    onEmergency: AppColors.paper,
    hazardBand: AppColors.hazardBand,
    onHazard: AppColors.hazardInk,
    isSunlight: false,
  );

  /// Sunlight: the high-contrast path for direct noon glare. Accents darken to
  /// stay legible as ink; the emergency tier keeps its field colours so a red
  /// screen still reads as a red screen from arm's length.
  static const AppSemantics sunlight = AppSemantics(
    canvas: AppColors.sunCanvas,
    surface1: AppColors.sunSurface1,
    surface2: AppColors.sunSurface2,
    surface3: AppColors.sunSurface2,
    hairline: AppColors.sunHairline,
    border: AppColors.sunBorder,
    textPrimary: AppColors.sunTextPrimary,
    textSecondary: AppColors.sunTextSecondary,
    textMuted: AppColors.sunTextMuted,
    protectedAccent: AppColors.hiVizInk,
    protectedFill: AppColors.hiViz,
    attentionAccent: AppColors.attentionInk,
    watchAccent: AppColors.watchInk,
    emergency: AppColors.signal,
    emergencyDeep: AppColors.signalDeep,
    onEmergency: AppColors.paper,
    hazardBand: AppColors.hazardBand,
    onHazard: AppColors.hazardInk,
    isSunlight: true,
  );

  final Color canvas;
  final Color surface1;
  final Color surface2;
  final Color surface3;
  final Color hairline;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// Protection is on and working.
  final Color protectedAccent;

  /// Large fills of the protected accent -- always pair with [onHazard].
  final Color protectedFill;

  /// Degraded, waiting, or needs a decision. Never used for danger.
  final Color attentionAccent;

  /// Who is watching. Information, never status.
  final Color watchAccent;

  /// Emergency tier. Reserved for SOS, crash countdown, off-route.
  final Color emergency;
  final Color emergencyDeep;
  final Color onEmergency;

  final Color hazardBand;
  final Color onHazard;

  final bool isSunlight;

  @override
  AppSemantics copyWith({
    Color? canvas,
    Color? surface1,
    Color? surface2,
    Color? surface3,
    Color? hairline,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? protectedAccent,
    Color? protectedFill,
    Color? attentionAccent,
    Color? watchAccent,
    Color? emergency,
    Color? emergencyDeep,
    Color? onEmergency,
    Color? hazardBand,
    Color? onHazard,
    bool? isSunlight,
  }) {
    return AppSemantics(
      canvas: canvas ?? this.canvas,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      hairline: hairline ?? this.hairline,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      protectedAccent: protectedAccent ?? this.protectedAccent,
      protectedFill: protectedFill ?? this.protectedFill,
      attentionAccent: attentionAccent ?? this.attentionAccent,
      watchAccent: watchAccent ?? this.watchAccent,
      emergency: emergency ?? this.emergency,
      emergencyDeep: emergencyDeep ?? this.emergencyDeep,
      onEmergency: onEmergency ?? this.onEmergency,
      hazardBand: hazardBand ?? this.hazardBand,
      onHazard: onHazard ?? this.onHazard,
      isSunlight: isSunlight ?? this.isSunlight,
    );
  }

  @override
  AppSemantics lerp(ThemeExtension<AppSemantics>? other, double t) {
    if (other is! AppSemantics) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppSemantics(
      canvas: c(canvas, other.canvas),
      surface1: c(surface1, other.surface1),
      surface2: c(surface2, other.surface2),
      surface3: c(surface3, other.surface3),
      hairline: c(hairline, other.hairline),
      border: c(border, other.border),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textMuted: c(textMuted, other.textMuted),
      protectedAccent: c(protectedAccent, other.protectedAccent),
      protectedFill: c(protectedFill, other.protectedFill),
      attentionAccent: c(attentionAccent, other.attentionAccent),
      watchAccent: c(watchAccent, other.watchAccent),
      // The emergency tier does not cross-fade. A half-faded red field is a
      // red field that means nothing; it snaps at the midpoint instead.
      emergency: t < 0.5 ? emergency : other.emergency,
      emergencyDeep: t < 0.5 ? emergencyDeep : other.emergencyDeep,
      onEmergency: t < 0.5 ? onEmergency : other.onEmergency,
      hazardBand: t < 0.5 ? hazardBand : other.hazardBand,
      onHazard: t < 0.5 ? onHazard : other.onHazard,
      isSunlight: t < 0.5 ? isSunlight : other.isSunlight,
    );
  }
}

extension AppSemanticsX on BuildContext {
  /// Semantic colours for the active theme.
  AppSemantics get semantics =>
      Theme.of(this).extension<AppSemantics>() ?? AppSemantics.night;
}
