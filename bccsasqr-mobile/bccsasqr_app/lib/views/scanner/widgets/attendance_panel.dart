import 'package:flutter/material.dart';

import '../../../controllers/scanner_controller.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/scanner_models.dart';
import '../../widgets/surface_panel.dart';

/// Today's scans by this account, newest first — the web scanner's Attendance
/// List, with its search box. Scans made in the browser are here too: both
/// read the same table.
class AttendancePanel extends StatefulWidget {
  const AttendancePanel({super.key, required this.controller});

  final ScannerController controller;

  @override
  State<AttendancePanel> createState() => _AttendancePanelState();
}

class _AttendancePanelState extends State<AttendancePanel> {
  late final TextEditingController _search = TextEditingController(
    text: widget.controller.search,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final all = controller.attendance;
    final visible = controller.visibleAttendance;

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
                _CountChip(count: all.length),
            ],
          ),
          const SizedBox(height: 12),
          if (all.isNotEmpty) ...[
            TextField(
              controller: _search,
              onChanged: controller.setSearch,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                isDense: true,
                hintText: ScannerStrings.attendanceSearch,
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (all.isEmpty && !controller.isLoadingAttendance)
            const _Empty(text: ScannerStrings.attendanceEmpty)
          else if (visible.isEmpty && all.isNotEmpty)
            const _Empty(text: ScannerStrings.attendanceNoMatch)
          else
            for (final (i, entry) in visible.indexed)
              _AttendanceRow(entry: entry, divider: i > 0),
        ],
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({required this.entry, required this.divider});

  final AttendanceEntry entry;
  final bool divider;

  @override
  Widget build(BuildContext context) {
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
                  entry.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    entry.studentNumber,
                    if (entry.courseAndSection.isNotEmpty)
                      entry.courseAndSection,
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
                if (entry.subject.isNotEmpty) ...[
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

class _CountChip extends StatelessWidget {
  const _CountChip({required this.count});

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

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

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
