import 'package:flutter/material.dart';

/// Central palette for the dark "SASQR" look.
///
/// Every colour used by the views comes from here so a re-skin never means
/// hunting for hard-coded hex values inside widgets.
abstract final class AppColors {
  // Backgrounds
  static const Color canvas = Color(0xFF0A0D12);
  static const Color surface = Color(0xFF11161D);
  static const Color surfaceRaised = Color(0xFF151B24);
  static const Color surfaceSunken = Color(0xFF0D1219);

  // Borders / dividers
  static const Color border = Color(0xFF222A35);
  static const Color borderStrong = Color(0xFF2C3644);

  // Text
  static const Color textPrimary = Color(0xFFE7EDF5);
  static const Color textSecondary = Color(0xFF8C9AAC);
  static const Color textMuted = Color(0xFF5C6878);

  // Accents
  static const Color accent = Color(0xFF2DD4F5);
  static const Color accentSoft = Color(0xFF67E3FF);
  static const Color accentDeep = Color(0xFF1AA9CC);

  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFBBF24);
  static const Color danger = Color(0xFFF87171);

  /// Thin gradient rule that runs along the top edge of the header card.
  static const LinearGradient headerRule = LinearGradient(
    colors: [accentDeep, accent, accentSoft],
  );

  /// Fill used by the app mark in the header.
  static const LinearGradient brandMark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF22D3EE), Color(0xFF0EA5E9)],
  );

  static Color accentWash(double opacity) => accent.withValues(alpha: opacity);
}
