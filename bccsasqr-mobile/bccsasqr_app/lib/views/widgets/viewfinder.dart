import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Four rounded corner brackets — a camera viewfinder. Drawn by the app's
/// opening splash around the seal, and by the scanner's around a QR.
class ViewfinderPainter extends CustomPainter {
  const ViewfinderPainter({required this.color});

  final Color color;

  static const double _arm = 26;
  static const double _radius = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const a = _arm;
    const r = _radius;

    final path = Path()
      // top left
      ..moveTo(0, a)
      ..lineTo(0, r)
      ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
      ..lineTo(a, 0)
      // top right
      ..moveTo(w - a, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
      ..lineTo(w, a)
      // bottom right
      ..moveTo(w, h - a)
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: const Radius.circular(r))
      ..lineTo(w - a, h)
      // bottom left
      ..moveTo(a, h)
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: const Radius.circular(r))
      ..lineTo(0, h - a);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = color;

    // A blurred pass under the crisp one reads as a glow.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(ViewfinderPainter old) => old.color != color;
}

/// A bright line with a soft wash trailing above it — a scan passing over.
class ScanBeam extends StatelessWidget {
  const ScanBeam({super.key, required this.trail, required this.palette});

  final double trail;

  /// Passed rather than read from the theme: the app's opening splash is
  /// dark whatever the theme, the scanner's follows it.
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final clear = palette.accent.withValues(alpha: 0);

    return Column(
      children: [
        Container(
          height: trail,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [palette.accentWash(0), palette.accentWash(0.28)],
            ),
          ),
        ),
        Container(
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [clear, palette.accentSoft, clear],
            ),
            boxShadow: [
              BoxShadow(color: palette.accentWash(0.7), blurRadius: 8),
            ],
          ),
        ),
      ],
    );
  }
}
