import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import 'widgets/splash_parts.dart';

/// The tracker, behind its opening splash.
class TrackerIntro extends StatelessWidget {
  const TrackerIntro({super.key, required this.page});

  final WidgetBuilder page;

  @override
  Widget build(BuildContext context) => SplashThen(
    splash: (onFinished) => TrackerSplash(onFinished: onFinished),
    page: page,
  );
}

/// A month on a calendar: the top bar drops in, the days appear in a wave
/// from the top-left, then the days present are checked off one after
/// another — one of them amber, for a late — and a glint passes over the
/// finished page. The generator's splash in shape, so the two student halves
/// read as one family.
class TrackerSplash extends StatefulWidget {
  const TrackerSplash({super.key, required this.onFinished});

  /// Called once, when the splash has played.
  final VoidCallback onFinished;

  /// The same pace as the generator's.
  static const SplashTimeline timeline = SplashTimeline(
    play: Duration(milliseconds: 2300),
    hold: Duration(milliseconds: 400),
  );

  static const List<SplashStep> steps = [
    (icon: Icons.pin_outlined, label: TrackerStrings.stepNumber),
    (icon: Icons.search_rounded, label: TrackerStrings.stepSearch),
    (icon: Icons.event_available_outlined, label: TrackerStrings.stepDays),
  ];

  @override
  State<TrackerSplash> createState() => _TrackerSplashState();
}

