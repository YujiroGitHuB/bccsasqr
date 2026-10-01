import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/phone_lock_controller.dart';
import '../controllers/profile_controller.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../services/device_lock.dart';
import 'student_menu.dart' show confirmForget;
import 'widgets/fade_scale_switcher.dart';
import 'widgets/island.dart';
import 'widgets/phone_lock_screen.dart';
import 'widgets/profile_avatar.dart';

/// The student's side behind the phone's own lock — fingerprint, face or
/// screen lock — once the student has turned it on: the instructor's
/// scanner lock (ScannerFlow), for a student. Asked for on 2026-10-01.
///
/// Off until the student turns it on: offered once, right after the phone
/// is set up in My Profile, and in Settings → Privacy after that. With it
/// on, the app opens on the lock, and locks again after a minute away. The
/// lock goes with the profile — "Not you?" — and turns itself off, saying
/// so, if the phone's screen lock is taken away.
///
/// Nothing of the side is built before the first unlock, so Home does not
/// ask the server for anything behind the lock. After that it is kept under
/// the lock, with its tickers stopped — Check in's camera included.
class StudentLockGate extends StatefulWidget {
  const StudentLockGate({
    super.key,
    required this.profile,
    required this.deviceLock,
    required this.store,
    required this.builder,
    this.clock,
  });

  /// Whose phone it is: on the lock screen, and the lock goes with it.
  final ProfileController profile;
  final DeviceLock deviceLock;
  final LockSwitchStore store;

  /// The lock's clock; tests step it past [PhoneLockController.relockAfter].
  final DateTime Function()? clock;

  /// The student's side, handed the lock — Settings has its switch.
  final Widget Function(BuildContext context, PhoneLockController lock) builder;

  @override
  State<StudentLockGate> createState() => _StudentLockGateState();
}

class _StudentLockGateState extends State<StudentLockGate> {
  late final PhoneLockController _lock = PhoneLockController(
    device: widget.deviceLock,
    store: widget.store,
    reason: StudentLockStrings.reason,
    enableReason: StudentLockStrings.enableReason,
    notUnlocked: StudentLockStrings.notUnlocked,
    clock: widget.clock,
  );

  late final AppLifecycleListener _lifecycle;

  /// The side, built once the lock has nothing to show over it, and kept —
  /// under the lock too — so a minute away does not lose the tab or a code
  /// half typed. The same instance each time.
  Widget? _side;

  bool _wasLocked = false;

  /// Whether a student was set up on this phone when last looked; null
  /// until the profile has been read.
  bool? _hadProfile;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: _lock.onHidden,
      onShow: () => unawaited(_lock.onShown()),
    );
    _lock.addListener(_onLock);
    widget.profile.addListener(_onProfile);
    _onProfile();
    unawaited(_lock.load());
  }

  @override
  void dispose() {
    widget.profile.removeListener(_onProfile);
    _lock.removeListener(_onLock);
    _lifecycle.dispose();
    _lock.dispose();
    super.dispose();
  }

  void _onLock() {
    final locked = _lock.locked;
    // The lock covers the whole side, so nothing opened over it — the code
    // full screen, What's New — may stay in front of it.
    if (!_wasLocked && locked) _closePagesAbove();
    _wasLocked = locked;

    if (_lock.lost) {
      // Nothing left to ask for: the lock turns itself off, and says so.
      unawaited(_lock.forget());
      if (mounted) {
        Island.show(
          context,
          const IslandMessage(
            title: StudentLockStrings.lostTitle,
            body: StudentLockStrings.lostBody,
            tone: IslandTone.warning,
            icon: Icons.fingerprint_rounded,
            hold: Duration(seconds: 6),
          ),
        );
      }
    }
  }

  /// A student set up just now — offer the lock; forgotten — the lock goes
  /// with them.
  void _onProfile() {
    final profile = widget.profile;
    if (!profile.loaded) return;
    final has = profile.profile != null;
    final had = _hadProfile;
    _hadProfile = has;
    // The first look, once the profile is read: nothing has changed yet.
    if (had == null) return;
    if (had && !has) unawaited(_lock.forget());
    if (!had && has) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_offerLock());
      });
    }
  }

  /// Right after the set-up, on a phone with a screen lock: asked once. The
  /// switch is in Settings → Privacy after that.
  Future<void> _offerLock() async {
    if (!_lock.ready || !_lock.available || _lock.enabled) return;
    final yes = await showLockOffer(
      context,
      title: StudentLockStrings.offerTitle,
      body: StudentLockStrings.offerBody,
    );
    if (!yes || !mounted) return;
    final on = await _lock.enable();
    if (!on || !mounted) return;
    Island.show(
      context,
      const IslandMessage(
        title: StudentLockStrings.on,
        tone: IslandTone.success,
        icon: Icons.fingerprint_rounded,
      ),
    );
  }

  void _closePagesAbove() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || route.isCurrent) return;
    Navigator.of(context).popUntil((r) => r == route);
  }

  /// "Not you?" on the lock screen: the same question as the Menu's. The
  /// phone forgets the student — and the lock with them — and opens on the
  /// set-up; nothing of theirs is shown.
  Future<void> _notYou() async {
    final kept = widget.profile.profile;
    if (kept == null) return;
    if (await confirmForget(context, kept)) await widget.profile.forget();
  }

  /// What the lock has to show in front of the side, or null when it is
  /// open.
  Widget? _cover() {
    // Until the switch is read, the side might be behind the lock.
    if (!_lock.ready) return const SizedBox.shrink(key: ValueKey('reading'));
    if (!_lock.locked) return null;

    final kept = widget.profile.profile;
    return PhoneLockScreen(
      key: const ValueKey('studentLock'),
      lock: _lock,
      title: StudentLockStrings.title,
      body: StudentLockStrings.body,
      owner: kept == null
          ? null
          : LockOwnerChip(
              avatar: ProfileAvatar(
                size: 30,
                name: kept.record.fullName,
                photo: kept.photo,
                photoUrl: kept.photoUrl,
              ),
              name: kept.givenName,
            ),
      alternative: kept == null
          ? null
          : (
              name: 'notYou',
              icon: Icons.person_remove_alt_1_outlined,
              label: StudentLockStrings.notYou,
              onPressed: () => unawaited(_notYou()),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_lock, widget.profile]),
      builder: (context, _) {
        final cover = _cover();
        if (cover == null) {
          _side ??= KeyedSubtree(
            key: const ValueKey('studentSide'),
            child: Builder(
              builder: (context) => widget.builder(context, _lock),
            ),
          );
        }
        final covered = cover != null;

        // Under the lock as it fades: the canvas, not black.
        return ColoredBox(
          color: context.colors.canvas,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Out of sight it is still: no camera, no taps, no focus.
              TickerMode(
                enabled: !covered,
                child: IgnorePointer(
                  ignoring: covered,
                  child: ExcludeSemantics(
                    excluding: covered,
                    child: ExcludeFocus(
                      excluding: covered,
                      child: _side ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
              FadeScaleSwitcher(
                child: cover ?? const SizedBox.shrink(key: ValueKey('open')),
              ),
            ],
          ),
        );
      },
    );
  }
}
