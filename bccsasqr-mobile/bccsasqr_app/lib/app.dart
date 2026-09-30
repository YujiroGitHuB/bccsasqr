import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controllers/profile_controller.dart';
import 'controllers/role_controller.dart';
import 'controllers/scanner_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/whats_new_controller.dart';
import 'core/config/app_config.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'models/app_role.dart';
import 'models/whats_new.dart';
import 'services/app_info.dart';
import 'services/connectivity.dart';
import 'services/device_lock.dart';
import 'services/http_scanner_repository.dart';
import 'services/http_student_repository.dart';
import 'services/link_repository.dart';
import 'services/offline_scan_store.dart';
import 'services/onboarding_store.dart';
import 'services/photo_picker.dart';
import 'services/photo_repository.dart';
import 'services/profile_store.dart';
import 'services/qr_export_service.dart';
import 'services/role_store.dart';
import 'services/saved_qr_store.dart';
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
import 'views/links/links_page.dart';
import 'views/links/links_splash.dart';
import 'views/onboarding_page.dart';
import 'views/profile/profile_page.dart';
import 'views/profile/profile_splash.dart';
import 'views/qr_generator_page.dart';
import 'views/role_picker_page.dart';
import 'views/scanner/scanner_flow.dart';
import 'views/scanner/scanner_page.dart';
import 'views/settings_page.dart';
import 'views/splash_page.dart';
import 'views/student_splash.dart';
import 'views/tracker_page.dart';
import 'views/tracker_splash.dart';
import 'views/whats_new_page.dart';
import 'views/widgets/connectivity_notice.dart';
import 'views/widgets/fade_scale_switcher.dart';
import 'views/widgets/island.dart';

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
    this.linkRepository,
    this.scanFeedback,
    this.settingsStore,
    this.whatsNewStore,
    this.roleStore,
    this.deviceLock,
    this.scannerLockStore,
    this.scannerLockClock,
    this.appInfo = AppInfo.load,
    this.cameraBuilder = deviceQrCamera,
    this.keepAwake = deviceKeepAwake,
    this.savedQrStore,
    this.connectivity,
    this.offlineScanStore,
    this.onboardingStore,
    this.profileStore,
    this.photoRepository,
    this.photoPicker = const DevicePhotoPicker(),
    this.showSplash = true,
  });

  /// Overridable for tests.
  final StudentRepository? repository;
  final TrackerRepository? trackerRepository;
  final QrExportService? exportService;
  final SpeechService? speech;
  final ScannerRepository? scannerRepository;

  /// The Links tab's server. The scanner's when it serves links too (the
  /// real one does); demo links otherwise.
  final LinkRepository? linkRepository;
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

  /// The lock's clock. Overridable for tests: see [ScannerFlow.lockClock].
  final DateTime Function()? scannerLockClock;
  final Future<AppInfo> Function() appInfo;
  final QrCameraBuilder cameraBuilder;
  final Future<void> Function(bool on) keepAwake;

  /// QR codes made on this phone, kept so they open offline. main.dart
  /// passes the phone's preferences; left out, they are kept only while the
  /// app runs — the generator waits on this store when offline, and a
  /// test's preferences never answer.
  final SavedQrStore? savedQrStore;

  /// Tells the island when the phone goes offline and comes back. Only
  /// main.dart passes the phone's own: with none, nothing is announced — a
  /// test has no network to watch.
  final ConnectivityService? connectivity;

  /// Scans made with no internet, kept until sent. A SQLite file with a real
  /// server; in memory in demo mode, whose scans never leave the phone.
  final OfflineScanStore? offlineScanStore;

  /// Whether this phone has had the introduction. Only main.dart passes the
  /// phone's own: with none it is not shown — a test is not a first launch.
  final OnboardingStore? onboardingStore;

  /// The student this phone belongs to (My Profile). Only main.dart passes
  /// the phone's own: with none it is kept while the app runs — a test's
  /// preferences never answer.
  final ProfileStore? profileStore;

  /// My Profile's server. The student repository's when it serves photos too
  /// (the real one does); the sample records' otherwise.
  final StudentPhotoRepository? photoRepository;

  /// The camera and the gallery, for My Profile.
  final PhotoPicker photoPicker;

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

  /// My Profile's half of the API: the HTTP repository serves it too; demo
  /// mode checks last names against the sample records.
  late final StudentPhotoRepository _photoRepository =
      widget.photoRepository ??
      switch (_repository) {
        final StudentPhotoRepository both => both,
        _ => InMemoryPhotoRepository(records: _repository),
      };

  late final QrExportService _exportService =
      widget.exportService ?? const ImageQrExportService();

  late final SavedQrStore _savedQrs =
      widget.savedQrStore ?? MemorySavedQrStore();

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

  /// The links ride on the scanner's sign-in, so the HTTP scanner serves
  /// both — one token. Demo mode has its own two links.
  late final LinkRepository _linkRepository =
      widget.linkRepository ??
      switch (_scannerRepository) {
        final LinkRepository both => both,
        _ => InMemoryLinkRepository(),
      };
  late final ScanFeedback _scanFeedback =
      widget.scanFeedback ??
      DeviceScanFeedback(
        sound: () => _settings.sound,
        vibration: () => _settings.vibration,
      );
  late final OfflineScanStore _offlineScans =
      widget.offlineScanStore ??
      (AppConfig.hasRemoteApi
          ? SqfliteOfflineScanStore()
          : MemoryOfflineScanStore());

  /// Made here, not on the home screen: the home screen and My Profile show
  /// the same student, and a photo saved on one is on the other at once.
  late final ProfileController _profile = ProfileController(
    store: widget.profileStore ?? MemoryProfileStore(),
    repository: _photoRepository,
    speech: _speech,
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

  /// Whether the introduction has been seen; null while the store answers.
  bool? _onboarded;

  bool _scannerOpened = false;

  /// "I'm a student" was just picked: the student's splash plays before the
  /// home screen, as the scanner's does after "I'm an instructor". Not on a
  /// launch with the role already kept — the app's own splash has played.
  bool _studentWelcome = false;

  @override
  void initState() {
    super.initState();
    // Read while the splash plays, so the first real screen already wears
    // the chosen theme — and is the right half of the app.
    _settings.load();
    _whatsNew.load();
    _role.load();
    _profile.load();

    final onboarding = widget.onboardingStore;
    if (onboarding == null) {
      _onboarded = true;
    } else {
      onboarding.hasSeen().then((seen) {
        if (mounted) setState(() => _onboarded = seen);
      });
    }
  }

  /// **Skip**, or **Get started** on the last slide: on to the question.
  void _finishOnboarding() {
    setState(() => _onboarded = true);
    widget.onboardingStore?.markSeen();
  }

  /// Settings → App tour: the introduction again, closed by its last button.
  Widget _tour(BuildContext context) => OnboardingPage(
    finishLabel: OnboardingStrings.done,
    onDone: () => Navigator.of(context).pop(),
  );

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
    _profile.dispose();
    _tab.dispose();
    super.dispose();
  }

  /// The picker's answer. A student's is kept at once; an instructor's only
  /// once the sign-in goes through (see [_instructor]).
  void _chooseRole(AppRole role) {
    _studentWelcome = role == AppRole.student;
    _role.choose(role, keep: role == AppRole.student);
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
      savedQrs: _savedQrs,
    ),
  );

  /// The student's My QR Code: the same page, with the missing-photo warning
  /// opening My Profile rather than the web page.
  Widget _studentGenerator(BuildContext context) => GeneratorIntro(
    page: (context) => QrGeneratorPage(
      repository: _repository,
      exportService: _exportService,
      speech: _speech,
      savedQrs: _savedQrs,
      photoPage: _profilePage,
    ),
  );

  /// My Profile, behind its splash. The student's side only.
  Widget _profilePage(BuildContext context) => ProfileIntro(
    page: (context) => ProfilePage(
      controller: _profile,
      picker: widget.photoPicker,
      demo: _photoRepository is InMemoryPhotoRepository,
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
    WhatsNewArea.profile,
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
    tourBuilder: _tour,
  );

  /// From the home screen, where each item can open the part it is about.
  Widget _studentWhatsNew(BuildContext context) => WhatsNewPage(
    areas: _studentAreas,
    onShown: _whatsNew.markSeen,
    onOpen: (area) {
      final builder = switch (area) {
        WhatsNewArea.qr => _studentGenerator,
        WhatsNewArea.tracker => _trackerPage,
        WhatsNewArea.profile => _profilePage,
        // Left out of [_studentAreas], so never asked for.
        WhatsNewArea.scanner || WhatsNewArea.links => null,
      };
      if (builder == null) return;
      Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
    },
  );

  // ── Instructor ──────────────────────────────────────────────────────
  // The sign-in, then the bottom bar. Settings is one of its tabs, so
  // nothing is pushed over the scanner but What's New.

  Widget _instructorSettings(BuildContext context, ScannerController session) =>
      SettingsPage(
        controller: _settings,
        appInfo: widget.appInfo,
        role: AppRole.instructor,
        account: session.user,
        onSignOut: session.signOut,
        pendingScans: () => session.pendingCount,
        onSwitchRole: () => _switchRole(context),
        whatsNewBuilder: (context) => WhatsNewPage(
          areas: {
            WhatsNewArea.qr,
            WhatsNewArea.scanner,
            WhatsNewArea.tracker,
            if (session.user?.canManageLinks ?? false) WhatsNewArea.links,
          },
          onShown: _whatsNew.markSeen,
          // Back down to the bar, on the item's tab.
          onOpen: (area) {
            Navigator.of(context).pop();
            _tab.value = InstructorTab.of(area);
          },
        ),
        tourBuilder: _tour,
      );

  /// The Links tab, behind its splash — which covers the list loading. A
  /// token refused there signs the whole side out, as a refused scan does.
  Widget _linksPage(BuildContext context, ScannerController session) =>
      LinksIntro(
        repository: _linkRepository,
        onSignedOut: session.sessionExpired,
        page: (context, controller) => LinksPage(
          repository: _linkRepository,
          controller: controller,
          exportService: _exportService,
          keepAwake: widget.keepAwake,
        ),
      );

  /// The whole instructor side sits behind the scanner's sign-in: until an
  /// instructor account is signed in — and past the phone's lock, when it is
  /// on — there is no bar, no QR Code tab, no Attendance tab. Only the form,
  /// and a way back to the question.
  Widget _instructor() {
    _scannerOpened = true;
    return ScannerFlow(
      key: const ValueKey('instructor'),
      repository: _scannerRepository,
      speech: _speech,
      feedback: _scanFeedback,
      cameraBuilder: widget.cameraBuilder,
      keepAwake: widget.keepAwake,
      offlineStore: _offlineScans,
      online: widget.connectivity?.online,
      deviceLock: widget.deviceLock ?? LocalAuthDeviceLock(),
      lockStore: widget.scannerLockStore ?? SharedPrefsScannerLockStore(),
      lockClock: widget.scannerLockClock,
      onOpenSettings: () => _tab.value = InstructorTab.settings,
      // A fresh bar opens on the scanner, and the phone is now known to be
      // an instructor's.
      onSignedIn: () {
        _tab.value = InstructorTab.scanner;
        _role.choose(AppRole.instructor);
      },
      onLeave: _role.clear,
      home: (context, scanner, session) => InstructorShell(
        tab: _tab,
        generatorBuilder: _generator,
        scannerBuilder: scanner,
        trackerBuilder: _trackerPage,
        settingsBuilder: (context) => _instructorSettings(context, session),
        linksBuilder: (context) => _linksPage(context, session),
        account: session,
        canManageLinks: () => session.user?.canManageLinks ?? false,
        whatsNew: _whatsNew,
      ),
    );
  }

  /// After the splash: on the first launch the introduction and then the
  /// question, then the half of the app it picked.
  Widget _home() {
    // Only without the splash (tests), for the moment the stores take.
    if (!_role.loaded || _onboarded == null) {
      return const SizedBox.shrink(key: ValueKey('loading'));
    }

    return switch (_role.role) {
      // Only before the first answer: a phone that already has a role —
      // updated from a version without the introduction — goes on as it was.
      null when _onboarded == false => OnboardingPage(
        key: const ValueKey('onboarding'),
        onDone: _finishOnboarding,
      ),
      null => RolePickerPage(
        key: const ValueKey('role'),
        onChosen: _chooseRole,
      ),
      AppRole.student when _studentWelcome => StudentSplash(
        key: const ValueKey('student-splash'),
        onFinished: () => setState(() => _studentWelcome = false),
      ),
      AppRole.student => HomePage(
        key: const ValueKey('home'),
        generatorBuilder: _studentGenerator,
        trackerBuilder: _trackerPage,
        settingsBuilder: _studentSettings,
        whatsNewBuilder: _studentWhatsNew,
        whatsNew: _whatsNew,
        profileBuilder: _profilePage,
        profile: _profile,
      ),
      AppRole.instructor => _instructor(),
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
        // The island rides over the navigator, so a message shows over any
        // page, dialog or sheet.
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: context.colors.overlayStyle,
          child: IslandHost(
            child: ConnectivityNotice(
              connectivity: widget.connectivity,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
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
