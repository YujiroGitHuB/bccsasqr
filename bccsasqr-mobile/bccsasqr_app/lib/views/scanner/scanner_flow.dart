import 'package:flutter/material.dart';

import '../../controllers/scanner_controller.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../services/scan_feedback.dart';
import '../../services/scanner_repository.dart';
import '../../services/speech_service.dart';
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
  });

  final ScannerRepository repository;
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
  );

  /// Leaving the app cuts the voice off rather than letting it read the last
  /// result over whatever was opened.
  late final AppLifecycleListener _lifecycle;

  bool get _demo => widget.repository is InMemoryScannerRepository;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: _controller.stopSpeaking);
    _controller.start();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: switch (_controller.session) {
          ScannerSession.checking => const _Checking(key: ValueKey('checking')),
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
          ),
        },
      ),
    );
  }
}

class _Checking extends StatelessWidget {
  const _Checking({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              ScannerStrings.checkingSession,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
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
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 44,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    ScannerStrings.unreachableTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.textSecondary,
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
