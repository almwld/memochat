import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(primary: AppColors.primary, error: AppColors.error),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: const TextTheme(
        headlineSmall: AppTextStyles.title,
        titleLarge: AppTextStyles.heading,
        bodyLarge: AppTextStyles.body,
        bodyMedium: AppTextStyles.bodySecondary,
        bodySmall: AppTextStyles.caption,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withOpacity(0.14),
        labelTextStyle: WidgetStatePropertyAll(AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
