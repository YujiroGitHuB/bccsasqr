import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/my_attendance_controller.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/date_label.dart';
import '../models/attendance_history.dart';
import 'instructor_home.dart' show codeParts, shortTime;
import 'scanner/widgets/attendance_panel.dart' show LateTag;
import 'widgets/surface_panel.dart';

/// Which days a filter chip leaves on screen.
enum _Filter { all, onTime, late }

/// My Attendance — the Attendance Tracker for the student this phone is set
/// up for: no number to type, it opens on their record. The three numbers,
/// then each subject with its days, late ones marked; a chip narrows the
/// days to on time or late.
///
/// Days present only, as on the web: the records hold no count of the
/// classes held, so there is no percentage to give.
class MyAttendancePage extends StatefulWidget {
  const MyAttendancePage({
    super.key,
    required this.controller,
    this.now = DateTime.now,
  });

  final MyAttendanceController controller;
  final DateTime Function() now;

  @override
  State<MyAttendancePage> createState() => _MyAttendancePageState();
}

class _MyAttendancePageState extends State<MyAttendancePage> {
  static const double _maxContentWidth = 640;

  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    // Opened to look: today's scan may have landed since Home loaded.
    // After the first frame: the refresh tells its listeners at once, and
    // this page is built inside one of them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.controller.loaded) {
        unawaited(widget.controller.refresh());
      }
    });
  }

  bool _keeps(AttendanceDay day) => switch (_filter) {
    _Filter.all => true,
    _Filter.onTime => !day.late,
    _Filter.late => day.late,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      key: const ValueKey('myAttendance'),
      // The foot is left to the padding, so the page runs on under the Menu
      // button and still ends clear of it.
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final controller = widget.controller;
            final history = controller.history;

            return RefreshIndicator(
              onRefresh: controller.refresh,
              color: colors.accent,
              backgroundColor: colors.surfaceRaised,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  AppTheme.pagePadding,
                  14,
                  AppTheme.pagePadding,
                  28 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _maxContentWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Header(
                          name: history?.fullName,
                          number: history?.studentNumber,
                          busy: controller.isLoading,
                          onRefresh: controller.refresh,
                        ),
                        const SizedBox(height: 16),
                        ..._body(controller, history),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _body(
    MyAttendanceController controller,
    AttendanceHistory? history,
  ) {
    if (history == null) {
      return [
        SurfacePanel(
          child: controller.error != null
              ? _Note(icon: Icons.cloud_off_rounded, text: controller.error!)
              : const _Note(
                  icon: Icons.hourglass_top_rounded,
                  text: MyAttendanceStrings.loading,
                ),
        ),
      ];
    }

    final late = controller.lateCount;
    final subjects = [
      for (final s in history.subjects)
        if (s.days.any(_keeps)) s,
    ];

    return [
      _Stats(history: history, now: widget.now()),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (filter, label, count) in [
            (_Filter.all, MyAttendanceStrings.filterAll, history.total),
            (
              _Filter.onTime,
              MyAttendanceStrings.filterOnTime,
              history.total - late,
            ),
            (_Filter.late, MyAttendanceStrings.filterLate, late),
          ])
            _FilterChip(
              name: filter.name,
              label: MyAttendanceStrings.filter(label, count),
              selected: _filter == filter,
              dot: filter == _Filter.late,
              onTap: () => setState(() => _filter = filter),
            ),
        ],
      ),
      const SizedBox(height: 14),
      if (history.isEmpty)
        const SurfacePanel(
          child: _Note(
            icon: Icons.event_busy_outlined,
            text: StudentStrings.attendanceEmpty,
          ),
        )
      else if (subjects.isEmpty)
        const SurfacePanel(
          child: _Note(
            icon: Icons.filter_alt_off_outlined,
            text: MyAttendanceStrings.noneForFilter,
          ),
        )
      else
        for (final (i, subject) in subjects.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          _SubjectCard(
            // Keyed by the filter too: a new filter starts each card over.
            key: ValueKey('${subject.subject}|${_filter.name}'),
            subject: subject,
            days: subject.days.where(_keeps).toList(),
            open: i == 0,
          ),
        ],
    ];
  }
}

