import 'package:flutter/material.dart';

import '../controllers/scanner_controller.dart';
import '../controllers/whats_new_controller.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/date_label.dart';
import '../models/today_summary.dart';
import 'instructor_shell.dart';
import 'scanner/widgets/attendance_panel.dart';
import 'scanner/widgets/attendance_sheet.dart';
import 'scanner/widgets/scanner_header.dart';
import 'scanner/widgets/sync_banner.dart';
import 'widgets/press_scale.dart';
import 'widgets/splash_parts.dart';
import 'widgets/surface_panel.dart';

/// The instructor's Home — what the bar opens on. Today at a glance: how many
/// were scanned, on time and late, and in which subjects; any scans not sent
/// yet; the newest few. The scanner is one tap away from the top card, and
/// the rest of the instructor's side from the shortcuts under it.
///
/// Everything here is read from the scanner's own controller — the list the
/// scanner shows — so nothing is fetched twice, and a scan made on the
/// Scanner tab counts here at once.
///
/// The pieces rise in one after another the first time it shows, as on the
/// student's home screen.
class InstructorHome extends StatefulWidget {
  const InstructorHome({
    super.key,
    required this.session,
    required this.onOpen,
    this.whatsNewBuilder,
    this.whatsNew,
    this.now = DateTime.now,
  });

  final ScannerController session;

  /// Shows a tab — one on the bar, or one the Menu opens (QR Code, Links).
  final ValueChanged<InstructorTab> onOpen;

  /// The What's New page, from the button beside the greeting. While
  /// [whatsNew] says this phone has not opened the newest release, the
  /// button carries a dot.
  final WidgetBuilder? whatsNewBuilder;
  final WhatsNewController? whatsNew;

  /// The clock the greeting is picked by. Overridable for tests.
  final DateTime Function() now;

  @override
  State<InstructorHome> createState() => _InstructorHomeState();
}

