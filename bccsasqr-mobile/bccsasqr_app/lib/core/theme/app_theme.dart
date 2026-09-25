import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Builds the single [ThemeData] the app runs on.
abstract final class AppTheme {
  static const double cardRadius = 16;
  static const double fieldRadius = 12;
  static const double pagePadding = 16;

  static const SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.canvas,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static ThemeData build() {
    const scheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: Color(0xFF04222B),
      secondary: AppColors.accentSoft,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
      outline: AppColors.border,
    );

    final base = ThemeData(
      colorScheme: scheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.canvas,
      useMaterial3: true,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: _inputTheme(),
      filledButtonTheme: _filledButtonTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      checkboxTheme: _checkboxTheme(),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surfaceRaised,
        contentTextStyle: TextStyle(color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  static TextTheme _textTheme(TextTheme base) => base.apply(
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  );

  static InputDecorationTheme _inputTheme() {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceSunken,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      hintStyle: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.accent, 1.6),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger, 1.6),
      errorStyle: const TextStyle(color: AppColors.danger, fontSize: 12),
    );
  }

  static FilledButtonThemeData _filledButtonTheme() => FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      backgroundColor: AppColors.accent,
      foregroundColor: const Color(0xFF04222B),
      disabledBackgroundColor: AppColors.surfaceRaised,
      disabledForegroundColor: AppColors.textMuted,
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
      ),
    ),
  );

  static OutlinedButtonThemeData _outlinedButtonTheme() =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderStrong),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(fieldRadius),
          ),
        ),
      );

  static CheckboxThemeData _checkboxTheme() => CheckboxThemeData(
    side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return AppColors.accent;
      return AppColors.surfaceRaised;
    }),
    checkColor: const WidgetStatePropertyAll(Color(0xFF04222B)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}
