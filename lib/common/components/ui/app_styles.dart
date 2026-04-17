import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF3B82F6);
  static const primaryDark = Color(0xFF1E3A5F);
  static const primarySoft = Color(0xFF93C5FD);

  // 🔵 MAIN HEADER COLORS (use these everywhere)
  static const headerTop = Color(0xFF4F8FF7);
  static const headerBottom = Color(0xFF1E5FD8);

  // 🔁 Aliases (so old code doesn't break)
  static const navyTop = headerTop;
  static const navyBottom = headerBottom;

  static const pageBg = Color(0xFFF7FAFC);
  static const cardBg = Colors.white;
  static const formFieldBg = Color(0xFFF1F5F9);

  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textHint = Color(0xFF94A3B8);

  static const borderSoft = Color(0xFFE2E8F0);
  static const iconCircle = Color(0xFFEAF2FF);

  static const cardDivider = Color(0xFFE5E7EB);

  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
}

class AppDims {
  static const radiusXl = 32.0;
  static const radiusLg = 35.0;
  static const radiusMd = 16.0;
  static const radiusSm = 12.0;

  static const padScreen = 20.0;
  static const padInputV = 16.0;
  static const padInputH = 18.0;

  static const buttonHeight = 56.0;
}

class AppTheme {
  static ThemeData build() {
    final base = ThemeData.light(useMaterial3: false);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.pageBg,
      primaryColor: AppColors.primary,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.primaryDark,
        surface: AppColors.cardBg,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.headerBottom,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      iconTheme: const IconThemeData(color: AppColors.primaryDark),
      dividerColor: AppColors.borderSoft,
    );
  }
}
