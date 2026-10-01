import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/qr_payload.dart';
import '../../models/student_record.dart';
import '../scanner/widgets/scan_result_card.dart' show StudentAvatar;

/// Which face of the card is toward the student.
enum CardSide { front, back }

/// The student's QR code as a card they can turn in their hand — GoTyme's 3D
/// card, standing up like an ID: the student on the front (photo, name,
/// number, course) and the code on the back. Picked on 2026-10-01.
///
/// Drag sideways to turn it; let go and it settles on the nearer face, or
/// the next one with a flick. A tap flips it, and so does [side] — Home's
/// Card / QR code switch — which the card also sets once it settles.
///
/// No 3D engine: each face, and the slices that make the card's edge, is a
/// flat widget under a perspective transform. Every movement is a drag or one
/// eased turn that settles, so nothing moves while the card is left alone —
/// the swing into place when it first shows included.
///
/// For looking at. The scanner reads the flat code on Show to scanner; a
/// tilted one reads badly.
class StudentCard3D extends StatefulWidget {
  const StudentCard3D({
    super.key,
    required this.record,
    required this.payload,
    required this.side,
    this.photo,
    this.photoUrl,
  });

  final StudentRecord record;

  /// The code on the back, in the colours the server issued it in.
  final QrPayload payload;

  /// The face to show, from outside; set by the card when it settles.
  final ValueNotifier<CardSide> side;

  /// The student's photo — the bytes kept on the phone first, so it shows
  /// offline; initials without either.
  final Uint8List? photo;
  final String? photoUrl;

  /// The card, as drawn: a little over an ID card's proportions, upright.
  static const Size size = Size(228, 362);

  @override
  State<StudentCard3D> createState() => _StudentCard3DState();
}

