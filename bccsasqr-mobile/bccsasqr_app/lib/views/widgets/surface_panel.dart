import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// The rounded, hairline-bordered container every block on the screen sits in.
class SurfacePanel extends StatelessWidget {
  const SurfacePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.surface,
    this.borderColor = AppColors.border,
    this.radius = AppTheme.cardRadius,
    this.topAccent = false,
    this.fill = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double radius;

  /// Draws the cyan gradient rule along the top edge (used by the header).
  final bool topAccent;

  /// Stretch to the height handed down by the parent instead of hugging the
  /// content — used so the two columns line up.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Column(
          mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (topAccent)
              const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.headerRule),
                child: SizedBox(height: 3, width: double.infinity),
              ),
            if (fill)
              Expanded(
                child: Padding(padding: padding, child: child),
              )
            else
              Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// Small uppercase heading with a leading icon — "YOUR DETAILS", "YOUR QR CODE".
class PanelHeading extends StatelessWidget {
  const PanelHeading({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.accent),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
