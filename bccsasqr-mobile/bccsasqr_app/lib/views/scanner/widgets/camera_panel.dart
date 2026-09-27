import 'package:flutter/material.dart';

import '../../../controllers/scanner_controller.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/scan_feedback.dart';
import '../../widgets/surface_panel.dart';
import '../camera/torch_control.dart';

/// The colour a scan outcome is shown in. Green, amber and red are the
/// states the records carry; the idle line stays muted.
Color scanToneColor(AppPalette colors, ScanTone? tone) => switch (tone) {
  ScanTone.success => colors.success,
  ScanTone.warning => colors.warning,
  ScanTone.error => colors.danger,
  null => colors.textSecondary,
};

/// The camera square with its frame, and the status line under it — the web
/// scanner's `#scannerContainer` and `#result`. The flashlight button sits at
/// the end of the status line, off the picture.
class CameraPanel extends StatefulWidget {
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
  State<CameraPanel> createState() => _CameraPanelState();
}

class _CameraPanelState extends State<CameraPanel> {
  final TorchControl _torch = TorchControl();

  @override
  void dispose() {
    _torch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.active;

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
                  if (active)
                    TorchScope(
                      control: _torch,
                      child: Builder(builder: widget.cameraBuilder),
                    )
                  else
                    const _CameraIdle(),
                  if (active)
                    IgnorePointer(
                      child: ScanFrame(fraction: widget.frameFraction),
                    ),
                  if (widget.recording)
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
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${ScannerStrings.statusLabel}  ',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: widget.status.text,
                          style: TextStyle(
                            color: scanToneColor(
                              context.colors,
                              widget.status.tone,
                            ),
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 13.5, height: 1.4),
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: _torch,
                // `active` too: a camera that has just gone is only detached
                // after this build, so the control still says available.
                builder: (context, _) => active && _torch.available
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _TorchButton(
                          on: _torch.on,
                          onPressed: _torch.toggle,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Outlined while off, filled while on — a lit torch should be obvious at a
/// glance, since it drains the battery.
class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.on, required this.onPressed});

  final bool on;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // The theme's buttons are full width; this one sits beside the status.
    const size = Size(0, 40);
    const padding = EdgeInsets.symmetric(horizontal: 14);
    const label = Text(ScannerStrings.flashlight);

    return Tooltip(
      message: on ? ScannerStrings.flashlightOff : ScannerStrings.flashlightOn,
      child: Semantics(
        toggled: on,
        child: on
            ? FilledButton.icon(
                key: const ValueKey('scanner.torch'),
                onPressed: onPressed,
                icon: const Icon(Icons.flashlight_on_rounded, size: 18),
                label: label,
                style: FilledButton.styleFrom(
                  minimumSize: size,
                  padding: padding,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : OutlinedButton.icon(
                key: const ValueKey('scanner.torch'),
                onPressed: onPressed,
                icon: const Icon(Icons.flashlight_off_rounded, size: 18),
                label: label,
                style: OutlinedButton.styleFrom(
                  minimumSize: size,
                  padding: padding,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ),
    );
  }
}

class _CameraIdle extends StatelessWidget {
  const _CameraIdle();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.surfaceSunken,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.qr_code_scanner_rounded,
                size: 44,
                color: context.colors.textMuted,
              ),
              const SizedBox(height: 12),
              Text(
                ScannerStrings.cameraIdle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.textSecondary,
                ),
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
      child: SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: context.colors.accent,
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
          color: context.colors.accent,
        ),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter({
    required this.fraction,
    required this.sweep,
    required this.color,
  });

  final double fraction;
  final double? sweep;
  final Color color;

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
      ..color = color
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
              color.withValues(alpha: 0),
              color.withValues(alpha: 0.85),
              color.withValues(alpha: 0),
            ],
          ).createShader(line),
      );
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.sweep != sweep || old.fraction != fraction || old.color != color;
}
