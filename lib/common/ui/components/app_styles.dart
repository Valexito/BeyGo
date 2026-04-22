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
    return buildLight();
  }

  static ThemeData buildLight() {
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

  static ThemeData buildDark() {
    final base = ThemeData.dark(useMaterial3: false);

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF0B1220),
      primaryColor: AppColors.primary,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primarySoft,
        secondary: AppColors.headerTop,
        surface: const Color(0xFF111827),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF111827),
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      cardColor: const Color(0xFF111827),
      canvasColor: const Color(0xFF0F172A),
      dividerColor: const Color(0xFF263244),
      iconTheme: const IconThemeData(color: Colors.white),
      textTheme: base.textTheme.apply(
        bodyColor: const Color(0xFFE5E7EB),
        displayColor: Colors.white,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.headerTop;
          return const Color(0xFF94A3B8);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.headerBottom.withValues(alpha: 0.45);
          }
          return const Color(0xFF334155);
        }),
      ),
    );
  }
}

extension AppThemeContext on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get appPageBackground =>
      isDarkMode ? const Color(0xFF0B1220) : AppColors.pageBg;

  Color get appSectionBackground =>
      isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

  Color get appCardBackground =>
      isDarkMode ? const Color(0xFF111827) : Colors.white;

  Color get appCardBackgroundSoft =>
      isDarkMode ? const Color(0xFF162033) : const Color(0xFFF4F8FC);

  Color get appInputBackground =>
      isDarkMode ? const Color(0xFF162033) : AppColors.formFieldBg;

  Color get appInputBackgroundActive =>
      isDarkMode ? const Color(0xFF1B263B) : Colors.white;

  Color get appBorderColor =>
      isDarkMode ? const Color(0xFF263244) : AppColors.borderSoft;

  Color get appTextPrimaryColor =>
      isDarkMode ? const Color(0xFFE5E7EB) : AppColors.textPrimary;

  Color get appTextSecondaryColor =>
      isDarkMode ? const Color(0xFF94A3B8) : AppColors.textSecondary;

  Color get appIconCircleColor =>
      isDarkMode ? const Color(0xFF1E293B) : AppColors.iconCircle;
}
