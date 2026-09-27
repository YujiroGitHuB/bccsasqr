import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter/widgets.dart';

/// The green the web scanner outlines a found code in (`drawDetectionBox()`
/// in Qrscanner/js/scriptV3.js). A literal rather than a theme colour: it is
/// drawn over the camera picture, which looks the same in either theme, and
/// an instructor who uses both scanners should see the same signal.
const Color scanGreen = Color(0xFF00FF88);

/// The square the scan frame's corners enclose inside a camera box of [size]
/// — the part of the picture the decoder reads.
Rect scanFrameBox(Size size, double fraction) {
  final side = size.shortestSide * fraction;
  return Rect.fromCenter(
    center: size.center(Offset.zero),
    width: side,
    height: side,
  );
}

/// The frame's four L-shaped corners around [box].
void paintFrameCorners(Canvas canvas, Rect box, Paint paint) {
  final arm = box.width * 0.14;
  for (final (point, dx, dy) in [
    (box.topLeft, 1.0, 1.0),
    (box.topRight, -1.0, 1.0),
    (box.bottomLeft, 1.0, -1.0),
    (box.bottomRight, -1.0, -1.0),
  ]) {
    canvas.drawPath(
      Path()
        ..moveTo(point.dx, point.dy + arm * dy)
        ..lineTo(point.dx, point.dy)
        ..lineTo(point.dx + arm * dx, point.dy),
      paint,
    );
  }
}

/// Where a code was seen: its four corners, in order around it, with (0, 0)
/// at the scan frame's top-left and (1, 1) at its bottom-right.
@immutable
class ScanQuad {
  const ScanQuad(this.corners);

  /// The whole frame — what lights up when a code is read but the decoder
  /// gave no position for it.
  static const ScanQuad frame = ScanQuad([
    Offset(0, 0),
    Offset(1, 0),
    Offset(1, 1),
    Offset(0, 1),
  ]);

  /// Top-left, top-right, bottom-right, bottom-left — the code's own, so a
  /// code held at an angle is outlined at that angle.
  final List<Offset> corners;

  Offset get center =>
      corners.reduce((a, b) => a + b) / corners.length.toDouble();

  /// The code's corners as the decoder reported them — pixels inside the
  /// square it read, which is [cropFraction] of the frame's short side — put
  /// the right way up for the screen and made relative to the scan frame.
  ///
  /// [rotation] is how far the picture is turned, clockwise, between the
  /// sensor and the screen ([displayRotation]). Returns null for anything
  /// that lands well outside the frame: a box drawn in the wrong place is
  /// worse than none.
  static ScanQuad? fromCrop({
    required int imageWidth,
    required int imageHeight,
    required double cropFraction,
    required List<Offset> points,
    required int rotation,
  }) {
    final crop = (math.min(imageWidth, imageHeight) * cropFraction).round();
    if (crop <= 0 || points.length != 4) return null;

    final corners = [
      for (final p in points)
        switch (rotation % 360) {
          90 => Offset(1 - p.dy / crop, p.dx / crop),
          180 => Offset(1 - p.dx / crop, 1 - p.dy / crop),
          270 => Offset(p.dy / crop, 1 - p.dx / crop),
          _ => Offset(p.dx / crop, p.dy / crop),
        },
    ];

    final sane = corners.every(
      (c) => c.dx > -0.25 && c.dx < 1.25 && c.dy > -0.25 && c.dy < 1.25,
    );
    return sane ? ScanQuad(corners) : null;
  }

  /// How far the back camera's picture is turned, clockwise, to show it the
  /// right way up: the sensor's own mounting, less the way the phone is held.
  /// A phone held upright with the usual 90° sensor turns it a quarter.
  static int displayRotation(int sensorOrientation, DeviceOrientation device) {
    final held = switch (device) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    return (sensorOrientation - held + 360) % 360;
  }

  static ScanQuad lerp(ScanQuad a, ScanQuad b, double t) => ScanQuad([
    for (var i = 0; i < 4; i++) Offset.lerp(a.corners[i], b.corners[i], t)!,
  ]);

  @override
  bool operator ==(Object other) =>
      other is ScanQuad &&
      other.corners[0] == corners[0] &&
      other.corners[1] == corners[1] &&
      other.corners[2] == corners[2] &&
      other.corners[3] == corners[3];

  @override
  int get hashCode => Object.hashAll(corners);
}

/// A read code, passed from the camera that saw it to the overlay that
/// outlines it — the same arrangement as the torch ([TorchScope]).
class ScanHighlightControl extends ChangeNotifier {
  ScanQuad? _quad;
  int _reads = 0;

  /// Where the latest code was; null until one is read.
  ScanQuad? get quad => _quad;

