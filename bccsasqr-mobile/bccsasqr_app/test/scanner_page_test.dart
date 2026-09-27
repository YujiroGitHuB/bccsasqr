import 'package:bccsasqr_app/app.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/services/app_info.dart';
import 'package:bccsasqr_app/services/qr_export_service.dart';
import 'package:bccsasqr_app/services/scan_feedback.dart';
import 'package:bccsasqr_app/services/device_lock.dart';
import 'package:bccsasqr_app/services/scanner_repository.dart';
import 'package:bccsasqr_app/services/settings_store.dart';
import 'package:bccsasqr_app/services/speech_service.dart';
import 'package:bccsasqr_app/services/student_repository.dart';
import 'package:bccsasqr_app/views/scanner/scanner_intro.dart';
import 'package:bccsasqr_app/views/scanner/widgets/scan_result_card.dart';
import 'package:bccsasqr_app/views/widgets/surface_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bccsasqr_app/models/app_role.dart';
import 'package:bccsasqr_app/services/role_store.dart';

class _NoExport implements QrExportService {
  @override
  Future<String> export({
    required GlobalKey boundaryKey,
    required String fileName,
    String? shareText,
  }) async => fileName;
}

/// Stands in for the camera: one button per code a test wants "scanned".
Widget _fakeCamera(BuildContext context, ValueChanged<String> onCode) =>
    ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final code in ['019-464', '023-770', 'not-a-student'])
              TextButton(
                key: ValueKey('scan:$code'),
                onPressed: () => onCode(code),
                child: Text('scan $code'),
              ),
          ],
        ),
      ),
    );

