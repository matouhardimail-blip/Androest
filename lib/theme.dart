import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF080B18);
  static const Color cardBackground = Color(0xFF141A2D);
  static const Color primary = Color(0xFF7659E8);
  static const Color accentBlue = Color(0xFF358CFF);
  static const Color success = Color(0xFF24C9A0);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF8E9BB3);
  static const Color danger = Color(0xFFFF4D4F);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accentBlue,
        surface: AppColors.cardBackground,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}