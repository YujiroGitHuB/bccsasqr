import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Rounded rectangle drawn with a dashed stroke — the empty-state frame.
class DashedBorderBox extends StatelessWidget {
  const DashedBorderBox({
    super.key,
    required this.child,
    this.radius = 14,
    this.color = AppColors.borderStrong,
    this.dash = 6,
    this.gap = 5,
  });

  final Widget child;
  final double radius;
  final Color color;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(
        radius: radius,
        color: color,
        dash: dash,
        gap: gap,
      ),
      child: child,
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({
    required this.radius,
    required this.color,
    required this.dash,
    required this.gap,
  });

  final double radius;
  final Color color;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    // Walk the outline and stroke alternating dash/gap segments.
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRectPainter old) =>
      old.radius != radius ||
      old.color != color ||
      old.dash != dash ||
      old.gap != gap;
}
