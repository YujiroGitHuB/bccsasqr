import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';

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

  @override
  Widget build(BuildContext context) {
    if (_unavailable) {
      return const _CameraMessage(text: ScannerStrings.cameraDenied);
    }

    return ReaderWidget(
      onScan: (code) {
        final text = code.text;
        if (code.isValid && text != null && text.isNotEmpty) {
          widget.onCode(text);
        }
      },
      onControllerCreated: (controller, error) {
        // A refused permission or a camera held by another app.
        if (error != null && mounted) setState(() => _unavailable = true);
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
      // The torch helps in a dim classroom; the gallery and the front camera
      // have no use here.
      showFlashlight: true,
      showGallery: false,
      showToggleCamera: false,
      actionButtonsAlignment: Alignment.topRight,
      actionButtonsBackgroundColor: Colors.black54,
      actionButtonsBackgroundBorderRadius: BorderRadius.circular(10),
      loading: const ColoredBox(
        color: AppColors.surfaceSunken,
        child: Center(child: CircularProgressIndicator()),
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
      color: AppColors.surfaceSunken,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: AppColors.textMuted,
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