  /// Goes up by one per read, so a code held still — the same quad twice —
  /// still counts as seen again.
  int get reads => _reads;

  final ValueNotifier<bool> _locked = ValueNotifier(false);

  /// True while the highlight is up. The frame's own sweeping line steps
  /// aside for it, so the only line over a read code is the green one.
  ValueListenable<bool> get locked => _locked;

  /// Called by [ScanHighlight] as it appears and fades.
  void setLocked(bool value) => _locked.value = value;

  /// Called by the camera with every code it reads. [quad] is null when the
  /// decoder gave no position; the frame lights up instead.
  void show(ScanQuad? quad) {
    _quad = quad ?? ScanQuad.frame;
    _reads++;
    notifyListeners();
  }

  @override
  void dispose() {
    _locked.dispose();
    super.dispose();
  }
}

/// Hands a [ScanHighlightControl] down to whichever camera is built under
/// it, without widening the camera builder every test fakes.
class ScanHighlightScope extends InheritedWidget {
  const ScanHighlightScope({
    super.key,
    required this.control,
    required super.child,
  });

  final ScanHighlightControl control;

  static ScanHighlightControl? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ScanHighlightScope>()?.control;

  @override
  bool updateShouldNotify(ScanHighlightScope oldWidget) =>
      control != oldWidget.control;
}

/// The web scanner's green box, grown up: when a code is read, the frame's
/// corners turn green, an outline traces itself around the code with a
/// glow, corner marks and dots snap on, a green line passes over it once and
/// a ring ripples out from its centre. It follows the code while it stays in
/// view and fades once it has gone.
class ScanHighlight extends StatefulWidget {
  const ScanHighlight({
    super.key,
    required this.control,
    required this.fraction,
  });

  final ScanHighlightControl control;

  /// The scan frame's size, as for [scanFrameBox].
  final double fraction;

  /// How long after the last read the highlight stays up. The camera reads a
  /// code in view about every 0.7 s (a 600 ms pause after each success), so
  /// this bridges one read to the next without flickering.
  static const Duration linger = Duration(milliseconds: 900);

  @override
  State<ScanHighlight> createState() => _ScanHighlightState();
}

class _ScanHighlightState extends State<ScanHighlight>
    with TickerProviderStateMixin {
  /// The entrance: trace, marks, line, ripple.
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  /// On while a code is in view; fades the whole highlight out after.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );

  /// Glides the outline from where the code was to where it is now.
  late final AnimationController _move = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );

  ScanQuad _from = ScanQuad.frame;
  ScanQuad _to = ScanQuad.frame;
  Timer? _hide;
  int _seen = 0;

  bool get _still => MediaQuery.of(context).disableAnimations;

  ScanQuad get _quad =>
      ScanQuad.lerp(_from, _to, Curves.easeOutCubic.transform(_move.value));

  @override
  void initState() {
    super.initState();
    _seen = widget.control.reads;
    widget.control.addListener(_onRead);
  }

  @override
  void didUpdateWidget(ScanHighlight old) {
    super.didUpdateWidget(old);
    if (old.control != widget.control) {
      old.control.removeListener(_onRead);
      _seen = widget.control.reads;
      widget.control.addListener(_onRead);
    }
  }

  void _onRead() {
    final quad = widget.control.quad;
    if (quad == null || widget.control.reads == _seen) return;
    _seen = widget.control.reads;

    final showing =
        _fade.status == AnimationStatus.forward ||
        _fade.status == AnimationStatus.completed;

    if (!showing) {
      // A new lock: start from the top.
      _from = quad;
      _to = quad;
      _move.value = 1;
      widget.control.setLocked(true);
      if (_still) {
        _entry.value = 1;
        _fade.value = 1;
      } else {
        _entry.forward(from: 0);
        _fade.forward();
      }
    } else {
      // The same code, moved: follow it.
      _from = _quad;
      _to = quad;
      if (_still) {
        _move.value = 1;
      } else {
        _move.forward(from: 0);
      }
    }

    _hide?.cancel();
    _hide = Timer(ScanHighlight.linger, () {
      if (!mounted) return;
      widget.control.setLocked(false);
      if (_still) {
        _fade.value = 0;
      } else {
        _fade.reverse();
      }
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    widget.control.removeListener(_onRead);
    _entry.dispose();
    _fade.dispose();
    _move.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_entry, _fade, _move]),
      builder: (context, _) => _fade.value == 0
          ? const SizedBox.expand()
          : CustomPaint(
              size: Size.infinite,
              painter: _HighlightPainter(
                fraction: widget.fraction,
                quad: _quad,
                entry: _entry.value,
                opacity: _fade.value,
              ),
            ),
    );
  }
}

class _HighlightPainter extends CustomPainter {
  const _HighlightPainter({
    required this.fraction,
    required this.quad,
    required this.entry,
    required this.opacity,
  });

