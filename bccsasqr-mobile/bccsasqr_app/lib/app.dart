import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'services/http_student_repository.dart';
import 'services/qr_export_service.dart';
import 'services/speech_service.dart';
import 'services/student_repository.dart';
import 'views/qr_generator_page.dart';
import 'views/splash_page.dart';

/// Root widget. Composes the dependency graph in one place so the views take
/// their collaborators by constructor rather than reaching for globals.
class BccSasqrApp extends StatefulWidget {
  const BccSasqrApp({
    super.key,
    this.repository,
    this.exportService,
    this.speech,
    this.showSplash = true,
  });

  /// Overridable for tests.
  final StudentRepository? repository;
  final QrExportService? exportService;
  final SpeechService? speech;

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

  late bool _splashing = widget.showSplash;

  @override
  void dispose() {
    final repository = _repository;
    if (repository is HttpStudentRepository) repository.dispose();
    super.dispose();
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
            : QrGeneratorPage(
                key: const ValueKey('generator'),
                repository: _repository,
                exportService: _exportService,
                speech: _speech,
              ),
      ),
    );
  }
}
