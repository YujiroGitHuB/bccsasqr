import 'package:flutter/material.dart';

import '../controllers/notifications_controller.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/date_label.dart';
import '../models/student_notice.dart';
import 'instructor_home.dart' show shortTime;
import 'widgets/island.dart';
import 'widgets/splash_parts.dart';
import 'widgets/surface_panel.dart';

/// How a notice reads — on the island the moment it comes, and in the list.
extension NoticeLook on StudentNotice {
  String get headline => switch (kind) {
    NoticeKind.present => NoticeStrings.present,
    NoticeKind.late => NoticeStrings.late,
    NoticeKind.removed => NoticeStrings.removed,
  };

  /// "8:04 AM" for today's record; "Wed, Sep 30, 8:04 AM" for an earlier
  /// one — a scan sent later, or one deleted.
  String when(DateTime now) {
    final time = shortTime(day.timeIn);
    final date = day.date;
    if (date == null) return '${day.rawDate}, $time';
    final today =
        date.year == now.year && date.month == now.month && date.day == now.day;
    return today ? time : '${DateLabel.short(date)}, $time';
  }

  String line(DateTime now) => NoticeStrings.body(
    subject,
    when(now),
    late: kind == NoticeKind.removed ? null : kind == NoticeKind.late,
  );

  /// The records' own colours for the state: green present, amber late,
  /// red for a record that is gone — as absent is.
  IslandTone get tone => switch (kind) {
    NoticeKind.present => IslandTone.success,
    NoticeKind.late => IslandTone.warning,
    NoticeKind.removed => IslandTone.error,
  };

  IconData get icon => switch (kind) {
    NoticeKind.present => Icons.how_to_reg_rounded,
    NoticeKind.late => Icons.schedule_rounded,
    NoticeKind.removed => Icons.event_busy_rounded,
  };
}

