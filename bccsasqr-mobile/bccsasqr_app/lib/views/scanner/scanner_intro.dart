import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/scanner_models.dart';
import '../widgets/splash_parts.dart';
import '../widgets/viewfinder.dart';
import 'widgets/scanner_header.dart';

/// The scanner, behind its opening splash — played the first time the
/// Scanner is opened, as the other tabs play theirs. Not when the app opens:
/// that is Home's moment, straight after the app's own splash.
class ScannerIntro extends StatelessWidget {
  const ScannerIntro({super.key, required this.page});

  final WidgetBuilder page;

  @override
  Widget build(BuildContext context) => SplashThen(
    splash: (onFinished) => ScannerSplash(onFinished: onFinished),
    page: page,
  );
}

/// What an instructor sees as the scanner opens: a QR in a viewfinder with
/// the scan line passing over it, the scanner's name, and the three steps of
/// a scan — the other tabs' splash in shape, so they read as one family.
///
/// There is nothing to wait for — the subjects came with the sign-in — so it
/// plays once and goes. It follows the app's theme, like the other tabs'.
class ScannerSplash extends StatefulWidget {
  const ScannerSplash({super.key, required this.onFinished});

  /// Called once, when the splash has played.
  final VoidCallback onFinished;

  /// The same pace as the other tabs'.
  static const SplashTimeline timeline = SplashTimeline(
    play: Duration(milliseconds: 2300),
    hold: Duration(milliseconds: 400),
  );

  static const List<SplashStep> steps = [
    (icon: Icons.menu_book_outlined, label: ScannerStrings.stepSubject),
    (icon: Icons.qr_code_scanner_rounded, label: ScannerStrings.stepScan),
    (icon: Icons.how_to_reg_outlined, label: ScannerStrings.stepPresent),
  ];

  @override
  State<ScannerSplash> createState() => _ScannerSplashState();
}

