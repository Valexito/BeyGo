import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF2D4D82);
  static const primaryDark = Color(0xFF102648);
  static const primarySoft = Color(0xFF6F8FBE);

  // Navy branding from the new logo.
  static const headerTop = Color(0xFF2E4E86);
  static const headerBottom = Color(0xFF102648);
  static const headerMid = Color(0xFF1A3764);

  // 🔁 Aliases (so old code doesn't break)
  static const navyTop = headerTop;
  static const navyBottom = headerBottom;

  static const pageBg = Color(0xFFEAF0F8);
  static const pageBgSoft = Color(0xFFF4F7FC);
  static const cardBg = Color(0xFFFDFEFF);
  static const cardBgSoft = Color(0xFFF4F8FD);
  static const formFieldBg = Color(0xFFE9F0F8);

  static const textPrimary = Color(0xFF13233D);
  static const textSecondary = Color(0xFF5D6B81);
  static const textHint = Color(0xFF8C9AB0);

  static const borderSoft = Color(0xFFD9E3F0);
  static const iconCircle = Color(0xFFDCE8F8);

  static const cardDivider = Color(0xFFDCE3EE);

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
      cardColor: AppColors.cardBg,
      canvasColor: AppColors.pageBgSoft,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.headerBottom,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        elevation: 0,
        shadowColor: AppColors.headerBottom.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.borderSoft),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.formFieldBg,
        hintStyle: const TextStyle(color: AppColors.textHint),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDims.radiusLg),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDims.radiusLg),
          borderSide: BorderSide(
            color: AppColors.headerBottom.withValues(alpha: 0.55),
            width: 1.2,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.headerBottom,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: AppColors.headerBottom.withValues(alpha: 0.28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDims.radiusLg),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.headerBottom,
          side: BorderSide(
            color: AppColors.headerBottom.withValues(alpha: 0.24),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDims.radiusLg),
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.primaryDark),
      dividerColor: AppColors.borderSoft,
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
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
      isDarkMode ? const Color(0xFF0F172A) : AppColors.pageBgSoft;

  Color get appCardBackground =>
      isDarkMode ? const Color(0xFF111827) : AppColors.cardBg;

  Color get appCardBackgroundSoft =>
      isDarkMode ? const Color(0xFF162033) : AppColors.cardBgSoft;

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
