import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/splash_parts.dart';

/// My Profile, behind its opening splash.
class ProfileIntro extends StatelessWidget {
  const ProfileIntro({super.key, required this.page});

  final WidgetBuilder page;

  @override
  Widget build(BuildContext context) => SplashThen(
    splash: (onFinished) => ProfileSplash(onFinished: onFinished),
    page: page,
  );
}

/// A portrait being taken: the viewfinder's corners snap in, a head and
/// shoulders draw themselves inside, the flash goes, the figure fills with
/// colour, and a check pops at its side — with the three steps underneath.
/// The generator's and the tracker's splash in shape, so the student side
/// reads as one family.
class ProfileSplash extends StatefulWidget {
  const ProfileSplash({super.key, required this.onFinished});

  /// Called once, when the splash has played.
  final VoidCallback onFinished;

  /// The same pace as the other two.
  static const SplashTimeline timeline = SplashTimeline(
    play: Duration(milliseconds: 2300),
    hold: Duration(milliseconds: 400),
  );

  static const List<SplashStep> steps = [
    (icon: Icons.verified_user_outlined, label: ProfileStrings.stepVerify),
    (icon: Icons.photo_camera_outlined, label: ProfileStrings.stepPhoto),
    (icon: Icons.qr_code_scanner_rounded, label: ProfileStrings.stepScanner),
  ];

  @override
  State<ProfileSplash> createState() => _ProfileSplashState();
}

