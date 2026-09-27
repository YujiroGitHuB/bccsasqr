import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Builds the app's [ThemeData] from an [AppPalette] — one for Light and one
/// for Dark, picked in Settings.
abstract final class AppTheme {
  static const double cardRadius = 16;
  static const double fieldRadius = 12;
  static const double pagePadding = 16;

  /// Before the theme is known: the splash is always dark, like the native
  /// launch screen it takes over from.
  static SystemUiOverlayStyle get overlayStyle => AppPalette.dark.overlayStyle;

  static ThemeData build(AppPalette p) {
    final scheme = p.isDark
        ? ColorScheme.dark(
            primary: p.accent,
            onPrimary: p.onAccent,
            secondary: p.accentSoft,
            surface: p.surface,
            onSurface: p.textPrimary,
            error: p.danger,
            outline: p.border,
          )
        : ColorScheme.light(
            primary: p.accent,
            onPrimary: p.onAccent,
            secondary: p.accentSoft,
            surface: p.surface,
            onSurface: p.textPrimary,
            error: p.danger,
            outline: p.border,
          );

    final base = ThemeData(
      colorScheme: scheme,
      brightness: p.brightness,
      scaffoldBackgroundColor: p.canvas,
      useMaterial3: true,
    );

    return base.copyWith(
      extensions: [p],
      textTheme: base.textTheme.apply(
        bodyColor: p.textPrimary,
        displayColor: p.textPrimary,
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      inputDecorationTheme: _inputTheme(p),
      filledButtonTheme: _filledButtonTheme(p),
      outlinedButtonTheme: _outlinedButtonTheme(p),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      checkboxTheme: _checkboxTheme(p),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceRaised,
        contentTextStyle: TextStyle(color: p.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      // Material 3 tints raised surfaces with the primary colour; the app's
      // surfaces are the palette's, in both themes.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  static InputDecorationTheme _inputTheme(AppPalette p) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceSunken,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      hintStyle: TextStyle(
        color: p.textMuted,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      prefixIconColor: p.textSecondary,
      suffixIconColor: p.textSecondary,
      enabledBorder: border(p.border),
      disabledBorder: border(p.border),
      focusedBorder: border(p.accent, 1.6),
      errorBorder: border(p.danger),
      focusedErrorBorder: border(p.danger, 1.6),
      errorStyle: TextStyle(color: p.danger, fontSize: 12),
    );
  }

  static FilledButtonThemeData _filledButtonTheme(AppPalette p) =>
      FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          disabledBackgroundColor: p.surfaceRaised,
          disabledForegroundColor: p.textMuted,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(fieldRadius),
          ),
        ),
      );

  static OutlinedButtonThemeData _outlinedButtonTheme(AppPalette p) =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.borderStrong),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(fieldRadius),
          ),
        ),
      );

  static CheckboxThemeData _checkboxTheme(AppPalette p) => CheckboxThemeData(
    side: BorderSide(color: p.borderStrong, width: 1.5),
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return p.accent;
      return p.surfaceRaised;
    }),
    checkColor: WidgetStatePropertyAll(p.onAccent),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}
