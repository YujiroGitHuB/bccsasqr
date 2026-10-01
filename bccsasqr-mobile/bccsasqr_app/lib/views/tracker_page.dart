import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/tracker_controller.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/date_label.dart';
import '../core/utils/student_number.dart';
import '../models/attendance_history.dart';
import '../services/speech_service.dart';
import '../services/tracker_repository.dart';
import 'scanner/widgets/attendance_panel.dart' show LateTag;
import 'scanner/widgets/scan_result_card.dart' show StudentAvatar;
import 'widgets/app_footer.dart';
import 'widgets/app_header_card.dart';
import 'widgets/demo_mode_banner.dart';
import 'widgets/surface_panel.dart';

/// The Attendance Tracker — `Tracker/view.php` on a phone. A student types
/// their number and sees how many times they were marked present, per
/// subject, with every date and any late mark.
///
/// View only, and no sign-in, exactly as on the web.
class TrackerPage extends StatefulWidget {
  const TrackerPage({
    super.key,
    required this.repository,
    this.speech = const SilentSpeechService(),
  });

  final TrackerRepository repository;
  final SpeechService speech;

  @override
  State<TrackerPage> createState() => _TrackerPageState();
}

class _TrackerPageState extends State<TrackerPage> {
  static const double _maxContentWidth = 640;

  static const List<HeaderChip> _chips = [
    (icon: Icons.visibility_outlined, label: TrackerStrings.chipViewOnly),
    (icon: Icons.history_rounded, label: TrackerStrings.chipLive),
  ];

  late final TrackerController _controller = TrackerController(
    repository: widget.repository,
    speech: widget.speech,
  );
  final TextEditingController _field = TextEditingController();

