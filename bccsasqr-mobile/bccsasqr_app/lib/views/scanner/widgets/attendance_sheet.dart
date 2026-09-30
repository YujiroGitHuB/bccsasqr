import 'package:flutter/material.dart';

import '../../../controllers/scanner_controller.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import 'attendance_panel.dart';

/// The whole of today's Attendance List, over the scanner: one subject at a
/// time (the one being scanned, to begin with), with the search box.
///
/// Rows are built only as they scroll into view, so a list of three hundred
/// opens as fast as one of three. The camera stays where it was underneath;
/// the list goes on updating while the sheet is up.
Future<void> showAttendanceSheet(
  BuildContext context,
  ScannerController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.colors.surface,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 1,
      builder: (context, scroll) =>
          _AttendanceSheet(controller: controller, scroll: scroll),
    ),
  );
}

class _AttendanceSheet extends StatefulWidget {
  const _AttendanceSheet({required this.controller, required this.scroll});

  final ScannerController controller;
  final ScrollController scroll;

  @override
  State<_AttendanceSheet> createState() => _AttendanceSheetState();
}

class _AttendanceSheetState extends State<_AttendanceSheet> {
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
    final colors = context.colors;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final all = controller.attendance;
        final visible = controller.visibleAttendance;
        final subject = controller.attendanceSubject;

        // Each subject on today's list, in the order it was first scanned,
        // with how many — and the one picked even before its first scan.
        final counts = <String, int>{};
        for (final e in all) {
          if (e.subject.isEmpty) continue;
          counts[e.subject] = (counts[e.subject] ?? 0) + 1;
        }
        if (subject != null) counts.putIfAbsent(subject, () => 0);

        final String empty;
        if (all.isEmpty) {
          empty = ScannerStrings.attendanceEmpty;
        } else if (controller.search.trim().isNotEmpty) {
          empty = ScannerStrings.attendanceNoMatch;
        } else {
          empty = ScannerStrings.attendanceNoneForSubject;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ScannerStrings.attendanceSheetTitle,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  CountChip(count: visible.length),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
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
            ),
            if (counts.isNotEmpty)
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                  children: [
                    _SubjectChip(
                      label: '${ScannerStrings.attendanceAll} · ${all.length}',
                      selected: subject == null,
                      onSelected: () => controller.setAttendanceSubject(null),
                    ),
                    for (final MapEntry(key: name, value: n) in counts.entries)
                      _SubjectChip(
                        label: '$name · $n',
                        selected: subject == name,
                        onSelected: () => controller.setAttendanceSubject(name),
                      ),
                  ],
                ),
              ),
            Divider(height: 1, color: colors.border),
            Expanded(
              // Always on the sheet's own scroll controller, list or not, so
              // dragging the list down past its top lowers the sheet.
              child: visible.isEmpty
                  ? ListView(
                      controller: widget.scroll,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [AttendanceEmpty(text: empty)],
                    )
                  : ListView.builder(
                      controller: widget.scroll,
                      padding: EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        20 + MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      itemCount: visible.length,
                      itemBuilder: (context, i) => AttendanceRow(
                        entry: visible[i],
                        divider: i > 0,
                        showSubject: subject == null,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        backgroundColor: colors.surfaceRaised,
        selectedColor: colors.accentWash(0.16),
        side: BorderSide(color: selected ? colors.accent : colors.border),
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: selected ? colors.accent : colors.textSecondary,
        ),
      ),
    );
  }
}
