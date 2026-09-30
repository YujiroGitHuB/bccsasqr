import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/island.dart';

/// The picture the student took or chose, to move and scale inside a circle —
/// the web page's cropper (Cropper.js, square, `viewMode: 1`) on a phone.
///
/// Pops with the square as a 400 px JPEG, or null when closed. Always dark,
/// like the scanner's camera: a photo is judged against black.
class PhotoCropPage extends StatefulWidget {
  const PhotoCropPage({super.key, required this.photo, this.pickAnother});

  final Uint8List photo;

  /// **Choose another**: a new picture from the same place, swapped in here.
  /// Left out, the button is not shown.
  final Future<Uint8List?> Function()? pickAnother;

  /// The web page saves 300 px; phones' screens are sharper than that.
  static const int outputSize = 400;
  static const int outputQuality = 85;

  /// The part of the picture inside a [side]-wide square viewport, in the
  /// picture's own pixels: the viewport run back through [transform] (the
  /// pinch and drag), then down by [cover] (the scale that first made the
  /// picture fill the square).
  static Rect sourceRect(Matrix4 transform, double side, double cover) {
    final inverse = Matrix4.inverted(transform);
    final a = MatrixUtils.transformPoint(inverse, Offset.zero);
    final b = MatrixUtils.transformPoint(inverse, Offset(side, side));
    return Rect.fromLTRB(
      a.dx / cover,
      a.dy / cover,
      b.dx / cover,
      b.dy / cover,
    );
  }

  /// Draws [source] of [image] into a square and encodes it as a JPEG. On a
  /// white plate, so a transparent PNG does not turn black. Drawn from
  /// pixels, so nothing from the original file — its EXIF, the phone's
  /// location — comes along.
  static Future<Uint8List> render(ui.Image image, Rect source) async {
    const size = outputSize;
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
      ..drawColor(AppPalette.light.surface, BlendMode.src)
      ..drawImageRect(
        image,
        source,
        const Rect.fromLTWH(0, 0, size + 0.0, size + 0.0),
        Paint()..filterQuality = FilterQuality.high,
      );
    final square = await recorder.endRecording().toImage(size, size);
    final data = await square.toByteData(format: ui.ImageByteFormat.rawRgba);
    square.dispose();
    if (data == null) throw StateError('The crop could not be read back.');
    return compute(_encodeJpeg, (
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      size,
    ));
  }

  @override
  State<PhotoCropPage> createState() => _PhotoCropPageState();
}

