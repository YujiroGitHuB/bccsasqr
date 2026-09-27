import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../controllers/scanner_controller.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/scanner_models.dart';
import '../../services/scanner_repository.dart';
import '../widgets/surface_panel.dart';
import 'camera/qr_camera.dart';
import 'widgets/attendance_panel.dart';
import 'widgets/camera_panel.dart';
import 'widgets/scan_result_card.dart';
import 'widgets/scanner_header.dart';
import 'widgets/subject_panel.dart';

/// Builds the camera, handed the callback for every code it reads. Tests
/// swap in one without a camera.
typedef QrCameraBuilder =
    Widget Function(BuildContext context, ValueChanged<String> onCode);

/// The phone's camera — see camera/qr_camera.dart.
Widget deviceQrCamera(BuildContext context, ValueChanged<String> onCode) =>
    QrCamera(onCode: onCode);

/// Holds the screen on through wakelock_plus.
Future<void> deviceKeepAwake(bool on) async {
  try {
    await WakelockPlus.toggle(enable: on);
  } catch (_) {
    // A phone that will not hold the screen on still scans — it just dims.
  }
}

/// The signed-in scanner: subject, camera, result, today's list. The web
/// scanner page (Qrscanner/qrscanner.php) in the order a phone shows it.
class ScannerPage extends StatefulWidget {
  const ScannerPage({
    super.key,
    required this.controller,
    this.demo = false,
    this.cameraBuilder = deviceQrCamera,
    this.keepAwake = deviceKeepAwake,
  });

  final ScannerController controller;

  /// Running on [InMemoryScannerRepository] — say so.
  final bool demo;
  final QrCameraBuilder cameraBuilder;

  /// Holds the screen on while the camera runs. Nobody touches the phone
  /// while a class files past it, and a screen that locks mid-queue stops
  /// the scanner with it.
  final Future<void> Function(bool on) keepAwake;

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  static const double _maxContentWidth = 560;

  ScannerController get _controller => widget.controller;

  late final StreamSubscription<ScanAlert> _alerts;
  Route<void>? _alertRoute;
  Timer? _alertTimer;
  bool _awake = false;

  @override
  void initState() {
    super.initState();
    _alerts = _controller.alerts.listen(_showAlert);
    _controller.addListener(_syncKeepAwake);
    _syncKeepAwake();
  }

  @override
  void dispose() {
    _alerts.cancel();
    _alertTimer?.cancel();
    _controller.removeListener(_syncKeepAwake);
    if (_awake) unawaited(widget.keepAwake(false));
    super.dispose();
  }

  void _syncKeepAwake() {
    final want = _controller.cameraActive;
    if (want == _awake) return;
    _awake = want;
    unawaited(widget.keepAwake(want));
  }

