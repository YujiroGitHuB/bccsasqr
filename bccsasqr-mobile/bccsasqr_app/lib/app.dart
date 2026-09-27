import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controllers/role_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/whats_new_controller.dart';
import 'core/config/app_config.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'models/app_role.dart';
import 'models/whats_new.dart';
import 'services/app_info.dart';
import 'services/device_lock.dart';
import 'services/http_scanner_repository.dart';
import 'services/http_student_repository.dart';
import 'services/qr_export_service.dart';
import 'services/role_store.dart';
import 'services/scan_feedback.dart';
import 'services/scanner_repository.dart';
import 'services/settings_store.dart';
import 'services/speech_service.dart';
import 'services/student_repository.dart';
import 'services/token_store.dart';
import 'services/tracker_repository.dart';
import 'services/whats_new_store.dart';
import 'views/generator_splash.dart';
import 'views/home_page.dart';
import 'views/instructor_shell.dart';
import 'views/qr_generator_page.dart';
import 'views/role_picker_page.dart';
import 'views/scanner/scanner_flow.dart';
import 'views/scanner/scanner_page.dart';
import 'views/settings_page.dart';
import 'views/splash_page.dart';
import 'views/tracker_page.dart';
import 'views/tracker_splash.dart';
import 'views/whats_new_page.dart';
import 'views/widgets/fade_scale_switcher.dart';

/// Root widget. Composes the dependency graph in one place so the views take
/// their collaborators by constructor rather than reaching for globals.
class BccSasqrApp extends StatefulWidget {
  const BccSasqrApp({
    super.key,
    this.repository,
    this.trackerRepository,
    this.exportService,
    this.speech,
    this.scannerRepository,
    this.scanFeedback,
    this.settingsStore,
    this.whatsNewStore,
    this.roleStore,
    this.deviceLock,
    this.scannerLockStore,
    this.appInfo = AppInfo.load,
    this.cameraBuilder = deviceQrCamera,
    this.keepAwake = deviceKeepAwake,
    this.showSplash = true,
  });

  /// Overridable for tests.
  final StudentRepository? repository;
  final TrackerRepository? trackerRepository;
  final QrExportService? exportService;
  final SpeechService? speech;
  final ScannerRepository? scannerRepository;
  final ScanFeedback? scanFeedback;
  final SettingsStore? settingsStore;

  /// Which What's New this phone has opened. Preferences when left out.
  final WhatsNewStore? whatsNewStore;

  /// Student or instructor, picked on the first launch. Preferences when
  /// left out.
  final RoleStore? roleStore;

  /// The phone's fingerprint, face or screen lock for the scanner, and the
  /// switch for it. The real ones when left out.
  final DeviceLock? deviceLock;
  final ScannerLockStore? scannerLockStore;
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

  /// The tracker reads the same public half of the API as the generator, so
  /// the HTTP repository serves both. Demo mode has its own sample history.
  late final TrackerRepository _tracker =
      widget.trackerRepository ??
      switch (_repository) {
        final TrackerRepository both => both,
        _ => InMemoryTrackerRepository(),
      };

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

  late final WhatsNewController _whatsNew = WhatsNewController(
    store: widget.whatsNewStore ?? SharedPrefsWhatsNewStore(),
  );

  late final RoleController _role = RoleController(
    store: widget.roleStore ?? SharedPrefsRoleStore(),
  );

  /// The instructor's bottom bar. Held here rather than in the bar, so What's
  /// New — pushed over it from the Settings tab — can open a tab.
  final ValueNotifier<InstructorTab> _tab = ValueNotifier(
    InstructorTab.scanner,
  );

  late bool _splashing = widget.showSplash;

  bool _scannerOpened = false;

  @override
  void initState() {
    super.initState();
    // Read while the splash plays, so the first real screen already wears
    // the chosen theme — and is the right half of the app.
    _settings.load();
    _whatsNew.load();
    _role.load();
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
    _whatsNew.dispose();
    _role.dispose();
    _tab.dispose();
    super.dispose();
  }

  /// The picker's answer. An instructor starts on the scanner.
  void _chooseRole(AppRole role) {
    _tab.value = InstructorTab.scanner;
    _role.choose(role);
  }