class _TrackerSplashState extends State<TrackerSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TrackerSplash.timeline.total,
  )..addStatusListener(_onStatus);

  late final Animation<double> _tile = _slice(0.00, 0.28, Curves.easeOutBack);
  late final Animation<double> _bar = _slice(0.08, 0.30, Curves.easeOutBack);
  late final Animation<double> _days = _slice(0.15, 0.48, Curves.linear);
  late final Animation<double> _ticks = _slice(0.36, 0.72, Curves.linear);
  late final Animation<double> _shine = _slice(0.62, 0.82, Curves.easeInOut);
  late final Animation<double> _title = _slice(0.30, 0.60, Curves.easeOutCubic);
  late final List<Animation<double>> _steps = [
    _slice(0.50, 0.70, Curves.easeOutCubic),
    _slice(0.56, 0.76, Curves.easeOutCubic),
    _slice(0.62, 0.82, Curves.easeOutCubic),
  ];

  Animation<double> _slice(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _controller,
        curve: TrackerSplash.timeline.interval(begin, end, curve),
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
        label: TrackerStrings.splashSemantics,
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
                          painter: _CalendarPainter(
                            bar: _bar.value,
                            days: _days.value,
                            ticks: _ticks.value,
                            shine: _shine.value,
                            accent: colors.accent,
                            late: colors.warning,
                            day: colors.textPrimary.withValues(alpha: 0.10),
                            ring: colors.textPrimary,
                            check: colors.onAccent,
                            glint: colors.accentSoft.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      splashRise(
                        _title.value,
                        const SplashWordmark(
                          tagline: TrackerStrings.splashTagline,
                        ),
                      ),
                      const SizedBox(height: 30),
                      SplashSteps(
                        steps: TrackerSplash.steps,
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

/// Draws the calendar part-built: the top bar scaled by [bar], each day
/// popping in as the diagonal [days] wave reaches it, the present days
/// checked in turn as [ticks] runs, and a [shine] corner to corner.
class _CalendarPainter extends CustomPainter {
  const _CalendarPainter({
    required this.bar,
    required this.days,
    required this.ticks,
    required this.shine,
    required this.accent,
    required this.late,
    required this.day,
    required this.ring,
    required this.check,
    required this.glint,
  });

  final double bar;
  final double days;
  final double ticks;
  final double shine;
  final Color accent;
  final Color late;
  final Color day;
  final Color ring;
  final Color check;
  final Color glint;

  static const int _cols = 5;
  static const int _rows = 4;
  static const double _gap = 5;
  static const double _barHeight = 22;
  static const double _gridTop = 34;

  /// The days checked off, in the order they are ticked, and the late one.
  static const List<int> _present = [0, 1, 3, 5, 6, 8, 10, 11, 13, 15, 16, 18];
  static const int _lateDay = 8;

  /// How much of its wave each piece takes to pop in; the rest is its delay.
  static const double _pop = 0.3;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final cellW = (w - _gap * (_cols - 1)) / _cols;
    final cellH = (size.height - _gridTop - _gap * (_rows - 1)) / _rows;

    Rect cell(int i) {
      final r = i ~/ _cols;
      final c = i % _cols;
      return Rect.fromLTWH(
        c * (cellW + _gap),
        _gridTop + r * (cellH + _gap),
        cellW,
        cellH,
      );
    }

    // The days.
    if (days > 0) {
      final paint = Paint()..color = day;
      for (var i = 0; i < _rows * _cols; i++) {
        final r = i ~/ _cols;
        final c = i % _cols;
        final delay = (r + c) / (_rows + _cols - 2) * (1 - _pop);
        final t = ((days - delay) / _pop).clamp(0.0, 1.0);
        if (t == 0) continue;
        final rect = cell(i);
        final s = Curves.easeOutBack.transform(t);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: rect.center,
              width: rect.width * s,
              height: rect.height * s,
            ),
            const Radius.circular(5),
          ),
          paint,
        );
      }
    }

    // The checks, one after another.
    if (ticks > 0) {
      final n = _present.length;
      for (var k = 0; k < n; k++) {
        final delay = k / (n - 1) * (1 - _pop);
        final t = ((ticks - delay) / _pop).clamp(0.0, 1.0);
        if (t == 0) continue;
        final index = _present[k];
        final rect = cell(index);
        final radius =
            rect.shortestSide * 0.46 * Curves.easeOutBack.transform(t);
        canvas.drawCircle(
          rect.center,
          radius,
          Paint()..color = index == _lateDay ? late : accent,
        );
        _drawCheck(canvas, rect, ((t - 0.35) / 0.65).clamp(0.0, 1.0));
      }
    }

    // The top bar and its two binder rings.
    if (bar > 0) {
      final top = Rect.fromLTWH(0, 6, w, _barHeight);
      canvas
        ..save()
        ..translate(top.center.dx, top.center.dy)
        ..scale(bar)
        ..translate(-top.center.dx, -top.center.dy)
        ..drawRRect(
          RRect.fromRectAndRadius(top, const Radius.circular(7)),
          Paint()..color = accent,
        );
      final ringPaint = Paint()..color = ring;
      for (final x in [w * 0.28, w * 0.72]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, 6), width: 6, height: 14),
            const Radius.circular(3),
          ),
          ringPaint,
        );
      }
      canvas.restore();
    }

    paintSplashShine(canvas, size, shine, glint);
  }

  /// A check mark inside [rect], drawn [t] of the way along its stroke.
  void _drawCheck(Canvas canvas, Rect rect, double t) {
    if (t <= 0) return;
    final s = rect.shortestSide;
    final a = rect.center + Offset(-s * 0.22, 0);
    final b = rect.center + Offset(-s * 0.06, s * 0.16);
    final c = rect.center + Offset(s * 0.24, -s * 0.18);
    final first = (a - b).distance;
    final total = first + (c - b).distance;
    final drawn = total * t;

    final path = Path()..moveTo(a.dx, a.dy);
    if (drawn <= first) {
      final p = Offset.lerp(a, b, drawn / first)!;
      path.lineTo(p.dx, p.dy);
    } else {
      final p = Offset.lerp(b, c, (drawn - first) / (total - first))!;
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
  bool shouldRepaint(_CalendarPainter old) =>
      old.bar != bar ||
      old.days != days ||
      old.ticks != ticks ||
      old.shine != shine ||
      old.accent != accent ||
      old.late != late ||
      old.day != day ||
      old.ring != ring ||
      old.check != check ||
      old.glint != glint;
}
