import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../controllers/links_controller.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../services/link_repository.dart';
import '../widgets/splash_parts.dart';

/// The Links tab, behind its opening splash.
///
/// Unlike the generator's, this splash has work to hide: the list is asked
/// for the moment it starts, so the cards are there when it ends — as the
/// scanner's splash spends its time checking the sign-in. The controller is
/// made here for that reason, and handed to the page.
class LinksIntro extends StatefulWidget {
  const LinksIntro({
    super.key,
    required this.repository,
    required this.page,
    this.onSignedOut,
    this.clock,
  });

  final LinkRepository repository;

  /// The page, given the controller whose list is already on its way.
  final Widget Function(BuildContext context, LinksController controller) page;

  /// See [LinksController.onSignedOut].
  final VoidCallback? onSignedOut;
  final DateTime Function()? clock;

  @override
  State<LinksIntro> createState() => _LinksIntroState();
}

class _LinksIntroState extends State<LinksIntro> {
  late final LinksController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LinksController(
      repository: widget.repository,
      onSignedOut: widget.onSignedOut,
      clock: widget.clock,
    );
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SplashThen(
    splash: (onFinished) => LinksSplash(onFinished: onFinished),
    page: (context) => widget.page(context, _controller),
  );
}

/// A class's link going live: a chain link pops into the tile, a countdown
/// ring sweeps round it — the time the link stays open — and students check
/// in on the ring as it passes them, the last one amber, after the late
/// cutoff. A glint passes over the finished picture. The generator's and the
/// tracker's splash in shape, so the tabs read as one family.
class LinksSplash extends StatefulWidget {
  const LinksSplash({super.key, required this.onFinished});

  /// Called once, when the splash has played.
  final VoidCallback onFinished;

  /// The same pace as the other tabs'.
  static const SplashTimeline timeline = SplashTimeline(
    play: Duration(milliseconds: 2300),
    hold: Duration(milliseconds: 400),
  );

  static const List<SplashStep> steps = [
    (icon: Icons.hourglass_top_rounded, label: LinksStrings.stepTime),
    (icon: Icons.qr_code_2_rounded, label: LinksStrings.stepQr),
    (icon: Icons.how_to_reg_outlined, label: LinksStrings.stepIn),
  ];

  @override
  State<LinksSplash> createState() => _LinksSplashState();
}

