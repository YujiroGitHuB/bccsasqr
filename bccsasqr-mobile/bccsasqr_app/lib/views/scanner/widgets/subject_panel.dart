import 'package:flutter/material.dart';

import '../../../controllers/scanner_controller.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/surface_panel.dart';

/// The subject picker, the late-marking switch and the "ready" line — the web
/// scanner's `.subject-selection`. Nothing scans until a subject is picked.
class SubjectPanel extends StatelessWidget {
  const SubjectPanel({
    super.key,
    required this.controller,
    required this.onPickSubject,
  });

  final ScannerController controller;
  final VoidCallback onPickSubject;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedSubject;

    return SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text.rich(
            TextSpan(
              text: ScannerStrings.subjectLabel,
              children: [
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.danger),
                ),
              ],
            ),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _SubjectField(
            label: selected?.label,
            onTap: controller.subjects.isEmpty ? null : onPickSubject,
          ),
          if (selected != null) ...[
            const SizedBox(height: 12),
            LateMarkingSwitch(
              on: selected.lateMarking,
              busy: controller.isLateBusy,
              onToggle: controller.toggleLate,
            ),
          ],
          const SizedBox(height: 12),
          _Readiness(ready: selected != null),
        ],
      ),
    );
  }
}

/// Looks like the form's text fields; opens the subject sheet.
class _SubjectField extends StatelessWidget {
  const _SubjectField({required this.label, required this.onTap});

  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.fieldRadius);

    return Material(
      color: AppColors.surfaceSunken,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: label == null ? AppColors.border : AppColors.accentWash(0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          child: Row(
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: 20,
                color: label == null ? AppColors.textMuted : AppColors.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label ?? ScannerStrings.subjectPlaceholder,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: label == null
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.expand_more_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One switch per subject. On: every scan from now on is saved as late — the
/// instructor flips it once class has started. Amber, because late is a state
/// the records carry, like the Late tag in the list.
class LateMarkingSwitch extends StatelessWidget {
  const LateMarkingSwitch({
    super.key,
    required this.on,
    required this.busy,
    required this.onToggle,
  });

  final bool on;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.fieldRadius);

    return Material(
      color: on
          ? AppColors.warning.withValues(alpha: 0.10)
          : AppColors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: on
              ? AppColors.warning.withValues(alpha: 0.45)
              : AppColors.border,
        ),
      ),
      child: InkWell(
        onTap: busy ? null : onToggle,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.alarm_rounded,
                          size: 16,
                          color: on
                              ? AppColors.warning
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            ScannerStrings.lateTitle,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: on
                                  ? AppColors.warning
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      on ? ScannerStrings.lateOn : ScannerStrings.lateOff,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: on,
                onChanged: busy ? null : (_) => onToggle(),
                thumbColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? const Color(0xFF2B1D00)
                      : AppColors.textSecondary,
                ),
                trackColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppColors.warning
                      : AppColors.surfaceSunken,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Please select a subject first" until one is picked, then "Ready to scan"
/// with a live dot — the web's `#scannerStatus.active`.
class _Readiness extends StatelessWidget {
  const _Readiness({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ready ? AppColors.accentWash(0.08) : AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ready ? AppColors.accentWash(0.30) : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 8,
            width: 8,
            decoration: BoxDecoration(
              color: ready ? AppColors.accent : AppColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              ready
                  ? ScannerStrings.readyToScan
                  : ScannerStrings.selectSubjectFirst,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ready ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
