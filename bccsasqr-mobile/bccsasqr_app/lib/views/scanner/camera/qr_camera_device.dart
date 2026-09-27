import 'package:camera/camera.dart' show FlashMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter_zxing/flutter_zxing.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import 'scan_highlight.dart';
import 'torch_control.dart';

/// The phone's back camera, decoding QR codes with ZXing.
///
/// ZXing rather than ML Kit for one reason: the BCC QR is drawn light-on-dark
/// (#38bdf8 on #0f172a — `gen_qr_spec()` in api/v1/lib/generator.php), and ML
/// Kit cannot read an inverted code at all. `tryInverted` reads both — the
/// light-on-dark code on a student's screen and a photocopied dark-on-light
/// one — which is what the web scanner's `inversionAttempts: 'attemptBoth'`
/// does.
class QrCamera extends StatefulWidget {
  const QrCamera({super.key, required this.onCode});

  /// Called with the text of every QR read. The same code is reported again
  /// for as long as it stays in view; the controller decides what a repeat
  /// means.
  final ValueChanged<String> onCode;

  /// How much of the frame, around the centre, is decoded. The overlay's
  /// corners are drawn at the same fraction.
  static const double cropFraction = 0.8;

  @override
  State<QrCamera> createState() => _QrCameraState();
}

class _QrCameraState extends State<QrCamera> {
  bool _unavailable = false;

  CameraController? _controller;
  TorchControl? _torch;

  void _onCameraReady(CameraController controller) {
    _controller?.removeListener(_reportTorch);
    _controller = controller..addListener(_reportTorch);
    _torch = TorchScope.maybeOf(context)
      ?..attach(
        (on) => controller.setFlashMode(on ? FlashMode.torch : FlashMode.off),
      );
  }

  /// Where [code] sits inside the scan frame, for the green outline.
  ///
  /// ZXing reports the corners in the frame as the sensor sees it — on its
  /// side on most phones — and inside the square it was asked to read, so
  /// they are turned the right way up and scaled to that square. Null when
  /// there is no position, or it does not land inside the frame.
  ScanQuad? _quadOf(Code code) {
    final pos = code.position;
    if (pos == null) return null;
    final controller = _controller;
    return ScanQuad.fromCrop(
      imageWidth: pos.imageWidth,
      imageHeight: pos.imageHeight,
      cropFraction: QrCamera.cropFraction,
      points: [
        Offset(pos.topLeftX.toDouble(), pos.topLeftY.toDouble()),
        Offset(pos.topRightX.toDouble(), pos.topRightY.toDouble()),
        Offset(pos.bottomRightX.toDouble(), pos.bottomRightY.toDouble()),
        Offset(pos.bottomLeftX.toDouble(), pos.bottomLeftY.toDouble()),
      ],
      rotation: ScanQuad.displayRotation(
        controller?.description.sensorOrientation ?? 90,
        controller?.value.deviceOrientation ?? DeviceOrientation.portraitUp,
      ),
    );
  }

  void _reportTorch() {
    final controller = _controller;
    if (controller == null) return;
    _torch?.report(controller.value.flashMode == FlashMode.torch);
  }

  @override
  void dispose() {
    _controller?.removeListener(_reportTorch);
    _torch?.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_unavailable) {
      return const _CameraMessage(text: ScannerStrings.cameraDenied);
    }

    return ReaderWidget(
      onScan: (code) {
        final text = code.text;
        if (code.isValid && text != null && text.isNotEmpty) {
          // Outlined the moment it is read, as the web scanner does —
          // before the server has said anything about it.
          if (mounted) ScanHighlightScope.maybeOf(context)?.show(_quadOf(code));
          widget.onCode(text);
        }
      },
      onControllerCreated: (controller, error) {
        if (!mounted) return;
        // A refused permission or a camera held by another app.
        if (error != null) {
          setState(() => _unavailable = true);
        } else if (controller != null) {
          _onCameraReady(controller);
        }
      },
      codeFormat: Format.qrCode,
      tryInverted: true,
      // A pause between decodes, not a frame rate: the web scanner reads
      // about twelve times a second (SCAN_INTERVAL = 80 ms). The default,
      // one second, made every scan feel a beat late.
      scanDelay: const Duration(milliseconds: 80),
      scanDelaySuccess: const Duration(milliseconds: 600),
      cropPercent: QrCamera.cropFraction,
      // The corners are drawn by the scanner page, in the app's colours.
      showScannerOverlay: false,
      // No buttons over the picture. The torch has its own, under the camera
      // (see TorchControl); the gallery and the front camera have no use here.
      showFlashlight: false,
      showGallery: false,
      showToggleCamera: false,
      loading: ColoredBox(
        color: context.colors.surfaceSunken,
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _CameraMessage extends StatelessWidget {
  const _CameraMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.surfaceSunken,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.no_photography_outlined,
                color: context.colors.textMuted,
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
