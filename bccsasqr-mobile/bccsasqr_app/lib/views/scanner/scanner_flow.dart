import 'package:flutter/material.dart';

import '../../controllers/scanner_controller.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../services/scan_feedback.dart';
import '../../services/scanner_repository.dart';
import '../../services/speech_service.dart';
import '../widgets/fade_scale_switcher.dart';
import 'scanner_intro.dart';
import 'scanner_page.dart';
import 'scanner_sign_in_page.dart';

/// The scanner, from opening to signing out. Owns the controller and shows
/// whichever screen the sign-in calls for: a saved sign-in goes straight to
/// the camera, anything else to the sign-in form.
class ScannerFlow extends StatefulWidget {
  const ScannerFlow({
    super.key,
    required this.repository,
    this.speech = const SilentSpeechService(),
    this.feedback = const SilentScanFeedback(),
    this.cameraBuilder = deviceQrCamera,
    this.keepAwake = deviceKeepAwake,
    this.onOpenSettings,
  });

  final ScannerRepository repository;
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

  /// Leaving the app cuts the voice off rather than letting it read the last
  /// result over whatever was opened.
  late final AppLifecycleListener _lifecycle;

  /// The splash has played its intro. Until then it stays up even when the
  /// sign-in check has already answered.
  bool _introDone = false;

  /// A sign-in typed just now, not one restored: it gets the welcome.
  bool _welcoming = false;
  late ScannerSession _seen = _controller.session;

  bool get _demo => widget.repository is InMemoryScannerRepository;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: _controller.stopSpeaking);
    _controller.addListener(_onSessionChange);
    _controller.start();
  }

  void _onSessionChange() {
    final now = _controller.session;
    if (now == _seen) return;
    setState(() {
      if (_seen == ScannerSession.signedOut && now == ScannerSession.signedIn) {
        _welcoming = true;
      } else if (now != ScannerSession.signedIn) {
        _welcoming = false;
      }
      _seen = now;
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onSessionChange);
    _lifecycle.dispose();
    _controller.dispose();
    super.dispose();
  }

  Widget _screen() {
    final session = _controller.session;
    final user = _controller.user;

    if (!_introDone || session == ScannerSession.checking) {
      final back = session == ScannerSession.signedIn && user != null;
      return ScannerSplash(
        key: const ValueKey('splash'),
        message: back
            ? ScannerStrings.welcomeBack(user.name)
            : ScannerStrings.checkingSession,
        done: back,
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
          if (mounted) setState(() => _welcoming = false);
        },
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
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
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