  final double fraction;
  final ScanQuad quad;
  final double entry;
  final double opacity;

  /// [entry] from [begin] to [end], eased.
  double _phase(double begin, double end, [Curve curve = Curves.easeOut]) =>
      curve.transform(((entry - begin) / (end - begin)).clamp(0.0, 1.0));

  Color _green(double alpha) =>
      scanGreen.withValues(alpha: (alpha * opacity).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final box = scanFrameBox(size, fraction);
    final pts = [
      for (final c in quad.corners)
        box.topLeft + Offset(c.dx * box.width, c.dy * box.height),
    ];
    final outline = Path()..addPolygon(pts, true);
    final edge =
        [
          for (var i = 0; i < 4; i++) (pts[(i + 1) % 4] - pts[i]).distance,
        ].reduce((a, b) => a + b) /
        4;

    // 1. The frame's corners go green: the scanner has locked on.
    paintFrameCorners(
      canvas,
      box,
      Paint()
        ..color = _green(_phase(0, 0.25))
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // 2. A green wash over the code, bright on arrival, settling faint.
    final flash = 1 - _phase(0.05, 0.6);
    canvas.drawPath(outline, Paint()..color = _green(0.08 + 0.22 * flash));

    // 3. The outline, tracing itself around the code, with a glow under it.
    final traced = _partial(outline, _phase(0, 0.45, Curves.easeOutCubic));
    canvas
      ..drawPath(
        traced,
        Paint()
          ..color = _green(0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      )
      ..drawPath(
        traced,
        Paint()
          ..color = _green(1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round,
      );

    // 4. Corner marks and dots, snapping on once the trace is round.
    final marks = _phase(0.35, 0.65, Curves.easeOutBack);
    if (marks > 0) {
      final arm = edge * 0.2 * marks;
      final mark = Paint()
        ..color = _green(1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final dot = Paint()..color = _green(1);
      for (var i = 0; i < 4; i++) {
        final p = pts[i];
        final toNext = _toward(p, pts[(i + 1) % 4], arm);
        final toPrev = _toward(p, pts[(i + 3) % 4], arm);
        canvas
          ..drawPath(
            Path()
              ..moveTo(toPrev.dx, toPrev.dy)
              ..lineTo(p.dx, p.dy)
              ..lineTo(toNext.dx, toNext.dy),
            mark,
          )
          ..drawCircle(p, 4.5 * marks.clamp(0.0, 1.2), dot);
      }
    }

    // 5. One green line passing over the code, top edge to bottom.
    final pass = _phase(0.25, 0.9, Curves.easeInOut);
    if (pass > 0 && pass < 1) {
      final a = Offset.lerp(pts[0], pts[3], pass)!;
      final b = Offset.lerp(pts[1], pts[2], pass)!;
      final strength = math.sin(math.pi * pass);
      final shader = LinearGradient(
        colors: [_green(0), _green(strength), _green(0)],
      ).createShader(Rect.fromPoints(a, b));
      canvas
        ..save()
        ..clipPath(outline)
        ..drawLine(
          a,
          b,
          Paint()
            ..shader = shader
            ..strokeWidth = 10
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        )
        ..drawLine(
          a,
          b,
          Paint()
            ..shader = shader
            ..strokeWidth = 2.5,
        )
        ..restore();
    }

    // 6. The centre: a dot, and a ring rippling out from it.
    final centre = pts.reduce((a, b) => a + b) / 4;
    canvas.drawCircle(
      centre,
      6 * marks.clamp(0.0, 1.2),
      Paint()..color = _green(1),
    );
    final ripple = _phase(0.3, 1.0, Curves.easeOutCubic);
    if (ripple > 0 && ripple < 1) {
      canvas.drawCircle(
        centre,
        10 + edge * 0.45 * ripple,
        Paint()
          ..color = _green(0.7 * (1 - ripple))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  /// [from] moved [length] along the line to [to].
  static Offset _toward(Offset from, Offset to, double length) {
    final d = to - from;
    final l = d.distance;
    return l == 0 ? from : from + d / l * length;
  }

  /// The first [t] of [path]'s length.
  static Path _partial(Path path, double t) {
    if (t >= 1) return path;
    final out = Path();
    if (t <= 0) return out;
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (sum, m) => sum + m.length);
    var left = total * t;
    for (final PathMetric m in metrics) {
      if (left <= 0) break;
      out.addPath(m.extractPath(0, math.min(left, m.length)), Offset.zero);
      left -= m.length;
    }
    return out;
  }

  @override
  bool shouldRepaint(_HighlightPainter old) =>
      old.quad != quad ||
      old.entry != entry ||
      old.opacity != opacity ||
      old.fraction != fraction;
}
