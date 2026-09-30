import 'package:flutter/material.dart';

import '../../../controllers/scanner_controller.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/scanner_models.dart';
import '../../widgets/surface_panel.dart';
import 'attendance_sheet.dart';

/// Today's scans by this account, newest first — the web scanner's Attendance
/// List. Scans made in the browser are here too: both read the same table,
/// and so are the ones kept on this phone while offline, marked Pending.
///
/// Only the newest [preview] sit under the camera. A class of forty used to
/// push the page forty rows long, and scrolling down to check one name took
/// the camera off the screen. The whole list, with its search, is a sheet
/// away ([showAttendanceSheet]).
class AttendancePanel extends StatelessWidget {
  const AttendancePanel({super.key, required this.controller});

  final ScannerController controller;

  /// How many of the newest scans show under the camera.
  static const int preview = 5;

  @override
  Widget build(BuildContext context) {
    final all = controller.attendance;
    final newest = all.take(preview).toList();

    return SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: PanelHeading(
                  icon: Icons.fact_check_outlined,
                  label: ScannerStrings.attendanceHeading,
                ),
              ),
              if (controller.isLoadingAttendance)
                const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                CountChip(count: all.length),
            ],
          ),
          const SizedBox(height: 4),
          // A new scan lands at the top; the panel grows into it rather than
          // jumping.
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (all.isEmpty && !controller.isLoadingAttendance)
                  const AttendanceEmpty(text: ScannerStrings.attendanceEmpty)
                else
                  for (final (i, entry) in newest.indexed)
                    AttendanceRow(entry: entry, divider: i > 0),
              ],
            ),
          ),
          if (all.length > preview) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => showAttendanceSheet(context, controller),
              icon: const Icon(Icons.format_list_bulleted_rounded, size: 18),
              label: Text(ScannerStrings.attendanceViewAll(all.length)),
            ),
          ],
        ],
      ),
    );
  }
}

/// One scan: who, their course and section, the subject, and the time — with
/// Late and Pending beside the time when they apply.
class AttendanceRow extends StatelessWidget {
  const AttendanceRow({
    super.key,
    required this.entry,
    required this.divider,
    this.showSubject = true,
  });

  final AttendanceEntry entry;
  final bool divider;

  /// Left out where the list is already one subject's.
  final bool showSubject;

  @override
  Widget build(BuildContext context) {
    // A scan kept offline with no class list has only its number, standing
    // in for the name — not said twice.
    final named = entry.name.isNotEmpty && entry.name != entry.studentNumber;
    final details = [
      if (named) entry.studentNumber,
      if (entry.courseAndSection.isNotEmpty) entry.courseAndSection,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: divider
            ? Border(top: BorderSide(color: context.colors.border))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  named ? entry.name : entry.studentNumber,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    details,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
                if (showSubject && entry.subject.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.subject,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                entry.timeIn,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
              if (entry.late) ...[const SizedBox(height: 4), const LateTag()],
              if (entry.pending) ...[
                const SizedBox(height: 4),
                const PendingTag(),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The amber "Late" beside a time — the web's `.scan-late-tag`.
class LateTag extends StatelessWidget {
  const LateTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: context.colors.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: context.colors.warning.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        ScannerStrings.lateTag,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: context.colors.warning,
        ),
      ),
    );
  }
}

/// "Pending" beside a time: kept on this phone, not yet on the server.
/// Neutral rather than a state colour — the student is marked; only the
/// sending is left.
class PendingTag extends StatelessWidget {
  const PendingTag({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.borderStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 12,
            color: colors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            ScannerStrings.pendingTag,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class CountChip extends StatelessWidget {
  const CountChip({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: context.colors.surfaceRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.colors.border),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: context.colors.textPrimary,
        ),
      ),
    );
  }
}

class AttendanceEmpty extends StatelessWidget {
  const AttendanceEmpty({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
      ),
    );
  }
}