  /// One dialog at a time, the newest winning — SweetAlert's behaviour, and
  /// the right one: a dialog about the previous student is stale the moment
  /// the next one is scanned.
  void _showAlert(ScanAlert alert) {
    if (!mounted) return;
    final navigator = Navigator.of(context);

    final previous = _alertRoute;
    if (previous != null && previous.isActive) navigator.removeRoute(previous);

    final route = DialogRoute<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(alert.title),
        content: Text(
          alert.body,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          if (alert.autoDismiss == null)
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(ScannerStrings.alertOk),
            ),
        ],
      ),
    );
    _alertRoute = route;
    navigator.push(route).whenComplete(() {
      if (_alertRoute == route) _alertRoute = null;
    });

    _alertTimer?.cancel();
    final dismissAfter = alert.autoDismiss;
    if (dismissAfter != null) {
      _alertTimer = Timer(dismissAfter, () {
        if (route.isActive) navigator.removeRoute(route);
      });
    }
  }

  Future<void> _pickSubject() async {
    final subjects = _controller.subjects;
    final current = _controller.selectedSubject;

    final picked = await showModalBottomSheet<ScanSubject>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  ScannerStrings.subjectSheetTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              for (final subject in subjects)
                ListTile(
                  onTap: () => Navigator.pop(context, subject),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: Icon(
                    subject.lateMarking
                        ? Icons.alarm_rounded
                        : Icons.menu_book_rounded,
                    color: subject.lateMarking
                        ? AppColors.warning
                        : AppColors.textSecondary,
                  ),
                  title: Text(
                    subject.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    subject.lateMarking
                        ? '${subject.code} · ${ScannerStrings.lateTitle} on'
                        : subject.code,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  trailing: subject == current
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.accent,
                        )
                      : null,
                ),
            ],
          ),
        ),
      ),
    );

    if (picked != null) _controller.selectSubject(picked);
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(ScannerStrings.signOutConfirmTitle),
        content: const Text(
          ScannerStrings.signOutConfirmBody,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(ScannerStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(ScannerStrings.signOut),
          ),
        ],
      ),
    );
    if (confirmed == true) await _controller.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _controller.refresh,
          color: AppColors.accent,
          backgroundColor: AppColors.surfaceRaised,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.pagePadding,
              vertical: 16,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_controller.user case final user?)
                        ScannerHeader(
                          user: user,
                          subjectCount: _controller.subjects.length,
                          onSignOut: _confirmSignOut,
                          onBack: Navigator.of(context).canPop()
                              ? () => Navigator.of(context).maybePop()
                              : null,
                        ),
                      if (widget.demo) const _DemoNotice(),
                      const SizedBox(height: 16),
                      ..._scanner(),
                      const SizedBox(height: 16),
                      AttendancePanel(controller: _controller),
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

  /// The subject picker and the camera — or, when there is nothing to scan
  /// for, the reason why.
  List<Widget> _scanner() {
    final c = _controller;

    if (c.blockedMessage case final message?) {
      return [
        _Notice(
          icon: Icons.lock_outline_rounded,
          title: null,
          body: message,
          onRetry: c.refresh,
        ),
      ];
    }
    if (c.subjects.isEmpty && c.isLoadingSubjects) {
      return const [
        SurfacePanel(
          child: SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }
    if (c.subjectsError case final error? when c.subjects.isEmpty) {
      return [
        _Notice(
          icon: Icons.cloud_off_rounded,
          title: ScannerStrings.subjectsFailed,
          body: error,
          onRetry: c.refresh,
        ),
      ];
    }
    if (c.subjects.isEmpty) {
      return [
        _Notice(
          icon: Icons.event_busy_rounded,
          title: ScannerStrings.noSubjectsTitle,
          body: ScannerStrings.noSubjectsBody,
          onRetry: c.refresh,
        ),
      ];
    }

    final record = c.lastRecord;
    return [
      SubjectPanel(controller: c, onPickSubject: _pickSubject),
      const SizedBox(height: 16),
      CameraPanel(
        active: c.cameraActive,
        recording: c.isRecording,
        status: c.status,
        frameFraction: QrCamera.cropFraction,
        cameraBuilder: (context) =>
            widget.cameraBuilder(context, c.onCodeScanned),
      ),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) => SizeTransition(
          sizeFactor: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: record == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                key: ObjectKey(record),
                padding: const EdgeInsets.only(top: 12),
                child: ScanResultCard(record: record),
              ),
      ),
    ];
  }
}

/// Why there is no camera: locked, no subjects, or the server did not answer.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.body,
    required this.onRetry,
  });

  final IconData icon;
  final String? title;
  final String body;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          if (title != null) ...[
            Text(
              title!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(ScannerStrings.retry),
          ),
        ],
      ),
    );
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.science_outlined,
            size: 18,
            color: AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppStrings.demoModeTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${ScannerStrings.demoModeBody} '
                  '${InMemoryScannerRepository.sampleNumbers.join(' · ')}',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.textSecondary,
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
