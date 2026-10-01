import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/scanner_controller.dart';
import '../../controllers/scanner_lock_controller.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../services/device_lock.dart';
import '../../services/offline_scan_store.dart';
import '../../services/scan_feedback.dart';
import '../../services/scanner_repository.dart';
import '../../services/speech_service.dart';
import '../widgets/fade_scale_switcher.dart';
import '../widgets/island.dart';
import 'scanner_intro.dart';
import 'scanner_lock_screen.dart';
import 'scanner_page.dart';
import 'scanner_sign_in_page.dart';

/// The instructor's side of the app, from opening to signing out. Owns the
/// scanner's controller and shows whichever screen the sign-in calls for: a
/// saved sign-in goes straight in — through the phone's lock first, when the
/// instructor turned it on — anything else to the sign-in form.
///
/// Signed in, it shows [home] (the instructor's shell) with the scanner in
/// it. Nothing of [home] is built before the sign-in, and it goes with the
/// sign-out: a student who taps "I'm an instructor" gets the form and no
/// more. The lock covers all of it, not just the scanner.
///
/// No splash of its own: the app's has just played, and a saved sign-in
/// opens straight on Home. The scanner's splash plays when the Scanner is
/// opened (ScannerIntro), as the other tabs' do.
class ScannerFlow extends StatefulWidget {
  const ScannerFlow({
    super.key,
    required this.repository,
    this.speech = const SilentSpeechService(),
    this.feedback = const SilentScanFeedback(),
    this.cameraBuilder = deviceQrCamera,
    this.keepAwake = deviceKeepAwake,
    this.deviceLock = const NoDeviceLock(),
    this.lockStore,
    this.lockClock,
    this.home,
    this.onSignedIn,
    this.onLeave,
    this.offlineStore,
    this.online,
  });

  /// What a signed-in instructor sees, handed the scanner to place in it,
  /// the scanner's controller — who is signed in, and the sign-out — and the
  /// phone's lock, whose switch is in Settings. The scanner alone when left
  /// out.
  final Widget Function(
    BuildContext context,
    WidgetBuilder scanner,
    ScannerController session,
    ScannerLockController lock,
  )?
  home;

  /// A sign-in typed or restored — the phone is an instructor's.
  final VoidCallback? onSignedIn;

  /// The back arrow on the sign-in form, and the phone's back button there:
  /// away from the instructor's side. None when left out.
  final VoidCallback? onLeave;

  final ScannerRepository repository;

  /// Where scans made with no internet are kept until sent, with the class
  /// lists they are checked against. In memory when left out.
  final OfflineScanStore? offlineStore;

  /// The phone's network, on and off — see [ScannerController]. Nothing is
  /// watched without it.
  final Stream<bool>? online;

  /// The phone's fingerprint, face or screen lock, and where the switch
  /// for it is kept. See [ScannerLockController].
  final DeviceLock deviceLock;
  final LockSwitchStore? lockStore;

  /// The lock's clock; tests step it past [ScannerLockController.relockAfter].
  final DateTime Function()? lockClock;
  final SpeechService speech;
  final ScanFeedback feedback;

  /// Overridable for tests; see [ScannerPage].
  final QrCameraBuilder cameraBuilder;
  final Future<void> Function(bool on) keepAwake;

  @override
  State<ScannerFlow> createState() => _ScannerFlowState();
}

class _ScannerFlowState extends State<ScannerFlow> {
  late final ScannerController _controller = ScannerController(
    repository: widget.repository,
    speech: widget.speech,
    feedback: widget.feedback,
    store: widget.offlineStore,
    online: widget.online,
  );

  late final ScannerLockController _lock = ScannerLockController(
    device: widget.deviceLock,
    store: widget.lockStore ?? MemoryLockSwitchStore(),
    clock: widget.lockClock,
  );

  /// Leaving the app cuts the voice off rather than letting it read the last
  /// result over whatever was opened.
  late final AppLifecycleListener _lifecycle;

  /// The scanner's messages, on the island. Heard here rather than on the
  /// Scanner tab: the app opens on Home, and scans kept offline are sent —
  /// and answered for — whichever tab is showing, the Scanner's never opened
  /// included.
  late final StreamSubscription<ScanAlert> _alerts;

  /// A sign-in typed just now, not one restored: it gets the welcome.
  bool _welcoming = false;

  /// A sign-in typed just now, on a phone with a screen lock: offer the lock
  /// once the welcome has played.
  bool _offerLock = false;

  /// The phone's screen lock went away while the lock was on — signing out.
  bool _signingOutForLock = false;

  /// The fingerprint just opened the saved sign-in: it gets a welcome too.
  bool _welcomingBack = false;
  bool _wasLocked = false;
  late ScannerSession _seen = _controller.session;

