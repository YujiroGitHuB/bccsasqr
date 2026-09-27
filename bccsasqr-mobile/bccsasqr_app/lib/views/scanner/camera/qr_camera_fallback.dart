import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import 'scan_highlight.dart';

/// Stands in for the camera where the native decoder does not run — the web
/// build, used to look at the screens in a browser. A typed number goes
/// through exactly the path a scanned one does.
class QrCamera extends StatefulWidget {
  const QrCamera({super.key, required this.onCode});

  final ValueChanged<String> onCode;

  static const double cropFraction = 0.8;

  @override
  State<QrCamera> createState() => _QrCameraState();
}

class _QrCameraState extends State<QrCamera> {
  final TextEditingController _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _field.text.trim();
    if (text.isEmpty) return;
    // No code to outline, so the frame itself lights up.
    ScanHighlightScope.maybeOf(context)?.show(null);
    widget.onCode(text);
    _field.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.surfaceSunken,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.qr_code_scanner_rounded,
                color: context.colors.textMuted,
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                ScannerStrings.cameraUnsupported,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: TextField(
                  controller: _field,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: ScannerStrings.manualEntryLabel,
                    suffixIcon: IconButton(
                      onPressed: _submit,
                      tooltip: ScannerStrings.manualEntrySubmit,
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
