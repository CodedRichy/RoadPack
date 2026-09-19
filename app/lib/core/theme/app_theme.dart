import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_motion.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembles [ThemeData] from the token layer.
///
/// Two themes, one system:
///
/// * [dark] -- "night". The default stance. Instrument-glass neutrals, hi-viz
///   accent, elevation carried by lightness.
/// * [light] -- "sunlight". Not a lighter dark theme: a paper theme built for
///   direct noon glare. Strokes double, shadows vanish, accents darken into
///   inks. At noon a dark screen becomes a mirror, so the high-contrast path
///   goes bright rather than dim.
abstract final class AppTheme {
  static ThemeData get dark => _build(AppSemantics.night);

  static ThemeData get light => _build(AppSemantics.sunlight);

  static ThemeData _build(AppSemantics s) {
    final sunlight = s.isSunlight;
    final brightness = sunlight ? Brightness.light : Brightness.dark;
    final onAccent = sunlight ? AppColors.paper : AppColors.hazardInk;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: s.protectedAccent,
      onPrimary: onAccent,
      primaryContainer: s.surface2,
      onPrimaryContainer: s.textPrimary,
      secondary: s.watchAccent,
      onSecondary: onAccent,
      secondaryContainer: s.surface2,
      onSecondaryContainer: s.textPrimary,
      tertiary: s.attentionAccent,
      onTertiary: onAccent,
      // Material's `error` role is routine form validation, so it maps to the
      // attention tier. The emergency tier is deliberately unreachable through
      // ColorScheme -- reach it through AppSemantics.emergency and mean it.
      error: sunlight ? AppColors.attentionInk : AppColors.attention,
      onError: onAccent,
      surface: s.canvas,
      onSurface: s.textPrimary,
      surfaceContainerLowest: s.canvas,
      surfaceContainerLow: s.surface1,
      surfaceContainer: s.surface2,
      surfaceContainerHigh: s.surface3,
      surfaceContainerHighest: s.surface3,
      onSurfaceVariant: s.textSecondary,
      outline: s.border,
      outlineVariant: s.hairline,
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
      inverseSurface: s.textPrimary,
      onInverseSurface: s.canvas,
      inversePrimary: s.protectedFill,
    );

    final text = AppType.textTheme(s.textPrimary);
    final stroke = AppStroke.resolve(AppStroke.hairline, sunlight: sunlight);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: s.canvas,
      canvasColor: s.canvas,
      textTheme: text,
      fontFamily: AppType.body,
      fontFamilyFallback: AppType.fallback,
      extensions: [s],
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: DividerThemeData(
        color: s.hairline,
        thickness: stroke,
        space: AppSpace.lg,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: s.canvas,
        foregroundColor: s.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.flat,
        scrolledUnderElevation: AppElevation.flat,
        centerTitle: false,
        titleTextStyle: AppType.displayStyle(
          AppType.titleSm,
          weight: FontWeight.w600,
        ).copyWith(color: s.textPrimary),
        shape: Border(
          bottom: BorderSide(color: s.hairline, width: stroke),
        ),
      ),
      cardTheme: CardThemeData(
        color: s.surface1,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.flat,
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpace.gutter,
          vertical: AppSpace.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: s.hairline, width: stroke),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: s.textSecondary,
        textColor: s.textPrimary,
        minVerticalPadding: AppSpace.md,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.xs,
        ),
        titleTextStyle: AppType.bodyStyle(
          AppType.bodyMd,
          weight: FontWeight.w500,
        ).copyWith(color: s.textPrimary),
        subtitleTextStyle: AppType.bodyStyle(
          AppType.bodySm,
        ).copyWith(color: s.textMuted),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: s.protectedFill,
          foregroundColor: AppColors.hazardInk,
          minimumSize: const Size.fromHeight(AppSpace.gloveTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: AppType.bodyStyle(AppType.bodyMd, weight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: s.textPrimary,
          minimumSize: const Size.fromHeight(AppSpace.tapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
          side: BorderSide(
            color: s.border,
            width: AppStroke.resolve(AppStroke.regular, sunlight: sunlight),
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: AppType.bodyStyle(AppType.bodyMd, weight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: s.protectedAccent,
          minimumSize: const Size(0, AppSpace.tapTarget),
          textStyle: AppType.bodyStyle(AppType.bodyMd, weight: FontWeight.w600),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: s.surface1,
          foregroundColor: s.textSecondary,
          selectedBackgroundColor: s.protectedFill,
          selectedForegroundColor: AppColors.hazardInk,
          side: BorderSide(color: s.hairline, width: stroke),
          minimumSize: const Size(0, AppSpace.tapTarget),
          textStyle: AppType.bodyStyle(AppType.bodySm, weight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: s.surface1,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.md,
        ),
        labelStyle: AppType.bodyStyle(
          AppType.bodySm,
        ).copyWith(color: s.textSecondary),
        hintStyle: AppType.bodyStyle(
          AppType.bodyMd,
        ).copyWith(color: s.textMuted),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: s.hairline, width: stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: s.hairline, width: stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(
            color: s.protectedAccent,
            width: AppStroke.resolve(AppStroke.heavy, sunlight: sunlight),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.hazardInk
              : s.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? s.protectedFill
              : s.surface2,
        ),
        trackOutlineColor: WidgetStateProperty.all(s.hairline),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: s.surface2,
        side: BorderSide(color: s.hairline, width: stroke),
        labelStyle: AppType.bodyStyle(
          AppType.bodySm,
          weight: FontWeight.w500,
        ).copyWith(color: s.textPrimary),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: AppType.bodyStyle(AppType.bodyMd),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(s.surface2),
          shape: WidgetStateProperty.all(
            const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: s.protectedAccent,
        linearTrackColor: s.surface2,
        circularTrackColor: s.surface2,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: s.surface3,
        contentTextStyle: AppType.bodyStyle(
          AppType.bodyMd,
        ).copyWith(color: s.textPrimary),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        behavior: SnackBarBehavior.floating,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      splashColor: s.protectedAccent.withValues(alpha: 0.08),
      highlightColor: s.protectedAccent.withValues(alpha: 0.05),
    );
  }

  /// How long the app takes to cross from night to sunlight.
  static const Duration themeSwitch = AppMotion.deliberate;
}
