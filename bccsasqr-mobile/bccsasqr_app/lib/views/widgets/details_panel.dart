import 'package:flutter/material.dart';

import '../../controllers/qr_generator_controller.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/student_number.dart';
import '../../models/record_warning.dart';
import '../../models/student_record.dart';
import 'how_this_works_tile.dart';
import 'record_field_row.dart';
import 'surface_panel.dart';
import 'terms_checkbox.dart';

/// Left column: the form the student fills in.
class DetailsPanel extends StatelessWidget {
  const DetailsPanel({
    super.key,
    required this.controller,
    required this.textController,
    required this.onOpenTerms,
    required this.onPrimaryAction,
    required this.onOpenUrl,
    this.onUploadPhoto,
  });

  final QrGeneratorController controller;
  final TextEditingController textController;
  final VoidCallback onOpenTerms;
  final VoidCallback onPrimaryAction;

  /// Opens a link a warning offers — the photo upload page, today.
  final ValueChanged<String> onOpenUrl;

  /// My Profile, where the app itself takes the photo. Given, the missing-
  /// photo warning opens it instead of the web page in the browser.
  final VoidCallback? onUploadPhoto;

  @override
  Widget build(BuildContext context) {
    final record = controller.record;

    return SurfacePanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PanelHeading(
            icon: Icons.badge_outlined,
            label: AppStrings.detailsHeading,
          ),
          const SizedBox(height: 16),
          HowThisWorksTile(onToggled: controller.onInstructionsToggled),
          const SizedBox(height: 18),
          Text(
            AppStrings.studentNumberLabel,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.studentNumberFormat,
            style: TextStyle(
              fontSize: 11.5,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          _StudentNumberField(
            controller: controller,
            textController: textController,
          ),
          if (controller.errorMessage != null) ...[
            const SizedBox(height: 8),
            _InlineMessage(
              icon: Icons.error_outline_rounded,
              color: context.colors.danger,
              message: controller.errorMessage!,
            ),
            if (controller.canRetry) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: controller.verifyNow,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text(AppStrings.actionRetry),
                // Same shape as the warning card's button, in the error's red.
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.danger,
                  side: BorderSide(
                    color: context.colors.danger.withValues(alpha: 0.55),
                  ),
                  minimumSize: const Size.fromHeight(40),
                ),
              ),
            ],
          ],
          if (controller.offlineCopyNotice case final notice?) ...[
            // Amber, not green: the record is the one checked when the code
            // was made, not one checked just now.
            const SizedBox(height: 8),
            _InlineMessage(
              icon: Icons.cloud_off_rounded,
              color: context.colors.warning,
              message: notice,
            ),
          ] else if (controller.isVerified) ...[
            const SizedBox(height: 8),
            _InlineMessage(
              icon: Icons.verified_rounded,
              color: context.colors.success,
              message: AppStrings.verifiedBadge,
            ),
          ],
          for (final warning in controller.warnings) ...[
            const SizedBox(height: 10),
            _WarningCard(
              warning: warning,
              onOpenUrl: onOpenUrl,
              onUploadPhoto: warning.code == 'photo_missing'
                  ? onUploadPhoto
                  : null,
            ),
          ],
          const SizedBox(height: 14),
          _RecordBox(controller: controller, record: record),
          const SizedBox(height: 14),
          TermsCheckbox(
            value: controller.termsAccepted,
            onChanged: controller.setTermsAccepted,
            onOpenTerms: onOpenTerms,
          ),
          const SizedBox(height: 14),
          _PrimaryActionButton(
            controller: controller,
            onPressed: onPrimaryAction,
          ),
        ],
      ),
    );
  }
}

class _StudentNumberField extends StatelessWidget {
  const _StudentNumberField({
    required this.controller,
    required this.textController,
  });

  final QrGeneratorController controller;
  final TextEditingController textController;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: textController,
      onChanged: controller.onStudentNumberChanged,
      onSubmitted: (_) => controller.verifyNow(),
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: const [StudentNumberInputFormatter()],
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: context.colors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: AppStrings.studentNumberHint,
        suffixIcon: controller.isVerifying
            ? Padding(
                padding: const EdgeInsets.all(14),
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colors.accent,
                  ),
                ),
              )
            : controller.isVerified
            ? Icon(Icons.check_circle_rounded, color: context.colors.success)
            : null,
      ),
    );
  }
}

/// Read-only box holding the three verified fields.
class _RecordBox extends StatelessWidget {
  const _RecordBox({required this.controller, required this.record});

  final QrGeneratorController controller;
  final StudentRecord? record;

  @override
  Widget build(BuildContext context) {
    final loading = controller.isVerifying;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          RecordFieldRow(
            label: AppStrings.fieldName,
            value: record?.fullName,
            loading: loading,
          ),
          const Divider(),
          RecordFieldRow(
            label: AppStrings.fieldCourse,
            value: record?.course,
            loading: loading,
          ),
          const Divider(),
          RecordFieldRow(
            label: AppStrings.fieldSection,
            value: record?.section,
            loading: loading,
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.controller,
    required this.onPressed,
  });

  final QrGeneratorController controller;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final busy = controller.isGenerating || controller.isExporting;
    final enabled = controller.isPrimaryActionEnabled;
    final icon = controller.hasQrCode
        ? Icons.download_rounded
        : Icons.auto_awesome_rounded;

    return FilledButton(
      onPressed: enabled && !busy ? onPressed : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
            SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.colors.textSecondary,
              ),
            )
          else
            Icon(icon, size: 17),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              controller.primaryActionLabel,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            message,
            style: TextStyle(fontSize: 12, height: 1.35, color: color),
          ),
        ),
      ],
    );
  }
}

/// One server warning, with its fix one tap away when the server offers one.
///
/// Styled like the demo-mode notice: amber, because nothing is broken yet —
/// the student can still generate — but something will be at the scanner.
class _WarningCard extends StatelessWidget {
  const _WarningCard({
    required this.warning,
    required this.onOpenUrl,
    this.onUploadPhoto,
  });

  final RecordWarning warning;
  final ValueChanged<String> onOpenUrl;

  /// Set only for the missing-photo warning, when the app can take it.
  final VoidCallback? onUploadPhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: context.colors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.fieldRadius),
        border: Border.all(
          color: context.colors.warning.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 17,
            color: context.colors.warning,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  warning.message,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: context.colors.textPrimary,
                  ),
                ),
                if (onUploadPhoto != null || warning.hasAction) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed:
                        onUploadPhoto ?? () => onOpenUrl(warning.actionUrl!),
                    icon: Icon(
                      onUploadPhoto != null
                          ? Icons.add_a_photo_outlined
                          : Icons.open_in_new_rounded,
                      size: 15,
                    ),
                    label: Text(
                      warning.actionLabel ?? ProfileStrings.uploadAction,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.warning,
                      side: BorderSide(
                        color: context.colors.warning.withValues(alpha: 0.55),
                      ),
                      // Full width like every button in the app, a little
                      // shorter so it reads as secondary to Generate.
                      minimumSize: const Size.fromHeight(40),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
