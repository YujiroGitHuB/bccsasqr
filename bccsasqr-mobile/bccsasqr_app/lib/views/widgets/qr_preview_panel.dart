import 'package:flutter/material.dart';

import '../../controllers/qr_generator_controller.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/qr_payload.dart';
import 'dashed_border_box.dart';
import 'qr_card.dart';
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

/// The generated card, scaled down to fit a narrow screen.
///
/// The [RepaintBoundary] sits INSIDE the [FittedBox], so the export captures
/// the card at its own full size — never the shrunken copy on screen.
class _GeneratedCode extends StatelessWidget {
  const _GeneratedCode({
    super.key,
    required this.payload,
    required this.boundaryKey,
  });

  final QrPayload payload;
  final GlobalKey boundaryKey;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: RepaintBoundary(
            key: boundaryKey,
            child: QrCard(payload: payload),
          ),
        ),
      ),
    );
  }
}