/// Notifications — what happened to the student's attendance, newest first,
/// told the moment the phone heard of it (notifications_controller.dart).
/// Opened from the bell on Home and the Menu, over the shell, as What's New
/// is.
///
/// Opening it is reading it: the count on the bell goes, and what was new
/// keeps its NEW mark until the page is closed. While it is open, anything
/// that comes in is read already, and marked NEW too.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.controller,
    this.onOpenAttendance,
    this.onSetUp,
    this.now = DateTime.now,
  });

  final NotificationsController controller;

  /// My Attendance, from a notice — where the record is.
  final VoidCallback? onOpenAttendance;

  /// My Profile, before the phone is set up.
  final VoidCallback? onSetUp;

  /// The clock the groups and the times are worked out by. Overridable for
  /// tests.
  final DateTime Function() now;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with SingleTickerProviderStateMixin {
  static const double _maxContentWidth = 560;

  /// Made in initState, not lazily, like every controller a screen owns.
  late final AnimationController _intro;

  /// The header, the note or the first groups, one after another; any
  /// further group arrives with the last.
  late final List<Animation<double>> _pieces;

  /// What was new when it arrived on this page.
  final Set<String> _fresh = {};

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _pieces = [
      for (var i = 0; i < 5; i++)
        CurvedAnimation(
          parent: _intro,
          curve: Interval(0.1 * i, 0.1 * i + 0.5, curve: Curves.easeOutCubic),
        ),
    ];
    widget.controller.addListener(_onChange);
    _onChange();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _intro.dispose();
    super.dispose();
  }

  /// Read on sight — after the frame: Home under this page rebuilds on the
  /// change, and may not in the middle of a build.
  void _onChange() {
    final unread = [
      for (final n in widget.controller.notices)
        if (!n.read) n.id,
    ];
    if (unread.isEmpty) return;
    _fresh.addAll(unread);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.markAllRead();
    });
  }

  /// Fades piece [i] in and lifts it into place, one after another.
  Widget _rise(int i, Widget child) {
    final piece = _pieces[i.clamp(0, _pieces.length - 1)];
    return AnimatedBuilder(
      animation: piece,
      child: child,
      builder: (context, child) => splashRise(piece.value, child!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final controller = widget.controller;

    return Scaffold(
      key: const ValueKey('notifications'),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.checkNow,
          color: colors.accent,
          backgroundColor: colors.surfaceRaised,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final now = widget.now();
              final groups = _groups(controller.notices, now);

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.pagePadding,
                  vertical: 12,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _maxContentWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _rise(0, _Header(controller: controller)),
                        const SizedBox(height: 18),
                        if (!controller.hasStudent)
                          _rise(
                            1,
                            _Note(
                              icon: Icons.person_add_alt_1_rounded,
                              title: NoticeStrings.setUpTitle,
                              body: NoticeStrings.setUpBody,
                              action: widget.onSetUp,
                            ),
                          )
                        else ...[
                          if (controller.stopped)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _rise(
                                1,
                                _Note(
                                  icon: Icons.pause_circle_outline_rounded,
                                  title: NoticeStrings.stoppedTitle,
                                  body: NoticeStrings.stoppedBody,
                                  action: widget.onSetUp,
                                  warning: true,
                                ),
                              ),
                            ),
                          if (groups.isEmpty)
                            _rise(
                              1,
                              const _Note(
                                icon: Icons.notifications_none_rounded,
                                title: NoticeStrings.emptyTitle,
                                body: NoticeStrings.emptyBody,
                              ),
                            )
                          else
                            for (final (i, (label, notices)) in groups.indexed)
                              _rise(
                                2 + i,
                                _Group(
                                  label: label,
                                  notices: notices,
                                  fresh: _fresh,
                                  now: now,
                                  onTap: widget.onOpenAttendance,
                                ),
                              ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// TODAY, YESTERDAY and EARLIER, by when the phone heard of each — the
  /// order they came in. Empty groups are left out.
  static List<(String, List<StudentNotice>)> _groups(
    List<StudentNotice> notices,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final byGroup = <String, List<StudentNotice>>{};
    for (final n in notices) {
      final label = !n.at.isBefore(today)
          ? NoticeStrings.today
          : !n.at.isBefore(yesterday)
          ? NoticeStrings.yesterday
          : NoticeStrings.earlier;
      (byGroup[label] ??= []).add(n);
    }
    return [
      for (final label in [
        NoticeStrings.today,
        NoticeStrings.yesterday,
        NoticeStrings.earlier,
      ])
        if (byGroup[label] case final list?) (label, list),
    ];
  }
}

/// Back, the title, and whether the feed is listening.
class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final NotificationsController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('notifications.back'),
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: AppStrings.homeBack,
              icon: const Icon(Icons.arrow_back_rounded),
              color: colors.textSecondary,
            ),
            const SizedBox(width: 4),
            // Wraps rather than runs off a small phone at a large text size.
            Flexible(
              child: Text(
                NoticeStrings.title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Text(
            NoticeStrings.intro,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: colors.textSecondary,
            ),
          ),
        ),
        if (controller.hasStudent && !controller.stopped) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ValueListenableBuilder<DateTime?>(
              valueListenable: controller.checkedAt,
              builder: (context, at, _) => Container(
                key: const ValueKey('notifications.live'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.accentWash(0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colors.accentWash(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Still: a dot that pulses forever is a loop with
                    // nothing happening.
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: colors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      at == null
                          ? NoticeStrings.waiting
                          : NoticeStrings.checked(_clockTime(at)),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// One day's heading, then its notices on one panel.
class _Group extends StatelessWidget {
  const _Group({
    required this.label,
    required this.notices,
    required this.fresh,
    required this.now,
    required this.onTap,
  });

  final String label;
  final List<StudentNotice> notices;
  final Set<String> fresh;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: colors.textSecondary,
              ),
            ),
          ),
          SurfacePanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < notices.length; i++)
                  _NoticeRow(
                    notice: notices[i],
                    fresh: fresh.contains(notices[i].id),
                    first: i == 0,
                    now: now,
                    onTap: onTap,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({
    required this.notice,
    required this.fresh,
    required this.first,
    required this.now,
    required this.onTap,
  });

  final StudentNotice notice;

  /// New when the page opened, or since.
  final bool fresh;
  final bool first;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = switch (notice.kind) {
      NoticeKind.present => colors.success,
      NoticeKind.late => colors.warning,
      NoticeKind.removed => colors.danger,
    };

    return InkWell(
      key: ValueKey('notifications.${notice.id}'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          color: fresh ? colors.accentWash(0.06) : null,
          border: first ? null : Border(top: BorderSide(color: colors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(notice.icon, size: 20, color: tint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          notice.headline,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      if (fresh) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.accentWash(0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            NoticeStrings.newBadge,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: colors.accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notice.line(now),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: colors.textSecondary,
                    ),
                  ),
                  if (notice.offline) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 13,
                          color: colors.textMuted,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            NoticeStrings.offline,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _ago(notice.at),
              style: TextStyle(fontSize: 11.5, color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  /// "just now", "5 min ago", "2 hrs ago" today; the time yesterday — the
  /// heading already says which day; the day itself before that.
  String _ago(DateTime at) {
    final since = now.difference(at);
    if (since.inMinutes < 1) return NoticeStrings.justNow;
    if (since.inMinutes < 60) return NoticeStrings.minutesAgo(since.inMinutes);
    bool on(DateTime day) =>
        at.year == day.year && at.month == day.month && at.day == day.day;
    if (on(now)) return NoticeStrings.hoursAgo(since.inHours);
    if (on(DateTime(now.year, now.month, now.day - 1))) return _clockTime(at);
    return DateLabel.short(at);
  }
}

/// `8:05 AM`.
String _clockTime(DateTime t) {
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// The page with nothing to list: why, and the way on when there is one.
class _Note extends StatelessWidget {
  const _Note({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.warning = false,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Opens My Profile.
  final VoidCallback? action;

  /// Amber: the feed has stopped, which is a warning.
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = warning ? colors.warning : colors.accent;
    final action = this.action;

    return SurfacePanel(
      borderColor: warning ? colors.warning.withValues(alpha: 0.35) : null,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: tint),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: colors.textSecondary,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('notifications.setUp'),
              onPressed: action,
              icon: const Icon(Icons.account_circle_outlined, size: 19),
              label: const Text(NoticeStrings.setUpAction),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