void main() {
  late List<bool> awake;
  late InMemoryScannerRepository scanner;

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.devicePixelRatio = 1.0;
    view.physicalSize = const Size(420, 2000);
    awake = [];
    scanner = InMemoryScannerRepository(latency: Duration.zero);
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Widget app() => BccSasqrApp(
    roleStore: MemoryRoleStore(AppRole.instructor),
    repository: InMemoryStudentRepository(latency: Duration.zero),
    exportService: _NoExport(),
    speech: const SilentSpeechService(),
    scannerRepository: scanner,
    scanFeedback: const SilentScanFeedback(),
    cameraBuilder: _fakeCamera,
    keepAwake: (on) async => awake.add(on),
    settingsStore: MemorySettingsStore(),
    deviceLock: const NoDeviceLock(),
    scannerLockStore: MemoryScannerLockStore(),
    appInfo: () async => const AppInfo(version: '1.1.0', buildNumber: '2'),
    showSplash: false,
  );

  /// An instructor's phone opens on the sign-in → signed in → subject
  /// picked.
  Future<void> openScanner(WidgetTester tester) async {
    // The scan line sweeps forever; with reduced motion it holds still, so
    // pumpAndSettle can settle.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text(ScannerStrings.signInHeading), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'demo@bcc.test');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.widgetWithText(FilledButton, ScannerStrings.signIn));
    await tester.pumpAndSettle();
  }

  Future<void> pickSubject(WidgetTester tester) async {
    await tester.tap(find.text(ScannerStrings.subjectPlaceholder));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Object Oriented Programming').last);
    await tester.pumpAndSettle();
  }

  testWidgets('the camera waits for a subject', (tester) async {
    await openScanner(tester);

    expect(find.text(ScannerStrings.title), findsOneWidget);
    expect(find.text(ScannerStrings.selectSubjectFirst), findsOneWidget);
    expect(find.text(ScannerStrings.cameraIdle), findsOneWidget);
    expect(find.byKey(const ValueKey('scan:019-464')), findsNothing);
    expect(awake, isEmpty);

    await pickSubject(tester);

    expect(find.text(ScannerStrings.readyToScan), findsOneWidget);
    expect(find.text(ScannerStrings.lateTitle), findsOneWidget);
    expect(find.byKey(const ValueKey('scan:019-464')), findsOneWidget);
    // The screen is held on only once the camera runs.
    expect(awake, [true]);
  });

  testWidgets('a scan shows the student and lands in the list', (tester) async {
    await openScanner(tester);
    await pickSubject(tester);

    await tester.tap(find.byKey(const ValueKey('scan:019-464')));
    await tester.pumpAndSettle();

    expect(find.byType(ScanResultCard), findsOneWidget);
    expect(find.text('✓ Object Oriented Programming'), findsOneWidget);
    expect(
      find.textContaining('✓ Charles Nixon Cayading - Object Oriented'),
      findsOneWidget,
    );
    // The card and the list row.
    expect(find.text('Charles Nixon Cayading'), findsNWidgets(2));

    // Let the card's hold run out, or its timer outlives the test.
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('no photo on file is said plainly on the card', (tester) async {
    await openScanner(tester);
    await pickSubject(tester);

    await tester.tap(find.byKey(const ValueKey('scan:023-770')));
    await tester.pumpAndSettle();

    expect(find.text(ScannerStrings.noPhoto), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('late marking tags the next scan', (tester) async {
    await openScanner(tester);
    await pickSubject(tester);

    await tester.tap(find.text(ScannerStrings.lateTitle));
    await tester.pumpAndSettle();
    expect(find.text(ScannerStrings.lateOn), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('scan:019-464')));
    await tester.pumpAndSettle();

    // On the card and in the list.
    expect(find.text(ScannerStrings.lateTag), findsNWidgets(2));
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a foreign QR says Invalid QR Code on the island, which closes', (
    tester,
  ) async {
    await openScanner(tester);
    await pickSubject(tester);

    await tester.tap(find.byKey(const ValueKey('scan:not-a-student')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(ScannerStrings.invalidQrTitle), findsOneWidget);
    // Not a dialog: nothing to tap before the next student.
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const ValueKey('scan:019-464')).hitTestable(), findsOne);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text(ScannerStrings.invalidQrTitle), findsNothing);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('signing out: avatar, then the sheet, then a confirmation', (
    tester,
  ) async {
    await openScanner(tester);

    await tester.tap(find.byTooltip(ScannerStrings.account));
    await tester.pumpAndSettle();
    // The sheet says who is signed in before offering to sign out.
    expect(find.text('demo@bcc.test'), findsOneWidget);

    await tester.tap(find.text(ScannerStrings.signOut).last);
    await tester.pumpAndSettle();
    expect(find.text(ScannerStrings.signOutConfirmTitle), findsOneWidget);

    await tester.tap(find.text(ScannerStrings.signOut).last);
    await tester.pumpAndSettle();
    expect(find.text(ScannerStrings.signInHeading), findsOneWidget);
  });

  testWidgets('cancelling the confirmation keeps you signed in', (
    tester,
  ) async {
    await openScanner(tester);

    await tester.tap(find.byTooltip(ScannerStrings.account));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ScannerStrings.signOut).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(ScannerStrings.cancel));
    await tester.pumpAndSettle();

    expect(find.text(ScannerStrings.title), findsOneWidget);
    expect(find.text(ScannerStrings.signInHeading), findsNothing);
  });

  testWidgets('the account sheet opens the Settings tab', (tester) async {
    await openScanner(tester);

    await tester.tap(find.byTooltip(ScannerStrings.account));
    await tester.pumpAndSettle();
    // The sheet's row, over the bar's own Settings.
    await tester.tap(find.text(SettingsStrings.title).last);
    await tester.pumpAndSettle();

    expect(find.text(SettingsStrings.appearance), findsOneWidget);
    expect(find.text('1.1.0 (build 2)'), findsOneWidget);
    // The bar's tab, not a page pushed over the scanner.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byTooltip(AppStrings.homeBack), findsNothing);
  });

  testWidgets('a refused sign-in shakes the form and says why', (tester) async {
    // At full speed, as on a phone: the shake is what is being checked.
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final form = find
        .ancestor(
          of: find.byType(TextField).first,
          matching: find.byType(SurfacePanel),
        )
        .first;
    final rest = tester.getTopLeft(form).dx;

    await tester.tap(find.widgetWithText(FilledButton, ScannerStrings.signIn));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getTopLeft(form).dx, isNot(rest));
    expect(find.text(ScannerStrings.errorCredentialsEmpty), findsOneWidget);

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(form).dx, rest);
    // The note for whoever came to see what was behind the card.
    expect(find.text(ScannerStrings.signInOnlyInstructors), findsOneWidget);
  });

  testWidgets('the scanner tab plays its splash, then asks to sign in', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    // The instructor's bar opens on it, once the role has been read.
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump();

    expect(find.byType(ScannerSplash), findsOneWidget);
    expect(find.text(ScannerStrings.checkingSession), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(ScannerSplash), findsNothing);
    expect(find.text(ScannerStrings.signInHeading), findsOneWidget);
  });

  // At full speed, as on a phone: the timings are what is being checked.
  Future<void> signInAtFullSpeed(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text(ScannerStrings.signInHeading), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'demo@bcc.test');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.widgetWithText(FilledButton, ScannerStrings.signIn));
  }

  testWidgets('a sign-in typed in is welcomed by name, then the scanner '
      'opens', (tester) async {
    await signInAtFullSpeed(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byType(ScannerWelcome), findsOneWidget);
    expect(
      find.text(ScannerStrings.welcomeTitle('Demo Instructor')),
      findsOneWidget,
    );
    // Their own initials in the ring, with the signed-in chip under it.
    expect(
      find.descendant(
        of: find.byType(ScannerWelcome),
        matching: find.text('DI'),
      ),
      findsOneWidget,
    );
    expect(find.text(ScannerStrings.welcomeLabel), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(ScannerWelcome), findsNothing);
    expect(find.text(ScannerStrings.title), findsOneWidget);
  });

  testWidgets('a saved sign-in says welcome back on the splash and skips '
      'the welcome', (tester) async {
    await signInAtFullSpeed(tester);
    await tester.pumpAndSettle();

    // The app closed and opened again: the sign-in is kept on the phone.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.byType(ScannerSplash), findsOneWidget);
    expect(
      find.text(ScannerStrings.welcomeBack('Demo Instructor')),
      findsOneWidget,
    );

    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(ScannerWelcome), findsNothing);
    }
    await tester.pumpAndSettle();
    expect(find.text(ScannerStrings.title), findsOneWidget);
  });

  testWidgets('lays out on a small phone without overflowing', (tester) async {
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .views
        .first
        .physicalSize = const Size(
      320,
      2200,
    );

    await openScanner(tester);
    await pickSubject(tester);
    await tester.tap(find.byKey(const ValueKey('scan:023-770')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ScanResultCard), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });
}
