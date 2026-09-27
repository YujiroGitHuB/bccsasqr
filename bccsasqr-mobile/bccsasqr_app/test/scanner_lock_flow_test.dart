import 'package:bccsasqr_app/app.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/services/app_info.dart';
import 'package:bccsasqr_app/services/device_lock.dart';
import 'package:bccsasqr_app/services/scan_feedback.dart';
import 'package:bccsasqr_app/services/scanner_repository.dart';
import 'package:bccsasqr_app/services/settings_store.dart';
import 'package:bccsasqr_app/services/speech_service.dart';
import 'package:bccsasqr_app/services/student_repository.dart';
import 'package:bccsasqr_app/views/scanner/scanner_lock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A phone whose lock answers from a script: the next results in order,
/// "unlocked" once the script runs out.
class _FakeDeviceLock implements DeviceLock {
  bool available = true;
  final List<DeviceUnlock> script = [];
  final List<String> asked = [];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<DeviceUnlock> unlock(String reason) async {
    asked.add(reason);
    return script.isEmpty ? DeviceUnlock.unlocked : script.removeAt(0);
  }
}

void main() {
  late _FakeDeviceLock device;
  late MemoryScannerLockStore store;

  setUp(() {
    device = _FakeDeviceLock();
    store = MemoryScannerLockStore();
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.devicePixelRatio = 1.0;
    view.physicalSize = const Size(420, 1600);
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Widget app() => BccSasqrApp(
    repository: InMemoryStudentRepository(latency: Duration.zero),
    speech: const SilentSpeechService(),
    scannerRepository: InMemoryScannerRepository(latency: Duration.zero),
    scanFeedback: const SilentScanFeedback(),
    cameraBuilder: (context, onCode) => const ColoredBox(color: Colors.black),
    keepAwake: (on) async {},
    settingsStore: MemorySettingsStore(),
    appInfo: () async => const AppInfo(version: '1.3.2', buildNumber: '6'),
    deviceLock: device,
    scannerLockStore: store,
    showSplash: false,
  );

  /// Home → scanner → signed in with the password.
  Future<void> signIn(WidgetTester tester) async {
    // The scan lines sweep forever; held still, pumpAndSettle can settle.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home.scanner')));
    await tester.pumpAndSettle();

    // No lock before a sign-in: there is nothing to unlock.
    expect(find.byType(ScannerLockScreen), findsNothing);
    expect(find.text(ScannerStrings.signInHeading), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'demo@bcc.test');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.widgetWithText(FilledButton, ScannerStrings.signIn));
    await tester.pumpAndSettle();
  }

  /// Signs in and says yes to the lock.
  Future<void> signInWithLock(WidgetTester tester) async {
    await signIn(tester);
    await tester.tap(find.byKey(const ValueKey('lock.offer.on')));
    await tester.pumpAndSettle();
  }

  /// Back to the home screen and into the scanner again — the saved sign-in.
  Future<void> reopen(WidgetTester tester) async {
    await tester.tap(find.byTooltip(AppStrings.homeBack));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home.scanner')));
    await tester.pumpAndSettle();
  }

  testWidgets('after a password sign-in the lock is offered, and turning it '
      'on asks the phone first', (tester) async {
    await signIn(tester);

    expect(find.text(ScannerStrings.lockOfferTitle), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('lock.offer.on')));
    await tester.pumpAndSettle();

    expect(device.asked, [ScannerStrings.lockEnableReason]);
    expect(store.enabled, isTrue);
    expect(find.text(ScannerStrings.lockOn), findsOneWidget);
    expect(find.text(ScannerStrings.title), findsOneWidget);
  });

  testWidgets('"Not now" leaves it off, and the scanner opens next time '
      'without asking', (tester) async {
    await signIn(tester);
    await tester.tap(find.byKey(const ValueKey('lock.offer.later')));
    await tester.pumpAndSettle();

    expect(store.enabled, isFalse);
    expect(device.asked, isEmpty);

    await reopen(tester);
    expect(find.byType(ScannerLockScreen), findsNothing);
    expect(find.text(ScannerStrings.title), findsOneWidget);
  });

  testWidgets('a phone without a screen lock is not offered one', (
    tester,
  ) async {
    device.available = false;
    await signIn(tester);

    expect(find.text(ScannerStrings.lockOfferTitle), findsNothing);
    expect(find.text(ScannerStrings.title), findsOneWidget);
  });

  testWidgets('with the lock on, a saved sign-in waits behind it', (
    tester,
  ) async {
    await signInWithLock(tester);

    // The first prompt is closed: still locked, and the camera never shown.
    device.script.add(DeviceUnlock.cancelled);
    await reopen(tester);

    expect(find.byType(ScannerLockScreen), findsOneWidget);
    expect(find.text(ScannerStrings.lockNotUnlocked), findsOneWidget);
    expect(find.text(ScannerStrings.title), findsNothing);
    expect(device.asked.last, ScannerStrings.lockReason);

    await tester.tap(find.byKey(const ValueKey('lock.unlock')));
    await tester.pumpAndSettle();

    expect(find.byType(ScannerLockScreen), findsNothing);
    expect(find.text(ScannerStrings.title), findsOneWidget);
  });

  testWidgets('the owner\'s finger opens it straight away', (tester) async {
    await signInWithLock(tester);
    await reopen(tester);

    // Asked on arrival, and answered: straight to the scanner.
    expect(device.asked, [
      ScannerStrings.lockEnableReason,
      ScannerStrings.lockReason,
    ]);
    expect(find.text(ScannerStrings.title), findsOneWidget);
  });

  testWidgets('"Sign in with password instead" signs out and drops the lock', (
    tester,
  ) async {
    await signInWithLock(tester);
    device.script.add(DeviceUnlock.cancelled);
    await reopen(tester);

    await tester.tap(find.byKey(const ValueKey('lock.password')));
    await tester.pumpAndSettle();

    expect(find.text(ScannerStrings.signInHeading), findsOneWidget);
    expect(store.enabled, isFalse);
  });

  testWidgets('a screen lock switched off asks for the password, and says '
      'why', (tester) async {
    await signInWithLock(tester);
    device.available = false;
    await reopen(tester);

    expect(find.text(ScannerStrings.signInHeading), findsOneWidget);
    expect(find.text(ScannerStrings.lockLost), findsOneWidget);
    expect(store.enabled, isFalse);
  });

  testWidgets('the switch in the account sheet turns it off', (tester) async {
    await signInWithLock(tester);

    await tester.tap(find.byTooltip(ScannerStrings.account));
    await tester.pumpAndSettle();
    expect(find.text(ScannerStrings.lockTile), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('account.lock')));
    await tester.pumpAndSettle();

    expect(store.enabled, isFalse);
  });
}
