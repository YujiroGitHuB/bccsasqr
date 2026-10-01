import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/my_attendance_controller.dart';
import '../controllers/my_qr_controller.dart';
import '../controllers/notifications_controller.dart';
import '../controllers/profile_controller.dart';
import '../controllers/whats_new_controller.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/date_label.dart';
import '../models/attendance_history.dart';
import '../models/student_profile.dart';
import '../services/saved_qr_store.dart';
import 'instructor_home.dart' show codeParts, shortTime;
import 'student_shell.dart';
import 'widgets/destination_card.dart';
import 'widgets/press_scale.dart';
import 'widgets/profile_avatar.dart';
import 'widgets/splash_parts.dart';
import 'widgets/student_card_3d.dart';
import 'widgets/surface_panel.dart';

/// The student's Home — what their phone opens on, with the Menu button
/// under it (student_shell.dart). Designed on 2026-10-01 to match the
/// instructor's, around what a student comes for: the QR code itself, ready
/// to show, whether today's scan reached the records, and their attendance
/// at a glance.
///
/// Everything personal needs the phone set up once in My Profile (number and
/// last name). Until then the QR card offers that, and My QR Code by number
/// as before.
///
/// The pieces rise in one after another the first time the screen shows,
/// not again on the way back from another tab.
///
/// Nothing on it needs a pull to stay current: the live feed adds a scan to
/// the Today card and the summary the moment it lands, and the bell beside
/// What's New counts what is new in Notifications.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.profile,
    required this.qr,
    required this.attendance,
    required this.onOpen,
    required this.onShowQr,
    this.whatsNewBuilder,
    this.whatsNew,
    this.notificationsBuilder,
    this.notifications,
    this.cardTurn,
    this.now = DateTime.now,
  });

  final ProfileController profile;
  final MyQrController qr;
  final MyAttendanceController attendance;

  /// Shows another tab, as the Menu would.
  final ValueChanged<StudentTab> onOpen;

  /// Puts the code full screen for the scanner.
  final VoidCallback onShowQr;

  /// The What's New page, from the button beside the greeting. While
  /// [whatsNew] says this phone has not opened the newest release, the
  /// button carries a dot and a card sits under the greeting — until the
  /// page is opened or the card closed.
  final WidgetBuilder? whatsNewBuilder;
  final WhatsNewController? whatsNew;

  /// Notifications, from the bell beside the greeting, which counts what
  /// the student has not seen there yet.
  final WidgetBuilder? notificationsBuilder;
  final NotificationsController? notifications;

  /// How long the card rests on each face before turning over by itself;
  /// null keeps it still (see [StudentCard3D.turnEvery]).
  final Duration? cardTurn;

  /// The clock the greeting is picked by. Overridable for tests.
  final DateTime Function() now;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  static const double _maxContentWidth = 560;

  /// Made in initState, not lazily, like every controller a screen owns.
  late final AnimationController _intro;
  late final List<Animation<double>> _pieces;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    _pieces = [
      for (var i = 0; i < 6; i++)
        CurvedAnimation(
          parent: _intro,
          curve: Interval(
            0.08 * i,
            (0.08 * i + 0.45).clamp(0.0, 1.0),
            curve: Curves.easeOutCubic,
          ),
        ),
    ];
    // Back in the app after class: today's scan may be in the records now.
    _lifecycle = AppLifecycleListener(onResume: _refreshAttendance);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _intro.dispose();
    super.dispose();
  }

  void _refreshAttendance() => unawaited(widget.attendance.refresh());

  Future<void> _refresh() => Future.wait([
    widget.attendance.refresh(),
    widget.profile.refresh(),
    widget.qr.reload(),
  ]);

  void _openNews() {
    final news = widget.whatsNewBuilder;
    if (news == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: news));
  }

  void _openNotifications() {
    final page = widget.notificationsBuilder;
    if (page == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: page));
  }

  String get _greeting {
    final hour = widget.now().hour;
    return hour < 12
        ? AppStrings.homeMorning
        : hour < 18
        ? AppStrings.homeAfternoon
        : AppStrings.homeEvening;
  }

  /// Fades [child] in and lifts it into place as piece [i] arrives.
  Widget _rise(int i, Widget child) => AnimatedBuilder(
    animation: _pieces[i],
    child: child,
    builder: (context, child) => splashRise(_pieces[i].value, child!),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.profile,
        widget.qr,
        widget.attendance,
        widget.whatsNew ?? const _Silent(),
        widget.notifications ?? const _Silent(),
      ]),
      builder: (context, _) {
        final profile = widget.profile.profile;
        final unread = widget.whatsNew?.unread ?? false;
        final askForPhoto =
            widget.profile.loaded && profile != null && !profile.hasPhoto;

        return Scaffold(
          key: const ValueKey('studentHome'),
          // The foot is left to the padding, so the page runs on under the
          // Menu button and still ends clear of it.
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: colors.accent,
              backgroundColor: colors.surfaceRaised,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  AppTheme.pagePadding,
                  12,
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
                        _rise(
                          0,
                          _TopBar(
                            greeting: _greeting,
                            profile: profile,
                            controller: widget.profile,
                            unread: unread,
                            onProfile: () => widget.onOpen(StudentTab.profile),
                            onWhatsNew: widget.whatsNewBuilder == null
                                ? null
                                : _openNews,
                            notices: widget.notifications?.unread ?? 0,
                            onNotifications: widget.notificationsBuilder == null
                                ? null
                                : _openNotifications,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _Folding(
                          shown: askForPhoto,
                          child: _PhotoNudge(
                            required: profile?.photoRequired ?? false,
                            onTap: () => widget.onOpen(StudentTab.profile),
                          ),
                        ),
                        _Folding(
                          shown: unread && widget.whatsNewBuilder != null,
                          child: _WhatsNewCard(
                            onTap: _openNews,
                            onClose: () => widget.whatsNew?.markSeen(),
                          ),
                        ),
                        _rise(
                          1,
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            child: switch (widget.qr.code) {
                              final code? => _CardSection(
                                key: const ValueKey('home.card'),
                                code: code,
                                profile: widget.profile,
                                onShow: widget.onShowQr,
                                turnEvery: widget.cardTurn,
                              ),
                              null => _QrCard(
                                key: const ValueKey('home.ask'),
                                status: widget.qr.status,
                                message: widget.qr.message,
                                onMake: () => widget.onOpen(StudentTab.qr),
                                onSetUp: () =>
                                    widget.onOpen(StudentTab.profile),
                              ),
                            },
                          ),
                        ),
                        _Folding(
                          shown:
                              profile != null &&
                              widget.attendance.history != null,
                          padding: const EdgeInsets.only(top: 16),
                          child: _rise(
                            2,
                            _TodayCard(today: widget.attendance.today),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _rise(3, _Shortcuts(onOpen: widget.onOpen)),
                        const SizedBox(height: 24),
                        _rise(
                          4,
                          profile == null
                              ? PressScale(
                                  child: DestinationCard(
                                    key: const ValueKey('home.attendanceCard'),
                                    icon: Icons.event_available_rounded,
                                    title: AppStrings.homeTrackerTitle,
                                    body: AppStrings.homeTrackerBody,
                                    onTap: () =>
                                        widget.onOpen(StudentTab.tracker),
                                  ),
                                )
                              : _AttendanceSummary(
                                  controller: widget.attendance,
                                  now: widget.now,
                                  onSeeAll: () =>
                                      widget.onOpen(StudentTab.tracker),
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

/// Folds [child] in and out rather than popping it, so the cards under it
/// slide instead of jumping.
class _Folding extends StatelessWidget {
  const _Folding({
    required this.shown,
    required this.child,
    this.padding = const EdgeInsets.only(bottom: 16),
  });

  final bool shown;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: const Duration(milliseconds: 240),
    curve: Curves.easeOut,
    alignment: Alignment.topCenter,
    child: shown
        ? Padding(padding: padding, child: child)
        : const SizedBox(width: double.infinity),
  );
}

/// The student's face, "Good morning," and their name — or, before the
/// phone is set up, the question the cards answer — then Notifications and
/// What's New.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.greeting,
    required this.profile,
    required this.controller,
    required this.unread,
    required this.onProfile,
    required this.onWhatsNew,
    this.notices = 0,
    this.onNotifications,
  });

  final String greeting;
  final StudentProfile? profile;
  final ProfileController controller;
  final bool unread;
  final VoidCallback onProfile;
  final VoidCallback? onWhatsNew;

  /// How many notifications are new, on the bell.
  final int notices;
  final VoidCallback? onNotifications;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final kept = profile;
    final news = onWhatsNew;
    final bell = onNotifications;
    final buttonStyle = IconButton.styleFrom(
      backgroundColor: colors.surface,
      side: BorderSide(color: colors.border),
      minimumSize: const Size(46, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );

    return Row(
      children: [
        Tooltip(
          message: kept == null ? ProfileStrings.setUp : ProfileStrings.open,
          child: PressScale(
            scale: 0.92,
            child: Material(
              type: MaterialType.transparency,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey('home.profile'),
                onTap: onProfile,
                child: ProfileAvatar(
                  size: 50,
                  name: kept?.record.fullName,
                  photo: controller.pendingPhoto ?? kept?.photo,
                  photoUrl: kept?.photoUrl,
                  busy: controller.isSaving,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kept == null ? greeting : '$greeting,',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                kept == null ? AppStrings.homeQuestion : kept.givenName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: kept == null ? 19 : 22,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (bell != null) ...[
          const SizedBox(width: 8),
          IconButton(
            key: const ValueKey('home.notifications'),
            onPressed: bell,
            tooltip: notices == 0
                ? NoticeStrings.open
                : NoticeStrings.openUnread(notices),
            style: buttonStyle,
            color: notices == 0 ? colors.textSecondary : colors.accent,
            icon: Badge(
              isLabelVisible: notices > 0,
              label: Text(notices > 9 ? '9+' : '$notices'),
              backgroundColor: colors.accent,
              textColor: colors.onAccent,
              child: Icon(
                notices == 0
                    ? Icons.notifications_none_rounded
                    : Icons.notifications_active_rounded,
              ),
            ),
          ),
        ],
        if (news != null) ...[
          const SizedBox(width: 8),
          IconButton(
            key: const ValueKey('home.whatsNew'),
            onPressed: news,
            tooltip: unread ? WhatsNewStrings.openUnread : WhatsNewStrings.open,
            style: buttonStyle,
            color: unread ? colors.accent : colors.textSecondary,
            icon: Badge(
              isLabelVisible: unread,
              smallSize: 9,
              backgroundColor: colors.accent,
              child: const Icon(Icons.auto_awesome_outlined),
            ),
          ),
        ],
      ],
    );
  }
}

/// No code on the phone yet: the one step that gets the student one — or,
/// while the phone asks, a spinner. The code itself is [_CardSection].
class _QrCard extends StatelessWidget {
  const _QrCard({
    super.key,
    required this.status,
    required this.message,
    required this.onMake,
    required this.onSetUp,
  });

  final MyQrStatus status;
  final String? message;
  final VoidCallback onMake;
  final VoidCallback onSetUp;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final Widget body = switch (status) {
      MyQrStatus.noProfile => _Ask(
        title: AppStrings.homeStudentTitle,
        body: StudentStrings.setUpBody,
        primary: _CardButton(
          name: 'setUp',
          icon: Icons.person_add_alt_1_rounded,
          label: StudentStrings.setUpAction,
          onPressed: onSetUp,
        ),
        secondary: TextButton.icon(
          key: const ValueKey('home.generator'),
          onPressed: onMake,
          icon: const Icon(Icons.qr_code_2_rounded, size: 18),
          label: const Text(StudentStrings.makeQrAction),
        ),
      ),
      MyQrStatus.needsTerms || MyQrStatus.unavailable => _Ask(
        title: StudentStrings.makeQrTitle,
        body: status == MyQrStatus.unavailable
            ? (message == null
                  ? StudentStrings.makeQrOffline
                  : '$message ${StudentStrings.makeQrOffline}')
            : StudentStrings.makeQrBody,
        primary: _CardButton(
          name: 'generator',
          icon: Icons.qr_code_2_rounded,
          label: StudentStrings.makeQrAction,
          onPressed: onMake,
        ),
      ),
      MyQrStatus.loading || MyQrStatus.ready => const _Loading(),
    };

    return Container(
      key: const ValueKey('home.qrCard'),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(gradient: colors.headerRule),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: KeyedSubtree(key: ValueKey(status), child: body),
            ),
          ),
        ],
      ),
    );
  }
}

/// The code on the phone, on a card the student can turn — the student on
/// the front, the code on the back (see [StudentCard3D]) — with the switch
/// between the two faces and the way to put the code full screen.
class _CardSection extends StatefulWidget {
  const _CardSection({
    super.key,
    required this.code,
    required this.profile,
    required this.onShow,
    this.turnEvery,
  });

  final SavedQr code;

  /// For the photo on the front: the one being saved, then the one kept.
  final ProfileController profile;
  final VoidCallback onShow;

  /// The card's own turns — see [StudentCard3D.turnEvery].
  final Duration? turnEvery;

  @override
  State<_CardSection> createState() => _CardSectionState();
}

class _CardSectionState extends State<_CardSection> {
  final ValueNotifier<CardSide> _side = ValueNotifier(CardSide.front);

  @override
  void dispose() {
    _side.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final kept = widget.profile.profile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          StudentStrings.qrLabel,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: colors.textSecondary,
          ),
        ),
        Center(
          child: StudentCard3D(
            record: widget.code.record,
            payload: widget.code.payload,
            side: _side,
            photo: widget.profile.pendingPhoto ?? kept?.photo,
            photoUrl: kept?.photoUrl,
            turnEvery: widget.turnEvery,
          ),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app_outlined, size: 16, color: colors.accent),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    StudentStrings.cardHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        ValueListenableBuilder<CardSide>(
          valueListenable: _side,
          builder: (context, side, _) => SegmentedButton<CardSide>(
            segments: [
              for (final (face, label, icon) in [
                (
                  CardSide.front,
                  StudentStrings.cardSideFront,
                  Icons.badge_outlined,
                ),
                (
                  CardSide.back,
                  StudentStrings.cardSideBack,
                  Icons.qr_code_2_rounded,
                ),
              ])
                ButtonSegment(
                  value: face,
                  icon: Icon(icon, size: 18),
                  label: Text(
                    label,
                    key: ValueKey('home.cardSide.${face.name}'),
                  ),
                ),
            ],
            selected: {side},
            showSelectedIcon: false,
            onSelectionChanged: (picked) => _side.value = picked.first,
            style: SegmentedButton.styleFrom(
              minimumSize: const Size(0, 44),
              backgroundColor: colors.surfaceSunken,
              foregroundColor: colors.textSecondary,
              selectedBackgroundColor: colors.accentWash(0.14),
              selectedForegroundColor: colors.accent,
              side: BorderSide(color: colors.border),
              textStyle: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _CardButton(
          name: 'showQr',
          icon: Icons.fit_screen_rounded,
          label: StudentStrings.showToScanner,
          onPressed: widget.onShow,
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.phone_android_rounded,
              size: 15,
              color: colors.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                StudentStrings.savedOffline,
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// No code to show yet: what it takes, and the button for it.
class _Ask extends StatelessWidget {
  const _Ask({
    required this.title,
    required this.body,
    required this.primary,
    this.secondary,
  });

  final String title;
  final String body;
  final Widget primary;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final secondary = this.secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: colors.accentWash(0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.qr_code_2_rounded, color: colors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          body,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.45,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        primary,
        if (secondary != null) ...[const SizedBox(height: 4), secondary],
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 112,
    child: Center(
      child: SizedBox.square(
        dimension: 26,
        child: CircularProgressIndicator(
          strokeWidth: 2.6,
          color: context.colors.accent,
        ),
      ),
    ),
  );
}

/// The card's one filled button.
class _CardButton extends StatelessWidget {
  const _CardButton({
    required this.name,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  /// `home.<name>`, for tests.
  final String name;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    key: ValueKey('home.$name'),
    onPressed: onPressed,
    icon: Icon(icon, size: 20),
    label: Text(label),
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
    ),
  );
}

/// Whether today's scan reached the records — green once it has, the
/// colour the records use for present.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.today});

  final List<TodayScan> today;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final present = today.isNotEmpty;
    final tint = present ? colors.success : colors.textSecondary;
    final subjects = {for (final s in today) s.subject}.length;

    final String title;
    final String body;
    if (present) {
      final first = today.first;
      title = subjects == 1
          ? StudentStrings.presentToday
          : StudentStrings.presentTodayIn(subjects);
      body = [
        first.subject,
        shortTime(first.day.timeIn),
        if (first.day.late) StudentStrings.late.toLowerCase(),
      ].join(' · ');
    } else {
      title = StudentStrings.noScanToday;
      body = StudentStrings.noScanTodayBody;
    }

    return Container(
      key: const ValueKey('home.today'),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: present
            ? colors.success.withValues(alpha: 0.10)
            : colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: present
              ? colors.success.withValues(alpha: 0.32)
              : colors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: present ? colors.success : colors.surfaceSunken,
              shape: BoxShape.circle,
              border: present ? null : Border.all(color: colors.border),
            ),
            child: Icon(
              present ? Icons.check_rounded : Icons.schedule_rounded,
              size: 20,
              color: present ? colors.onAccent : tint,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
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

/// The rest of the student's side a tap away, as the instructor's Home has
/// its own — quick ways in, all of them in the Menu too.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts({required this.onOpen});

  final ValueChanged<StudentTab> onOpen;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (name, tab, icon, label) in [
          (
            'tracker',
            StudentTab.tracker,
            Icons.event_available_rounded,
            StudentStrings.attendance,
          ),
          (
            'checkIn',
            StudentTab.checkIn,
            Icons.qr_code_scanner_rounded,
            StudentStrings.checkIn,
          ),
          (
            'profileShortcut',
            StudentTab.profile,
            Icons.account_circle_outlined,
            NavStrings.profile,
          ),
          (
            'settings',
            StudentTab.settings,
            Icons.settings_outlined,
            NavStrings.settings,
          ),
        ])
          Expanded(
            child: _Shortcut(
              name: name,
              icon: icon,
              label: label,
              onTap: () => onOpen(tab),
            ),
          ),
      ],
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.name,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  /// `home.<name>`, for tests.
  final String name;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Tooltip(
      message: label,
      child: PressScale(
        scale: 0.92,
        child: InkWell(
          key: ValueKey('home.$name'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 54,
                  width: 54,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(icon, size: 24, color: colors.accent),
                ),
                const SizedBox(height: 7),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
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

/// My Attendance at a glance: the three numbers, and the subjects most
/// recently attended. Days present only — the records hold no count of the
/// classes held, so there is no percentage to give.
class _AttendanceSummary extends StatelessWidget {
  const _AttendanceSummary({
    required this.controller,
    required this.now,
    required this.onSeeAll,
  });

  final MyAttendanceController controller;
  final DateTime Function() now;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final history = controller.history;

    final Widget body;
    if (history == null) {
      body = Padding(
        padding: const EdgeInsets.all(18),
        child: controller.error != null
            ? Text(
                StudentStrings.attendanceFailed,
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              )
            : Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: colors.accent,
                  ),
                ),
              ),
      );
    } else {
      final recent = [...history.subjects]
        ..sort((a, b) => _latest(b).compareTo(_latest(a)));
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  _Stat(
                    value: '${history.total}',
                    label: StudentStrings.daysPresent,
                  ),
                  VerticalDivider(width: 1, color: colors.border),
                  _Stat(
                    value: '${history.subjects.length}',
                    label: StudentStrings.subjects,
                  ),
                  VerticalDivider(width: 1, color: colors.border),
                  _Stat(
                    value: '${controller.lateCount}',
                    label: StudentStrings.late,
                    dot: colors.warning,
                  ),
                ],
              ),
            ),
          ),
          if (history.isEmpty)
            _Line(text: StudentStrings.attendanceEmpty)
          else
            for (final subject in recent.take(3))
              _SubjectRow(subject: subject, now: now()),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                AppStrings.homeTrackerTitle.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: colors.textSecondary,
                ),
              ),
            ),
            TextButton(
              key: const ValueKey('home.seeAll'),
              onPressed: onSeeAll,
              child: const Text(StudentStrings.seeAll),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SurfacePanel(padding: EdgeInsets.zero, child: body),
      ],
    );
  }

  static DateTime _latest(SubjectAttendance s) =>
      s.days.isEmpty ? DateTime(0) : (s.days.first.date ?? DateTime(0));
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.dot});

  final String value;
  final String label;

  /// The state's colour beside the label — amber for late.
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dot = this.dot;

    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (dot != null) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One subject: its initials on a tile, its name, when last attended, and
