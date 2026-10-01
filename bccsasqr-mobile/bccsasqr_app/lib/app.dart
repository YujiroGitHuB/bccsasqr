import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controllers/check_in_controller.dart';
import 'controllers/my_attendance_controller.dart';
import 'controllers/my_qr_controller.dart';
import 'controllers/profile_controller.dart';
import 'controllers/role_controller.dart';
import 'controllers/scanner_controller.dart';
import 'controllers/scanner_lock_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/whats_new_controller.dart';
import 'core/config/app_config.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'models/app_role.dart';
import 'models/whats_new.dart';
import 'services/app_info.dart';
import 'services/check_in_repository.dart';
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
import 'views/get_started_splash.dart';
import 'views/check_in_page.dart';
import 'views/home_page.dart';
import 'views/instructor_home.dart';
import 'views/instructor_menu.dart';
import 'views/instructor_shell.dart';
import 'views/links/links_page.dart';
import 'views/links/links_splash.dart';
import 'views/my_attendance_page.dart';
import 'views/onboarding_page.dart';
import 'views/profile/profile_page.dart';
import 'views/profile/profile_splash.dart';
import 'views/qr_generator_page.dart';
import 'views/role_picker_page.dart';
import 'views/scanner/scanner_flow.dart';
import 'views/scanner/scanner_intro.dart';
import 'views/scanner/scanner_page.dart';
import 'views/settings_page.dart';
import 'views/show_qr_page.dart';
import 'views/splash_page.dart';
import 'views/student_lock_gate.dart';
import 'views/student_menu.dart';
import 'views/student_shell.dart';
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
    this.studentLockStore,
    this.lockClock,
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
    this.checkInRepository,
    this.deviceTokenStore,
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

  /// The phone's fingerprint, face or screen lock, and each side's switch
  /// for it: in front of the scanner's sign-in, and the student's side.
  ///
  /// Only main.dart passes the phone's own lock: with none there is nothing
  /// to ask for — a test is not a phone, and the real one waits seconds on
  /// a plugin that never answers there. The scanner's switch is the real
  /// one when left out.
  final DeviceLock? deviceLock;
  final LockSwitchStore? scannerLockStore;

  /// Only main.dart passes the phone's own: with none, the student's lock
  /// is off and kept while the app runs — a test's preferences never
  /// answer, and the student's side waits on this switch.
  final LockSwitchStore? studentLockStore;

  /// The locks' clock. Overridable for tests: see [ScannerFlow.lockClock].
  final DateTime Function()? lockClock;
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

  /// Check in's server. The student repository's when it serves check-ins
  /// too (the real one does); one demo class otherwise.
  final CheckInRepository? checkInRepository;

  /// The token that keeps this phone one device for Check in. Only
  /// main.dart passes the phone's own: with none it is kept while the app
  /// runs.
  final DeviceTokenStore? deviceTokenStore;

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

  /// Watched, so the student's Home shows a code the moment My QR Code
  /// keeps it.
  late final WatchedSavedQrStore _savedQrs = WatchedSavedQrStore(
    widget.savedQrStore ?? MemorySavedQrStore(),
  );

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
    // A release only about the other half of the app is no news here.
    areas: () =>
        _role.role == AppRole.student ? _studentAreas : _instructorAreas,
  );

  late final RoleController _role = RoleController(
    store: widget.roleStore ?? SharedPrefsRoleStore(),
  );

  // The student's side is made the first time it shows — an instructor's
  // phone never asks the server for a student's code or attendance.
  MyQrController? _myQrMade;
  MyAttendanceController? _myAttendanceMade;
  CheckInController? _checkInMade;

  MyQrController get _myQr => _myQrMade ??= MyQrController(
    profile: _profile,
    saved: _savedQrs,
    repository: _repository,
  );

  MyAttendanceController get _myAttendance => _myAttendanceMade ??=
      MyAttendanceController(profile: _profile, repository: _tracker);

  CheckInController get _checkIn => _checkInMade ??= CheckInController(
    repository:
        widget.checkInRepository ??
        switch (_repository) {
          final CheckInRepository both => both,
          _ => InMemoryCheckInRepository(),
        },
    profile: _profile,
    devices: widget.deviceTokenStore ?? MemoryDeviceTokenStore(),
    deviceLock: widget.deviceLock ?? const NoDeviceLock(),
  );

  /// The student's tab showing — held here, as the instructor's is, so
  /// What's New can open one.
  final ValueNotifier<StudentTab> _studentTab = ValueNotifier(StudentTab.home);

  /// The instructor's tab showing. Held here rather than in the shell, so
  /// What's New — pushed over it from Home, the Menu or Settings — can open
  /// one.
  final ValueNotifier<InstructorTab> _tab = ValueNotifier(InstructorTab.home);

  late bool _splashing = widget.showSplash;

  /// Whether the introduction has been seen; null while the store answers.
  bool? _onboarded;

  /// The introduction was just ended: its splash plays before the question.
  /// Not when Settings → Role asks the question again.
  bool _gettingStarted = false;

  bool _scannerOpened = false;

  /// "I'm a student" was just picked: the student's splash plays before the
  /// home screen. Not on a launch with the role already kept — the app's own
  /// splash has played. "I'm an instructor" goes straight to the sign-in;
  /// the scanner's splash waits for the Scanner to be opened.
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

  /// **Skip**, or **Get started** on the last slide: the getting-started
  /// splash, then the question.
  void _finishOnboarding() {
    setState(() {
      _onboarded = true;
      _gettingStarted = true;
    });
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
    _myQrMade?.dispose();
    _myAttendanceMade?.dispose();
    _checkInMade?.dispose();
    _tab.dispose();
    _studentTab.dispose();
    super.dispose();
  }

  /// The picker's answer. A student's is kept at once; an instructor's only
  /// once the sign-in goes through (see [_instructor]).
  void _chooseRole(AppRole role) {
    _studentWelcome = role == AppRole.student;
    // A fresh student side opens on Home.
    _studentTab.value = StudentTab.home;
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
  /// opening My Profile rather than the web page, and the number this phone
  /// is set up for typed in already.
  Widget _studentGenerator(BuildContext context) => GeneratorIntro(
    page: (context) => QrGeneratorPage(
      repository: _repository,
      exportService: _exportService,
      speech: _speech,
      savedQrs: _savedQrs,
      photoPage: _profilePage,
      initialNumber: _profile.profile?.record.studentNumber.value,
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
    WhatsNewArea.checkIn,
  };

  Widget _studentSettings(BuildContext context, PhoneLockController lock) =>
      SettingsPage(
        controller: _settings,
        appInfo: widget.appInfo,
        role: AppRole.student,
        lock: lock,
        onSwitchRole: () => _switchRole(context),
        // No links from here: Settings is already a page over the home screen,
        // and What's New would stack a third.
        whatsNewBuilder: (context) =>
            WhatsNewPage(areas: _studentAreas, onShown: _whatsNew.markSeen),
        tourBuilder: _tour,
      );

  /// From Home and the Menu, where each item opens its tab: back down to
  /// the shell, on the item's part.
  Widget _studentWhatsNew(BuildContext context) => WhatsNewPage(
    areas: _studentAreas,
    onShown: _whatsNew.markSeen,
    onOpen: (area) {
      Navigator.of(context).pop();
      _studentTab.value = StudentTab.of(area);
    },
  );

  /// My Attendance: the student this phone is set up for, with no number to
  /// type — or, before it is set up, the tracker to look one up.
  Widget _studentTracker(BuildContext context) => TrackerIntro(
    page: (context) => ListenableBuilder(
      listenable: _profile,
      builder: (context, _) => _profile.profile == null
          ? TrackerPage(repository: _tracker, speech: _speech)
          : MyAttendancePage(controller: _myAttendance),
    ),
  );

  /// The code full screen, for the instructor's camera.
  void _showQr(BuildContext context) {
    final code = _myQr.code;
    if (code == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ShowQrPage(
          code: code,
          exportService: _exportService,
          attendance: _myAttendance,
          keepAwake: widget.keepAwake,
        ),
      ),
    );
  }

  /// The student's side: the shell, opening on Home, with the Menu button
  /// at its foot — the instructor's, laid out for a student — behind the
  /// phone's lock once the student turns it on.
  Widget _student() => StudentLockGate(
    key: const ValueKey('home'),
    profile: _profile,
    deviceLock: widget.deviceLock ?? const NoDeviceLock(),
    store: widget.studentLockStore ?? MemoryLockSwitchStore(),
    clock: widget.lockClock,
    builder: (context, lock) => StudentShell(
      tab: _studentTab,
      homeBuilder: (context) => HomePage(
        profile: _profile,
        qr: _myQr,
        attendance: _myAttendance,
        onOpen: (tab) => _studentTab.value = tab,
        onShowQr: () => _showQr(context),
        whatsNewBuilder: _studentWhatsNew,
        whatsNew: _whatsNew,
      ),
      generatorBuilder: _studentGenerator,
      trackerBuilder: _studentTracker,
      checkInBuilder: (context) => CheckInPage(
        controller: _checkIn,
        profile: _profile,
        settings: _settings,
        cameraBuilder: widget.cameraBuilder,
        onSetUp: () => _studentTab.value = StudentTab.profile,
        onCheckedIn: () => unawaited(_myAttendance.refresh()),
      ),
      profileBuilder: _profilePage,
      settingsBuilder: (context) => _studentSettings(context, lock),
      menuBuilder: (context, menu) => StudentMenu(
        menu: menu,
        profile: _profile,
        qr: _myQr,
        onShowQr: () => _showQr(context),
        whatsNewBuilder: _studentWhatsNew,
        whatsNew: _whatsNew,
        tourBuilder: _tour,
      ),
    ),
  );

  // ── Instructor ──────────────────────────────────────────────────────
  // The sign-in, then the shell, opening on Home, with the Menu button at
  // its foot. Every part of the side is a tab of it; only What's New, the
  // tour, today's list and the questions are opened over it.

  /// What an instructor's What's New can be about. Links only for an account
  /// allowed to manage them, on the page itself.
  static const Set<WhatsNewArea> _instructorAreas = {
    WhatsNewArea.qr,
    WhatsNewArea.scanner,
    WhatsNewArea.tracker,
    WhatsNewArea.links,
  };

  /// What's New on an instructor's phone — the same page from Home, the Menu
  /// and Settings, each item opening its tab.
  Widget _instructorWhatsNew(BuildContext context, ScannerController session) =>
      WhatsNewPage(
        areas: {
          for (final area in _instructorAreas)
            if (area != WhatsNewArea.links ||
                (session.user?.canManageLinks ?? false))
              area,
        },
        onShown: _whatsNew.markSeen,
        // Back down to the shell, on the item's tab.
        onOpen: (area) {
          Navigator.of(context).pop();
          _tab.value = InstructorTab.of(area);
        },
      );

  Widget _instructorSettings(
    BuildContext context,
    ScannerController session,
    ScannerLockController lock,
  ) => SettingsPage(
    controller: _settings,
    appInfo: widget.appInfo,
    role: AppRole.instructor,
    account: session.user,
    subjectCount: () => session.subjects.length,
    lock: lock,
    onSignOut: session.signOut,
    pendingScans: () => session.pendingCount,
    onSwitchRole: () => _switchRole(context),
    whatsNewBuilder: (context) => _instructorWhatsNew(context, session),
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
      deviceLock: widget.deviceLock ?? const NoDeviceLock(),
      lockStore:
          widget.scannerLockStore ?? const SharedPrefsLockSwitchStore.scanner(),
      lockClock: widget.lockClock,
      // A fresh bar opens on Home, and the phone is now known to be an
      // instructor's.
      onSignedIn: () {
        _tab.value = InstructorTab.home;
        _role.choose(AppRole.instructor);
      },
      onLeave: _role.clear,
      home: (context, scanner, session, lock) => InstructorShell(
        tab: _tab,
        homeBuilder: (context) => InstructorHome(
          session: session,
          onOpen: (tab) => _tab.value = tab,
          whatsNewBuilder: (context) => _instructorWhatsNew(context, session),
          whatsNew: _whatsNew,
        ),
        generatorBuilder: _generator,
        // Its splash the first time it is opened, as the other tabs.
        scannerBuilder: (context) => ScannerIntro(page: scanner),
        trackerBuilder: _trackerPage,
        settingsBuilder: (context) =>
            _instructorSettings(context, session, lock),
        linksBuilder: (context) => _linksPage(context, session),
        menuBuilder: (context, menu) => InstructorMenu(
          menu: menu,
          session: session,
          whatsNewBuilder: (context) => _instructorWhatsNew(context, session),
          whatsNew: _whatsNew,
          tourBuilder: _tour,
        ),
        account: session,
        canManageLinks: () => session.user?.canManageLinks ?? false,
      ),
    );
  }

  /// After the splash: on the first launch the introduction, its splash and
  /// then the question, then the half of the app it picked.
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
      null when _gettingStarted => GetStartedSplash(
        key: const ValueKey('get-started'),
        onFinished: () => setState(() => _gettingStarted = false),
      ),
      null => RolePickerPage(
        key: const ValueKey('role'),
        onChosen: _chooseRole,
      ),
      AppRole.student when _studentWelcome => StudentSplash(
        key: const ValueKey('student-splash'),
        onFinished: () => setState(() => _studentWelcome = false),
      ),
      AppRole.student => _student(),
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
