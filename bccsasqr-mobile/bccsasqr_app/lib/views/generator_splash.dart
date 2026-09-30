import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import 'widgets/splash_parts.dart';

/// The generator, behind its opening splash.
class GeneratorIntro extends StatelessWidget {
  const GeneratorIntro({super.key, required this.page});

  final WidgetBuilder page;

  @override
  Widget build(BuildContext context) => SplashThen(
    splash: (onFinished) => GeneratorSplash(onFinished: onFinished),
    page: page,
  );
}

/// A QR being made — the three corner eyes, then the dots in a wave from the
/// top-left, then a glint across the finished code — with the three steps a
/// student is about to take laid out underneath.
///
/// There is nothing to load here; the splash is the welcome. It follows the
/// app's theme, like the scanner's.
class GeneratorSplash extends StatefulWidget {
  const GeneratorSplash({super.key, required this.onFinished});

  /// Called once, when the splash has played.
  final VoidCallback onFinished;

  /// Unhurried enough to watch the code build, then a hold on the finished
  /// scene so the steps can be read.
  static const SplashTimeline timeline = SplashTimeline(
    play: Duration(milliseconds: 2300),
    hold: Duration(milliseconds: 400),
  );

  static const List<SplashStep> steps = [
    (icon: Icons.pin_outlined, label: AppStrings.generatorStepNumber),
    (icon: Icons.verified_outlined, label: AppStrings.generatorStepVerify),
    (icon: Icons.download_rounded, label: AppStrings.generatorStepSave),
  ];

  @override
  State<GeneratorSplash> createState() => _GeneratorSplashState();
}

class _GeneratorSplashState extends State<GeneratorSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: GeneratorSplash.timeline.total,
  )..addStatusListener(_onStatus);

  late final Animation<double> _tile = _slice(0.00, 0.28, Curves.easeOutBack);
  late final Animation<double> _eyes = _slice(0.08, 0.30, Curves.easeOutBack);
  late final Animation<double> _wave = _slice(0.15, 0.62, Curves.linear);
  late final Animation<double> _shine = _slice(0.58, 0.80, Curves.easeInOut);
  late final Animation<double> _title = _slice(0.30, 0.60, Curves.easeOutCubic);
  late final List<Animation<double>> _steps = [
    _slice(0.50, 0.70, Curves.easeOutCubic),
    _slice(0.56, 0.76, Curves.easeOutCubic),
    _slice(0.62, 0.82, Curves.easeOutCubic),
  ];

  /// "BCC SASQR" as a real QR, so the dots land where a code's would.
  late final QrImage _code = QrImage(
    QrCode.fromData(
      data: AppStrings.appName,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    ),
  );

  Animation<double> _slice(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _controller,
        curve: GeneratorSplash.timeline.interval(begin, end, curve),
      );

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onFinished();
  }

  @override
  void initState() {
    super.initState();
    // With "reduce motion" on, the framework runs this at a twentieth of its
    // length: the finished scene, near enough at once.
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      body: Semantics(
        label: AppStrings.generatorSplashSemantics,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SplashTile(
                        shown: _tile.value,
                        child: CustomPaint(
                          painter: BuildingQrPainter(
                            code: _code,
                            eyes: _eyes.value,
                            wave: _wave.value,
                            shine: _shine.value,
                            module: colors.textPrimary,
                            eye: colors.accent,
                            glint: colors.accentSoft.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      splashRise(
                        _title.value,
                        const SplashWordmark(
                          tagline: AppStrings.generatorSplashTagline,
                        ),
                      ),
                      const SizedBox(height: 30),
                      SplashSteps(
                        steps: GeneratorSplash.steps,
                        shown: [for (final s in _steps) s.value],
                      ),
                    ],
                  ),
                ),
                SplashFooter(shown: _steps.last.value),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws [code] part-built: eyes scaled by [eyes], each dot popping in as the
/// diagonal [wave] reaches it, and a [shine] sweeping corner to corner. The
/// introduction's QR slide draws it too.
class BuildingQrPainter extends CustomPainter {
  const BuildingQrPainter({
    required this.code,
    required this.eyes,
    required this.wave,
    required this.shine,
    required this.module,
    required this.eye,
    required this.glint,
  });

  final QrImage code;
  final double eyes;
  final double wave;
  final double shine;
  final Color module;
  final Color eye;
  final Color glint;

  /// How much of the wave each dot takes to pop in; the rest is its delay.
  static const double _pop = 0.3;

  @override
  void paint(Canvas canvas, Size size) {
    final n = code.moduleCount;
    final cell = size.width / n;

    bool inEye(int r, int c) =>
        (r < 7 && c < 7) || (r < 7 && c >= n - 7) || (r >= n - 7 && c < 7);

    if (wave > 0) {
      final dot = Paint()..color = module;
      for (var r = 0; r < n; r++) {
        for (var c = 0; c < n; c++) {
          if (inEye(r, c) || !code.isDark(r, c)) continue;
          final delay = (r + c) / (2 * (n - 1)) * (1 - _pop);
          final t = ((wave - delay) / _pop).clamp(0.0, 1.0);
          if (t == 0) continue;
          canvas.drawCircle(
            Offset((c + 0.5) * cell, (r + 0.5) * cell),
            cell * 0.42 * Curves.easeOutBack.transform(t),
            dot,
          );
        }
      }
    }

    if (eyes > 0) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell
        ..color = eye;
      final pupil = Paint()..color = eye;
      for (final (row, col) in [(0, 0), (0, n - 7), (n - 7, 0)]) {
        final centre = Offset((col + 3.5) * cell, (row + 3.5) * cell);
        canvas
          ..save()
          ..translate(centre.dx, centre.dy)
          ..scale(eyes)
          ..translate(-centre.dx, -centre.dy)
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                (col + 0.5) * cell,
                (row + 0.5) * cell,
                6 * cell,
                6 * cell,
              ),
              Radius.circular(cell * 1.6),
            ),
            ring,
          )
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                (col + 2) * cell,
                (row + 2) * cell,
                3 * cell,
                3 * cell,
              ),
              Radius.circular(cell * 0.8),
            ),
            pupil,
          )
          ..restore();
      }
    }

    paintSplashShine(canvas, size, shine, glint);
  }

  @override
  bool shouldRepaint(BuildingQrPainter old) =>
      old.eyes != eyes ||
      old.wave != wave ||
      old.shine != shine ||
      old.module != module ||
      old.eye != eye ||
      old.glint != glint ||
      old.code != code;
}
