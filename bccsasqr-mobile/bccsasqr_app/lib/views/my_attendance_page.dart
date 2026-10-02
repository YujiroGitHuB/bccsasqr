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
import 'widgets/absent_tag.dart';
import 'widgets/surface_panel.dart';

/// Which days a filter chip leaves on screen.
enum _Filter { all, onTime, late, absent }

/// My Attendance — the Attendance Tracker for the student this phone is set
/// up for: no number to type, it opens on their record. The numbers, then
/// each subject with its days, late ones marked; a chip narrows the days to
/// on time, late or absent.
///
/// Absences since 2026-10-02: the days each enrolled subject's class was
/// scanned without the student, counted by the server the way the
/// instructor's absences report counts them, and listed among the days
/// present in red. Every enrolled subject is listed, the ones never attended
/// too. A server that cannot count them leaves the page as it was: days
/// present only.
///
/// With no signal it shows the copy kept on the phone, under a note saying
/// when it is from, rather than "Could not load".
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

  bool _keeps(ClassDay day) => switch (_filter) {
    _Filter.all => true,
    _Filter.onTime => !day.absent && !day.late,
    _Filter.late => day.late,
    _Filter.absent => day.absent,
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
    final absent = history.absences;
    // Every subject under All — an enrolled one with no class yet included;
    // under a narrower chip, only those with a day it keeps.
    final subjects = [
      for (final s in history.subjects)
        if (_filter == _Filter.all || s.classDays.any(_keeps)) s,
    ];

    final asOf = controller.asOf;

    return [
      // The copy kept on the phone, or the answer before an ask that
      // failed: said once, above the numbers it is about.
      if (controller.stale && asOf != null) ...[
        _KeptNote(when: DateLabel.since(asOf, widget.now())),
        const SizedBox(height: 12),
      ],
      _Stats(history: history, now: widget.now()),
      if (absent != null) ...[const SizedBox(height: 10), const _AbsenceNote()],
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (filter, label, count) in [
            (
              _Filter.all,
              MyAttendanceStrings.filterAll,
              history.total + (absent ?? 0),
            ),
            (
              _Filter.onTime,
              MyAttendanceStrings.filterOnTime,
              history.total - late,
            ),
            (_Filter.late, MyAttendanceStrings.filterLate, late),
            if (absent != null)
              (_Filter.absent, MyAttendanceStrings.filterAbsent, absent),
          ])
            _FilterChip(
              name: filter.name,
              label: MyAttendanceStrings.filter(label, count),
              selected: _filter == filter,
              dot: switch (filter) {
                _Filter.late => context.colors.warning,
                _Filter.absent => context.colors.danger,
                _ => null,
              },
              onTap: () => setState(() => _filter = filter),
            ),
        ],
      ),
      const SizedBox(height: 14),
      if (history.subjects.isEmpty)
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
            days: subject.classDays.where(_keeps).toList(),
            absentOnly: _filter == _Filter.absent,
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

/// The three numbers, under the accent rule the header cards wear: days
/// present, absences — the subjects' count instead where none were counted —
/// and the last day attended.
class _Stats extends StatelessWidget {
  const _Stats({required this.history, required this.now});

  final AttendanceHistory history;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final last = history.lastAttended;
    final absent = history.absences;
    final lastLabel = last == null
        ? '—'
        : last.year == now.year &&
              last.month == now.month &&
              last.day == now.day
        ? StudentStrings.today[0].toUpperCase() +
              StudentStrings.today.substring(1)
        : DateLabel.short(last);

