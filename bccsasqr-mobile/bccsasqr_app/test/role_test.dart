import 'package:bccsasqr_app/app.dart';
import 'package:bccsasqr_app/controllers/role_controller.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/models/app_role.dart';
import 'package:bccsasqr_app/services/app_info.dart';
import 'package:bccsasqr_app/services/device_lock.dart';
import 'package:bccsasqr_app/services/qr_export_service.dart';
import 'package:bccsasqr_app/services/role_store.dart';
import 'package:bccsasqr_app/services/scan_feedback.dart';
import 'package:bccsasqr_app/services/scanner_repository.dart';
import 'package:bccsasqr_app/services/settings_store.dart';
import 'package:bccsasqr_app/services/speech_service.dart';
import 'package:bccsasqr_app/services/student_repository.dart';
import 'package:bccsasqr_app/services/tracker_repository.dart';
import 'package:bccsasqr_app/services/whats_new_store.dart';
import 'package:bccsasqr_app/core/constants/whats_new_log.dart';
import 'package:bccsasqr_app/views/generator_splash.dart';
import 'package:bccsasqr_app/views/instructor_shell.dart';
import 'package:bccsasqr_app/views/scanner/scanner_flow.dart';
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
  });

  group('the app', () {
    late MemoryRoleStore roles;
    late List<bool> awake;

    setUp(() {
      roles = MemoryRoleStore();
      awake = [];
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
      scannerRepository: InMemoryScannerRepository(latency: Duration.zero),
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
    void reduceMotion(WidgetTester tester) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }

    testWidgets('the first launch asks; a student gets no scanner', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.text(RoleStrings.question), findsOneWidget);
      expect(find.byKey(const ValueKey('home.generator')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('role.student')));
      await tester.pumpAndSettle();

      expect(roles.saved, AppRole.student);
      expect(find.byKey(const ValueKey('home.generator')), findsOneWidget);
      expect(find.byKey(const ValueKey('home.tracker')), findsOneWidget);
      // Nothing of the instructor's, anywhere.
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(ScannerFlow, skipOffstage: false), findsNothing);
      expect(find.text(NavStrings.scanner), findsNothing);
    });

    testWidgets('an instructor gets the bar, opening on the scanner', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('role.instructor')));
      await tester.pumpAndSettle();

      expect(roles.saved, AppRole.instructor);
      expect(find.byType(NavigationBar), findsOneWidget);
      for (final label in [
        NavStrings.qr,
        NavStrings.scanner,
        NavStrings.tracker,
        NavStrings.settings,
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text(ScannerStrings.signInHeading), findsOneWidget);
      // The other tabs are built the first time they are opened.
      expect(find.byType(GeneratorIntro, skipOffstage: false), findsNothing);

      await tester.tap(find.byKey(const ValueKey('nav.qr')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.studentNumberLabel), findsOneWidget);
      expect(find.text(ScannerStrings.signInHeading), findsNothing);
    });

    testWidgets('a saved role skips the question', (tester) async {
      roles = MemoryRoleStore(AppRole.instructor);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.text(RoleStrings.question), findsNothing);
      expect(find.byType(InstructorShell), findsOneWidget);
    });

    testWidgets('Settings → Role asks again, from either half', (tester) async {
      roles = MemoryRoleStore(AppRole.student);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('home.settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings.switchRole')));
      await tester.pumpAndSettle();

      // Settings was a page over the home screen; it is closed too.
      expect(find.text(RoleStrings.question), findsOneWidget);
      expect(find.text(SettingsStrings.title), findsNothing);
      expect(roles.saved, isNull);

      await tester.tap(find.byKey(const ValueKey('role.instructor')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav.settings')));
      await tester.pumpAndSettle();
      expect(find.text(RoleStrings.currentInstructor), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('settings.switchRole')));
      await tester.pumpAndSettle();

      expect(find.text(RoleStrings.question), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('back from another tab goes to the scanner first', (
      tester,
    ) async {
      roles = MemoryRoleStore(AppRole.instructor);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav.tracker')));
      await tester.pumpAndSettle();
      expect(find.text(ScannerStrings.signInHeading), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text(ScannerStrings.signInHeading), findsOneWidget);
      expect(find.byType(InstructorShell), findsOneWidget);
    });

    testWidgets('the camera stops on another tab and the subject is kept', (
      tester,
    ) async {
      reduceMotion(tester);
      roles = MemoryRoleStore(AppRole.instructor);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'demo@bcc.test');
      await tester.enterText(find.byType(TextField).at(1), 'secret');
      await tester.tap(
        find.widgetWithText(FilledButton, ScannerStrings.signIn),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(ScannerStrings.subjectPlaceholder));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Object Oriented Programming').last);
      await tester.pumpAndSettle();

      expect(_camera, findsOneWidget);
      expect(awake, [true]);

      await tester.tap(find.byKey(const ValueKey('nav.tracker')));
      await tester.pumpAndSettle();
      // Let go, not left running behind the tracker — nor the screen held
      // on for it.
      expect(_camera, findsNothing);
      expect(awake, [true, false]);

      await tester.tap(find.byKey(const ValueKey('nav.scanner')));
      await tester.pumpAndSettle();
      expect(_camera, findsOneWidget);
      expect(awake, [true, false, true]);
      expect(find.text(ScannerStrings.readyToScan), findsOneWidget);
    });
  });
}