class _InstructorHomeState extends State<InstructorHome>
    with SingleTickerProviderStateMixin {
  static const double _maxContentWidth = 560;

  /// Made in initState, not lazily, like every controller a screen owns.
  late final AnimationController _intro;

  late final Animation<double> _top = _slice(0.00, 0.40, Curves.easeOut);
  late final Animation<double> _hero = _slice(0.10, 0.52, Curves.easeOutCubic);
  late final List<Animation<double>> _shortcuts = [
    for (var i = 0; i < 4; i++)
      _slice(0.24 + 0.06 * i, 0.60 + 0.06 * i, Curves.easeOutCubic),
  ];
  late final Animation<double> _subjects = _slice(0.40, 0.84, Curves.easeOut);
  late final Animation<double> _recent = _slice(0.50, 0.94, Curves.easeOut);

  Animation<double> _slice(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _intro,
        curve: Interval(begin, end, curve: curve),
      );

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  ScannerController get _session => widget.session;

  String get _greeting {
    final hour = widget.now().hour;
    return hour < 12
        ? AppStrings.homeMorning
        : hour < 18
        ? AppStrings.homeAfternoon
        : AppStrings.homeEvening;
  }

  /// Today's whole list over Home — every subject, or [subject]'s.
  void _openList(String? subject) {
    _session.setAttendanceSubject(subject);
    showAttendanceSheet(context, _session);
  }

  /// Fades [child] in and lifts it into place as [shown] runs 0 → 1.
  Widget _rise(Animation<double> shown, Widget child) => AnimatedBuilder(
    animation: shown,
    child: child,
    builder: (context, child) => splashRise(shown.value, child!),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListenableBuilder(
      listenable: Listenable.merge([
        _session,
        widget.whatsNew ?? const _Silent(),
      ]),
      builder: (context, _) {
        final session = _session;
        final summary = TodaySummary.of(
          entries: session.attendance,
          today: session.today,
          subjects: session.subjects,
          selected: session.selectedSubject,
        );
        final news = widget.whatsNewBuilder;
        final links = session.user?.canManageLinks ?? false;

        final shortcuts = [
          _Shortcut(
            name: 'qr',
            icon: Icons.qr_code_2_rounded,
            label: NavStrings.qr,
            onTap: () => widget.onOpen(InstructorTab.qr),
          ),
          if (links)
            _Shortcut(
              name: 'links',
              icon: Icons.link_rounded,
              label: NavStrings.links,
              onTap: () => widget.onOpen(InstructorTab.links),
            ),
          _Shortcut(
            name: 'tracker',
            icon: Icons.event_available_rounded,
            label: NavStrings.tracker,
            onTap: () => widget.onOpen(InstructorTab.tracker),
          ),
          _Shortcut(
            name: 'today',
            icon: Icons.format_list_bulleted_rounded,
            label: InstructorHomeStrings.todayList,
            onTap: () => _openList(null),
          ),
        ];

        return Scaffold(
          key: const ValueKey('instructorHome'),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: session.refresh,
              color: colors.accent,
              backgroundColor: colors.surfaceRaised,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.pagePadding,
                  12,
                  AppTheme.pagePadding,
                  28,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _maxContentWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _rise(
                          _top,
                          _Greeting(
                            greeting: _greeting,
                            session: session,
                            unread: widget.whatsNew?.unread ?? false,
                            onWhatsNew: news == null
                                ? null
                                : () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(builder: news),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _rise(
                          _hero,
                          _TodayCard(
                            summary: summary,
                            session: session,
                            onScan: () => widget.onOpen(InstructorTab.scanner),
                          ),
                        ),
                        // Only while there is something to say about the
                        // internet — the same strip as under the camera.
                        SyncBanner(controller: session),
                        const SizedBox(height: 22),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final (i, shortcut) in shortcuts.indexed)
                              Expanded(child: _rise(_shortcuts[i], shortcut)),
                          ],
                        ),
                        if (summary.subjects.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          _rise(
                            _subjects,
                            _BySubject(
                              subjects: summary.subjects,
                              onOpen: _openList,
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        _rise(
                          _recent,
                          _Recent(
                            session: session,
                            onViewAll: () => _openList(null),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "Good morning" and the instructor's name, their face beside it, and What's
/// New in the corner.
class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.greeting,
    required this.session,
    required this.unread,
    required this.onWhatsNew,
  });

  final String greeting;
  final ScannerController session;
  final bool unread;
  final VoidCallback? onWhatsNew;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = session.user;
    final whatsNew = onWhatsNew;

    return Row(
      children: [
        if (user != null) ...[
          UserAvatar(user: user, size: 48),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user?.name ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (whatsNew != null)
          IconButton(
            key: const ValueKey('instructorHome.whatsNew'),
            onPressed: whatsNew,
            tooltip: unread ? WhatsNewStrings.openUnread : WhatsNewStrings.open,
            color: unread ? colors.accent : colors.textSecondary,
            icon: Badge(
              isLabelVisible: unread,
              smallSize: 9,
              backgroundColor: colors.accent,
              child: const Icon(Icons.auto_awesome_outlined),
            ),
          ),
      ],
    );
  }
}

/// Today in one card: how many were scanned, on time and late, and the way
/// into the scanner — with the subject the next scan goes to.
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.summary,
    required this.session,
    required this.onScan,
  });

  final TodaySummary summary;
  final ScannerController session;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final date = DateTime.tryParse(session.today);
    final selected = session.selectedSubject;
    final total = summary.total;

    // What the foot of the card says about the scanner, and what its button
    // does about it.
    final (String caption, String value) = switch (session) {
      ScannerController(blockedMessage: final message?) => (
        InstructorHomeStrings.scanner,
        message,
      ),
      // The name alone: beside the button, the code in brackets would push
      // it past two lines. The Menu and the scanner give the code.
      _ when selected != null => (
        InstructorHomeStrings.scanningFor,
        selected.name,
      ),
      ScannerController(subjects: [], isLoadingSubjects: false) => (
        InstructorHomeStrings.scanner,
        ScannerStrings.noSubjectsTitle,
      ),
      _ => (InstructorHomeStrings.scanner, InstructorHomeStrings.pickSubject),
    };

    return SurfacePanel(
      topAccent: true,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  InstructorHomeStrings.scannedToday,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              if (session.isLoadingAttendance)
                const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (date != null)
                _Pill(DateLabel.short(date)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              _Count(total),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  total == 0
                      ? InstructorHomeStrings.noneYet
                      : InstructorHomeStrings.scannedIn(
                          summary.subjectsScanned,
                        ),
                  style: TextStyle(fontSize: 14, color: colors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Split(total: total, late: summary.late),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _Legend(
                color: colors.success,
                label: InstructorHomeStrings.onTime(summary.onTime),
              ),
              _Legend(
                color: colors.warning,
                label: InstructorHomeStrings.late(summary.late),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  key: const ValueKey('instructorHome.scanFor'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caption,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              PressScale(
                scale: 0.95,
                child: FilledButton.icon(
                  key: const ValueKey('instructorHome.scan'),
                  onPressed: onScan,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: Text(
                    selected != null
                        ? InstructorHomeStrings.scanNow
                        : InstructorHomeStrings.openScanner,
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The day's count, running up to a new figure rather than jumping to it.
class _Count extends StatelessWidget {
  const _Count(this.value);

  final int value;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, shown, _) => Text(
        '${shown.round()}',
        key: const ValueKey('instructorHome.count'),
        style: TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w800,
          height: 1,
          letterSpacing: -1,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: context.colors.textPrimary,
        ),
      ),
    );
  }
}

/// On time against late, as one bar: emerald and amber, the colours the
/// records use for them. An empty track before the first scan.
class _Split extends StatelessWidget {
  const _Split({required this.total, required this.late});

  final int total;
  final int late;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final share = total == 0 ? 0.0 : late / total;

    return SizedBox(
      height: 8,
      child: total == 0
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceRaised,
                borderRadius: BorderRadius.circular(4),
              ),
            )
          : TweenAnimationBuilder<double>(
              tween: Tween(end: share),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, lateShare, _) => LayoutBuilder(
                builder: (context, box) {
                  // A sliver of each, whichever is small, so one late scan in
                  // forty still shows.
                  const gap = 3.0;
                  final both = lateShare > 0 && lateShare < 1;
                  final room = box.maxWidth - (both ? gap : 0);
                  final lateWidth = lateShare == 0
                      ? 0.0
                      : (room * lateShare).clamp(6.0, room);
                  final onTimeWidth = room - lateWidth;
                  return Row(
                    children: [
                      if (onTimeWidth > 0) _bar(onTimeWidth, colors.success),
                      if (both) const SizedBox(width: gap),
                      if (lateWidth > 0) _bar(lateWidth, colors.warning),
                    ],
                  );
                },
              ),
            ),
    );
  }

  Widget _bar(double width, Color color) => Container(
    width: width,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 8,
          width: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12.5, color: context.colors.textSecondary),
        ),
      ],
    );
  }
}