class _StudentCard3DState extends State<StudentCard3D>
    with SingleTickerProviderStateMixin {
  /// Half the card's thickness, and the step between the slices that draw
  /// its edge.
  static const double _half = 3.5;
  static const double _sliceStep = 1;

  /// How far the eye is: larger turns read as nearer.
  static const double _perspective = 0.0012;

  /// Made in initState, not lazily, like every controller a screen owns.
  late final AnimationController _turn;

  /// The card's turn about its upright axis and its tilt, in degrees.
  double _ry = 0;
  double _rx = 0;

  // The ease in progress: from where, to where.
  double _fromRy = 0;
  double _fromRx = 0;
  double _toRy = 0;

  // The drag in progress.
  double _dragRy = 0;
  double _dragRx = 0;
  Offset _dragStart = Offset.zero;

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// The face toward the student at [ry] degrees.
  static CardSide _sideAt(double ry) =>
      math.cos(ry * math.pi / 180) >= 0 ? CardSide.front : CardSide.back;

  @override
  void initState() {
    super.initState();
    _turn =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 750),
          )
          ..addListener(_onTurn)
          ..addStatusListener(_onTurnStatus);
    widget.side.addListener(_onSide);
    _ry = _toRy = widget.side.value == CardSide.front ? 0 : 180;
    // Swings into place the first time it shows.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _still) return;
      setState(() {
        _ry -= 32;
        _rx = 10;
      });
      _settle(_toRy, duration: const Duration(milliseconds: 900));
    });
  }

  @override
  void didUpdateWidget(StudentCard3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.side != widget.side) {
      oldWidget.side.removeListener(_onSide);
      widget.side.addListener(_onSide);
    }
  }

  @override
  void dispose() {
    widget.side.removeListener(_onSide);
    _turn.dispose();
    super.dispose();
  }

  void _onTurn() {
    final t = Curves.easeOutBack.transform(_turn.value);
    setState(() {
      _ry = _fromRy + (_toRy - _fromRy) * t;
      _rx = _fromRx * (1 - t);
    });
  }

  /// Settled: tell the switch which face is up.
  void _onTurnStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final side = _sideAt(_toRy);
    if (widget.side.value != side) widget.side.value = side;
  }

  /// The switch asked for a face the card is not turning to.
  void _onSide() {
    if (_sideAt(_toRy) == widget.side.value) return;
    _settle(_toRy + 180);
  }

  /// Turns to [ry] — always a whole face — and lies flat.
  void _settle(double ry, {Duration? duration}) {
    final turnsFace = _sideAt(ry) != _sideAt(_toRy);
    _fromRy = _ry;
    _fromRx = _rx;
    _toRy = ry;
    if (turnsFace) HapticFeedback.selectionClick();
    if (_still) {
      _turn.value = 1;
      _onTurn();
      _onTurnStatus(AnimationStatus.completed);
      return;
    }
    _turn
      ..duration = duration ?? const Duration(milliseconds: 750)
      ..forward(from: 0);
  }

  /// The nearest whole face to [ry].
  static double _nearest(double ry) => (ry / 180).roundToDouble() * 180;

  void _flip() => _settle(_nearest(_toRy) + 180);

  void _onDragStart(DragStartDetails details) {
    _turn.stop();
    _dragRy = _ry;
    _dragRx = _rx;
    _dragStart = details.globalPosition;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final moved = details.globalPosition - _dragStart;
    setState(() {
      _ry = _dragRy + moved.dx * 0.6;
      _rx = (_dragRx - moved.dy * 0.35).clamp(-28.0, 28.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final flick = details.primaryVelocity ?? 0;
    // A flick turns to the next face in its direction; a slow drag lands
    // on whichever is nearer.
    final target = flick.abs() > 700
        ? (flick > 0
              ? (_ry / 180).floorToDouble() * 180 + 180
              : (_ry / 180).ceilToDouble() * 180 - 180)
        : _nearest(_ry);
    _settle(target);
  }

  Matrix4 _at(double z, {bool turnedOver = false}) {
    final m = Matrix4.identity()
      ..setEntry(3, 2, _perspective)
      ..rotateX(_rx * math.pi / 180)
      ..rotateY(_ry * math.pi / 180)
      ..translateByDouble(0, 0, z, 1);
    if (turnedOver) m.rotateY(math.pi);
    return m;
  }

  @override
  Widget build(BuildContext context) {
    const size = StudentCard3D.size;
    final side = _sideAt(_ry);
    final angle = _ry * math.pi / 180;
    final facing = math.cos(angle).abs();
    // How far from straight on, -1..1, for the light across the face.
    final glance = math.sin(angle) * (side == CardSide.front ? 1 : -1);

    return Semantics(
      button: true,
      label: side == CardSide.front
          ? StudentStrings.cardFrontSemantics(
              widget.record.fullName,
              widget.record.studentNumber.value,
            )
          : StudentStrings.cardBackSemantics,
      onTap: _flip,
      child: ExcludeSemantics(
        child: GestureDetector(
          key: const ValueKey('studentCard'),
          behavior: HitTestBehavior.opaque,
          onTap: _flip,
          // Sideways only: an up-and-down drag on the card scrolls Home.
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: SizedBox(
            height: size.height + 44,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // The shadow, narrowing as the card turns edge-on.
                Positioned(
                  bottom: 10,
                  child: Opacity(
                    opacity: 0.55 + 0.45 * facing,
                    child: Transform.scale(
                      scaleX: 0.45 + 0.55 * facing,
                      child: Container(
                        width: size.width * 0.82,
                        height: 16,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.all(
                            Radius.elliptical(94, 8),
                          ),
                          // A shadow reads on both grounds only as black.
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF000000).withValues(
                                alpha: context.colors.isDark ? 0.55 : 0.22,
                              ),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  child: SizedBox.fromSize(
                    size: size,
                    child: Stack(
                      children: [
                        // The edge: thin slices of the card between its two
                        // faces, seen when it turns.
                        for (
                          var z = -_half + _sliceStep;
                          z < _half;
                          z += _sliceStep
                        )
                          Positioned.fill(
                            child: Transform(
                              alignment: Alignment.center,
                              transform: _at(z),
                              child: const DecoratedBox(
                                decoration: BoxDecoration(
                                  color: _CardInk.edge,
                                  borderRadius: _CardInk.radius,
                                ),
                              ),
                            ),
                          ),
                        // The face toward the student, on its side of the
                        // card — drawn last, over the edge.
                        Positioned.fill(
                          child: Transform(
                            alignment: Alignment.center,
                            transform: side == CardSide.front
                                ? _at(-_half)
                                : _at(_half, turnedOver: true),
                            // At the card's own size, whatever the phone's
                            // text size: it is a drawn object, like the QR
                            // card, and its words are in the label above
                            // for a screen reader.
                            child: MediaQuery.withNoTextScaling(
                              child: side == CardSide.front
                                  ? _Front(
                                      record: widget.record,
                                      photo: widget.photo,
                                      photoUrl: widget.photoUrl,
                                      glance: glance,
                                    )
                                  : _Back(
                                      record: widget.record,
                                      payload: widget.payload,
                                      glance: glance,
                                    ),
                            ),
                          ),
                        ),
                      ],
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

/// The card's own colours. Always dark, in both themes: like the QR it
/// carries, the card is the same object whichever theme the phone is in.
abstract final class _CardInk {
  static const AppPalette ink = AppPalette.dark;
  static const Color edge = Color(0xFF0B3346);
  static const Color rim = Color(0x4767E3FF);
  static const BorderRadius radius = BorderRadius.all(Radius.circular(20));
  static const LinearGradient ground = LinearGradient(
    begin: Alignment(-0.6, -1),
    end: Alignment(0.6, 1),
    colors: [Color(0xFF12324A), Color(0xFF0D1B27), Color(0xFF0A0D12)],
    stops: [0, 0.5, 1],
  );
}

/// The band of light across a face, sliding over as the card turns.
class _Shine extends StatelessWidget {
  const _Shine({required this.glance, this.strength = 0.16});

  /// -1..1, how far the card is turned from straight on.
  final double glance;
  final double strength;

  @override
  Widget build(BuildContext context) {
    final at = (0.5 - glance * 0.9).clamp(-0.4, 1.4);
    final light = Color.fromRGBO(255, 255, 255, strength);
    const clear = Color(0x00FFFFFF);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [clear, light, clear],
            stops: [
              (at - 0.18).clamp(0.0, 1.0),
              at.clamp(0.0, 1.0),
              (at + 0.18).clamp(0.0, 1.0),
            ],
          ),
        ),
      ),
    );
  }
}

/// The student: the school's mark, their photo, name, number and course.
class _Front extends StatelessWidget {
  const _Front({
    required this.record,
    required this.photo,
    required this.photoUrl,
    required this.glance,
  });

  final StudentRecord record;
  final Uint8List? photo;
  final String? photoUrl;
  final double glance;

  @override
  Widget build(BuildContext context) {
    const ink = _CardInk.ink;

    return Container(
      decoration: BoxDecoration(
        gradient: _CardInk.ground,
        borderRadius: _CardInk.radius,
        border: Border.all(color: _CardInk.rim),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // A glow in the top corner.
          Positioned(
            right: -80,
            top: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    ink.accent.withValues(alpha: 0.32),
                    ink.accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 4,
              decoration: const BoxDecoration(gradient: AppPalette.brandMark),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: AppPalette.brandMark,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(
                        Icons.qr_code_2_rounded,
                        size: 16,
                        color: ink.onAccent,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: AppStrings.splashBrand,
                          children: [
                            TextSpan(
                              text: AppStrings.splashBrandAccent,
                              style: TextStyle(color: ink.accent),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: ink.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: ink.accent.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        StudentStrings.cardStudent,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: ink.accentSoft,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                _Photo(name: record.fullName, photo: photo, url: photoUrl),
                const SizedBox(height: 14),
                Text(
                  record.fullName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: ink.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  record.studentNumber.value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                    color: ink.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final part in [record.course, record.section])
                      if (part.trim().isNotEmpty) _Chip(label: part.trim()),
                  ],
                ),
                const Spacer(),
                Container(
                  height: 1,
                  color: ink.accentSoft.withValues(alpha: 0.18),
                ),
                const SizedBox(height: 9),
                Text(
                  AppStrings.splashFooter,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9.5,
                    letterSpacing: 0.3,
                    color: ink.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(child: _Shine(glance: glance)),
        ],
      ),
    );
  }
}

/// The face on the front: the photo kept on the phone, then the one on the
/// server, then initials — in an accent ring, as on Home.
class _Photo extends StatelessWidget {
  const _Photo({required this.name, required this.photo, required this.url});

  final String name;
  final Uint8List? photo;
  final String? url;

  static const double _size = 92;

  @override
  Widget build(BuildContext context) {
    const ink = _CardInk.ink;
    final initials = Center(
      child: Text(
        StudentAvatar.initialsOf(name),
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: ink.accentSoft,
        ),
      ),
    );
    final bytes = photo;
    final url = this.url;

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ink.accentWash(0.14),
        border: Border.all(color: ink.accentWash(0.6), width: 3),
        boxShadow: [BoxShadow(color: ink.accentWash(0.08), spreadRadius: 6)],
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes != null
          ? Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => initials,
            )
          : url != null
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => initials,
            )
          : initials,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    const ink = _CardInk.ink;

    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: ink.accentWash(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: ink.accentSoft,
        ),
      ),
    );
  }
}

/// The code, on the colours the server issued it in, with whose it is.
class _Back extends StatelessWidget {
  const _Back({
    required this.record,
    required this.payload,
    required this.glance,
  });

  final StudentRecord record;
  final QrPayload payload;
  final double glance;

  @override
  Widget build(BuildContext context) {
    const ink = _CardInk.ink;
    final spec = payload.spec;
    final details = [
      record.fullName,
      [
        record.course,
        record.section,
      ].where((p) => p.trim().isNotEmpty).join(' '),
    ].where((p) => p.trim().isNotEmpty).join(' · ');

    return Container(
      decoration: BoxDecoration(
        // The code's own background, so there is no seam round it.
        color: spec.background,
        borderRadius: _CardInk.radius,
        border: Border.all(color: _CardInk.rim),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
            child: Column(
              children: [
                Text(
                  StudentStrings.cardScan,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: ink.accentSoft,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 192,
                  height: 192,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: spec.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: spec.foreground.withValues(alpha: 0.35),
                    ),
                  ),
                  child: QrImageView(
                    data: payload.encode(),
                    version: QrVersions.auto,
                    padding: EdgeInsets.zero,
                    backgroundColor: spec.background,
                    eyeStyle: QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: spec.foreground,
                    ),
                    dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: spec.foreground,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  record.studentNumber.value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: ink.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  details,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: ink.textSecondary),
                ),
              ],
            ),
          ),
          Positioned.fill(child: _Shine(glance: glance, strength: 0.12)),
        ],
      ),
    );
  }
}
