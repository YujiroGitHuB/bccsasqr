import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import 'widgets/fade_scale_switcher.dart';

/// The generator, behind its opening splash: the splash plays once, then
/// cross-fades into the page. The page is not built until then, so nothing on
/// it starts talking under the animation.
class GeneratorIntro extends StatefulWidget {
  const GeneratorIntro({super.key, required this.page});

  final WidgetBuilder page;

  @override
  State<GeneratorIntro> createState() => _GeneratorIntroState();
}

class _GeneratorIntroState extends State<GeneratorIntro> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return FadeScaleSwitcher(
      child: _done
          ? Builder(key: const ValueKey('generator'), builder: widget.page)
          : GeneratorSplash(
              key: const ValueKey('splash'),
              onFinished: () {
                if (mounted) setState(() => _done = true);
              },
            ),
    );
  }
}

/// A QR being made — the three corner eyes, then the dots in a wave from the
/// top-left, then a glint across the finished code — with the three steps a
/// student is about to take laid out underneath.
///
/// There is nothing to load here; the splash is the welcome, so it is kept
/// short. It follows the app's theme, like the scanner's.
class GeneratorSplash extends StatefulWidget {
  const GeneratorSplash({super.key, required this.onFinished});

  /// Called once, when the splash has played.
  final VoidCallback onFinished;

  /// The last sixth is a hold, so the steps can be read.
  static const Duration duration = Duration(milliseconds: 1700);

  @override
  State<GeneratorSplash> createState() => _GeneratorSplashState();
}

class _GeneratorSplashState extends State<GeneratorSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: GeneratorSplash.duration,
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
        curve: Interval(begin, end, curve: curve),
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
                      _BuildingCode(
                        code: _code,
                        tile: _tile.value,
                        eyes: _eyes.value,
                        wave: _wave.value,
                        shine: _shine.value,
                      ),
                      const SizedBox(height: 26),
                      _rise(_title.value, const _GeneratorWordmark()),
                      const SizedBox(height: 30),
                      _Steps(shown: [for (final s in _steps) s.value]),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Opacity(
                      opacity: _steps.last.value.clamp(0.0, 1.0),
                      child: Text(
                        AppStrings.splashFooter,
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 0.4,
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _rise(double t, Widget child) => Opacity(
  opacity: t.clamp(0.0, 1.0),
  child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
);

/// The tile the code is drawn on, and the glow behind it.
class _BuildingCode extends StatelessWidget {
  const _BuildingCode({
    required this.code,
    required this.tile,
    required this.eyes,
    required this.wave,
    required this.shine,
  });

  final QrImage code;
  final double tile;
  final double eyes;
  final double wave;
  final double shine;

  static const double _box = 210;
  static const double _tileSize = 150;
  static const double _inset = 16;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shown = tile.clamp(0.0, 1.0);

    return SizedBox.square(
      dimension: _box,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: shown,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [colors.accentWash(0.22), colors.accentWash(0)],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          Opacity(
            opacity: shown,
            child: Transform.scale(
              scale: 0.8 + 0.2 * tile,
              child: Container(
                width: _tileSize,
                height: _tileSize,
                padding: const EdgeInsets.all(_inset),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: colors.accentWash(0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: CustomPaint(
                  painter: _BuildingQrPainter(
                    code: code,
                    eyes: eyes,
                    wave: wave,
                    shine: shine,
                    module: colors.textPrimary,
                    eye: colors.accent,
                    glint: colors.accentSoft.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws [code] part-built: eyes scaled by [eyes], each dot popping in as the
/// diagonal [wave] reaches it, and a [shine] sweeping corner to corner.
class _BuildingQrPainter extends CustomPainter {
  const _BuildingQrPainter({
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

    if (shine > 0 && shine < 1) {
      final s = -0.25 + 1.5 * shine;
      final rect = Offset.zero & size;
      final clear = glint.withValues(alpha: 0);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [clear, glint, clear],
            stops: [
              (s - 0.15).clamp(0.0, 1.0),
              s.clamp(0.0, 1.0),
              (s + 0.15).clamp(0.0, 1.0),
            ],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_BuildingQrPainter old) =>
      old.eyes != eyes ||
      old.wave != wave ||
      old.shine != shine ||
      old.module != module ||
      old.eye != eye ||
      old.glint != glint ||
      old.code != code;
}

/// "BCC SASQR" and what this half of the app does.
class _GeneratorWordmark extends StatelessWidget {
  const _GeneratorWordmark();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: AppStrings.splashBrand),
              TextSpan(
                text: AppStrings.splashBrandAccent,
                style: TextStyle(color: colors.accent),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.generatorSplashTagline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.4,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Student number → Verify → Save QR, each arriving in turn, joined by a line
/// that draws itself across.
class _Steps extends StatelessWidget {
  const _Steps({required this.shown});

  /// One 0 → 1 value per step.
  final List<double> shown;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Step(
          icon: Icons.pin_outlined,
          label: AppStrings.generatorStepNumber,
          shown: shown[0],
        ),
        _Connector(shown: shown[1]),
        _Step(
          icon: Icons.verified_outlined,
          label: AppStrings.generatorStepVerify,
          shown: shown[1],
        ),
        _Connector(shown: shown[2]),
        _Step(
          icon: Icons.download_rounded,
          label: AppStrings.generatorStepSave,
          shown: shown[2],
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.label, required this.shown});

  final IconData icon;
  final String label;
  final double shown;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      width: 76,
      child: _rise(
        shown,
        Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accentWash(0.12),
                border: Border.all(color: colors.accentWash(0.30)),
              ),
              child: Icon(icon, size: 18, color: colors.accent),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.shown});

  final double shown;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Level with the middle of the 38 px circles.
      padding: const EdgeInsets.only(top: 18),
      child: SizedBox(
        width: 20,
        height: 2,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: shown.clamp(0.0, 1.0),
            heightFactor: 1,
            child: ColoredBox(color: context.colors.accentWash(0.45)),
          ),
        ),
      ),
    );
  }
}