/// A small rounded label — the date on the card.
class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}

/// One way into the rest of the instructor's side: an icon on a tile, its
/// name under it.
class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.name,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  /// `instructorHome.<name>`, for tests.
  final String name;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return MergeSemantics(
      child: PressScale(
        scale: 0.92,
        child: InkWell(
          key: ValueKey('instructorHome.$name'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 58,
                  width: 58,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(icon, size: 26, color: colors.accent),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: colors.textSecondary,
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

/// A heading over a card, with the button that opens the whole list.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    this.action,
    this.actionKey,
    this.onAction,
  });

  final String title;
  final String? action;
  final Key? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = action;

    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ),
          if (label != null)
            TextButton(
              key: actionKey,
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(label),
            ),
        ],
      ),
    );
  }
}

/// Each subject scanned today, with how many and when the last one was —
/// and the subject being scanned, even before its first. A row opens the
/// list on that subject.
class _BySubject extends StatelessWidget {
  const _BySubject({required this.subjects, required this.onOpen});

  final List<SubjectToday> subjects;

  /// Opens the whole list on one subject — or on all of them, with null.
  final ValueChanged<String?> onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(
          title: InstructorHomeStrings.bySubject,
          action: InstructorHomeStrings.seeAll,
          actionKey: const ValueKey('instructorHome.seeAll'),
          onAction: () => onOpen(null),
        ),
        const SizedBox(height: 8),
        SurfacePanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, subject) in subjects.indexed) ...[
                if (i > 0) Divider(height: 1, indent: 74, color: colors.border),
                _SubjectRow(
                  subject: subject,
                  onTap: () => onOpen(subject.name),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.subject, required this.onTap});

  final SubjectToday subject;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (String letters, String? digits) = codeParts(
      subject.subject?.code,
      subject.name,
    );
    final lastTime = subject.lastTimeIn;
    final lateOn = subject.subject?.lateMarking ?? false;

    return MergeSemantics(
      child: InkWell(
        key: ValueKey('instructorHome.subject.${subject.name}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: colors.accentWash(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      letters,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: digits == null ? 13 : 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        height: 1.1,
                        color: colors.accent,
                      ),
                    ),
                    if (digits != null)
                      Text(
                        digits,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          color: colors.accent,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subject.scanned == 0
                          ? InstructorHomeStrings.noScansYet
                          : InstructorHomeStrings.scanned(
                              subject.scanned,
                              subject.late,
                            ),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (lastTime != null)
                    Text(
                      shortTime(lastTime),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  if (lateOn) ...[
                    if (lastTime != null) const SizedBox(height: 4),
                    const _LateOn(),
                  ],
                ],
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Late on" beside a subject whose scans are being saved as late — amber,
/// as the switch on the scanner is.
class _LateOn extends StatelessWidget {
  const _LateOn();

  @override
  Widget build(BuildContext context) {
    final warning = context.colors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: warning.withValues(alpha: 0.45)),
      ),
      child: Text(
        InstructorHomeStrings.lateOn,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: warning,
        ),
      ),
    );
  }
}

