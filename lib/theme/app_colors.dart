import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF3A0519);
  static const Color card = Color(0xFF670D2F);
  static const Color primary = Color(0xFFA53860);
  static const Color textSecondary = Color(0xFFEF88AD); 
  static const Color inputBackground = Color(0xFF670D2F); // Matching card
  static const Color white = Colors.white;
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        surface: AppColors.card,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: AppColors.white),
        bodySmall: TextStyle(color: AppColors.textSecondary),
        titleLarge: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