/// "My Attendance", whose it is, and the refresh.
class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.number,
    required this.busy,
    required this.onRefresh,
  });

  final String? name;
  final String? number;
  final bool busy;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final who = [?name, ?number].join(' · ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                MyAttendanceStrings.title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              if (who.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  who,
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          key: const ValueKey('myAttendance.refresh'),
          onPressed: busy ? null : onRefresh,
          tooltip: MyAttendanceStrings.refresh,
          style: IconButton.styleFrom(
            backgroundColor: colors.surface,
            side: BorderSide(color: colors.border),
            minimumSize: const Size(46, 46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          color: colors.accent,
          icon: busy
              ? SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: colors.accent,
                  ),
                )
              : const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

/// The three numbers, under the accent rule the header cards wear.
class _Stats extends StatelessWidget {
  const _Stats({required this.history, required this.now});

  final AttendanceHistory history;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final last = history.lastAttended;
    final lastLabel = last == null
        ? '—'
        : last.year == now.year &&
              last.month == now.month &&
              last.day == now.day
        ? StudentStrings.today[0].toUpperCase() +
              StudentStrings.today.substring(1)
        : DateLabel.short(last);

    Widget stat(String value, String label, {double size = 26}) => Expanded(
      child: Column(
        children: [
          SizedBox(
            height: 32,
            child: Center(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: size,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(gradient: colors.headerRule),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  stat('${history.total}', StudentStrings.daysPresent),
                  VerticalDivider(width: 1, color: colors.border),
                  stat('${history.subjects.length}', StudentStrings.subjects),
                  VerticalDivider(width: 1, color: colors.border),
                  stat(lastLabel, MyAttendanceStrings.lastAttended, size: 17),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.name,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dot = false,
  });

  /// `myAttendance.filter.<name>`, for tests.
  final String name;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Amber beside it — the late chip.
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? colors.accentWash(0.12) : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? colors.accentWash(0.45) : colors.borderStrong,
          ),
        ),
        child: InkWell(
          key: ValueKey('myAttendance.filter.$name'),
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dot) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: colors.warning,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    color: selected ? colors.accent : colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One subject: its tile, name and instructor, how many days, and — opened —
/// the days themselves, newest first.
class _SubjectCard extends StatefulWidget {
  const _SubjectCard({
    super.key,
    required this.subject,
    required this.days,
    required this.open,
  });

  final SubjectAttendance subject;

  /// The days the filter leaves.
  final List<AttendanceDay> days;

  /// Opened at first — the top card.
  final bool open;

  static const int _collapsedRows = 3;

  @override
  State<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<_SubjectCard> {
  late bool _open = widget.open;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final subject = widget.subject;
    final days = widget.days;
    final late = days.where((d) => d.late).length;
    final (tile, _) = codeParts(null, subject.subject);
    final shown = _all ? days : days.take(_SubjectCard._collapsedRows);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            expanded: _open,
            child: InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.surfaceSunken,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(
                        tile,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: colors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subject.subject,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              subject.instructor,
                              if (late > 0) MyAttendanceStrings.lateCount(late),
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.accentWash(0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        TrackerStrings.days(days.length),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: colors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final day in shown) _DayRow(day: day),
                      if (days.length > _SubjectCard._collapsedRows)
                        TextButton(
                          onPressed: () => setState(() => _all = !_all),
                          child: Text(
                            _all
                                ? TrackerStrings.showLess
                                : TrackerStrings.showAll(days.length),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day});

  final AttendanceDay day;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final date = day.date;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              date == null ? day.rawDate : DateLabel.short(date),
              style: TextStyle(fontSize: 13.5, color: colors.textPrimary),
            ),
          ),
          if (day.late) ...[const LateTag(), const SizedBox(width: 8)],
          Text(
            shortTime(day.timeIn),
            style: TextStyle(
              fontSize: 13,
              color: colors.textSecondary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        Icon(icon, color: colors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
