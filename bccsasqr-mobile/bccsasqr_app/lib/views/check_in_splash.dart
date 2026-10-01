import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import 'widgets/splash_parts.dart';

/// Check in, behind its opening splash — played the first time the tab is
/// opened, as My QR Code, Attendance and My Profile play theirs (asked for
/// on 2026-10-01).
class CheckInIntro extends StatelessWidget {
  const CheckInIntro({super.key, required this.page});

  final WidgetBuilder page;

  @override
  Widget build(BuildContext context) => SplashThen(
    splash: (onFinished) => CheckInSplash(onFinished: onFinished),
    page: page,
  );
}

/// A check-in, start to end, on one tile: the class code drops into its six
/// boxes letter by letter, a fingerprint pops in under it and is read once,
/// then turns into a tick with a ripple going out — with the three steps
/// underneath. The other tabs' splash in shape and pace, so the student
/// side reads as one family.
class CheckInSplash extends StatefulWidget {
  const CheckInSplash({super.key, required this.onFinished});

  /// Called once, when the splash has played.
  final VoidCallback onFinished;

  /// The same pace as the other tabs'.
  static const SplashTimeline timeline = SplashTimeline(
    play: Duration(milliseconds: 2300),
    hold: Duration(milliseconds: 400),
  );

  static const List<SplashStep> steps = [
    (icon: Icons.content_paste_rounded, label: CheckInStrings.stepCode),
    (icon: Icons.fingerprint_rounded, label: CheckInStrings.stepConfirm),
    (icon: Icons.how_to_reg_rounded, label: CheckInStrings.stepDone),
  ];

  /// A made-up class code — never a real class's.
  static const String sampleCode = 'K7P2QX';

  @override
  State<CheckInSplash> createState() => _CheckInSplashState();
}