/// On a background isolate: a 400 px JPEG takes long enough to drop frames.
Uint8List _encodeJpeg((Uint8List, int) args) {
  final (rgba, size) = args;
  final image = img.Image.fromBytes(
    width: size,
    height: size,
    bytes: rgba.buffer,
    bytesOffset: rgba.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(image, quality: PhotoCropPage.outputQuality);
}

class _PhotoCropPageState extends State<PhotoCropPage>
    with SingleTickerProviderStateMixin {
  final TransformationController _transform = TransformationController();

  /// The circle drawing itself round and the picture settling in — each time
  /// a picture arrives.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  ui.Image? _image;
  bool _failed = false;
  bool _saving = false;

  /// The viewport's side and the picture's fill scale, as last laid out.
  double _side = 0;
  double _cover = 1;

  @override
  void initState() {
    super.initState();
    _open(widget.photo);
  }

  @override
  void dispose() {
    _transform.dispose();
    _intro.dispose();
    _image?.dispose();
    super.dispose();
  }

  Future<void> _open(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _image?.dispose();
        _image = frame.image;
        _failed = false;
        _side = 0; // centred again at the next layout
      });
      _intro.forward(from: 0);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _another() async {
    final pick = widget.pickAnother;
    if (pick == null || _saving) return;
    final Uint8List? bytes;
    try {
      bytes = await pick();
    } catch (_) {
      if (mounted) _say(ProfileStrings.pickFailed);
      return;
    }
    if (bytes != null && mounted) await _open(bytes);
  }

  Future<void> _use() async {
    final image = _image;
    if (image == null || _saving || _side == 0) return;
    setState(() => _saving = true);
    try {
      final source = PhotoCropPage.sourceRect(
        _transform.value,
        _side,
        _cover,
      ).intersect(Rect.fromLTWH(0, 0, image.width + 0.0, image.height + 0.0));
      final jpeg = await PhotoCropPage.render(image, source);
      if (mounted) Navigator.of(context).pop(jpeg);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _say(ProfileStrings.cropFailed);
    }
  }

  void _say(String message) => Island.show(
    context,
    IslandMessage(title: message, tone: IslandTone.error),
  );

  /// Lays the picture out to fill a [side] square and, the first time for
  /// each picture, centres it.
  void _fit(ui.Image image, double side) {
    if (side == _side) return;
    _side = side;
    _cover = side / math.min(image.width, image.height);
    final dx = (side - image.width * _cover) / 2;
    final dy = (side - image.height * _cover) / 2;
    _transform.value = Matrix4.translationValues(dx, dy, 0);
  }

  @override
  Widget build(BuildContext context) {
    // Its own dark theme, whatever the app's, like the camera's page.
    return Theme(
      data: AppTheme.build(AppPalette.dark),
      child: Builder(builder: _page),
    );
  }

  Widget _page(BuildContext context) {
    final colors = context.colors;
    final image = _image;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    tooltip: ProfileStrings.cropClose,
                    icon: const Icon(Icons.close_rounded),
                    color: colors.textPrimary,
                  ),
                  Expanded(
                    child: Text(
                      ProfileStrings.cropTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  // Balances the close button, so the title sits centred.
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final side = math.min(
                    constraints.maxWidth - AppTheme.pagePadding * 2,
                    math.min(constraints.maxHeight - 72, 460.0),
                  );
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox.square(
                        dimension: side,
                        child: image != null
                            ? _viewport(image, side)
                            : _placeholder(context),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _failed
                              ? ProfileStrings.cropFailed
                              : ProfileStrings.cropHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: _failed
                                ? colors.danger
                                : colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                8,
                AppTheme.pagePadding,
                16,
              ),
              child: Row(
                children: [
                  if (widget.pickAnother != null) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('crop.another'),
                        onPressed: _saving ? null : _another,
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          size: 18,
                        ),
                        label: const Text(ProfileStrings.cropAnother),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('crop.use'),
                      onPressed: image == null || _saving ? null : _use,
                      icon: _saving
                          ? SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: colors.onAccent,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 20),
                      label: const Text(ProfileStrings.cropUse),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewport(ui.Image image, double side) {
    _fit(image, side);

    return AnimatedBuilder(
      animation: _intro,
      builder: (context, viewer) {
        final t = Curves.easeOutCubic.transform(_intro.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: t,
              child: Transform.scale(scale: 0.94 + 0.06 * t, child: viewer),
            ),
            IgnorePointer(
              child: CustomPaint(
                painter: _CircleGuidePainter(
                  shown: t,
                  scrim: const Color(0xFF000000),
                  ring: AppPalette.light.surface,
                ),
              ),
            ),
          ],
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: ColoredBox(
          // The camera viewports' black, on purpose (see theme-tokens notes).
          color: const Color(0xFF000000),
          child: InteractiveViewer(
            transformationController: _transform,
            constrained: false,
            minScale: 1,
            maxScale: 6,
            boundaryMargin: EdgeInsets.zero,
            clipBehavior: Clip.none,
            child: SizedBox(
              width: image.width * _cover,
              height: image.height * _cover,
              child: RawImage(
                image: image,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: colors.border),
      ),
      child: Center(
        child: _failed
            ? Icon(
                Icons.broken_image_outlined,
                size: 40,
                color: colors.textMuted,
              )
            : CircularProgressIndicator(color: colors.accent),
      ),
    );
  }
}

/// Darkens everything outside the circle and draws the circle's edge — round
/// from the top as [shown] runs 0 → 1, with the dark coming up behind it.
class _CircleGuidePainter extends CustomPainter {
  const _CircleGuidePainter({
    required this.shown,
    required this.scrim,
    required this.ring,
  });

  final double shown;
  final Color scrim;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final circle = rect.deflate(size.width * 0.04);

    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRRect(
          RRect.fromRectAndRadius(
            rect,
            const Radius.circular(AppTheme.cardRadius),
          ),
        )
        ..addOval(circle),
      Paint()..color = scrim.withValues(alpha: 0.55 * shown),
    );

    if (shown <= 0) return;
    canvas.drawArc(
      circle,
      -math.pi / 2,
      2 * math.pi * shown,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = ring.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_CircleGuidePainter old) =>
      old.shown != shown || old.scrim != scrim || old.ring != ring;
}
