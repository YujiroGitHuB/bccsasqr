import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controllers/settings_controller.dart';
import 'core/config/app_config.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'services/app_info.dart';
import 'services/http_scanner_repository.dart';
import 'services/http_student_repository.dart';
import 'services/qr_export_service.dart';
import 'services/scan_feedback.dart';
import 'services/scanner_repository.dart';
import 'services/settings_store.dart';
import 'services/speech_service.dart';
import 'services/student_repository.dart';
import 'services/token_store.dart';
import 'views/generator_splash.dart';
import 'views/home_page.dart';
import 'views/qr_generator_page.dart';
import 'views/scanner/scanner_flow.dart';
import 'views/scanner/scanner_page.dart';
import 'views/settings_page.dart';
import 'views/splash_page.dart';
import 'views/widgets/fade_scale_switcher.dart';

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
    this.settingsStore,
    this.appInfo = AppInfo.load,
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
  final SettingsStore? settingsStore;
  final Future<AppInfo> Function() appInfo;
  final QrCameraBuilder cameraBuilder;
  final Future<void> Function(bool on) keepAwake;

  /// Tests that are about the generator switch the opening animation off.
  final bool showSplash;

  @override
  State<BccSasqrApp> createState() => _BccSasqrAppState();
}

class _BccSasqrAppState extends State<BccSasqrApp> {
  late final SettingsController _settings = SettingsController(
    store: widget.settingsStore ?? SharedPrefsSettingsStore(),
  );

  /// Real backend when one was supplied at build time, bundled demo records
  /// otherwise — see [AppConfig].
  late final StudentRepository _repository =
      widget.repository ??
      (AppConfig.hasRemoteApi
          ? HttpStudentRepository()
          : InMemoryStudentRepository());
  late final QrExportService _exportService =
      widget.exportService ?? const ImageQrExportService();

  /// One voice for the whole app, silenced by the Voice switch in Settings.
  late final SpeechService _speech = ToggleableSpeechService(
    widget.speech ?? DeviceSpeechService(),
    enabled: () => _settings.voice,
  );

  // The scanner's collaborators are built the first time the scanner opens —
  // a student who only ever opens the generator never loads an audio player
  // or touches the keystore.
  late final ScannerRepository _scannerRepository =
      widget.scannerRepository ??
      (AppConfig.hasRemoteApi
          ? HttpScannerRepository(tokens: SecureTokenStore())
          : InMemoryScannerRepository());
  late final ScanFeedback _scanFeedback =
      widget.scanFeedback ??
      DeviceScanFeedback(
        sound: () => _settings.sound,
        vibration: () => _settings.vibration,
      );

  late bool _splashing = widget.showSplash;

  bool _scannerOpened = false;

  @override
  void initState() {
    super.initState();
    // Read while the splash plays, so the first real screen already wears
    // the chosen theme.
    _settings.load();
  }

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
    _settings.dispose();
    super.dispose();
  }

  Widget _generator(BuildContext context) => GeneratorIntro(
    page: (context) => QrGeneratorPage(
      repository: _repository,
      exportService: _exportService,
      speech: _speech,
    ),
  );

  Widget _settingsPage(BuildContext context) =>
      SettingsPage(controller: _settings, appInfo: widget.appInfo);

  Widget _scanner(BuildContext context) {
    _scannerOpened = true;
    return ScannerFlow(
      repository: _scannerRepository,
      speech: _speech,
      feedback: _scanFeedback,
      cameraBuilder: widget.cameraBuilder,
      keepAwake: widget.keepAwake,
      onOpenSettings: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: _settingsPage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) => MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(AppPalette.light),
        darkTheme: AppTheme.build(AppPalette.dark),
        themeMode: _settings.themeMode,
        // Status and navigation bar icons follow the theme, so they stay
        // readable on a light screen.
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: context.colors.overlayStyle,
          child: child ?? const SizedBox.shrink(),
        ),
        // A cross-fade rather than a route push: there is nothing to go
        // "back" to, and the splash should not sit under the page on the
        // stack.
        home: FadeScaleSwitcher(
          duration: const Duration(milliseconds: 450),
          child: _splashing
              // Always dark, whatever the theme: it continues the native
              // launch screen, which is drawn before any setting is read.
              ? Theme(
                  key: const ValueKey('splash'),
                  data: AppTheme.build(AppPalette.dark),
                  child: AnnotatedRegion<SystemUiOverlayStyle>(
                    value: AppPalette.dark.overlayStyle,
                    child: SplashPage(
                      onFinished: () => setState(() => _splashing = false),
                    ),
                  ),
                )
              : HomePage(
                  key: const ValueKey('home'),
                  generatorBuilder: _generator,
                  scannerBuilder: _scanner,
                  settingsBuilder: _settingsPage,
                ),
        ),
      ),
    );
  }
}