class _ScannerSplashState extends State<ScannerSplash>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: ScannerSplash.timeline.total,
  )..addStatusListener(_onIntroStatus);

  /// The scan line, round and round while the splash is up — and gone with
  /// it.
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );

  late final Animation<double> _frame = _slice(0.00, 0.45, Curves.easeOutBack);
  late final Animation<double> _code = _slice(0.12, 0.50, Curves.easeOutCubic);
  late final Animation<double> _title = _slice(0.30, 0.60, Curves.easeOutCubic);
  late final List<Animation<double>> _steps = [
    _slice(0.50, 0.70, Curves.easeOutCubic),
    _slice(0.56, 0.76, Curves.easeOutCubic),
    _slice(0.62, 0.82, Curves.easeOutCubic),
  ];

  bool _started = false;

  Animation<double> _slice(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _intro,
        curve: ScannerSplash.timeline.interval(begin, end, curve),
      );

  void _onIntroStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onFinished();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      // With "reduce motion" on, the framework runs this at a twentieth of
      // its length: the finished scene, near enough at once.
      _intro.forward();
    }
    // The sweep is decoration; the spinner under it still says "working".
    if (MediaQuery.disableAnimationsOf(context)) {
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Semantics(
        label: ScannerStrings.splashSemantics,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([_intro, _sweep]),
            builder: (context, _) => Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ScannedCode(
                        frame: _frame.value,
                        code: _code.value,
                        sweep: _sweep.isAnimating ? _sweep.value : null,
                      ),
                      const SizedBox(height: 26),
                      splashRise(_title.value, const _ScannerWordmark()),
                      const SizedBox(height: 30),
                      SplashSteps(
                        steps: ScannerSplash.steps,
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

/// A QR on a tile, inside the viewfinder, with the scan line going over it.
class _ScannedCode extends StatelessWidget {
  const _ScannedCode({
    required this.frame,
    required this.code,
    required this.sweep,
  });

  /// 0 → 1: the glow and the viewfinder corners arriving.
  final double frame;

  /// 0 → 1: the QR tile rising into the frame.
  final double code;

  /// 0 → 1, over and over: the scan line's trip down the tile. Null holds it
  /// still (reduce motion).
  final double? sweep;

  static const double _box = 208;
  static const double _viewfinder = 164;
  static const double _tile = 116;
  static const double _trail = 30;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shown = frame.clamp(0.0, 1.0);
    final t = sweep;
    // Fades in at the top and out at the bottom instead of popping.
    final beam = t == null ? 0.0 : math.sin(math.pi * t) * code.clamp(0, 1);

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
              scale: 1.3 - 0.3 * frame,
              child: CustomPaint(
                size: const Size.square(_viewfinder),
                painter: ViewfinderPainter(color: colors.accent),
              ),
            ),
          ),
          Opacity(
            opacity: code.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.86 + 0.14 * code,
              child: Container(
                width: _tile,
                height: _tile,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: colors.accentWash(0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: Stack(
                    children: [
                      Center(
                        child: QrImageView(
                          data: AppStrings.appName,
                          version: QrVersions.auto,
                          size: _tile - 28,
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.transparent,
                          eyeStyle: QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: colors.accent,
                          ),
                          dataModuleStyle: QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.circle,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      if (t != null && beam > 0)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: _tile * t - _trail,
                          height: _trail + 2,
                          child: Opacity(
                            opacity: beam.clamp(0.0, 1.0),
                            child: ScanBeam(trail: _trail, palette: colors),
                          ),
                        ),
                    ],
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

/// "BCC SASQR Scanner" and what it is.
class _ScannerWordmark extends StatelessWidget {
  const _ScannerWordmark();

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
              const TextSpan(text: ScannerStrings.splashWord),
            ],
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          ScannerStrings.subtitle.toUpperCase(),
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

/// Plays once after the email and password are accepted: the instructor's
/// photo (or initials) pops in, a ring closes round it, a tick badge lands on
/// its corner — with a burst of dots and a ripple going out — and they are
/// greeted by name while a bar fills as their subjects load behind it. A
/// saved sign-in skips this and opens straight on Home, which greets them by
/// name — unless it was behind the fingerprint lock: opening that plays this
/// too, as [ScannerWelcome.unlocked].
class ScannerWelcome extends StatefulWidget {
  const ScannerWelcome({
    super.key,
    required this.name,
    this.user,
    required this.onFinished,
  }) : unlocked = false;

  /// After the phone's lock opened a saved sign-in: "UNLOCKED",
  /// "Welcome back".
  const ScannerWelcome.unlocked({
    super.key,
    required this.name,
    this.user,
    required this.onFinished,
  }) : unlocked = true;

  final String name;

  /// Whose photo, or initials, sit in the ring. A person icon without one.
  final ScannerUser? user;
  final bool unlocked;

  /// Called once, when the welcome has played. The caller shows the scanner.
  final VoidCallback onFinished;

  /// Unhurried, then a hold so the name can be read.
  static const SplashTimeline timeline = SplashTimeline(
    play: Duration(milliseconds: 2300),
    hold: Duration(milliseconds: 400),
  );

  @override
  State<ScannerWelcome> createState() => _ScannerWelcomeState();
}

class _ScannerWelcomeState extends State<ScannerWelcome>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ScannerWelcome.timeline.total,
  )..addStatusListener(_onStatus);

  // Everything lands by 0.85 of the play; the rest, and the hold, is still —
  // but for the bar, which fills to the very end.
  late final Animation<double> _pop = _slice(0.00, 0.30, Curves.easeOutBack);
  late final Animation<double> _ring = _slice(0.05, 0.40, Curves.easeInOut);
  late final Animation<double> _badge = _slice(0.34, 0.52, Curves.easeOutBack);
  late final Animation<double> _tick = _slice(0.40, 0.58, Curves.easeOut);
  late final Animation<double> _burst = _slice(0.38, 0.78, Curves.easeOutCubic);
  late final Animation<double> _ripple = _slice(0.40, 0.95, Curves.easeOut);
  late final Animation<double> _label = _slice(0.42, 0.68, Curves.easeOutCubic);
  late final Animation<double> _name = _slice(0.48, 0.76, Curves.easeOutCubic);
  late final Animation<double> _body = _slice(0.56, 0.84, Curves.easeOut);
  late final Animation<double> _load = _slice(0.56, 1.00, Curves.easeInOut);

  Animation<double> _slice(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _controller,
        curve: ScannerWelcome.timeline.interval(begin, end, curve),
      );

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onFinished();
  }

  @override
  void initState() {
    super.initState();
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
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Portrait(
                    user: widget.user,
                    pop: _pop.value,
                    ring: _ring.value,
                    badge: _badge.value,
                    tick: _tick.value,
                    burst: _burst.value,
                    ripple: _ripple.value,
                    unlocked: widget.unlocked,
                  ),
                  const SizedBox(height: 18),
                  splashRise(_label.value, _Chip(unlocked: widget.unlocked)),
                  const SizedBox(height: 14),
                  splashRise(
                    _name.value,
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        widget.unlocked
                            ? ScannerStrings.welcomeBack(widget.name)
                            : ScannerStrings.welcomeTitle(widget.name),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  splashRise(_body.value, _Loading(load: _load.value)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The instructor in the middle of it all: the ring, the badge, the burst
/// and the ripple, round their photo.
class _Portrait extends StatelessWidget {
  const _Portrait({
    required this.user,
    required this.pop,
    required this.ring,
    required this.badge,
    required this.tick,
    required this.burst,
    required this.ripple,
    required this.unlocked,
  });

  final ScannerUser? user;
  final double pop;
  final double ring;
  final double badge;
  final double tick;
  final double burst;
  final double ripple;
  final bool unlocked;

  static const double _photo = 96;
  static const double _box = 232;
  static const double _badgeSize = 34;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = this.user;
    // Where the badge sits: on the ring, at half past four.
    const corner = _photo / 2 + 8;
    final badgeAt = Offset(
      corner * math.cos(math.pi / 4),
      corner * math.sin(math.pi / 4),
    );

    return SizedBox.square(
      dimension: _box,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The glow, the ripples and the burst, all behind the photo.
          Positioned.fill(
            child: CustomPaint(
              painter: _CelebrationPainter(
                ripple: ripple,
                burst: burst,
                photo: _photo,
                glow: colors.accentWash(0.20 * pop.clamp(0.0, 1.0)),
                accent: colors.accent,
                soft: colors.accentSoft,
              ),
            ),
          ),
          Transform.scale(
            scale: pop,
            child: SizedBox.square(
              dimension: _photo + 24,
              child: CustomPaint(
                foregroundPainter: _RingPainter(
                  ring: ring,
                  color: colors.accent,
                  track: colors.accentWash(0.16),
                ),
                child: Center(
                  child: user == null
                      ? Container(
                          width: _photo,
                          height: _photo,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.accentWash(0.14),
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            size: _photo * 0.5,
                            color: colors.accent,
                          ),
                        )
                      : UserAvatar(user: user, size: _photo),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: badgeAt,
            child: Transform.scale(
              scale: badge,
              child: Container(
                width: _badgeSize,
                height: _badgeSize,
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
                child: unlocked
                    ? Icon(
                        Icons.lock_open_rounded,
                        size: 16,
                        color: AppPalette.dark.onAccent,
                      )
                    : CustomPaint(
                        painter: _TickPainter(
                          tick: tick,
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
}

/// The signed-in (or unlocked) chip, on a wash of the accent.
class _Chip extends StatelessWidget {
  const _Chip({required this.unlocked});

  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
      decoration: BoxDecoration(
        color: colors.accentWash(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.accentWash(0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            unlocked ? Icons.lock_open_rounded : Icons.verified_rounded,
            size: 15,
            color: colors.accent,
          ),
          const SizedBox(width: 6),
          Text(
            unlocked
                ? ScannerStrings.lockUnlockedLabel
                : ScannerStrings.welcomeLabel,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
              color: colors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// The opening-the-scanner line, over a bar that fills while the subjects
/// load.
class _Loading extends StatelessWidget {
  const _Loading({required this.load});

  final double load;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      children: [
        Text(
          ScannerStrings.welcomeBody,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 180,
          height: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(color: colors.accentWash(0.14)),
                ),
                FractionallySizedBox(
                  widthFactor: load.clamp(0.0, 1.0),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(gradient: AppPalette.brandMark),
                    child: SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Behind the photo: a soft glow, two ripples going out from the ring, and a
/// ring of dots thrown outwards as the badge lands.
class _CelebrationPainter extends CustomPainter {
  const _CelebrationPainter({
    required this.ripple,
    required this.burst,
    required this.photo,
    required this.glow,
    required this.accent,
    required this.soft,
  });

  final double ripple;
  final double burst;
  final double photo;
  final Color glow;
  final Color accent;
  final Color soft;

  static const int _dots = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final base = photo / 2 + 8;
    final reach = size.shortestSide / 2;

    canvas.drawCircle(
      centre,
      reach,
      Paint()
        ..shader = RadialGradient(
          colors: [glow, glow.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: centre, radius: reach)),
    );

    // Two ripples, the second a beat behind the first.
    for (final lag in const [0.0, 0.28]) {
      final r = ((ripple - lag) / (1 - lag)).clamp(0.0, 1.0);
      if (r <= 0 || r >= 1) continue;
      canvas.drawCircle(
        centre,
        base + (reach - base) * r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1 - r)
          ..color = accent.withValues(alpha: 0.55 * (1 - r)),
      );
    }

    if (burst <= 0 || burst >= 1) return;
    for (var i = 0; i < _dots; i++) {
      // Every other dot a little nearer and smaller: a burst, not a clock
      // face.
      final far = i.isEven ? 1.0 : 0.78;
      final angle = -math.pi / 2 + i * 2 * math.pi / _dots;
      final distance = base + 6 + (reach - base - 10) * burst * far;
      final at = centre + Offset(math.cos(angle), math.sin(angle)) * distance;
      canvas.drawCircle(
        at,
        (i.isEven ? 3.6 : 2.6) * (1 - burst * 0.6),
        Paint()
          ..color = (i.isEven ? accent : soft).withValues(
            alpha: (1 - burst).clamp(0.0, 1.0),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_CelebrationPainter old) =>
      old.ripple != ripple ||
      old.burst != burst ||
      old.photo != photo ||
      old.glow != glow ||
      old.accent != accent ||
      old.soft != soft;
}

/// A ring round the photo, drawn round from the top.
class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.ring,
    required this.color,
    required this.track,
  });

  final double ring;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 3;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, stroke..color = track);
    if (ring <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * ring.clamp(0.0, 1.0),
      false,
      stroke..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.ring != ring || old.color != color || old.track != track;
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
          ..strokeWidth = 3.2
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