/// how many days.
class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.subject, required this.now});

  final SubjectAttendance subject;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (tile, _) = codeParts(null, subject.subject);
    final last = subject.days.isEmpty ? null : subject.days.first;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                if (last != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    StudentStrings.last(_when(last)),
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${subject.count}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                StudentStrings.days(subject.count),
                style: TextStyle(fontSize: 11, color: colors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "today, 8:04 AM", or "Wed, Sep 30".
  String _when(AttendanceDay day) {
    final d = day.date;
    if (d == null) return day.rawDate;
    final today =
        d.year == now.year && d.month == now.month && d.day == now.day;
    return today
        ? '${StudentStrings.today}, ${shortTime(day.timeIn)}'
        : DateLabel.short(d);
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: context.colors.border)),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
    ),
  );
}

/// "Add your photo" — under the greeting until one is on file. Amber only
/// when the school requires it, because then it is a warning.
class _PhotoNudge extends StatelessWidget {
  const _PhotoNudge({required this.required, required this.onTap});

  final bool required;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = required ? colors.warning : colors.accent;

    return PressScale(
      child: MergeSemantics(
        child: Stack(
          key: const ValueKey('home.photoNudge'),
          children: [
            SurfacePanel(
              borderColor: tint.withValues(alpha: 0.35),
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      required
                          ? Icons.warning_amber_rounded
                          : Icons.add_a_photo_outlined,
                      size: 20,
                      color: tint,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          required
                              ? ProfileStrings.nudgeRequiredTitle
                              : ProfileStrings.nudgeTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          required
                              ? ProfileStrings.nudgeRequiredBody
                              : ProfileStrings.nudgeBody,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded, color: colors.textMuted),
                ],
              ),
            ),
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "New in this update" — under the greeting until the page is opened once
/// or the card is closed.
class _WhatsNewCard extends StatelessWidget {
  const _WhatsNewCard({required this.onTap, required this.onClose});

  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Laid out like a destination, with the ink on top of the panel; the
    // close button sits above the ink so a tap on it only closes.
    return Stack(
      key: const ValueKey('home.whatsNewCard'),
      children: [
        MergeSemantics(
          child: Stack(
            children: [
              SurfacePanel(
                borderColor: colors.accentWash(0.35),
                padding: const EdgeInsets.fromLTRB(16, 14, 44, 14),
                child: Row(
                  children: [
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: colors.accentWash(0.14),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 21,
                        color: colors.accent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            WhatsNewStrings.cardTitle,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            WhatsNewStrings.cardBody,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            key: const ValueKey('home.whatsNewClose'),
            onPressed: onClose,
            tooltip: WhatsNewStrings.cardClose,
            iconSize: 18,
            icon: const Icon(Icons.close_rounded),
            color: colors.textMuted,
          ),
        ),
      ],
    );
  }
}

/// A [Listenable] that never fires — for a home screen with no What's New.
class _Silent implements Listenable {
  const _Silent();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
