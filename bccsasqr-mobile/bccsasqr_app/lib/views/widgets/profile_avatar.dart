import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../scanner/widgets/scan_result_card.dart' show StudentAvatar;

/// The student's face in an accent ring — the home screen's corner and the
/// top of My Profile.
///
/// The ring draws itself round once, the first time it shows. While a photo
/// is being saved ([busy]) an arc chases round it — the one loop, and only for
/// as long as the upload takes. When a new photo lands, the face gives a
/// small pop.
///
/// With no [name] there is no profile yet: a dashed ring and a camera, asking
/// for one. With a name and no photo, the initials, as the scanner shows them.
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.size,
    this.name,
    this.photo,
    this.photoUrl,
    this.busy = false,
  });

  final double size;
  final String? name;

  /// Preferred over [photoUrl]: it shows with no internet.
  final Uint8List? photo;
  final String? photoUrl;
  final bool busy;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar>
    with TickerProviderStateMixin {
  // All three are made here, not lazily: a controller first touched in
  // dispose would look for its ticker in a tree already coming down.
  late final AnimationController _draw;
  late final AnimationController _spin;
  late final AnimationController _pop;

  late final Animation<double> _popScale = TweenSequence([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.07,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.07,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 60,
    ),
  ]).animate(_pop);

  @override
  void initState() {
    super.initState();
    _draw = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    if (widget.busy) _spin.repeat();
  }

  @override
  void didUpdateWidget(ProfileAvatar old) {
    super.didUpdateWidget(old);
    if (widget.busy && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.busy && _spin.isAnimating) {
      _spin
        ..stop()
        ..value = 0;
    }
    // The pop is for a photo that has landed: the one on its way up, kept
    // once the save is done, or a newer one from the server. A save that
    // failed hands back the old photo, and that is no news.
    final photo = widget.photo;
    final saved = old.busy && !widget.busy && identical(photo, old.photo);
    final fetched = !old.busy && !widget.busy && !identical(photo, old.photo);
    if (photo != null && (saved || fetched)) _pop.forward(from: 0);
  }

  @override
  void dispose() {
    _draw.dispose();
    _spin.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = widget.size;
    final name = widget.name;
    final stroke = math.max(2.0, size * 0.03);
    final gap = stroke + size * 0.035;

    return Semantics(
      image: true,
      label: name,
      child: SizedBox.square(
        dimension: size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_draw, _spin, _pop]),
          builder: (context, face) => Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: name == null
                    ? _DashedRingPainter(
                        color: colors.accentWash(0.55),
                        stroke: stroke,
                        shown: Curves.easeOut.transform(_draw.value),
                      )
                    : _RingPainter(
                        track: colors.accentWash(0.16),
                        arc: colors.accent,
                        stroke: stroke,
                        drawn: Curves.easeInOutCubic.transform(_draw.value),
                        spin: widget.busy ? _spin.value : null,
                      ),
              ),
              Padding(
                padding: EdgeInsets.all(gap),
                child: Transform.scale(scale: _popScale.value, child: face),
              ),
            ],
          ),
          child: ClipOval(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.accentWash(name == null ? 0.07 : 0.12),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 380),
                switchInCurve: Curves.easeOut,
                child: KeyedSubtree(
                  key: ValueKey<Object?>(
                    widget.photo ?? widget.photoUrl ?? name,
                  ),
                  child: _face(context, size - gap * 2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _face(BuildContext context, double inner) {
    final colors = context.colors;
    final name = widget.name;

    if (name == null) {
      return Center(
        child: Icon(
          Icons.add_a_photo_outlined,
          size: inner * 0.38,
          color: colors.accent,
        ),
      );
    }

    final initials = Center(
      child: Text(
        StudentAvatar.initialsOf(name),
        style: TextStyle(
          fontSize: inner * 0.34,
          fontWeight: FontWeight.w800,
          color: colors.accent,
        ),
      ),
    );

    final photo = widget.photo;
    if (photo != null) {
      return Image.memory(
        photo,
        fit: BoxFit.cover,
        width: inner,
        height: inner,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => initials,
      );
    }
    final url = widget.photoUrl;
    if (url != null) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: inner,
        height: inner,
        errorBuilder: (_, _, _) => initials,
      );
    }
    return initials;
  }
}

/// The accent ring: a faint track, the arc drawn [drawn] of the way round
/// from the top, and — while saving — a short arc chasing round ([spin]).
class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.track,
    required this.arc,
    required this.stroke,
    required this.drawn,
    required this.spin,
  });

  final Color track;
  final Color arc;
  final double stroke;
  final double drawn;
  final double? spin;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawOval(rect, paint..color = track);

    final spin = this.spin;
    if (spin != null) {
      canvas.drawArc(
        rect,
        -math.pi / 2 + spin * 2 * math.pi,
        math.pi * 0.55,
        false,
        paint..color = arc,
      );
      return;
    }
    if (drawn > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        drawn * 2 * math.pi,
        false,
        paint..color = arc,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.drawn != drawn ||
      old.spin != spin ||
      old.track != track ||
      old.arc != arc ||
      old.stroke != stroke;
}

/// A dashed ring for the empty avatar, turning a little into place as it
/// fades in.
class _DashedRingPainter extends CustomPainter {
  const _DashedRingPainter({
    required this.color,
    required this.stroke,
    required this.shown,
  });

  final Color color;
  final double stroke;
  final double shown;

  static const int _dashes = 22;

  @override
  void paint(Canvas canvas, Size size) {
    if (shown <= 0) return;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: color.a * shown);
    const step = 2 * math.pi / _dashes;
    final turn = (1 - shown) * step * 2;
    for (var i = 0; i < _dashes; i++) {
      canvas.drawArc(
        rect,
        -math.pi / 2 + i * step - turn,
        step * 0.55,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter old) =>
      old.shown != shown || old.color != color || old.stroke != stroke;
}
