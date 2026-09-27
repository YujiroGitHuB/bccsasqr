import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import 'widgets/splash_parts.dart';

/// Plays once "I'm a student" is picked, before the student's home screen: a
/// student card builds itself — the college's band across the top, the
/// photo, the name — then the QR in its corner dot by dot and three days
/// ticked off beside it, and a glint passes over the finished card. The two
/// things the student side is for, on one card.
///
/// The generator's and the tracker's splashes in shape and pace, so the
/// student side reads as one family — and the instructor's pick has the
/// scanner's splash.
class StudentSplash extends StatefulWidget {
  const StudentSplash({super.key, required this.onFinished});

  /// Called once, when the splash has played.
  final VoidCallback onFinished;

  static const SplashTimeline timeline = SplashTimeline(
    play: Duration(milliseconds: 2300),
    hold: Duration(milliseconds: 400),
  );

  static const List<SplashStep> steps = [
    (icon: Icons.qr_code_2_rounded, label: AppStrings.studentStepSave),
    (icon: Icons.qr_code_scanner_rounded, label: AppStrings.studentStepScan),
    (icon: Icons.event_available_outlined, label: AppStrings.studentStepCheck),
  ];

  @override
  State<StudentSplash> createState() => _StudentSplashState();
}

class _StudentSplashState extends State<StudentSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: StudentSplash.timeline.total,
  )..addStatusListener(_onStatus);

  late final Animation<double> _tile = _slice(0.00, 0.28, Curves.easeOutBack);
  late final Animation<double> _band = _slice(0.08, 0.30, Curves.easeOutBack);
  late final Animation<double> _photo = _slice(0.14, 0.36, Curves.easeOutBack);
  late final Animation<double> _lines = _slice(0.22, 0.44, Curves.easeOut);
  late final Animation<double> _code = _slice(0.30, 0.60, Curves.linear);
  late final Animation<double> _ticks = _slice(0.44, 0.70, Curves.linear);
  late final Animation<double> _shine = _slice(0.62, 0.82, Curves.easeInOut);
  late final Animation<double> _title = _slice(0.30, 0.60, Curves.easeOutCubic);
  late final List<Animation<double>> _steps = [
    _slice(0.50, 0.70, Curves.easeOutCubic),
    _slice(0.56, 0.76, Curves.easeOutCubic),
    _slice(0.62, 0.82, Curves.easeOutCubic),
  ];

  /// "BCC SASQR" as a real QR, so the dots land where a code's would.
  late final QrImage _qr = QrImage(
    QrCode.fromData(
      data: AppStrings.appName,
      errorCorrectLevel: QrErrorCorrectLevel.L,
    ),
  );

  Animation<double> _slice(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _controller,
        curve: StudentSplash.timeline.interval(begin, end, curve),
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
        label: AppStrings.studentSplashSemantics,
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
                          painter: _StudentCardPainter(
                            qr: _qr,
                            band: _band.value,
                            photo: _photo.value,
                            lines: _lines.value,
                            code: _code.value,
                            ticks: _ticks.value,
                            shine: _shine.value,
                            accent: colors.accent,
                            onAccent: colors.onAccent,
                            ink: colors.textPrimary,
                            glint: colors.accentSoft.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      splashRise(
                        _title.value,
                        const SplashWordmark(
                          tagline: AppStrings.studentSplashTagline,
                        ),
                      ),
                      const SizedBox(height: 30),
                      SplashSteps(
                        steps: StudentSplash.steps,
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

/// Draws the student card part-built: the band scaled out from the middle by
/// [band], the photo popping in by [photo], the name lines drawn across by
/// [lines], the QR's dots arriving in a wave by [code], the three days
/// ticked in turn by [ticks], and a [shine] corner to corner.
class _StudentCardPainter extends CustomPainter {
  const _StudentCardPainter({
    required this.qr,
    required this.band,
    required this.photo,
    required this.lines,
    required this.code,
    required this.ticks,
    required this.shine,
    required this.accent,
    required this.onAccent,
    required this.ink,
    required this.glint,
  });

  final QrImage qr;
  final double band;
  final double photo;
  final double lines;
  final double code;
  final double ticks;
  final double shine;
  final Color accent;
  final Color onAccent;
  final Color ink;
  final Color glint;

  /// How much of its wave each dot takes to pop in; the rest is its delay.
  static const double _pop = 0.3;

  static const int _days = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _paintBand(canvas, w, h);
    _paintPhoto(canvas, w, h);
    _paintLines(canvas, w, h);
    _paintDays(canvas, w, h);
    _paintCode(canvas, w, h);
    paintSplashShine(canvas, size, shine, glint);
  }

  /// Scales [draw] about [centre] by [t], the way each piece pops in.
  void _scaled(Canvas canvas, Offset centre, double t, VoidCallback draw) {
    if (t <= 0) return;
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..scale(t)
      ..translate(-centre.dx, -centre.dy);
    draw();
    canvas.restore();
  }

  void _paintBand(Canvas canvas, double w, double h) {
    if (band <= 0) return;
    final bandH = h * 0.18;
    canvas
      ..save()
      ..translate(w / 2, 0)
      ..scale(band, 1)
      ..translate(-w / 2, 0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, bandH),
        const Radius.circular(6),
      ),
      Paint()..color = accent,
    );
    // The college's name, as a line of ink on the band.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.07, bandH * 0.38, w * 0.42, bandH * 0.24),
        Radius.circular(bandH * 0.12),
      ),
      Paint()..color = onAccent.withValues(alpha: 0.75),
    );
    canvas.restore();
  }

  void _paintPhoto(Canvas canvas, double w, double h) {
    final centre = Offset(w * 0.19, h * 0.42);
    final r = w * 0.13;
    _scaled(canvas, centre, photo, () {
      canvas.drawCircle(
        centre,
        r,
        Paint()..color = ink.withValues(alpha: 0.10),
      );
      // A head and shoulders, cut to the circle.
      canvas
        ..save()
        ..clipPath(Path()..addOval(Rect.fromCircle(center: centre, radius: r)));
      final figure = Paint()..color = ink.withValues(alpha: 0.40);
      canvas
        ..drawCircle(centre.translate(0, -r * 0.22), r * 0.36, figure)
        ..drawOval(
          Rect.fromCenter(
            center: centre.translate(0, r * 0.78),
            width: r * 1.5,
            height: r * 1.1,
          ),
          figure,
        )
        ..restore();
    });
  }

  void _paintLines(Canvas canvas, double w, double h) {
    if (lines <= 0) return;
    final left = w * 0.40;
    final lineH = h * 0.06;
    final paint = Paint()..color = ink.withValues(alpha: 0.18);
    // The name, then the student number under it, each drawn left to right.
    for (final (i, (top, length)) in [
      (h * 0.31, w * 0.56),
      (h * 0.44, w * 0.38),
    ].indexed) {
      final t = ((lines - i * 0.35) / 0.65).clamp(0.0, 1.0);
      if (t == 0) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, length * t, lineH),
          Radius.circular(lineH / 2),
        ),
        paint,
      );
    }
  }

  /// Three days in a row, ticked off one after another — My Attendance.
  void _paintDays(Canvas canvas, double w, double h) {
    final d = h * 0.15;
    final gap = w * 0.035;
    final top = h * 0.74;
    for (var i = 0; i < _days; i++) {
      final rect = Rect.fromLTWH(i * (d + gap), top, d, d);
      final box = RRect.fromRectAndRadius(rect, Radius.circular(d * 0.26));
      canvas.drawRRect(box, Paint()..color = ink.withValues(alpha: 0.10));

      final t = (ticks * _days - i).clamp(0.0, 1.0);
      if (t == 0) continue;
      canvas.drawRRect(box, Paint()..color = accent.withValues(alpha: t));
      final tick = Path()
        ..moveTo(rect.left + d * 0.26, rect.top + d * 0.52)
        ..lineTo(rect.left + d * 0.43, rect.top + d * 0.69)
        ..lineTo(rect.left + d * 0.76, rect.top + d * 0.33);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = d * 0.13
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = onAccent;
      for (final PathMetric m in tick.computeMetrics()) {
        canvas.drawPath(m.extractPath(0, m.length * t), stroke);
      }
    }
  }

  /// The QR in the corner — My QR Code — eyes first, then the dots in a
  /// wave from the top-left.
  void _paintCode(Canvas canvas, double w, double h) {
    if (code <= 0) return;
    final n = qr.moduleCount;
    final side = h * 0.40;
    final origin = Offset(w - side, h - side);
    final cell = side / n;

    bool inEye(int r, int c) =>
        (r < 7 && c < 7) || (r < 7 && c >= n - 7) || (r >= n - 7 && c < 7);

    final dot = Paint()..color = ink;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (inEye(r, c) || !qr.isDark(r, c)) continue;
        final delay = (r + c) / (2 * (n - 1)) * (1 - _pop);
        final t = ((code - delay) / _pop).clamp(0.0, 1.0);
        if (t == 0) continue;
        canvas.drawCircle(
          origin + Offset((c + 0.5) * cell, (r + 0.5) * cell),
          cell * 0.45 * Curves.easeOutBack.transform(t),
          dot,
        );
      }
    }

    final eyes = Curves.easeOutBack.transform((code / 0.35).clamp(0.0, 1.0));
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell
      ..color = accent;
    final pupil = Paint()..color = accent;
    for (final (row, col) in [(0, 0), (0, n - 7), (n - 7, 0)]) {
      final at = origin + Offset(col * cell, row * cell);
      _scaled(canvas, at + Offset(3.5 * cell, 3.5 * cell), eyes, () {
        canvas
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                at.dx + 0.5 * cell,
                at.dy + 0.5 * cell,
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
                at.dx + 2 * cell,
                at.dy + 2 * cell,
                3 * cell,
                3 * cell,
              ),
              Radius.circular(cell * 0.8),
            ),
            pupil,
          );
      });
    }
  }

  @override
  bool shouldRepaint(_StudentCardPainter old) =>
      old.band != band ||
      old.photo != photo ||
      old.lines != lines ||
      old.code != code ||
      old.ticks != ticks ||
      old.shine != shine ||
      old.accent != accent ||
      old.onAccent != onAccent ||
      old.ink != ink ||
      old.glint != glint ||
      old.qr != qr;
}
