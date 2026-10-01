import 'package:bccsasqr_app/app.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/core/constants/whats_new_log.dart';
import 'package:bccsasqr_app/core/theme/app_colors.dart';
import 'package:bccsasqr_app/core/theme/app_theme.dart';
import 'package:bccsasqr_app/models/app_role.dart';
import 'package:bccsasqr_app/services/app_info.dart';
import 'package:bccsasqr_app/services/device_lock.dart';
import 'package:bccsasqr_app/services/onboarding_store.dart';
import 'package:bccsasqr_app/services/qr_export_service.dart';
import 'package:bccsasqr_app/services/role_store.dart';
import 'package:bccsasqr_app/services/scan_feedback.dart';
import 'package:bccsasqr_app/services/scanner_repository.dart';
import 'package:bccsasqr_app/services/settings_store.dart';
import 'package:bccsasqr_app/services/speech_service.dart';
import 'package:bccsasqr_app/services/student_repository.dart';
import 'package:bccsasqr_app/services/tracker_repository.dart';
import 'package:bccsasqr_app/services/whats_new_store.dart';
import 'package:bccsasqr_app/views/get_started_splash.dart';
import 'package:bccsasqr_app/views/onboarding_page.dart';
import 'package:bccsasqr_app/views/role_picker_page.dart';
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

void main() {
  late MemoryRoleStore roles;
  late MemoryOnboardingStore onboarding;

  setUp(() {
    roles = MemoryRoleStore();
    onboarding = MemoryOnboardingStore();
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.devicePixelRatio = 1.0;
    view.physicalSize = const Size(420, 900);
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Widget app() => BccSasqrApp(
    roleStore: roles,
    onboardingStore: onboarding,
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
    appInfo: () async => const AppInfo(version: '1.9.0', buildNumber: '13'),
    cameraBuilder: (context, onCode) =>
        const ColoredBox(key: ValueKey('camera'), color: Colors.black),
    keepAwake: (on) async {},
    showSplash: false,
  );

  /// At full speed, as on a phone: every animation on the way must end, or
  /// pumpAndSettle never returns.
  Future<void> launch(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.text(OnboardingStrings.next));
    await tester.pumpAndSettle();
  }

  testWidgets('the first launch opens on the introduction, then asks the '
      'question', (tester) async {
    await launch(tester);

    expect(find.text(OnboardingStrings.welcomeTitle), findsOneWidget);
    expect(find.text(RoleStrings.question), findsNothing);

    await next(tester);
    expect(find.text(OnboardingStrings.qrTitle), findsOneWidget);
    await next(tester);
    expect(find.text(OnboardingStrings.scanTitle), findsOneWidget);
    await next(tester);
    expect(find.text(OnboardingStrings.daysTitle), findsOneWidget);
    // The calendar has counted its days by the time it holds still.
    expect(find.text(OnboardingStrings.daysChip(12)), findsOneWidget);
    expect(find.text(OnboardingStrings.next), findsNothing);

    await tester.tap(find.text(OnboardingStrings.start));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Its splash first, the question after it.
    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.byType(GetStartedSplash), findsOneWidget);
    expect(find.text(AppStrings.startSplashTagline), findsOneWidget);
    expect(find.text(RoleStrings.question), findsNothing);
    expect(onboarding.seen, isTrue);

    await tester.pumpAndSettle();
    expect(find.byType(GetStartedSplash), findsNothing);
    expect(find.text(RoleStrings.question), findsOneWidget);
  });

  testWidgets('Skip plays the same splash, then asks the question', (
    tester,
  ) async {
    await launch(tester);
    await tester.tap(find.text(OnboardingStrings.skip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(GetStartedSplash), findsOneWidget);
    expect(onboarding.seen, isTrue);

    await tester.pumpAndSettle();
    expect(find.byType(GetStartedSplash), findsNothing);
    expect(find.text(RoleStrings.question), findsOneWidget);
  });

  testWidgets('seen once, it is not shown again, nor its splash', (
    tester,
  ) async {
    onboarding = MemoryOnboardingStore(seen: true);
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump();

    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.byType(GetStartedSplash), findsNothing);
    expect(find.byType(RolePickerPage), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text(RoleStrings.question), findsOneWidget);
  });

  testWidgets('a phone that already has a role goes on as it was', (
    tester,
  ) async {
    roles = MemoryRoleStore(AppRole.student);
    await launch(tester);

    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.byKey(const ValueKey('home.generator')), findsOneWidget);
  });

  testWidgets('a swipe moves on a slide; back steps back one', (tester) async {
    await launch(tester);

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(OnboardingStrings.qrTitle), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(OnboardingStrings.welcomeTitle), findsOneWidget);
    expect(find.byType(OnboardingPage), findsOneWidget);
  });

  testWidgets('a dot goes straight to its slide', (tester) async {
    await launch(tester);

    await tester.tap(find.byKey(const ValueKey('onboarding.dot.3')));
    await tester.pumpAndSettle();

    expect(find.text(OnboardingStrings.daysTitle), findsOneWidget);
    expect(find.text(OnboardingStrings.start), findsOneWidget);
  });

  testWidgets('Settings → App tour shows it again, closed by Done', (
    tester,
  ) async {
    roles = MemoryRoleStore(AppRole.student);
    onboarding = MemoryOnboardingStore(seen: true);
    await launch(tester);

    await tester.tap(find.byKey(const ValueKey('home.settings')));
    await tester.pumpAndSettle();
    final tour = find.byKey(const ValueKey('settings.tour'));
    await tester.ensureVisible(tour);
    await tester.pumpAndSettle();
    await tester.tap(tour);
    await tester.pumpAndSettle();

    expect(find.text(OnboardingStrings.welcomeTitle), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await next(tester);
    }
    await tester.tap(find.text(OnboardingStrings.done));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.text(SettingsStrings.title), findsOneWidget);
    // The phone's role is untouched.
    expect(roles.saved, AppRole.student);
  });

  testWidgets('lays out on a small phone, with large text, without '
      'overflowing', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await launch(tester);
    for (var i = 0; i < 3; i++) {
      expect(tester.takeException(), isNull);
      await next(tester);
    }
    expect(tester.takeException(), isNull);

    // Its splash too, frame by frame: the parts fly in from the edges.
    await tester.tap(find.text(OnboardingStrings.start));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull, reason: 'frame $i');
    }
    await tester.pumpAndSettle();
    expect(find.text(RoleStrings.question), findsOneWidget);
  });

  testWidgets('its splash holds still once it has played, in both themes', (
    tester,
  ) async {
    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppPalette.light),
          darkTheme: AppTheme.build(AppPalette.dark),
          themeMode: mode,
          home: GetStartedSplash(onFinished: () {}),
        ),
      );
      // pumpAndSettle returns only once nothing is left moving.
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.startStepReady), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$mode');
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