class _ProfileSplashState extends State<ProfileSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ProfileSplash.timeline.total,
  )..addStatusListener(_onStatus);

  late final Animation<double> _tile = _slice(0.00, 0.28, Curves.easeOutBack);
  late final Animation<double> _frame = _slice(0.08, 0.32, Curves.easeOutBack);
  late final Animation<double> _figure = _slice(0.16, 0.50, Curves.easeInOut);
  late final Animation<double> _flash = _slice(0.50, 0.62, Curves.linear);
  late final Animation<double> _fill = _slice(0.53, 0.66, Curves.easeOut);
  late final Animation<double> _check = _slice(0.60, 0.76, Curves.easeOutBack);
  late final Animation<double> _shine = _slice(0.66, 0.84, Curves.easeInOut);
  late final Animation<double> _title = _slice(0.30, 0.60, Curves.easeOutCubic);
  late final List<Animation<double>> _steps = [
    _slice(0.50, 0.70, Curves.easeOutCubic),
    _slice(0.56, 0.76, Curves.easeOutCubic),
    _slice(0.62, 0.82, Curves.easeOutCubic),
  ];

  Animation<double> _slice(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _controller,
        curve: ProfileSplash.timeline.interval(begin, end, curve),
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
        label: ProfileStrings.splashSemantics,
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
                          painter: PortraitPainter(
                            frame: _frame.value,
                            figure: _figure.value,
                            flash: _flash.value,
                            fill: _fill.value,
                            check: _check.value,
                            shine: _shine.value,
                            accent: colors.accent,
                            line: colors.textPrimary,
                            corner: colors.textSecondary,
                            onAccent: colors.onAccent,
                            surface: colors.surface,
                            glint: colors.accentSoft.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      splashRise(
                        _title.value,
                        const SplashWordmark(
                          tagline: ProfileStrings.splashTagline,
                        ),
                      ),
                      const SizedBox(height: 30),
                      SplashSteps(
                        steps: ProfileSplash.steps,
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

/// Draws the portrait part-taken. Each value runs 0 → 1 (a little past, with
/// an overshooting curve):
///
/// * [frame] — the viewfinder's four corners, closing in from outside;
/// * [figure] — the head and shoulders, traced along their outline;
/// * [flash] — the camera's flash, up and down again;
/// * [fill] — the captured figure filling with the accent;
/// * [check] — the check that pops at the figure's side;
/// * [shine] — the glint corner to corner, as on the other splashes.
class PortraitPainter extends CustomPainter {
  const PortraitPainter({
    required this.frame,
    required this.figure,
    required this.flash,
    required this.fill,
    required this.check,
    required this.shine,
    required this.accent,
    required this.line,
    required this.corner,
    required this.onAccent,
    required this.surface,
    required this.glint,
  });

  final double frame;
  final double figure;
  final double flash;
  final double fill;
  final double check;
  final double shine;
  final Color accent;
  final Color line;
  final Color corner;
  final Color onAccent;

  /// The tile's own colour: the check is cut out of the figure with it.
  final Color surface;
  final Color glint;

  /// A flash is white in both themes, as a camera's is.
  static const Color _flashColor = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = w * 0.035;

    // The figure: a head, and shoulders that run off the bottom.
    final headCentre = Offset(w * 0.5, h * 0.40);
    final headRadius = w * 0.165;
    final head = Path()
      ..addOval(Rect.fromCircle(center: headCentre, radius: headRadius));
    final shoulders = Path()
      ..moveTo(w * 0.16, h * 0.97)
      ..cubicTo(w * 0.16, h * 0.70, w * 0.32, h * 0.63, w * 0.5, h * 0.63)
      ..cubicTo(w * 0.68, h * 0.63, w * 0.84, h * 0.70, w * 0.84, h * 0.97);

    if (fill > 0) {
      final body = Paint()..color = accent.withValues(alpha: 0.22 * fill);
      canvas
        ..drawPath(head, body)
        ..drawPath(Path.from(shoulders)..close(), body);
    }

    if (figure > 0) {
      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(line, accent, fill)!;
      // The head first, then the shoulders, as one pen stroke.
      final headPart = (figure / 0.45).clamp(0.0, 1.0);
      final shoulderPart = ((figure - 0.35) / 0.65).clamp(0.0, 1.0);
      _drawPart(canvas, head, headPart, outline);
      _drawPart(canvas, shoulders, shoulderPart, outline);
    }

    if (frame > 0) _drawCorners(canvas, size, stroke);

    // A burst from the middle that fades to nothing at the edges — a flat
    // white square read as a box inside the tile, not as light.
    if (flash > 0 && flash < 1) {
      final strength = math.sin(math.pi * flash);
      final centre = Offset(w / 2, h / 2);
      final radius = w * (0.45 + 0.35 * flash);
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _flashColor.withValues(alpha: 0.9 * strength),
              _flashColor.withValues(alpha: 0.5 * strength),
              _flashColor.withValues(alpha: 0),
            ],
            stops: const [0, 0.45, 1],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }

    if (check > 0) _drawCheck(canvas, size);

    paintSplashShine(canvas, size, shine, glint);
  }

  /// The first [t] of [path]'s length.
  void _drawPart(Canvas canvas, Path path, double t, Paint paint) {
    if (t <= 0) return;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * t), paint);
    }
  }

  /// Four L-shaped corners, travelling in from 18 % outside their place.
  void _drawCorners(Canvas canvas, Size size, double stroke) {
    final w = size.width;
    final arm = w * 0.2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Color.lerp(
        corner,
        accent,
        fill,
      )!.withValues(alpha: frame.clamp(0.0, 1.0));
    final out = w * 0.18 * (1 - frame);
    final inset = stroke / 2;
    for (final (x, y) in [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)]) {
      final cx = x < 0 ? inset - out : w - inset + out;
      final cy = y < 0 ? inset - out : size.height - inset + out;
      canvas.drawPath(
        Path()
          ..moveTo(cx, cy - y * arm)
          ..lineTo(cx, cy)
          ..lineTo(cx - x * arm, cy),
        paint,
      );
    }
  }

  /// A filled accent disc at the figure's lower right, and its tick.
  void _drawCheck(Canvas canvas, Size size) {
    final w = size.width;
    final centre = Offset(w * 0.78, size.height * 0.74);
    final radius = w * 0.13 * check;
    canvas
      ..drawCircle(centre, radius + w * 0.025, Paint()..color = surface)
      ..drawCircle(centre, radius, Paint()..color = accent);

    final t = ((check - 0.4) / 0.6).clamp(0.0, 1.0);
    if (t <= 0) return;
    final s = w * 0.13;
    final a = centre + Offset(-s * 0.42, s * 0.02);
    final b = centre + Offset(-s * 0.12, s * 0.32);
    final c = centre + Offset(s * 0.44, -s * 0.30);
    final tick = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy);
    _drawPart(
      canvas,
      tick,
      t,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = onAccent,
    );
  }

  @override
  bool shouldRepaint(PortraitPainter old) =>
      old.frame != frame ||
      old.figure != figure ||
      old.flash != flash ||
      old.fill != fill ||
      old.check != check ||
      old.shine != shine ||
      old.accent != accent ||
      old.line != line ||
      old.corner != corner ||
      old.onAccent != onAccent ||
      old.surface != surface ||
      old.glint != glint;
}
