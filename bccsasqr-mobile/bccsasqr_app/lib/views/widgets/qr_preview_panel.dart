import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../controllers/qr_generator_controller.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/qr_payload.dart';
import '../../models/student_record.dart';
import 'dashed_border_box.dart';
import 'surface_panel.dart';

/// Right column: the empty state, or the finished code once it exists.
class QrPreviewPanel extends StatelessWidget {
  const QrPreviewPanel({
    super.key,
    required this.controller,
    required this.boundaryKey,
    required this.onReset,
    this.fill = false,
  });

  final QrGeneratorController controller;

  /// True in the two-column layout, where this panel must match the height of
  /// the details panel beside it.
  final bool fill;

  /// Wraps the printable card so the export service can rasterise it.
  final GlobalKey boundaryKey;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final payload = controller.payload;

    final body = AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: payload == null
          ? _EmptyState(key: const ValueKey('empty'), fill: fill)
          : _GeneratedCode(
              key: const ValueKey('code'),
              payload: payload,
              record: controller.record!,
              boundaryKey: boundaryKey,
            ),
    );

    return SurfacePanel(
      fill: fill,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHeading(
            icon: Icons.qr_code_2_rounded,
            label: AppStrings.qrHeading,
          ),
          const SizedBox(height: 16),
          if (fill) Expanded(child: body) else body,
          if (payload != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text(AppStrings.actionReset),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key, this.fill = false});

  final bool fill;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.qr_code_2_rounded,
            size: 52,
            color: AppColors.textMuted.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 18),
          const Text(
            AppStrings.emptyQrTitle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            AppStrings.emptyQrBody,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );

    return DashedBorderBox(
      child: fill
          ? Center(child: content)
          : SizedBox(width: double.infinity, child: content),
    );
  }
}

/// The printable card: white QR on white, with the identifying details under
/// it so a saved image still says who it belongs to.
class _GeneratedCode extends StatelessWidget {
  const _GeneratedCode({
    super.key,
    required this.payload,
    required this.record,
    required this.boundaryKey,
  });

  final QrPayload payload;
  final StudentRecord record;
  final GlobalKey boundaryKey;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: boundaryKey,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: payload.encode(),
              version: QrVersions.auto,
              size: 208,
              gapless: true,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.Q,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF0A0D12),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF0A0D12),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              record.fullName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0A0D12),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              record.studentNumber.value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${record.course} • ${record.section}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
