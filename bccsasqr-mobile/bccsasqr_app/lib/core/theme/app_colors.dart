import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app's colours, in a light and a dark set — the app's copy of the web
/// system's theme tokens (`assets/css/theme.css`).
///
/// Every colour the views use comes from here, read through [PaletteContext]:
///
/// ```dart
/// Text('…', style: TextStyle(color: context.colors.textSecondary))
/// ```
///
/// Read from the theme rather than a global so that switching Light and Dark
/// in Settings repaints every widget that uses a colour, `const` ones
/// included: the lookup makes each of them depend on the theme.
///
/// The accents follow the web's rule: sky, emerald, amber and red are the
/// brand and the states, and read on both grounds — but on white their pale
/// dark-mode tints are too faint for text, so the light set darkens them, as
/// theme.css does with its `*-ink` tints.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentSoft,
    required this.accentDeep,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.onWarning,
    required this.danger,
    required this.violet,
  });

  /// The app's original look, and the web's `[data-theme="dark"]`.
  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    canvas: Color(0xFF0A0D12),
    surface: Color(0xFF11161D),
    surfaceRaised: Color(0xFF151B24),
    surfaceSunken: Color(0xFF0D1219),
    border: Color(0xFF222A35),
    borderStrong: Color(0xFF2C3644),
    textPrimary: Color(0xFFE7EDF5),
    textSecondary: Color(0xFF8C9AAC),
    textMuted: Color(0xFF5C6878),
    accent: Color(0xFF2DD4F5),
    accentSoft: Color(0xFF67E3FF),
    accentDeep: Color(0xFF1AA9CC),
    onAccent: Color(0xFF04222B),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    onWarning: Color(0xFF2B1D00),
    danger: Color(0xFFF87171),
    violet: Color(0xFFC4B5FD),
  );

  /// The web's `:root` light palette: `--bg` #eef2f7 under white surfaces,
  /// slate ink, hairlines at 12 % and 20 % of the ink colour.
  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    canvas: Color(0xFFEEF2F7),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF1F5F9),
    surfaceSunken: Color(0xFFF8FAFC),
    border: Color(0xFFDDE2E9),
    borderStrong: Color(0xFFCBD2DB),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF94A3B8),
    accent: Color(0xFF0284C7),
    accentSoft: Color(0xFF0EA5E9),
    accentDeep: Color(0xFF0369A1),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF059669),
    warning: Color(0xFFB45309),
    onWarning: Color(0xFFFFFFFF),
    danger: Color(0xFFDC2626),
    violet: Color(0xFF6D28D9),
  );

  final Brightness brightness;

  // Backgrounds
  final Color canvas;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSunken;

  // Borders / dividers
  final Color border;
  final Color borderStrong;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // Accents
  final Color accent;
  final Color accentSoft;
  final Color accentDeep;

  /// Text and icons on a filled [accent] button.
  final Color onAccent;

  final Color success;
  final Color warning;

  /// The thumb of a switch whose track is [warning].
  final Color onWarning;
  final Color danger;

  /// The web's second accent (`--att-ink`): the Improved chip in What's New,
  /// as on the web. Not a state — only sky, emerald, amber and red are.
  final Color violet;

  bool get isDark => brightness == Brightness.dark;

  /// Thin gradient rule that runs along the top edge of the header card.
  LinearGradient get headerRule =>
      LinearGradient(colors: [accentDeep, accent, accentSoft]);

  /// Fill used by the app mark. The same in both themes: it is the brand.
  static const LinearGradient brandMark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF22D3EE), Color(0xFF0EA5E9)],
  );

  Color accentWash(double opacity) => accent.withValues(alpha: opacity);

  /// Status and navigation bar icons that read on [canvas].
  SystemUiOverlayStyle get overlayStyle => SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: canvas,
    systemNavigationBarIconBrightness: isDark
        ? Brightness.light
        : Brightness.dark,
  );

  @override
  AppPalette copyWith() => this;

  /// Switching theme swaps the palette outright. Lerping two palettes would
  /// fade through muddy in-between colours for no gain.
  @override
  AppPalette lerp(AppPalette? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

/// `context.colors` — the palette of the theme around [this].
extension PaletteContext on BuildContext {
  AppPalette get colors =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}
