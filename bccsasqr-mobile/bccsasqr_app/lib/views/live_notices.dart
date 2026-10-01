import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/notifications_controller.dart';
import '../controllers/phone_lock_controller.dart';
import '../controllers/settings_controller.dart';
import '../core/constants/app_strings.dart';
import '../models/student_notice.dart';
import 'notifications_page.dart' show NoticeLook;
import 'widgets/island.dart';

/// The live feed (NotificationsController), bound to the student's side on
/// screen: it listens while the side is open — not in the background, not
/// under the lock — and says what it brings on the island, over whatever
/// page is up. Show to scanner included: a pushed page leaves this mounted
/// under it.
///
/// The island is the Attendance alerts switch in Settings; with it off the
/// list in Notifications still fills.
class LiveNotices extends StatefulWidget {
  const LiveNotices({
    super.key,
    required this.controller,
    required this.settings,
    required this.child,
    this.lock,
    this.onOpen,
    this.now = DateTime.now,
  });

  final NotificationsController controller;
  final SettingsController settings;

  /// The student's lock: nothing is asked for or shown while it is up.
  final PhoneLockController? lock;

  /// Opens Notifications — a tap on the island.
  final VoidCallback? onOpen;

  /// The clock the island's times are worded by. Overridable for tests.
  final DateTime Function() now;

  final Widget child;

  @override
  State<LiveNotices> createState() => _LiveNoticesState();
}

class _LiveNoticesState extends State<LiveNotices> {
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<List<StudentNotice>>? _arrivals;

  /// The app is on screen — in front, or only behind the notification shade.
  late bool _shown = _isShown(WidgetsBinding.instance.lifecycleState);

  static bool _isShown(AppLifecycleState? state) =>
      state == null ||
      state == AppLifecycleState.resumed ||
      state == AppLifecycleState.inactive;

  bool get _open => _shown && !(widget.lock?.locked ?? false);

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _shown = _isShown(state);
        _update();
      },
    );
    widget.lock?.addListener(_update);
    _arrivals = widget.controller.arrivals.listen(_onArrival);
    _update();
  }

  @override
  void didUpdateWidget(LiveNotices oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lock != widget.lock) {
      oldWidget.lock?.removeListener(_update);
      widget.lock?.addListener(_update);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.setActive(false);
      unawaited(_arrivals?.cancel());
      _arrivals = widget.controller.arrivals.listen(_onArrival);
    }
    _update();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    widget.lock?.removeListener(_update);
    unawaited(_arrivals?.cancel());
    widget.controller.setActive(false);
    super.dispose();
  }

  void _update() => widget.controller.setActive(_open);

  void _onArrival(List<StudentNotice> notices) {
    if (!mounted || !_open || notices.isEmpty || !widget.settings.alerts) {
      return;
    }
    unawaited(HapticFeedback.mediumImpact());
    final now = widget.now();
    final first = notices.first;
    Island.show(
      context,
      notices.length == 1
          ? IslandMessage(
              title: first.headline,
              body: first.line(now),
              tone: first.tone,
              icon: first.icon,
              hold: const Duration(seconds: 4),
              onTap: widget.onOpen,
            )
          : IslandMessage(
              title: NoticeStrings.several(notices.length),
              body: NoticeStrings.severalBody(
                first.line(now),
                notices.length - 1,
              ),
              icon: Icons.notifications_active_rounded,
              hold: const Duration(seconds: 5),
              onTap: widget.onOpen,
            ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
