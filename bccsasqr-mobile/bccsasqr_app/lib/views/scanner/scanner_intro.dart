import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/splash_parts.dart';
import '../widgets/viewfinder.dart';

/// What an instructor sees while the scanner opens: a QR in a viewfinder with
/// the scan line passing over it, while the saved sign-in is checked with the
/// server.
///
/// The intro plays once whatever the network does, so a quick answer does not
/// flash it past; a slow one keeps the line sweeping until the answer comes.
/// It follows the app's theme — unlike the app's opening splash, which has to
/// match the dark native launch screen.
class ScannerSplash extends StatefulWidget {
  const ScannerSplash({
    super.key,
    required this.message,
    required this.onIntroDone,
    this.done = false,
  });

  /// The line under the name: "Checking your sign-in…", then who is back.
  final String message;

  /// The check came back signed in: a tick in place of the spinner.
  final bool done;

  /// Called once, when the intro has played. The caller moves on then, or as
  /// soon as the check answers, whichever is later.
  final VoidCallback onIntroDone;

  /// Slow enough to watch the code slide in, then a hold so "Welcome back"
  /// can be read before the scanner takes over.
  static const SplashTimeline timeline = SplashTimeline(
    play: Duration(milliseconds: 1800),
    hold: Duration(milliseconds: 500),
  );

  @override
  State<ScannerSplash> createState() => _ScannerSplashState();
}

class _ScannerSplashState extends State<ScannerSplash>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: ScannerSplash.timeline.total,
  )..addStatusListener(_onIntroStatus);

  /// The scan line, round and round for as long as the splash is up.
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );

  late final Animation<double> _frame = _slice(0.00, 0.45, Curves.easeOutBack);
  late final Animation<double> _code = _slice(0.12, 0.50, Curves.easeOutCubic);
  late final Animation<double> _title = _slice(0.32, 0.72, Curves.easeOutCubic);
  late final Animation<double> _status = _slice(0.55, 0.95, Curves.easeOut);

  bool _started = false;

  Animation<double> _slice(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _intro,
        curve: ScannerSplash.timeline.interval(begin, end, curve),
      );

  void _onIntroStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onIntroDone();
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
    final colors = context.colors;

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
                      const SizedBox(height: 28),
                      Opacity(
                        opacity: _title.value.clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, 14 * (1 - _title.value)),
                          child: const _ScannerWordmark(),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Opacity(
                        opacity: _status.value.clamp(0.0, 1.0),
                        child: _StatusLine(
                          message: widget.message,
                          done: widget.done,
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Opacity(
                      opacity: _status.value.clamp(0.0, 1.0),
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

/// A spinner and what is being waited on; a tick once it has answered.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.message, required this.done});

  final String message;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 18,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: done
                  ? Icon(
                      Icons.check_circle_rounded,
                      key: const ValueKey('done'),
                      size: 18,
                      color: colors.success,
                    )
                  : Padding(
                      key: const ValueKey('busy'),
                      padding: const EdgeInsets.all(2),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.accent,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                message,
                key: ValueKey(message),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Plays once after the email and password are accepted: a ring closes, a
/// tick is drawn, and the instructor is greeted by name while their subjects
/// load behind it. A saved sign-in skips this — the splash says "Welcome
/// back" instead — unless it was behind the fingerprint lock: opening that
/// plays this too, as [ScannerWelcome.unlocked].
class ScannerWelcome extends StatefulWidget {
  const ScannerWelcome({
    super.key,
    required this.name,
    required this.onFinished,
  }) : unlocked = false;

  /// After the phone's lock opened a saved sign-in: "UNLOCKED",
  /// "Welcome back".
  const ScannerWelcome.unlocked({
    super.key,
    required this.name,
    required this.onFinished,
  }) : unlocked = true;

  final String name;
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

  // Everything lands by 0.85 of the play; the rest, and the hold, is still.
  late final Animation<double> _pop = _slice(0.00, 0.32, Curves.easeOutBack);
  late final Animation<double> _ring = _slice(0.00, 0.40, Curves.easeOutCubic);
  late final Animation<double> _tick = _slice(0.30, 0.55, Curves.easeOutCubic);
  late final Animation<double> _pulse = _slice(0.40, 0.85, Curves.easeOut);
  late final Animation<double> _label = _slice(0.40, 0.68, Curves.easeOutCubic);
  late final Animation<double> _name = _slice(0.46, 0.76, Curves.easeOutCubic);
  late final Animation<double> _body = _slice(0.56, 0.84, Curves.easeOut);

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

  Widget _rise(Animation<double> a, Widget child) => Opacity(
    opacity: a.value.clamp(0.0, 1.0),
    child: Transform.translate(
      offset: Offset(0, 12 * (1 - a.value)),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const badge = 104.0;

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
                  SizedBox.square(
                    dimension: badge * 1.7,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // A halo that spreads and fades as the tick lands.
                        Opacity(
                          opacity:
                              (1 - _pulse.value).clamp(0.0, 1.0) *
                              (_pulse.value > 0 ? 1 : 0),
                          child: Container(
                            width: badge * (1 + 0.6 * _pulse.value),
                            height: badge * (1 + 0.6 * _pulse.value),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.accentWash(0.28),
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: _pop.value,
                          child: Container(
                            width: badge,
                            height: badge,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.accentWash(0.12),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.accentWash(0.30),
                                  blurRadius: 28,
                                ),
                              ],
                            ),
                            child: CustomPaint(
                              painter: _TickPainter(
                                ring: _ring.value,
                                tick: _tick.value,
                                color: colors.accent,
                                track: colors.accentWash(0.18),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _rise(
                    _label,
                    Text(
                      widget.unlocked
                          ? ScannerStrings.lockUnlockedLabel
                          : ScannerStrings.welcomeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: colors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _rise(
                    _name,
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        widget.unlocked
                            ? ScannerStrings.welcomeBack(widget.name)
                            : ScannerStrings.welcomeTitle(widget.name),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _rise(
                    _body,
                    Text(
                      ScannerStrings.welcomeBody,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A ring drawn round from the top, then a tick drawn stroke by stroke.
class _TickPainter extends CustomPainter {
  const _TickPainter({
    required this.ring,
    required this.tick,
    required this.color,
    required this.track,
  });

  final double ring;
  final double tick;
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
    if (ring > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * ring.clamp(0.0, 1.0),
        false,
        stroke..color = color,
      );
    }

    if (tick <= 0) return;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.30, h * 0.52)
      ..lineTo(w * 0.44, h * 0.66)
      ..lineTo(w * 0.71, h * 0.38);
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * tick.clamp(0.0, 1.0)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_TickPainter old) =>
      old.ring != ring ||
      old.tick != tick ||
      old.color != color ||
      old.track != track;
}