  /// Switching to another app cuts the voice off mid-sentence.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: _controller.stopSpeaking);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controller.dispose();
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The foot is left to the padding, so the page runs on under the
      // instructor's Menu button, or the phone's own bar, and still ends
      // clear of it.
      body: SafeArea(
        bottom: false,
        // Pull down to search the same number again — for a scan made a
        // minute ago. Always scrollable, so the pull works on a short page.
        child: RefreshIndicator(
          onRefresh: _controller.refresh,
          color: context.colors.accent,
          backgroundColor: context.colors.surfaceRaised,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              18,
              AppTheme.pagePadding,
              18 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppHeaderCard(
                        title: TrackerStrings.title,
                        tagline: TrackerStrings.tagline,
                        chips: _chips,
                      ),
                      DemoModeBanner(
                        active: widget.repository is InMemoryTrackerRepository,
                      ),
                      const SizedBox(height: 16),
                      _SearchPanel(controller: _controller, field: _field),
                      const SizedBox(height: 16),
                      ..._results(),
                      const SizedBox(height: 26),
                      AppFooter(
                        onOpenDeveloper: () => launchUrl(
                          Uri.parse(AppStrings.developerUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _results() {
    final history = _controller.history;

    if (_controller.isFound && history != null) {
      return [
        _IdentityCard(history: history),
        const SizedBox(height: 12),
        if (history.isEmpty)
          const _EmptyCard(
            icon: Icons.event_busy_outlined,
            title: TrackerStrings.emptyTitle,
            body: TrackerStrings.emptyBody,
          )
        else ...[
          _Stats(history: history),
          for (final subject in history.subjects) ...[
            const SizedBox(height: 12),
            _SubjectCard(subject: subject),
          ],
        ],
      ];
    }

    if (_controller.isNotFound) {
      return const [
        _EmptyCard(
          icon: Icons.person_search_outlined,
          title: TrackerStrings.notFoundTitle,
          body: TrackerStrings.notFoundBody,
        ),
      ];
    }

    if (_controller.showPlaceholder) {
      return const [
        _EmptyCard(
          icon: Icons.event_available_outlined,
          title: TrackerStrings.placeholderTitle,
          body: TrackerStrings.placeholderBody,
        ),
      ];
    }

    return const [];
  }
}

// ------------------------------------------------------------------ search

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({required this.controller, required this.field});

  final TrackerController controller;
  final TextEditingController field;

  @override
  Widget build(BuildContext context) {
    final message = controller.statusMessage;

    return SurfacePanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHeading(
            icon: Icons.search_rounded,
            label: TrackerStrings.findHeading,
          ),
          const SizedBox(height: 16),
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
          TextField(
            key: const ValueKey('tracker.field'),
            controller: field,
            onChanged: controller.onStudentNumberChanged,
            onSubmitted: (_) => controller.searchNow(),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.search,
            inputFormatters: const [StudentNumberInputFormatter()],
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: context.colors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: AppStrings.studentNumberHint,
              prefixIcon: const Icon(Icons.tag_rounded, size: 20),
              suffixIcon: controller.isSearching
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
                  : controller.isFound
                  ? Icon(
                      Icons.check_circle_rounded,
                      color: context.colors.success,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          if (message == null || controller.isSearching)
            Text(
              controller.isSearching
                  ? TrackerStrings.searching
                  : TrackerStrings.autoSearchHint,
              style: TextStyle(fontSize: 11.5, color: context.colors.textMuted),
            )
          else
            _StatusLine(controller: controller, message: message),
          if (controller.canRetry) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: controller.searchNow,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text(AppStrings.actionRetry),
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
      ),
    );
  }
}

/// The web's message box under the field: green when the records loaded,
/// cyan when the student exists but has none, red when nothing matched.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.controller, required this.message});

  final TrackerController controller;
  final String message;

  @override
  Widget build(BuildContext context) {
    final history = controller.history;
    final (icon, color) = switch (controller.status) {
      TrackerStatus.found when history != null && history.isEmpty => (
        Icons.info_outline_rounded,
        context.colors.accent,
      ),
      TrackerStatus.found => (
        Icons.check_circle_outline_rounded,
        context.colors.success,
      ),
      _ => (Icons.error_outline_rounded, context.colors.danger),
    };

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

// ----------------------------------------------------------------- results

/// Who was found — the name is what the eye looks for to confirm the right
/// person; the rest are supporting chips.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.history});

  final AttendanceHistory history;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          StudentAvatar(
            name: history.fullName,
            photoUrl: history.photoUrl,
            size: 56,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  history.fullName,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MetaChip(
                      icon: Icons.badge_outlined,
                      text: history.studentNumber,
                    ),
                    if (history.course.isNotEmpty)
                      _MetaChip(
                        icon: Icons.school_outlined,
                        text: history.course,
                      ),
                    if (history.section.isNotEmpty)
                      _MetaChip(
                        icon: Icons.groups_outlined,
                        text: history.section,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.surfaceRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: context.colors.textSecondary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: context.colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The three numbers the web shows over the tables — days present, subjects,
/// last attended — so nobody has to count rows.
class _Stats extends StatelessWidget {
  const _Stats({required this.history});

  final AttendanceHistory history;

  @override
  Widget build(BuildContext context) {
    final last = history.lastAttended;
    final present = _StatTile(
      key: const ValueKey('tracker.stat.present'),
      icon: Icons.check_circle_outline_rounded,
      label: TrackerStrings.statPresent,
      value: '${history.total}',
      primary: true,
    );
    final subjects = _StatTile(
      icon: Icons.menu_book_outlined,
      label: TrackerStrings.statSubjects,
      value: '${history.subjects.length}',
    );
    final lastTile = _StatTile(
      icon: Icons.event_outlined,
      label: TrackerStrings.statLast,
      value: last == null ? AppStrings.emptyValue : DateLabel.date(last),
      isText: true,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Three across only where a date fits beside two numbers; on a
        // phone the date takes its own row.
        if (constraints.maxWidth >= 480) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: present),
                const SizedBox(width: 10),
                Expanded(child: subjects),
                const SizedBox(width: 10),
                Expanded(child: lastTile),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: present),
                  const SizedBox(width: 10),
                  Expanded(child: subjects),
                ],
              ),
            ),
            const SizedBox(height: 10),
            lastTile,
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.primary = false,
    this.isText = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Days present — the number the student came for, in the accent.
  final bool primary;

  /// A date rather than a count: smaller, so it fits.
  final bool isText;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      color: primary ? context.colors.accentWash(0.10) : null,
      borderColor: primary ? context.colors.accentWash(0.35) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: context.colors.accent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: isText ? 16 : 26,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: primary
                  ? context.colors.accent
                  : context.colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// One subject: its instructor, how many days, and each day with its time.
///
/// A long term would make one card a whole screen, so only the newest few
/// show until the student asks for the rest.
class _SubjectCard extends StatefulWidget {
  const _SubjectCard({required this.subject});

  final SubjectAttendance subject;

  static const int _collapsedRows = 5;

  @override
  State<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<_SubjectCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    final days = subject.days;
    final collapsible = days.length > _SubjectCard._collapsedRows;
    final shown = collapsible && !_expanded
        ? days.take(_SubjectCard._collapsedRows).toList()
        : days;

    return SurfacePanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.subject,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 14,
                          color: context.colors.textMuted,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            subject.instructor,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _CountPill(count: subject.count),
            ],
          ),
          const SizedBox(height: 12),
          const _TableHead(),
          for (final (i, day) in shown.indexed) _DayRow(index: i + 1, day: day),
          if (collapsible)
            TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18,
              ),
              label: Text(
                _expanded
                    ? TrackerStrings.showLess
                    : TrackerStrings.showAll(days.length),
              ),
            )
          else
            const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.colors.accentWash(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.colors.accentWash(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 14, color: context.colors.accent),
          const SizedBox(width: 4),
          Text(
            TrackerStrings.days(count),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.colors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

const double _numberColumn = 30;

class _TableHead extends StatelessWidget {
  const _TableHead();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: context.colors.textMuted,
    );

    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _numberColumn,
            child: Text('#', style: style),
          ),
          Expanded(
            child: Text(TrackerStrings.tableDate.toUpperCase(), style: style),
          ),
          Text(TrackerStrings.tableTimeIn.toUpperCase(), style: style),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.index, required this.day});

  final int index;
  final AttendanceDay day;

  @override
  Widget build(BuildContext context) {
    final date = day.date;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _numberColumn,
            child: Text(
              '$index',
              style: TextStyle(fontSize: 12, color: context.colors.textMuted),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date == null ? day.rawDate : DateLabel.date(date),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                if (date != null)
                  Text(
                    DateLabel.weekday(date),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (day.late) ...[const LateTag(), const SizedBox(width: 8)],
          Text(
            day.timeIn,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// A calm card for the three states with nothing to list: before a search,
/// a number that matched nobody, and a record with no scans yet.
class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: context.colors.accentWash(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.accentWash(0.30)),
            ),
            child: Icon(icon, color: context.colors.accent, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