class _LinksSplashState extends State<LinksSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: LinksSplash.timeline.total,
  )..addStatusListener(_onStatus);

  late final Animation<double> _tile = _slice(0.00, 0.28, Curves.easeOutBack);
  late final Animation<double> _chain = _slice(0.10, 0.34, Curves.easeOutBack);
  late final Animation<double> _ring = _slice(0.22, 0.70, Curves.easeInOut);
  late final Animation<double> _shine = _slice(0.66, 0.86, Curves.easeInOut);
  late final Animation<double> _title = _slice(0.30, 0.60, Curves.easeOutCubic);
  late final List<Animation<double>> _steps = [
    _slice(0.50, 0.70, Curves.easeOutCubic),
    _slice(0.56, 0.76, Curves.easeOutCubic),
    _slice(0.62, 0.82, Curves.easeOutCubic),
  ];

  Animation<double> _slice(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _controller,
        curve: LinksSplash.timeline.interval(begin, end, curve),
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
        label: LinksStrings.splashSemantics,
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
                          painter: LinkRingPainter(
                            chain: _chain.value,
                            ring: _ring.value,
                            shine: _shine.value,
                            accent: colors.accent,
                            late: colors.warning,
                            track: colors.textPrimary.withValues(alpha: 0.10),
                            hole: colors.surface,
                            check: colors.onAccent,
                            glint: colors.accentSoft.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      splashRise(
                        _title.value,
                        const SplashWordmark(
                          tagline: LinksStrings.splashTagline,
                        ),
                      ),
                      const SizedBox(height: 30),
                      SplashSteps(
                        steps: LinksSplash.steps,
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

/// Draws the picture part-built: the chain link scaled in by [chain], the
/// ring swept clockwise from the top by [ring] — sky while students are on
/// time, amber past the late cutoff — each student's dot popping onto the
/// ring as the sweep reaches it, and a [shine] corner to corner.
class LinkRingPainter extends CustomPainter {
  const LinkRingPainter({
    required this.chain,
    required this.ring,
    required this.shine,
    required this.accent,
    required this.late,
    required this.track,
    required this.hole,
    required this.check,
    required this.glint,
  });

  final double chain;
  final double ring;
  final double shine;
  final Color accent;
  final Color late;
  final Color track;

  /// The tile's own colour, cut round each student's dot so it sits on the
  /// ring rather than in it.
  final Color hole;
  final Color check;
  final Color glint;

  static const double _stroke = 7;

  /// Where on the ring the late cutoff falls.
  static const double _lateFrom = 0.74;

  /// Where on the ring each student checks in, in order.
  static const List<double> _students = [0.12, 0.30, 0.47, 0.62, 0.86];

  /// How far past a student the sweep goes while their dot pops in.
  static const double _pop = 0.12;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 9;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    const top = -math.pi / 2;

    // The track, fading in as the sweep starts.
    if (ring > 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = track.withValues(
            alpha: track.a * (ring * 5).clamp(0.0, 1.0),
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke,
      );

      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round;
      final onTime = math.min(ring, _lateFrom);
      canvas.drawArc(
        bounds,
        top,
        2 * math.pi * onTime,
        false,
        arc..color = accent,
      );
      if (ring > _lateFrom) {
        canvas.drawArc(
          bounds,
          top + 2 * math.pi * _lateFrom,
          2 * math.pi * (ring - _lateFrom),
          false,
          arc..color = late,
        );
      }
    }

    _drawChain(canvas, center, radius * 0.76);

    // The students, each as the sweep reaches them.
    for (final at in _students) {
      final t = ((ring - at) / _pop).clamp(0.0, 1.0);
      if (t == 0) continue;
      final angle = top + 2 * math.pi * at;
      final spot = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final r = 8.5 * Curves.easeOutBack.transform(t);
      canvas
        ..drawCircle(spot, r + 2.5, Paint()..color = hole)
        ..drawCircle(spot, r, Paint()..color = at >= _lateFrom ? late : accent);
      _drawCheck(canvas, spot, r, ((t - 0.4) / 0.6).clamp(0.0, 1.0));
    }

    paintSplashShine(canvas, size, shine, glint);
  }

  /// Two links of a chain, crossed on the diagonal, [span] across.
  void _drawChain(Canvas canvas, Offset center, double span) {
    if (chain <= 0) return;
    final length = span * 1.05;
    final height = span * 0.46;
    final paint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = span * 0.13
      ..strokeCap = StrokeCap.round;

    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(chain)
      ..rotate(-math.pi / 4);
    for (final dx in [-length * 0.29, length * 0.29]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(dx, 0),
            width: length * 0.72,
            height: height,
          ),
          Radius.circular(height / 2),
        ),
        paint,
      );
    }
    canvas.restore();
  }

  /// A check mark in a dot of radius [r] at [c], drawn [t] of the way along.
  void _drawCheck(Canvas canvas, Offset c, double r, double t) {
    if (t <= 0) return;
    final a = c + Offset(-r * 0.45, 0);
    final b = c + Offset(-r * 0.12, r * 0.32);
    final d = c + Offset(r * 0.48, -r * 0.36);
    final first = (a - b).distance;
    final total = first + (d - b).distance;
    final drawn = total * t;

    final path = Path()..moveTo(a.dx, a.dy);
    if (drawn <= first) {
      final p = Offset.lerp(a, b, drawn / first)!;
      path.lineTo(p.dx, p.dy);
    } else {
      final p = Offset.lerp(b, d, (drawn - first) / (total - first))!;
      path
        ..lineTo(b.dx, b.dy)
        ..lineTo(p.dx, p.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = check
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(LinkRingPainter old) =>
      old.chain != chain ||
      old.ring != ring ||
      old.shine != shine ||
      old.accent != accent ||
      old.late != late ||
      old.track != track ||
      old.hole != hole ||
      old.check != check ||
      old.glint != glint;
}