/// The newest scans — the same rows as the scanner's list, Late and Pending
/// included — with the whole list a tap away.
class _Recent extends StatelessWidget {
  const _Recent({required this.session, required this.onViewAll});

  final ScannerController session;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final all = session.attendance;
    final newest = all.take(AttendancePanel.preview).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(
          title: InstructorHomeStrings.recent,
          action: all.length > AttendancePanel.preview
              ? InstructorHomeStrings.viewAll(all.length)
              : null,
          actionKey: const ValueKey('instructorHome.viewAll'),
          onAction: onViewAll,
        ),
        const SizedBox(height: 8),
        SurfacePanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          // A new scan lands at the top; the card grows into it rather than
          // jumping.
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (newest.isEmpty)
                  const AttendanceEmpty(text: ScannerStrings.attendanceEmpty)
                else
                  for (final (i, entry) in newest.indexed)
                    AttendanceRow(entry: entry, divider: i > 0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A subject's code as its tile shows it: `ITE211` → `ITE` over `211`. A
/// code with no number is shown whole, cut to five; no code at all — a
/// subject this account no longer has — the name's initials.
(String, String?) codeParts(String? code, String name) {
  final c = (code ?? '').trim();
  final split = RegExp(r'^([A-Za-z]+)[\s-]*(\d+[A-Za-z]?)$').firstMatch(c);
  if (split != null) return (split[1]!.toUpperCase(), split[2]!);
  if (c.isNotEmpty) return (c.length > 5 ? c.substring(0, 5) : c, null);
  final initials = name
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .take(3)
      .map((w) => w[0].toUpperCase())
      .join();
  return (initials.isEmpty ? '?' : initials, null);
}

/// `08:14:03 AM` → `8:14 AM`: the seconds and the leading zero are noise on
/// a glance. A time in any other shape is shown as it is.
String shortTime(String timeIn) {
  final m = RegExp(
    r'^0?(\d{1,2}):(\d{2})(?::\d{2})?\s*([AaPp][Mm])$',
  ).firstMatch(timeIn.trim());
  if (m == null) return timeIn;
  return '${m[1]}:${m[2]} ${m[3]!.toUpperCase()}';
}

/// A [Listenable] that never fires — for a Home with no What's New.
class _Silent implements Listenable {
  const _Silent();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
