import 'package:flutter/material.dart';

import '../../../controllers/scanner_controller.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/scan_feedback.dart';
import '../../widgets/surface_panel.dart';

/// The colour a scan outcome is shown in. Green, amber and red are the
/// states the records carry; the idle line stays muted.
Color scanToneColor(ScanTone? tone) => switch (tone) {
  ScanTone.success => AppColors.success,
  ScanTone.warning => AppColors.warning,
  ScanTone.error => AppColors.danger,
  null => AppColors.textSecondary,
};

/// The camera square with its frame, and the status line under it — the web
/// scanner's `#scannerContainer` and `#result`.
class CameraPanel extends StatelessWidget {
  const CameraPanel({
    super.key,
    required this.active,
    required this.recording,
    required this.status,
    required this.cameraBuilder,
    this.frameFraction = 0.8,
  });

  /// False until a subject is picked: the camera is not even started.
  final bool active;

  /// A scan is on its way to the server.
  final bool recording;
  final ScanStatus status;
  final WidgetBuilder cameraBuilder;

  /// How much of the square the frame's corners enclose — the part of the
  /// picture the decoder reads.
  final double frameFraction;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (active) cameraBuilder(context) else const _CameraIdle(),
                  if (active)
                    IgnorePointer(child: ScanFrame(fraction: frameFraction)),
                  if (recording)
                    const Positioned(
                      left: 10,
                      bottom: 10,
                      child: _SavingChip(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: '${ScannerStrings.statusLabel}  ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: status.text,
                    style: TextStyle(color: scanToneColor(status.tone)),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 13.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraIdle extends StatelessWidget {
  const _CameraIdle();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surfaceSunken,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.qr_code_scanner_rounded,
                size: 44,
                color: AppColors.textMuted,
              ),
              SizedBox(height: 12),
              Text(
                ScannerStrings.cameraIdle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavingChip extends StatelessWidget {
  const _SavingChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

/// Four corners and a sweeping line over the camera — where to hold the QR.
class ScanFrame extends StatefulWidget {
  const ScanFrame({super.key, required this.fraction});

  final double fraction;

  @override
  State<ScanFrame> createState() => _ScanFrameState();
}

class _ScanFrameState extends State<ScanFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The line is decoration. Where the phone asks for less motion, the
    // corners alone say where to aim.
    if (MediaQuery.of(context).disableAnimations) {
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _sweep,
      builder: (context, _) => CustomPaint(
        painter: _FramePainter(
          fraction: widget.fraction,
          sweep: _sweep.isAnimating ? _sweep.value : null,
        ),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter({required this.fraction, required this.sweep});

  final double fraction;
  final double? sweep;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide * fraction;
    final box = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: side,
      height: side,
    );
    final arm = side * 0.14;

    final corner = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final (point, dx, dy) in [
      (box.topLeft, 1.0, 1.0),
      (box.topRight, -1.0, 1.0),
      (box.bottomLeft, 1.0, -1.0),
      (box.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(point.dx, point.dy + arm * dy)
          ..lineTo(point.dx, point.dy)
          ..lineTo(point.dx + arm * dx, point.dy),
        corner,
      );
    }

    final t = sweep;
    if (t != null) {
      final y = box.top + side * 0.06 + (side * 0.88) * t;
      final line = Rect.fromLTWH(box.left + 10, y - 1, side - 20, 2);
      canvas.drawRect(
        line,
        Paint()
          ..shader = LinearGradient(
            colors: [
              AppColors.accent.withValues(alpha: 0),
              AppColors.accent.withValues(alpha: 0.85),
              AppColors.accent.withValues(alpha: 0),
            ],
          ).createShader(line),
      );
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.sweep != sweep || old.fraction != fraction;
}
