import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants/app_assets.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import 'widgets/splash_parts.dart';

/// Plays once **Get started** — or **Skip** — ends the introduction, before
/// the student-or-instructor question: the school seal pops in, the three
/// parts the slides told of (the QR code, the scan, the attendance) fly in
/// and take their places round it, a ring joins them, lighting each as it
/// passes, and a tick lands on the seal as the ring closes. Everything the
/// introduction showed, gathered and ready.
///
/// Asked for on 2026-10-01: the introduction used to fade straight into the
/// question — the one step on the way in with no splash of its own, between
/// the app's and the student's. The other splashes' shape and pace (the
/// picture, the wordmark, three steps, the college's name), so it reads as
/// one of the family. Not when Settings → Role asks the question again: the
/// phone is past getting started by then.
class GetStartedSplash extends StatefulWidget {
  const GetStartedSplash({super.key, required this.onFinished});

  /// Called once, when the splash has played.
  final VoidCallback onFinished;

  static const SplashTimeline timeline = SplashTimeline(
    play: Duration(milliseconds: 2300),
    hold: Duration(milliseconds: 400),
  );

  /// What comes next, whichever answer is picked: a student sets up the
  /// phone, an instructor signs in.
  static const List<SplashStep> steps = [
    (icon: Icons.people_alt_outlined, label: AppStrings.startStepRole),
    (icon: Icons.badge_outlined, label: AppStrings.startStepSetUp),
    (icon: Icons.task_alt_rounded, label: AppStrings.startStepReady),
  ];

  @override
  State<GetStartedSplash> createState() => _GetStartedSplashState();
}