  /// Settings → Role: close whatever is open over the home screen, then ask
  /// the first launch's question again. The scanner's sign-in is kept.
  void _switchRole(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    _role.clear();
  }

  Widget _generator(BuildContext context) => GeneratorIntro(
    page: (context) => QrGeneratorPage(
      repository: _repository,
      exportService: _exportService,
      speech: _speech,
    ),
  );

  Widget _trackerPage(BuildContext context) => TrackerIntro(
    page: (context) => TrackerPage(repository: _tracker, speech: _speech),
  );

  // ── Student ─────────────────────────────────────────────────────────
  // The home screen, and pages pushed over it. Nothing here reaches the
  // scanner.

  static const Set<WhatsNewArea> _studentAreas = {
    WhatsNewArea.qr,
    WhatsNewArea.tracker,
  };

  Widget _studentSettings(BuildContext context) => SettingsPage(
    controller: _settings,
    appInfo: widget.appInfo,
    role: AppRole.student,
    onSwitchRole: () => _switchRole(context),
    // No links from here: Settings is already a page over the home screen,
    // and What's New would stack a third.
    whatsNewBuilder: (context) =>
        WhatsNewPage(areas: _studentAreas, onShown: _whatsNew.markSeen),
  );

  /// From the home screen, where each item can open the part it is about.
  Widget _studentWhatsNew(BuildContext context) => WhatsNewPage(
    areas: _studentAreas,
    onShown: _whatsNew.markSeen,
    onOpen: (area) {
      final builder = switch (area) {
        WhatsNewArea.qr => _generator,
        WhatsNewArea.tracker => _trackerPage,
        // Left out of [_studentAreas], so never asked for.
        WhatsNewArea.scanner => null,
      };
      if (builder == null) return;
      Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
    },
  );

  // ── Instructor ──────────────────────────────────────────────────────
  // The bottom bar. Settings is one of its tabs, so nothing is pushed over
  // the scanner but What's New.

  Widget _instructorSettings(BuildContext context) => SettingsPage(
    controller: _settings,
    appInfo: widget.appInfo,
    role: AppRole.instructor,
    onSwitchRole: () => _switchRole(context),
    whatsNewBuilder: (context) => WhatsNewPage(
      onShown: _whatsNew.markSeen,
      // Back down to the bar, on the item's tab.
      onOpen: (area) {
        Navigator.of(context).pop();
        _tab.value = InstructorTab.of(area);
      },
    ),
  );

  Widget _scanner(BuildContext context) {
    _scannerOpened = true;
    return ScannerFlow(
      repository: _scannerRepository,
      speech: _speech,
      feedback: _scanFeedback,
      cameraBuilder: widget.cameraBuilder,
      keepAwake: widget.keepAwake,
      deviceLock: widget.deviceLock ?? LocalAuthDeviceLock(),
      lockStore: widget.scannerLockStore ?? SharedPrefsScannerLockStore(),
      onOpenSettings: () => _tab.value = InstructorTab.settings,
    );
  }

  /// After the splash: the question on the first launch, then the half of
  /// the app it picked.
  Widget _home() {
    // Only without the splash (tests), for the moment the store takes.
    if (!_role.loaded) return const SizedBox.shrink(key: ValueKey('loading'));

    return switch (_role.role) {
      null => RolePickerPage(
        key: const ValueKey('role'),
        onChosen: _chooseRole,
      ),
      AppRole.student => HomePage(
        key: const ValueKey('home'),
        generatorBuilder: _generator,
        trackerBuilder: _trackerPage,
        settingsBuilder: _studentSettings,
        whatsNewBuilder: _studentWhatsNew,
        whatsNew: _whatsNew,
      ),
      AppRole.instructor => InstructorShell(
        key: const ValueKey('instructor'),
        tab: _tab,
        generatorBuilder: _generator,
        scannerBuilder: _scanner,
        trackerBuilder: _trackerPage,
        settingsBuilder: _instructorSettings,
        whatsNew: _whatsNew,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_settings, _role]),
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
              : _home(),
        ),
      ),
    );
  }
}