  /// The signed-in side, built once the sign-in has nothing left to show
  /// over it, and kept — under the lock too — until the sign-out. The same
  /// instance each time, so the scanner's every change does not rebuild
  /// the tabs beside it.
  Widget? _home;

  bool get _demo => widget.repository is InMemoryScannerRepository;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () {
        _controller.stopSpeaking();
        _lock.onHidden();
      },
      onShow: () {
        _lock.onShown();
        // Back in front: scans kept while it was away are tried at once.
        _controller.onResumed();
      },
    );
    _alerts = _controller.alerts.listen(_showAlert);
    _controller.addListener(_onSessionChange);
    _lock.addListener(_onLockChange);
    _controller.start();
    _lock.load();
  }

  /// On the island, the newest winning — SweetAlert's one-at-a-time, without
  /// its OK button: the queue at the door keeps moving while the reason
  /// shows, and a message about the previous student is stale the moment the
  /// next one is scanned. The web's self-closing ones keep their length; the
  /// rest stay long enough to read.
  void _showAlert(ScanAlert alert) {
    if (!mounted) return;
    Island.show(
      context,
      IslandMessage(
        title: alert.title,
        body: alert.body,
        tone: switch (alert.tone) {
          ScanTone.success => IslandTone.success,
          ScanTone.warning => IslandTone.warning,
          ScanTone.error => IslandTone.error,
        },
        icon: alert.tone == ScanTone.success ? Icons.cloud_done_outlined : null,
        hold: alert.autoDismiss ?? const Duration(seconds: 4),
      ),
    );
  }

  void _onSessionChange() {
    final now = _controller.session;
    if (now == _seen) return;
    setState(() {
      if (_seen == ScannerSession.signedOut && now == ScannerSession.signedIn) {
        _welcoming = true;
        _offerLock = true;
      } else if (now != ScannerSession.signedIn) {
        _welcoming = false;
        _welcomingBack = false;
        _offerLock = false;
      }
      _seen = now;
    });
    // The lock guarded that sign-in; it goes with it.
    if (now == ScannerSession.signedOut) {
      _signingOutForLock = false;
      _lock.forget();
    }
    if (now == ScannerSession.signedIn) widget.onSignedIn?.call();
  }

  /// The phone no longer has a screen lock, so the lock cannot be asked
  /// for: the saved sign-in is closed, and the password asked for instead.
  void _onLockChange() {
    final locked = _lock.locked;
    final signedIn = _controller.session == ScannerSession.signedIn;
    if (_wasLocked && !locked && _lock.enabled && signedIn) {
      setState(() => _welcomingBack = true);
    }
    if (!_wasLocked && locked && signedIn) _closePagesAbove();
    _wasLocked = locked;

    if (!_lock.lost || _signingOutForLock) return;
    if (_controller.session != ScannerSession.signedIn) return;
    _signingOutForLock = true;
    _controller.signOut(message: ScannerStrings.lockLost);
  }

  /// The lock covers the whole of the instructor's side, so nothing opened
  /// over it — What's New, a sheet — may stay in front of it.
  void _closePagesAbove() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || route.isCurrent) return;
    Navigator.of(context).popUntil((r) => r == route);
  }

  /// Right after a sign-in with the password: offer to put the phone's lock
  /// in front of it next time. Asked once; the switch is in Settings →
  /// Account after that.
  Future<void> _maybeOfferLock() async {
    if (!_offerLock) return;
    _offerLock = false;
    if (!_lock.ready || !_lock.available || _lock.enabled) return;

    final yes = await showLockOffer(
      context,
      title: ScannerStrings.lockOfferTitle,
      body: ScannerStrings.lockOfferBody,
    );
    if (!yes || !mounted) return;
    final on = await _lock.enable();
    if (!on || !mounted) return;
    Island.show(
      context,
      const IslandMessage(
        title: ScannerStrings.lockOn,
        tone: IslandTone.success,
        icon: Icons.fingerprint_rounded,
      ),
    );
  }

  @override
  void dispose() {
    _alerts.cancel();
    _controller.removeListener(_onSessionChange);
    _lock.removeListener(_onLockChange);
    _lifecycle.dispose();
    _controller.dispose();
    _lock.dispose();
    super.dispose();
  }

  Widget _scanner(BuildContext context) => ScannerPage(
    key: const ValueKey('scanner'),
    controller: _controller,
    demo: _demo,
    cameraBuilder: widget.cameraBuilder,
    keepAwake: widget.keepAwake,
  );

  /// Whatever the sign-in has to show in front of the signed-in side — the
  /// check, the form, a welcome, the lock — or null when it is open.
  Widget? _cover() {
    final session = _controller.session;
    final user = _controller.user;

    final signedIn = session == ScannerSession.signedIn;

    // Until the lock's switch has been read, a saved sign-in cannot be
    // shown: it might be behind the lock.
    if (session == ScannerSession.checking || (signedIn && !_lock.ready)) {
      return const _Checking(key: ValueKey('checking'));
    }

    if (_welcoming && session == ScannerSession.signedIn) {
      return ScannerWelcome(
        key: const ValueKey('welcome'),
        name: user?.name ?? '',
        user: user,
        onFinished: () {
          if (!mounted) return;
          setState(() => _welcoming = false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _maybeOfferLock();
          });
        },
      );
    }

    if (_welcomingBack && signedIn) {
      return ScannerWelcome.unlocked(
        key: const ValueKey('unlocked'),
        name: user?.name ?? '',
        user: user,
        onFinished: () {
          if (mounted) setState(() => _welcomingBack = false);
        },
      );
    }

    if (signedIn && (_lock.locked || _lock.lost)) {
      return ScannerLockScreen(
        key: const ValueKey('lock'),
        lock: _lock,
        user: user,
        onUsePassword: _controller.signOut,
      );
    }

    return switch (session) {
      // Handled above; here only to keep the switch exhaustive.
      ScannerSession.checking => const SizedBox.shrink(),
      ScannerSession.unreachable => _Unreachable(
        key: const ValueKey('unreachable'),
        message: _controller.sessionMessage,
        onRetry: _controller.start,
        onSignOut: _controller.signOut,
      ),
      ScannerSession.signedOut => ScannerSignInPage(
        key: const ValueKey('sign-in'),
        controller: _controller,
        demo: _demo,
        onBack: widget.onLeave,
      ),
      ScannerSession.signedIn => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_controller, _lock]),
      builder: (context, _) {
        final cover = _cover();
        final session = _controller.session;

        if (session != ScannerSession.signedIn) {
          _home = null;
        } else if (cover == null) {
          final home = widget.home;
          _home ??= KeyedSubtree(
            key: const ValueKey('home'),
            child: Builder(
              builder: (context) => home == null
                  ? _scanner(context)
                  : home(context, _scanner, _controller, _lock),
            ),
          );
        }

        final covered = cover != null;
        final leaving =
            session == ScannerSession.signedOut && widget.onLeave != null;

        return PopScope(
          canPop: !leaving,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && leaving) widget.onLeave?.call();
          },
          // Under the covers as they fade: the canvas, not black.
          child: ColoredBox(
            color: context.colors.canvas,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Kept under a cover rather than dropped, so a lock after a
                // minute away does not lose the tab or a half-typed number.
                // Out of sight it is still: no camera, no taps, no focus.
                TickerMode(
                  enabled: !covered,
                  child: IgnorePointer(
                    ignoring: covered,
                    child: ExcludeSemantics(
                      excluding: covered,
                      child: ExcludeFocus(
                        excluding: covered,
                        child: _home ?? const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
                FadeScaleSwitcher(
                  child: cover ?? const SizedBox.shrink(key: ValueKey('open')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The moment a saved sign-in is checked with the server, between the app's
/// own splash and Home. Blank at first, so a quick answer flashes nothing
/// past; a spinner and "Checking your sign-in…" fade in only when the check
/// runs long, so a slow network does not look like a frozen app.
class _Checking extends StatelessWidget {
  const _Checking({super.key});

  /// How long the check runs before it says so, and its fade in after.
  static const Duration _quiet = Duration(milliseconds: 600);
  static const Duration _fade = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = _quiet + _fade;

    return Scaffold(
      body: Center(
        // Frame-driven rather than a timer, so "reduce motion" shortens the
        // wait with everything else, and a test's pumpAndSettle runs through
        // it.
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: total,
          curve: Interval(
            _quiet.inMicroseconds / total.inMicroseconds,
            1,
            curve: Curves.easeOut,
          ),
          builder: (context, shown, _) => shown == 0
              // Nothing spinning while nothing is shown.
              ? const SizedBox.shrink()
              : Opacity(
                  opacity: shown,
                  child: Semantics(
                    liveRegion: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox.square(
                          dimension: 18,
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          ScannerStrings.checkingSession,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// A sign-in is saved on this phone, but the server could not be asked about
/// it. Kept rather than dropped: no signal in the classroom is not a reason to
/// type the password again.
class _Unreachable extends StatelessWidget {
  const _Unreachable({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onSignOut,
  });

  final String? message;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 44,
                    color: context.colors.textMuted,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    ScannerStrings.unreachableTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text(ScannerStrings.retry),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onSignOut,
                    child: const Text(ScannerStrings.signOut),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
