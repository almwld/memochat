import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary);
    return _base(scheme, Brightness.light);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    );
    return _base(scheme, Brightness.dark);
  }

  static ThemeData _base(ColorScheme scheme, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme.copyWith(
        primary: AppColors.primary,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor:
          dark ? const Color(0xFF0B1121) : AppColors.background,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor:
            dark ? const Color(0xFF0B1121) : AppColors.background,
        foregroundColor:
            dark ? Colors.white : const Color(0xFF172026),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: dark ? const Color(0xFF111827) : Colors.white,
        indicatorColor: AppColors.primary.withOpacity(.14),
        labelTextStyle: MaterialStatePropertyAll(
          TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: dark ? Colors.white : const Color(0xFF263238),
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: AppTextStyles.title,
        titleLarge: AppTextStyles.heading,
        bodyLarge: AppTextStyles.body,
        bodyMedium: AppTextStyles.bodySecondary,
        bodySmall: AppTextStyles.caption,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        labelStyle: TextStyle(
          color: dark ? Colors.white70 : const Color(0xFF455A64),
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: TextStyle(
          color: dark ? Colors.white : AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: TextStyle(
          color: dark ? Colors.white54 : const Color(0xFF607D8B),
        ),
        prefixIconColor: dark ? Colors.white70 : const Color(0xFF607D8B),
        suffixIconColor: dark ? Colors.white70 : const Color(0xFF607D8B),
        fillColor: dark ? const Color(0xFF162039) : AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}