    Widget stat(
      String name,
      String value,
      String label, {
      double size = 26,
      Color? tint,
    }) => Expanded(
      child: Column(
        key: ValueKey('myAttendance.stat.$name'),
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
                  color: tint ?? colors.textPrimary,
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
                  stat(
                    'present',
                    '${history.total}',
                    StudentStrings.daysPresent,
                  ),
                  VerticalDivider(width: 1, color: colors.border),
                  if (absent != null)
                    stat(
                      'absent',
                      '$absent',
                      StudentStrings.absences,
                      // Red only while there is one: a state, not decoration.
                      tint: absent > 0 ? colors.danger : null,
                    )
                  else
                    stat(
                      'subjects',
                      '${history.subjects.length}',
                      StudentStrings.subjects,
                    ),
                  VerticalDivider(width: 1, color: colors.border),
                  stat(
                    'last',
                    lastLabel,
                    MyAttendanceStrings.lastAttended,
                    size: 17,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Saved on this phone · as of 8:04 AM" — what is shown is the copy kept
/// on the phone, not the server's word right now — and how to update it.
class _KeptNote extends StatelessWidget {
  const _KeptNote({required this.when});

  final String when;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SurfacePanel(
      key: const ValueKey('myAttendance.kept'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 20, color: colors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  MyAttendanceStrings.keptAsOf(when),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  MyAttendanceStrings.keptHint,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: colors.textSecondary,
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

/// How an absence is counted, under the number it explains.
class _AbsenceNote extends StatelessWidget {
  const _AbsenceNote();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              TrackerStrings.absenceNote,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: colors.textSecondary,
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
    this.dot,
  });

  /// `myAttendance.filter.<name>`, for tests.
  final String name;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// The state's colour beside it — amber for late, red for absent.
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dot = this.dot;

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
                if (dot != null) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: dot,
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

/// One subject: its tile, name, instructor and section, its classes and
/// absences, how many days — and, opened, the days themselves, newest first,
/// the missed ones among them.
class _SubjectCard extends StatefulWidget {
  const _SubjectCard({
    super.key,
    required this.subject,
    required this.days,
    required this.absentOnly,
    required this.open,
  });

  final SubjectAttendance subject;

  /// The days the filter leaves.
  final List<ClassDay> days;

  /// Under the Absent chip: the pill counts the days missed, in red.
  final bool absentOnly;

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
    final present = days.where((d) => !d.absent).length;
    final missed = days.length - present;
    final classes = subject.classes;
    final absences = subject.absences ?? 0;
    final (tile, _) = codeParts(null, subject.subject);
    final shown = _all ? days : days.take(_SubjectCard._collapsedRows);
    final pill = widget.absentOnly ? colors.danger : colors.accent;

    final meta = [
      if (subject.instructor.isNotEmpty) subject.instructor,
      if (subject.section.isNotEmpty) TrackerStrings.section(subject.section),
      if (late > 0) MyAttendanceStrings.lateCount(late),
    ].join(' · ');

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
                          if (meta.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              meta,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                          if (classes != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              classes == 0
                                  ? TrackerStrings.noClassYet
                                  : TrackerStrings.classesAttended(
                                      subject.attended!,
                                      classes,
                                    ),
                              style: TextStyle(
                                fontSize: 12.5,
                                color: colors.textSecondary,
                              ),
                            ),
                            // A line of its own: on a phone it would wrap
                            // there anyway, and it is what the card is for.
                            if (absences > 0)
                              Text(
                                TrackerStrings.absentCount(absences),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: colors.danger,
                                ),
                              ),
                          ],
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
                        color: pill.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        widget.absentOnly
                            ? TrackerStrings.absentCount(missed)
                            : TrackerStrings.days(present),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: pill,
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
                      if (days.isEmpty)
                        // Enrolled, and the class not scanned yet.
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: colors.border),
                            ),
                          ),
                          child: Text(
                            TrackerStrings.noClassYetBody,
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
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

  final ClassDay day;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final date = day.date;
    final present = day.present;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              date == null ? (present?.rawDate ?? '') : DateLabel.short(date),
              style: TextStyle(
                fontSize: 13.5,
                color: present == null
                    ? colors.textSecondary
                    : colors.textPrimary,
              ),
            ),
          ),
          if (present == null)
            const AbsentTag()
          else ...[
            if (present.late) ...[const LateTag(), const SizedBox(width: 8)],
            Text(
              shortTime(present.timeIn),
              style: TextStyle(
                fontSize: 13,
                color: colors.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
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
