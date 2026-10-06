import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  static ThemeData light() => _base(
        brightness: Brightness.light,
        scheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          primaryContainer: AppColors.primarySoft,
          onPrimaryContainer: Color(0xFF064A43),
          secondary: Color(0xFF3F6B67),
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFFDCEDEA),
          onSecondaryContainer: Color(0xFF173B37),
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          surfaceContainerHighest: AppColors.surfaceAlt,
          outline: AppColors.border,
          outlineVariant: Color(0xFFE7ECEB),
          error: AppColors.error,
          onError: Colors.white,
        ),
      );

  static ThemeData dark() => _base(
        brightness: Brightness.dark,
        scheme: const ColorScheme.dark(
          primary: Color(0xFF53C7B9),
          onPrimary: Color(0xFF003B35),
          primaryContainer: AppColors.primarySoftDark,
          onPrimaryContainer: Color(0xFF9CE9DE),
          secondary: Color(0xFFA9CCC7),
          onSecondary: Color(0xFF173532),
          secondaryContainer: Color(0xFF294743),
          onSecondaryContainer: Color(0xFFC7E9E4),
          surface: AppColors.darkSurface,
          onSurface: AppColors.darkTextPrimary,
          surfaceContainerHighest: AppColors.darkSurfaceAlt,
          outline: AppColors.darkBorder,
          outlineVariant: Color(0xFF1F2D2F),
          error: Color(0xFFFF8A80),
          onError: Color(0xFF4A0000),
        ),
      );

  static ThemeData _base({
    required Brightness brightness,
    required ColorScheme scheme,
  }) {
    final dark = brightness == Brightness.dark;
    final onSurfaceVariant =
        dark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final background =
        dark ? AppColors.darkBackground : AppColors.background;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: AppTextStyles.heading.copyWith(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: dark ? AppColors.darkSurface : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        labelTextStyle: MaterialStatePropertyAll(
          TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 11,
            color: scheme.onSurface,
          ),
        ),
        iconTheme: MaterialStatePropertyAll(
          IconThemeData(color: onSurfaceVariant, size: 23),
        ),
      ),
      textTheme: TextTheme(
        headlineSmall: AppTextStyles.title.copyWith(color: scheme.onSurface),
        titleLarge: AppTextStyles.heading.copyWith(color: scheme.onSurface),
        bodyLarge: AppTextStyles.body.copyWith(color: scheme.onSurface),
        bodyMedium: AppTextStyles.bodySecondary.copyWith(color: onSurfaceVariant),
        bodySmall: AppTextStyles.caption.copyWith(color: onSurfaceVariant),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? AppColors.darkSurfaceAlt : AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle:
            TextStyle(color: onSurfaceVariant, fontWeight: FontWeight.w600),
        floatingLabelStyle:
            TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
        hintStyle: TextStyle(color: onSurfaceVariant.withOpacity(.78)),
        prefixIconColor: onSurfaceVariant,
        suffixIconColor: onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: dark ? AppColors.darkSurface : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        minVerticalPadding: 10,
        iconColor: onSurfaceVariant,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: dark ? AppColors.darkSurfaceAlt : AppColors.surface,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelStyle:
            TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: dark ? AppColors.darkSurface : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? AppColors.darkSurface : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor:
            dark ? AppColors.primarySoftDark : AppColors.primary,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
          height: 1.35,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          side: BorderSide(color: scheme.outline),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }
}