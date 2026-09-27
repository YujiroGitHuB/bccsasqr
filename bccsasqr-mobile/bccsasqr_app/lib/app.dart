import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'services/http_scanner_repository.dart';
import 'services/http_student_repository.dart';
import 'services/qr_export_service.dart';
import 'services/scan_feedback.dart';
import 'services/scanner_repository.dart';
import 'services/speech_service.dart';
import 'services/student_repository.dart';
import 'services/token_store.dart';
import 'views/home_page.dart';
import 'views/qr_generator_page.dart';
import 'views/scanner/scanner_flow.dart';
import 'views/scanner/scanner_page.dart';
import 'views/splash_page.dart';

/// Root widget. Composes the dependency graph in one place so the views take
/// their collaborators by constructor rather than reaching for globals.
class BccSasqrApp extends StatefulWidget {
  const BccSasqrApp({
    super.key,
    this.repository,
    this.exportService,
    this.speech,
    this.scannerRepository,
    this.scanFeedback,
    this.cameraBuilder = deviceQrCamera,
    this.keepAwake = deviceKeepAwake,
    this.showSplash = true,
  });

  /// Overridable for tests.
  final StudentRepository? repository;
  final QrExportService? exportService;
  final SpeechService? speech;
  final ScannerRepository? scannerRepository;
  final ScanFeedback? scanFeedback;
  final QrCameraBuilder cameraBuilder;
  final Future<void> Function(bool on) keepAwake;

  /// Tests that are about the generator switch the opening animation off.
  final bool showSplash;

  @override
  State<BccSasqrApp> createState() => _BccSasqrAppState();
}

class _BccSasqrAppState extends State<BccSasqrApp> {
  /// Real backend when one was supplied at build time, bundled demo records
  /// otherwise — see [AppConfig].
  late final StudentRepository _repository =
      widget.repository ??
      (AppConfig.hasRemoteApi
          ? HttpStudentRepository()
          : InMemoryStudentRepository());
  late final QrExportService _exportService =
      widget.exportService ?? const ImageQrExportService();
  late final SpeechService _speech = widget.speech ?? DeviceSpeechService();

  // The scanner's collaborators are built the first time the scanner opens —
  // a student who only ever opens the generator never loads an audio player
  // or touches the keystore.
  late final ScannerRepository _scannerRepository =
      widget.scannerRepository ??
      (AppConfig.hasRemoteApi
          ? HttpScannerRepository(tokens: SecureTokenStore())
          : InMemoryScannerRepository());
  late final ScanFeedback _scanFeedback =
      widget.scanFeedback ?? DeviceScanFeedback();

  late bool _splashing = widget.showSplash;

  bool _scannerOpened = false;

  @override
  void dispose() {
    final repository = _repository;
    if (repository is HttpStudentRepository) repository.dispose();
    if (_scannerOpened) {
      final scanner = _scannerRepository;
      if (scanner is HttpScannerRepository) scanner.dispose();
      final feedback = _scanFeedback;
      if (feedback is DeviceScanFeedback) feedback.dispose();
    }
    super.dispose();
  }

  Widget _generator(BuildContext context) => QrGeneratorPage(
    repository: _repository,
    exportService: _exportService,
    speech: _speech,
  );

  Widget _scanner(BuildContext context) {
    _scannerOpened = true;
    return ScannerFlow(
      repository: _scannerRepository,
      speech: _speech,
      feedback: _scanFeedback,
      cameraBuilder: widget.cameraBuilder,
      keepAwake: widget.keepAwake,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      // A cross-fade rather than a route push: there is nothing to go
      // "back" to, and the splash should not sit under the page on the stack.
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(animation),
            child: child,
          ),
        ),
        child: _splashing
            ? SplashPage(
                key: const ValueKey('splash'),
                onFinished: () => setState(() => _splashing = false),
              )
            : HomePage(
                key: const ValueKey('home'),
                generatorBuilder: _generator,
                scannerBuilder: _scanner,
              ),
      ),
    );
  }
}
