import 'package:flutter/material.dart';

import '../../controllers/scanner_controller.dart';
import '../../controllers/scanner_lock_controller.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../services/device_lock.dart';
import '../../services/scan_feedback.dart';
import '../../services/scanner_repository.dart';
import '../../services/speech_service.dart';
import '../widgets/fade_scale_switcher.dart';
import 'scanner_intro.dart';
import 'scanner_lock_screen.dart';
import 'scanner_page.dart';
import 'scanner_sign_in_page.dart';

/// The scanner, from opening to signing out. Owns the controller and shows
/// whichever screen the sign-in calls for: a saved sign-in goes straight to
/// the camera — through the phone's lock first, when the instructor turned
/// it on — anything else to the sign-in form.
class ScannerFlow extends StatefulWidget {
  const ScannerFlow({
    super.key,
    required this.repository,
    this.speech = const SilentSpeechService(),
    this.feedback = const SilentScanFeedback(),
    this.cameraBuilder = deviceQrCamera,
    this.keepAwake = deviceKeepAwake,
    this.onOpenSettings,
    this.deviceLock = const NoDeviceLock(),
    this.lockStore,
  });

  final ScannerRepository repository;

  /// The phone's fingerprint, face or screen lock, and where the switch
  /// for it is kept. See [ScannerLockController].
  final DeviceLock deviceLock;
  final ScannerLockStore? lockStore;
  final SpeechService speech;
  final ScanFeedback feedback;

  /// Opens the app's Settings; see [ScannerPage.onOpenSettings].
  final VoidCallback? onOpenSettings;

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
  );

  late final ScannerLockController _lock = ScannerLockController(
    device: widget.deviceLock,
    store: widget.lockStore ?? MemoryScannerLockStore(),
  );

  /// Leaving the app cuts the voice off rather than letting it read the last
  /// result over whatever was opened.
  late final AppLifecycleListener _lifecycle;

  /// The splash has played its intro. Until then it stays up even when the
  /// sign-in check has already answered.
  bool _introDone = false;

  /// A sign-in typed just now, not one restored: it gets the welcome.
  bool _welcoming = false;

  /// A sign-in typed just now, on a phone with a screen lock: offer the lock
  /// once the welcome has played.
  bool _offerLock = false;

  /// The phone's screen lock went away while the lock was on — signing out.
  bool _signingOutForLock = false;
  late ScannerSession _seen = _controller.session;

  bool get _demo => widget.repository is InMemoryScannerRepository;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () {
        _controller.stopSpeaking();
        _lock.onHidden();
      },
      onShow: _lock.onShown,
    );
    _controller.addListener(_onSessionChange);
    _lock.addListener(_onLockChange);
    _controller.start();
    _lock.load();
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
        _offerLock = false;
      }
      _seen = now;
    });
    // The lock guarded that sign-in; it goes with it.
    if (now == ScannerSession.signedOut) {
      _signingOutForLock = false;
      _lock.forget();
    }
  }

  /// The phone no longer has a screen lock, so the lock cannot be asked
  /// for: the saved sign-in is closed, and the password asked for instead.
  void _onLockChange() {
    if (!_lock.lost || _signingOutForLock) return;
    if (_controller.session != ScannerSession.signedIn) return;
    _signingOutForLock = true;
    _controller.signOut(message: ScannerStrings.lockLost);
  }

  /// Right after a sign-in with the password: offer to put the phone's lock
  /// in front of it next time. Asked once; the switch is in the account
  /// sheet after that.
  Future<void> _maybeOfferLock() async {
    if (!_offerLock) return;
    _offerLock = false;
    if (!_lock.ready || !_lock.available || _lock.enabled) return;

    final yes = await showLockOffer(context);
    if (!yes || !mounted) return;
    final on = await _lock.enable();
    if (!on || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(ScannerStrings.lockOn)));
  }

  @override
  void dispose() {
    _controller.removeListener(_onSessionChange);
    _lock.removeListener(_onLockChange);
    _lifecycle.dispose();
    _controller.dispose();
    _lock.dispose();
    super.dispose();
  }

  Widget _screen() {
    final session = _controller.session;
    final user = _controller.user;

    final signedIn = session == ScannerSession.signedIn;

    // Until the lock's switch has been read, a saved sign-in cannot be
    // shown: it might be behind the lock.
    if (!_introDone ||
        session == ScannerSession.checking ||
        (signedIn && !_lock.ready)) {
      final back = signedIn && user != null;
      final locked = _lock.ready && _lock.locked;
      return ScannerSplash(
        key: const ValueKey('splash'),
        message: !back
            ? ScannerStrings.checkingSession
            : locked
            ? ScannerStrings.lockTitle
            : ScannerStrings.welcomeBack(user.name),
        done: back && !locked,
        onIntroDone: () {
          if (mounted) setState(() => _introDone = true);
        },
      );
    }

    if (_welcoming && session == ScannerSession.signedIn) {
      return ScannerWelcome(
        key: const ValueKey('welcome'),
        name: user?.name ?? '',
        onFinished: () {
          if (!mounted) return;
          setState(() => _welcoming = false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _maybeOfferLock();
          });
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
      ),
      ScannerSession.signedIn => ScannerPage(
        key: const ValueKey('scanner'),
        controller: _controller,
        demo: _demo,
        cameraBuilder: widget.cameraBuilder,
        keepAwake: widget.keepAwake,
        onOpenSettings: widget.onOpenSettings,
        lock: _lock,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_controller, _lock]),
      builder: (context, _) => FadeScaleSwitcher(child: _screen()),
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