class _CheckInSplashState extends State<CheckInSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: CheckInSplash.timeline.total,
  )..addStatusListener(_onStatus);

  late final Animation<double> _tile = _slice(0.00, 0.28, Curves.easeOutBack);
  late final List<Animation<double>> _letters = [
    for (var i = 0; i < CheckInSplash.sampleCode.length; i++)
      _slice(0.10 + 0.055 * i, 0.24 + 0.055 * i, Curves.easeOutBack),
  ];
  late final Animation<double> _flow = _slice(0.40, 0.50, Curves.easeOut);
  late final Animation<double> _print = _slice(0.44, 0.60, Curves.easeOutBack);
  late final Animation<double> _read = _slice(0.56, 0.74, Curves.easeInOut);
  late final Animation<double> _tick = _slice(0.72, 0.86, Curves.easeOutBack);
  late final Animation<double> _ripple = _slice(0.74, 0.98, Curves.easeOut);
  late final Animation<double> _shine = _slice(0.80, 0.96, Curves.easeInOut);
  late final Animation<double> _title = _slice(0.30, 0.60, Curves.easeOutCubic);
  late final List<Animation<double>> _steps = [
    _slice(0.50, 0.70, Curves.easeOutCubic),
    _slice(0.56, 0.76, Curves.easeOutCubic),
    _slice(0.62, 0.82, Curves.easeOutCubic),
  ];

  Animation<double> _slice(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _controller,
        curve: CheckInSplash.timeline.interval(begin, end, curve),
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
        label: CheckInStrings.splashSemantics,
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
                        child: _CheckInPicture(
                          letters: [for (final l in _letters) l.value],
                          flow: _flow.value,
                          print: _print.value,
                          read: _read.value,
                          tick: _tick.value,
                          ripple: _ripple.value,
                          shine: _shine.value,
                        ),
                      ),
                      const SizedBox(height: 26),
                      splashRise(
                        _title.value,
                        const SplashWordmark(
                          tagline: CheckInStrings.splashTagline,
                        ),
                      ),
                      const SizedBox(height: 30),
                      SplashSteps(
                        steps: CheckInSplash.steps,
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

/// The tile's picture: the code's six boxes along the top, three dots
/// leading down to the fingerprint, and the fingerprint turning into the
/// tick.
class _CheckInPicture extends StatelessWidget {
  const _CheckInPicture({
    required this.letters,
    required this.flow,
    required this.print,
    required this.read,
    required this.tick,
    required this.ripple,
    required this.shine,
  });

  /// One 0 → 1 (a little past) per letter: its drop into its box.
  final List<double> letters;

  /// 0 → 1: the dots from the code down to the fingerprint.
  final double flow;

  /// 0 → 1 (a little past): the fingerprint popping in.
  final double print;

  /// 0 → 1: the light's one pass down the fingerprint.
  final double read;

  /// 0 → 1 (a little past): the fingerprint becoming the tick.
  final double tick;

  /// 0 → 1: a ring going out from the tick.
  final double ripple;

  /// 0 → 1: a light passing over the finished picture.
  final double shine;

  static const double _size = 118;
  static const double _gap = 4;
  static const double _boxHeight = 22;
  static const double _disc = 50;
  static const double _discTop = 62;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final boxWidth = (_size - _gap * (letters.length - 1)) / letters.length;
    const centre = Offset(_size / 2, _discTop + _disc / 2);
    final done = tick.clamp(0.0, 1.0);

    return SizedBox.square(
      dimension: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final (i, t) in letters.indexed)
            Positioned(
              left: i * (boxWidth + _gap),
              top: 4,
              width: boxWidth,
              height: _boxHeight,
              child: _CodeBox(letter: CheckInSplash.sampleCode[i], landed: t),
            ),
          // The dots and the ripple, behind the fingerprint.
          Positioned.fill(
            child: CustomPaint(
              painter: _FlowPainter(
                flow: flow,
                ripple: ripple,
                centre: centre,
                disc: _disc,
                from: 4 + _boxHeight,
                color: colors.accent,
              ),
            ),
          ),
          Positioned(
            left: centre.dx - _disc / 2,
            top: _discTop,
            width: _disc,
            height: _disc,
            child: Opacity(
              opacity: print.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.6 + 0.4 * print,
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.accentWash(0.12),
                          border: Border.all(color: colors.accentWash(0.45)),
                        ),
                      ),
                      // The one bright element: the brand fill, as the tick
                      // lands.
                      Opacity(
                        opacity: done,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppPalette.brandMark,
                          ),
                        ),
                      ),
                      Opacity(
                        opacity: 1 - done,
                        child: Icon(
                          Icons.fingerprint_rounded,
                          size: 32,
                          color: colors.accent,
                        ),
                      ),
                      if (read > 0 && read < 1)
                        Positioned(
                          left: 8,
                          right: 8,
                          top: 6 + (_disc - 14) * read,
                          height: 2,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colors.accentSoft.withValues(alpha: 0),
                                  colors.accentSoft,
                                  colors.accentSoft.withValues(alpha: 0),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.accentWash(0.6),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      Transform.scale(
                        scale: tick,
                        // The brand fill is the same cyan in both themes,
                        // so the ink on it is the dark set's in both.
                        child: Icon(
                          Icons.check_rounded,
                          size: 30,
                          color: AppPalette.dark.onAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ShinePainter(
                  shine: shine,
                  glint: colors.accentSoft.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One box of the code, with its letter dropping in and the box lighting up
/// as it lands.
class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.letter, required this.landed});

  final String letter;
  final double landed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lit = landed.clamp(0.0, 1.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: Color.lerp(colors.borderStrong, colors.accentWash(0.6), lit)!,
        ),
      ),
      child: Center(
        child: Opacity(
          opacity: lit,
          child: Transform.translate(
            offset: Offset(0, -10 * (1 - landed)),
            child: Text(
              letter,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three dots leading down from the code to the fingerprint, each arriving
/// in turn, and the ripple going out from the tick.
class _FlowPainter extends CustomPainter {
  const _FlowPainter({
    required this.flow,
    required this.ripple,
    required this.centre,
    required this.disc,
    required this.from,
    required this.color,
  });

  final double flow;
  final double ripple;
  final Offset centre;
  final double disc;

  /// Where the dots start: the foot of the code's boxes.
  final double from;
  final Color color;

  static const int _dots = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final to = centre.dy - disc / 2;
    final step = (to - from) / (_dots + 1);
    for (var i = 0; i < _dots; i++) {
      final t = ((flow * _dots) - i).clamp(0.0, 1.0);
      if (t == 0) continue;
      canvas.drawCircle(
        Offset(centre.dx, from + step * (i + 1)),
        2.2 * t,
        Paint()..color = color.withValues(alpha: 0.65 * t),
      );
    }

    if (ripple <= 0 || ripple >= 1) return;
    canvas.drawCircle(
      centre,
      disc / 2 + 16 * ripple,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * (1 - ripple)
        ..color = color.withValues(alpha: 0.5 * (1 - ripple)),
    );
  }

  @override
  bool shouldRepaint(_FlowPainter old) =>
      old.flow != flow ||
      old.ripple != ripple ||
      old.centre != centre ||
      old.disc != disc ||
      old.from != from ||
      old.color != color;
}

/// The light passing over the finished picture, as on the other splashes.
class _ShinePainter extends CustomPainter {
  const _ShinePainter({required this.shine, required this.glint});

  final double shine;
  final Color glint;

  @override
  void paint(Canvas canvas, Size size) =>
      paintSplashShine(canvas, size, shine, glint);

  @override
  bool shouldRepaint(_ShinePainter old) =>
      old.shine != shine || old.glint != glint;
}