class _GetStartedSplashState extends State<GetStartedSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: GetStartedSplash.timeline.total,
  )..addStatusListener(_onStatus);

  late final Animation<double> _seal = _slice(0.00, 0.26, Curves.easeOutBack);
  late final List<Animation<double>> _parts = [
    _slice(0.10, 0.34, Curves.easeOutBack),
    _slice(0.17, 0.41, Curves.easeOutBack),
    _slice(0.24, 0.48, Curves.easeOutBack),
  ];
  late final Animation<double> _ring = _slice(0.36, 0.66, Curves.easeInOut);
  late final Animation<double> _tick = _slice(0.62, 0.78, Curves.easeOutBack);
  late final Animation<double> _stroke = _slice(0.66, 0.80, Curves.easeOut);
  late final Animation<double> _ripple = _slice(0.62, 0.98, Curves.easeOut);
  late final Animation<double> _title = _slice(0.40, 0.66, Curves.easeOutCubic);
  late final List<Animation<double>> _steps = [
    _slice(0.52, 0.72, Curves.easeOutCubic),
    _slice(0.58, 0.78, Curves.easeOutCubic),
    _slice(0.64, 0.84, Curves.easeOutCubic),
  ];

  Animation<double> _slice(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _controller,
        curve: GetStartedSplash.timeline.interval(begin, end, curve),
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
    return Scaffold(
      body: Semantics(
        label: AppStrings.startSplashSemantics,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Gathering(
                        seal: _seal.value,
                        parts: [for (final p in _parts) p.value],
                        ring: _ring.value,
                        tick: _tick.value,
                        stroke: _stroke.value,
                        ripple: _ripple.value,
                      ),
                      const SizedBox(height: 26),
                      splashRise(
                        _title.value,
                        const SplashWordmark(
                          tagline: AppStrings.startSplashTagline,
                        ),
                      ),
                      const SizedBox(height: 30),
                      SplashSteps(
                        steps: GetStartedSplash.steps,
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

/// The seal in the middle, the three parts on a ring round it, and the tick
/// that says it is ready.
class _Gathering extends StatelessWidget {
  const _Gathering({
    required this.seal,
    required this.parts,
    required this.ring,
    required this.tick,
    required this.stroke,
    required this.ripple,
  });

  /// 0 → 1 (and a little past): the seal and its glow popping in.
  final double seal;

  /// One 0 → 1 per part (a little past, too): its flight in to the ring.
  final List<double> parts;

  /// 0 → 1: the ring drawn round from the top, through each part in turn.
  final double ring;

  /// 0 → 1 (a little past): the tick's badge landing; [stroke] draws its
  /// tick.
  final double tick;
  final double stroke;

  /// 0 → 1: two ripples going out once the ring has closed.
  final double ripple;

  static const double _box = 232;
  static const double _seal = 92;
  static const double _orbit = 84;
  static const double _partSize = 42;
  static const double _badge = 30;

  /// The parts on the introduction's welcome slide, in its order: placed
  /// round the ring from the top, a third of the way round each.
  static const List<IconData> _icons = [
    Icons.qr_code_2_rounded,
    Icons.qr_code_scanner_rounded,
    Icons.event_available_rounded,
  ];

  /// How much of the ring's trip each part takes to light up once the ring
  /// reaches it.
  static const double _lightUp = 0.10;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shown = seal.clamp(0.0, 1.0);
    // The badge sits on the seal's edge, at half past four.
    const corner = _seal / 2 * math.sqrt1_2 + 2;

    return SizedBox.square(
      dimension: _box,
      child: Stack(
        alignment: Alignment.center,
        // The parts start their flight outside the picture.
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RingPainter(
                ring: ring,
                ripple: ripple,
                orbit: _orbit,
                glow: colors.accentWash(0.20 * shown),
                track: colors.accentWash(0.16 * shown),
                accent: colors.accent,
              ),
            ),
          ),
          Opacity(
            opacity: shown,
            child: Transform.scale(
              scale: 0.5 + 0.5 * seal,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.accentWash(0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    AppAssets.bccLogo,
                    width: _seal,
                    height: _seal,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
          ),
          for (final (i, icon) in _icons.indexed)
            _flyingPart(colors, icon, i, parts[i]),
          Transform.translate(
            offset: const Offset(corner, corner),
            child: Transform.scale(
              scale: tick,
              child: Container(
                width: _badge,
                height: _badge,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppPalette.brandMark,
                  border: Border.all(color: colors.canvas, width: 3),
                  boxShadow: [
                    BoxShadow(color: colors.accentWash(0.45), blurRadius: 12),
                  ],
                ),
                // The brand fill is the same cyan in both themes, so the ink
                // on it is the dark set's in both.
                child: CustomPaint(
                  painter: _TickPainter(
                    tick: stroke,
                    color: AppPalette.dark.onAccent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Part [i], flying in along its own line from well outside the ring —
  /// an overshooting [fly] lets it land a touch inside and settle back — then
  /// lit, with a little bump, as the ring reaches it.
  Widget _flyingPart(AppPalette colors, IconData icon, int i, double fly) {
    if (fly <= 0) return const SizedBox.shrink();
    final angle = -math.pi / 2 + i * 2 * math.pi / _icons.length;
    final distance = _orbit * (1 + 1.3 * (1 - fly));
    final light = ((ring - i / _icons.length) / _lightUp).clamp(0.0, 1.0);
    final bump = 1 + 0.14 * math.sin(math.pi * light);

    return Transform.translate(
      offset: Offset(math.cos(angle), math.sin(angle)) * distance,
      child: Opacity(
        opacity: fly.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: (0.6 + 0.4 * fly) * bump,
          child: Container(
            width: _partSize,
            height: _partSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(colors.surface, colors.accent, light),
              border: Border.all(
                color: Color.lerp(colors.border, colors.accent, light)!,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.accentWash(0.12 + 0.24 * light),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 21,
              color: Color.lerp(colors.accent, colors.onAccent, light),
            ),
          ),
        ),
      ),
    );
  }
}

/// Behind the seal: a soft glow, the ring's track with the ring drawn round
/// it from the top, and two ripples going out once it has closed.
class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.ring,
    required this.ripple,
    required this.orbit,
    required this.glow,
    required this.track,
    required this.accent,
  });

  final double ring;
  final double ripple;
  final double orbit;
  final Color glow;
  final Color track;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final reach = size.shortestSide / 2;

    canvas.drawCircle(
      centre,
      reach,
      Paint()
        ..shader = RadialGradient(
          colors: [glow, glow.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: centre, radius: reach)),
    );

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(centre, orbit, stroke..color = track);
    if (ring > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: orbit),
        -math.pi / 2,
        2 * math.pi * ring.clamp(0.0, 1.0),
        false,
        stroke..color = accent,
      );
    }

    // Two ripples, the second a beat behind the first.
    for (final lag in const [0.0, 0.28]) {
      final r = ((ripple - lag) / (1 - lag)).clamp(0.0, 1.0);
      if (r <= 0 || r >= 1) continue;
      canvas.drawCircle(
        centre,
        orbit + (reach - orbit) * r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1 - r)
          ..color = accent.withValues(alpha: 0.5 * (1 - r)),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.ring != ring ||
      old.ripple != ripple ||
      old.orbit != orbit ||
      old.glow != glow ||
      old.track != track ||
      old.accent != accent;
}

/// A tick drawn stroke by stroke, in the badge.
class _TickPainter extends CustomPainter {
  const _TickPainter({required this.tick, required this.color});

  final double tick;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (tick <= 0) return;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.29, h * 0.52)
      ..lineTo(w * 0.44, h * 0.66)
      ..lineTo(w * 0.72, h * 0.36);
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * tick.clamp(0.0, 1.0)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_TickPainter old) =>
      old.tick != tick || old.color != color;
}
