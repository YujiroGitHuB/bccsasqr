import 'package:bccsasqr_app/app.dart';
import 'package:bccsasqr_app/controllers/role_controller.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/core/constants/whats_new_log.dart';
import 'package:bccsasqr_app/models/app_role.dart';
import 'package:bccsasqr_app/models/scanner_models.dart';
import 'package:bccsasqr_app/services/app_info.dart';
import 'package:bccsasqr_app/services/device_lock.dart';
import 'package:bccsasqr_app/services/link_repository.dart';
import 'package:bccsasqr_app/services/qr_export_service.dart';
import 'package:bccsasqr_app/services/role_store.dart';
import 'package:bccsasqr_app/services/scan_feedback.dart';
import 'package:bccsasqr_app/services/scanner_repository.dart';
import 'package:bccsasqr_app/services/settings_store.dart';
import 'package:bccsasqr_app/services/speech_service.dart';
import 'package:bccsasqr_app/services/student_repository.dart';
import 'package:bccsasqr_app/services/tracker_repository.dart';
import 'package:bccsasqr_app/services/whats_new_store.dart';
import 'package:bccsasqr_app/views/generator_splash.dart';
import 'package:bccsasqr_app/views/get_started_splash.dart';
import 'package:bccsasqr_app/views/instructor_shell.dart';
import 'package:bccsasqr_app/views/links/links_splash.dart';
import 'package:bccsasqr_app/views/role_picker_page.dart';
import 'package:bccsasqr_app/views/scanner/scanner_flow.dart';
import 'package:bccsasqr_app/views/student_splash.dart';
import 'package:bccsasqr_app/views/tracker_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoExport implements QrExportService {
  @override
  Future<String> export({
    required GlobalKey boundaryKey,
    required String fileName,
    String? shareText,
  }) async => fileName;
}

final _camera = find.byKey(const ValueKey('camera'), skipOffstage: false);
final _home = find.byKey(const ValueKey('instructorHome'));

/// The demo scanner, for an account whose "Manage attendance links" can be
/// ticked and unticked between answers.
class _Scanner extends InMemoryScannerRepository {
  _Scanner() : super(latency: Duration.zero);

  bool links = true;

  ScannerUser _as(ScannerUser u) => ScannerUser(
    id: u.id,
    name: u.name,
    email: u.email,
    role: u.role,
    canManageLinks: links,
  );

  @override
  Future<ScannerUser> signIn({
    required String email,
    required String password,
  }) async => _as(await super.signIn(email: email, password: password));

  @override
  Future<SubjectList> loadSubjects() async {
    final list = await super.loadSubjects();
    return (user: _as(list.user), subjects: list.subjects, date: list.date);
  }
}

