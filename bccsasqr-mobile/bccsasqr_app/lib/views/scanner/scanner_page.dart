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
import 'widgets/sync_banner.dart';

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

  // The scanner's messages go on the island from ScannerFlow, which hears
  // them whichever tab is showing.
  bool _awake = false;

  /// On screen: not on another tab of the instructor's bar, nor under a
  /// page. The camera stops out of sight (CameraPanel), so the screen need
  /// not stay on for it.
  bool _shown = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncKeepAwake);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _shown = TickerMode.of(context);
    _syncKeepAwake();
  }

  @override
  void dispose() {
    _controller.removeListener(_syncKeepAwake);
    if (_awake) unawaited(widget.keepAwake(false));
    super.dispose();
  }

  void _syncKeepAwake() {
    final want = _controller.cameraActive && _shown;
    if (want == _awake) return;
    _awake = want;
    unawaited(widget.keepAwake(want));
  }

  Future<void> _pickSubject() async {
    final subjects = _controller.subjects;
    final current = _controller.selectedSubject;

    final picked = await showModalBottomSheet<ScanSubject>(
      context: context,
      backgroundColor: context.colors.surface,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  ScannerStrings.subjectSheetTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
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
                        ? context.colors.warning
                        : context.colors.textSecondary,
                  ),
                  title: Text(
                    subject.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    subject.lateMarking
                        ? '${subject.code} · ${ScannerStrings.lateTitle} on'
                        : subject.code,
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                  trailing: subject == current
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: context.colors.accent,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The foot is left to the padding, so the page runs on under the Menu
      // button and still ends clear of it.
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _controller.refresh,
          color: context.colors.accent,
          backgroundColor: context.colors.surfaceRaised,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              16,
              AppTheme.pagePadding,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ScannerHeader(
                        onBack: Navigator.of(context).canPop()
                            ? () => Navigator.of(context).maybePop()
                            : null,
                      ),
                      if (widget.demo) const _DemoNotice(),
                      const SizedBox(height: 16),
                      ..._scanner(),
                      SyncBanner(controller: _controller),
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
      return [
        const SurfacePanel(
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
        paused: c.cameraPaused,
        onCameraChanged: c.setCameraOn,
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
          Icon(icon, size: 40, color: context.colors.textMuted),
          const SizedBox(height: 12),
          if (title != null) ...[
            Text(
              title!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: context.colors.textSecondary,
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
        color: context.colors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: context.colors.warning.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_outlined, size: 18, color: context.colors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.demoModeTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colors.warning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${ScannerStrings.demoModeBody} '
                  '${InMemoryScannerRepository.sampleNumbers.join(' · ')}',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: context.colors.textSecondary,
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
