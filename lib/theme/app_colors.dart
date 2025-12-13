import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF0A1628);
  static const Color card = Color(0xFF0F1F35);
  static const Color primary = Color(0xFF3B82F6);
  static const Color textSecondary = Color(0xFF9CA3AF); // gray-400
  static const Color inputBackground = Color(0xFF1A2F47);
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