void main() {
  group('RoleController', () {
    test('reads the saved role, and saves a new one', () async {
      final store = MemoryRoleStore(AppRole.student);
      final role = RoleController(store: store);
      expect(role.loaded, isFalse);

      await role.load();
      expect(role.loaded, isTrue);
      expect(role.role, AppRole.student);

      role.choose(AppRole.instructor);
      expect(role.role, AppRole.instructor);
      expect(store.saved, AppRole.instructor);

      role.clear();
      expect(role.role, isNull);
      expect(store.saved, isNull);
    });

    test('a role not kept is shown but not saved, until it is', () async {
      final store = MemoryRoleStore();
      final role = RoleController(store: store);
      await role.load();

      role.choose(AppRole.instructor, keep: false);
      expect(role.role, AppRole.instructor);
      expect(store.saved, isNull);

      role.choose(AppRole.instructor);
      expect(store.saved, AppRole.instructor);
    });
  });

  group('the app', () {
    late MemoryRoleStore roles;
    late List<bool> awake;
    late _Scanner scanner;

    setUp(() {
      roles = MemoryRoleStore();
      awake = [];
      scanner = _Scanner();
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.devicePixelRatio = 1.0;
      view.physicalSize = const Size(420, 2000);
    });

    tearDown(() {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    Widget app() => BccSasqrApp(
      roleStore: roles,
      repository: InMemoryStudentRepository(latency: Duration.zero),
      trackerRepository: InMemoryTrackerRepository(latency: Duration.zero),
      exportService: _NoExport(),
      speech: const SilentSpeechService(),
      scannerRepository: scanner,
      linkRepository: InMemoryLinkRepository(latency: Duration.zero),
      scanFeedback: const SilentScanFeedback(),
      settingsStore: MemorySettingsStore(),
      whatsNewStore: MemoryWhatsNewStore(WhatsNewLog.version),
      deviceLock: const NoDeviceLock(),
      scannerLockStore: MemoryScannerLockStore(),
      appInfo: () async => const AppInfo(version: '1.6.0', buildNumber: '10'),
      cameraBuilder: (context, onCode) =>
          const ColoredBox(key: ValueKey('camera'), color: Colors.black),
      keepAwake: (on) async => awake.add(on),
      showSplash: false,
    );

    /// The scan line sweeps forever; with reduced motion it holds still, so
    /// pumpAndSettle can settle.
    Future<void> launch(WidgetTester tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
    }

    /// The instructor's form, filled in and sent.
    Future<void> signIn(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField).at(0), 'demo@bcc.test');
      await tester.enterText(find.byType(TextField).at(1), 'secret');
      await tester.tap(
        find.widgetWithText(FilledButton, ScannerStrings.signIn),
      );
      await tester.pumpAndSettle();
    }

    /// Launch, "I'm an instructor", and the form sent.
    Future<void> openAsInstructor(WidgetTester tester) async {
      await launch(tester);
      await tester.tap(find.byKey(const ValueKey('role.instructor')));
      await tester.pumpAndSettle();
      await signIn(tester);
    }

    testWidgets('the first launch asks; a student gets no scanner', (
      tester,
    ) async {
      await launch(tester);

      expect(find.text(RoleStrings.question), findsOneWidget);
      expect(find.byKey(const ValueKey('home.generator')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('role.student')));
      await tester.pumpAndSettle();

      expect(roles.saved, AppRole.student);
      expect(find.byKey(const ValueKey('home.generator')), findsOneWidget);
      expect(find.byKey(const ValueKey('home.tracker')), findsOneWidget);
      // Nothing of the instructor's, anywhere: the Menu button is the
      // student's own, and its Menu has no scanner.
      expect(find.byType(ScannerFlow, skipOffstage: false), findsNothing);
      expect(find.text(NavStrings.scanner), findsNothing);
      await tester.tap(find.byKey(const ValueKey('nav.menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('menu.showQr')), findsOneWidget);
      expect(find.byKey(const ValueKey('menu.scanner')), findsNothing);
      expect(find.text(StudentStrings.role.toUpperCase()), findsOneWidget);
    });

    testWidgets('a picked card lights up with a tick before the app moves on', (
      tester,
    ) async {
      // At full speed, as on a phone: the moment is what is being checked.
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final tick = find.descendant(
        of: find.byKey(const ValueKey('role.instructor')),
        matching: find.byIcon(Icons.check_rounded),
      );

      await tester.tap(find.byKey(const ValueKey('role.instructor')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text(RoleStrings.question), findsOneWidget);
      expect(tick, findsOneWidget);
      expect(roles.saved, isNull);

      await tester.pumpAndSettle();
      expect(find.text(RoleStrings.question), findsNothing);
      expect(find.text(ScannerStrings.signInHeading), findsOneWidget);
    });

    testWidgets('"I\'m a student" plays the student\'s splash first', (
      tester,
    ) async {
      await launch(tester);
      await tester.tap(find.byKey(const ValueKey('role.student')));
      // The card lights up first — a twentieth of its length with reduce
      // motion on — then the splash takes over.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump();

      expect(find.byType(StudentSplash), findsOneWidget);
      expect(find.text(AppStrings.studentSplashTagline), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(StudentSplash), findsNothing);
      expect(find.byKey(const ValueKey('home.generator')), findsOneWidget);
    });

    testWidgets('a kept student role opens straight on the home screen', (
      tester,
    ) async {
      roles = MemoryRoleStore(AppRole.student);
      await tester.pumpWidget(app());
      await tester.pump();
      await tester.pump();

      expect(find.byType(StudentSplash), findsNothing);
      expect(find.byKey(const ValueKey('home.generator')), findsOneWidget);
    });

    testWidgets('"I\'m an instructor" is only a sign-in until one goes '
        'through', (tester) async {
      await launch(tester);
      await tester.tap(find.byKey(const ValueKey('role.instructor')));
      await tester.pumpAndSettle();

      // A student who taps it gets the form, and nothing behind it.
      expect(find.text(ScannerStrings.signInHeading), findsOneWidget);
      expect(find.byType(InstructorDock, skipOffstage: false), findsNothing);
      expect(find.byType(InstructorShell, skipOffstage: false), findsNothing);
      expect(find.byType(GeneratorIntro, skipOffstage: false), findsNothing);
      expect(find.text(NavStrings.qr), findsNothing);
      // Not kept either: the next launch asks again.
      expect(roles.saved, isNull);

      await signIn(tester);

      expect(roles.saved, AppRole.instructor);
      expect(find.byType(InstructorDock), findsOneWidget);
      // Only the Menu button at the foot: the tabs are all in the Menu.
      expect(find.byTooltip(NavStrings.menu), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(InstructorDock),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      // Opening on Home; the other tabs built when first opened.
      expect(_home, findsOneWidget);
      expect(find.text(ScannerStrings.title), findsNothing);
      expect(find.byType(GeneratorIntro, skipOffstage: false), findsNothing);

      await tester.tap(find.byKey(const ValueKey('instructorHome.qr')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.studentNumberLabel), findsOneWidget);
    });

    testWidgets('the sign-in\'s back arrow, and the phone\'s back button, '
        'go back to the question', (tester) async {
      await launch(tester);
      await tester.tap(find.byKey(const ValueKey('role.instructor')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('signIn.back')));
      await tester.pumpAndSettle();
      expect(find.text(RoleStrings.question), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('role.instructor')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(RoleStrings.question), findsOneWidget);
      expect(roles.saved, isNull);
    });

    testWidgets('a saved sign-in opens straight on the bar next time', (
      tester,
    ) async {
      await openAsInstructor(tester);

      // The app closed and opened again, the phone's storage kept.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.text(RoleStrings.question), findsNothing);
      expect(find.text(ScannerStrings.signInHeading), findsNothing);
      expect(find.byType(InstructorDock), findsOneWidget);
    });

    testWidgets('an instructor\'s phone, signed out, asks for the sign-in '
        'and not the bar', (tester) async {
      roles = MemoryRoleStore(AppRole.instructor);
      await launch(tester);

      expect(find.text(RoleStrings.question), findsNothing);
      expect(find.text(ScannerStrings.signInHeading), findsOneWidget);
      expect(find.byType(InstructorShell, skipOffstage: false), findsNothing);
    });

    testWidgets('signing out takes the bar away with it', (tester) async {
      await openAsInstructor(tester);
      await openFromMenu(tester, 'tracker');
      await openFromMenu(tester, 'scanner');

      await openFromMenu(tester, 'settings');
      await tester.ensureVisible(
        find.byKey(const ValueKey('settings.signOut')),
      );
      await tester.tap(find.byKey(const ValueKey('settings.signOut')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ScannerStrings.signOut).last);
      await tester.pumpAndSettle();

      expect(find.text(ScannerStrings.signInHeading), findsOneWidget);
      expect(find.byType(InstructorShell, skipOffstage: false), findsNothing);
      expect(find.byType(TrackerIntro, skipOffstage: false), findsNothing);
      // Still an instructor's phone: the next launch shows the form, not
      // the question.
      expect(roles.saved, AppRole.instructor);
    });

    testWidgets('an instructor can sign out from Settings too', (tester) async {
      await openAsInstructor(tester);
      await openFromMenu(tester, 'settings');

      // Who is signed in, at the top.
      expect(find.text(SettingsStrings.account), findsOneWidget);
      expect(find.text('demo@bcc.test'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('settings.signOut')));
      await tester.pumpAndSettle();
      expect(find.text(ScannerStrings.signOutConfirmTitle), findsOneWidget);
      await tester.tap(find.text(ScannerStrings.signOut).last);
      await tester.pumpAndSettle();

      expect(find.text(ScannerStrings.signInHeading), findsOneWidget);
      expect(find.byType(InstructorShell, skipOffstage: false), findsNothing);
    });

    testWidgets('a student\'s Settings has no account and no sign-out', (
      tester,
    ) async {
      roles = MemoryRoleStore(AppRole.student);
      await launch(tester);
      await tester.tap(find.byKey(const ValueKey('home.settings')));
      await tester.pumpAndSettle();

      expect(find.text(SettingsStrings.account), findsNothing);
      expect(find.byKey(const ValueKey('settings.signOut')), findsNothing);
    });

    testWidgets('Settings → Role asks again, from either half', (tester) async {
      roles = MemoryRoleStore(AppRole.student);
      await launch(tester);

      await tester.tap(find.byKey(const ValueKey('home.settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings.switchRole')));
      await tester.pump();
      await tester.pump();
      // Straight to the question: getting started was long ago.
      expect(find.byType(GetStartedSplash), findsNothing);
      expect(find.byType(RolePickerPage), findsOneWidget);
      await tester.pumpAndSettle();

      // Settings was a page over the home screen; it is closed too.
      expect(find.text(RoleStrings.question), findsOneWidget);
      expect(find.text(SettingsStrings.title), findsNothing);
      expect(roles.saved, isNull);

      await tester.tap(find.byKey(const ValueKey('role.instructor')));
      await tester.pumpAndSettle();
      await signIn(tester);
      await openFromMenu(tester, 'settings');
      // The Role row's — the Account panel's chip says it too.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('settings.switchRole')),
          matching: find.text(RoleStrings.currentInstructor),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('settings.switchRole')));
      await tester.pumpAndSettle();

      expect(find.text(RoleStrings.question), findsOneWidget);
      expect(find.byType(InstructorDock), findsNothing);
    });

    testWidgets('back from another tab goes Home first', (tester) async {
      await openAsInstructor(tester);
      await openFromMenu(tester, 'tracker');
      expect(_home, findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(_home, findsOneWidget);
      expect(find.byType(InstructorShell), findsOneWidget);
    });

    testWidgets('the camera stops on another tab and the subject is kept', (
      tester,
    ) async {
      await openAsInstructor(tester);
      await openFromMenu(tester, 'scanner');
      await tester.tap(find.text(ScannerStrings.subjectPlaceholder));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Object Oriented Programming').last);
      await tester.pumpAndSettle();

      expect(_camera, findsOneWidget);
      expect(awake, [true]);

      await openFromMenu(tester, 'tracker');
      // Let go, not left running behind the tracker — nor the screen held
      // on for it.
      expect(_camera, findsNothing);
      expect(awake, [true, false]);

      await openFromMenu(tester, 'scanner');
      expect(_camera, findsOneWidget);
      expect(awake, [true, false, true]);
      expect(find.text(ScannerStrings.readyToScan), findsOneWidget);
    });

    testWidgets('Links opens from the Menu, with the class links', (
      tester,
    ) async {
      await openAsInstructor(tester);

      await tester.tap(find.byKey(const ValueKey('nav.menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu.links')));
      await tester.pump();
      // Its splash first, once, like the other tabs.
      expect(find.byType(LinksSplash), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.byType(LinksSplash), findsNothing);
      expect(find.text(LinksStrings.title), findsOneWidget);
      expect(find.text('Introduction to Computing'), findsOneWidget);
      // The camera is let go here too, and the Menu button is still there.
      expect(_camera, findsNothing);
      expect(find.byType(InstructorDock), findsOneWidget);
    });

    testWidgets('no Links without the permission, until it is given', (
      tester,
    ) async {
      final links = find.byKey(const ValueKey('instructorHome.links'));
      Future<void> refresh() async {
        await tester.drag(
          find.text(InstructorHomeStrings.scannedToday),
          const Offset(0, 400),
        );
        await tester.pumpAndSettle();
      }

      scanner.links = false;
      await openAsInstructor(tester);

      expect(links, findsNothing);
      expect(
        find.byKey(const ValueKey('instructorHome.tracker')),
        findsOneWidget,
      );

      // Ticked on the web: the next answer about the account brings it.
      scanner.links = true;
      await refresh();
      expect(links, findsOneWidget);

      // And unticked again: gone with the next answer, and the bar does not
      // jump back to it if it returns.
      await tester.tap(links);
      await tester.pumpAndSettle();
      await openFromMenu(tester, 'home');
      scanner.links = false;
      await refresh();
      expect(links, findsNothing);
      expect(_home, findsOneWidget);
      expect(find.text(LinksStrings.title), findsNothing);
    });
  });
}

/// Opens one of the instructor's tabs the only way there is: the Menu
/// button at the foot of the screen, then the tab's tile.
Future<void> openFromMenu(WidgetTester tester, String tab) async {
  await tester.tap(find.byKey(const ValueKey('nav.menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('menu.$tab')));
  await tester.pumpAndSettle();
}
