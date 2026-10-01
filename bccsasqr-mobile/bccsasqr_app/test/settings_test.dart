import 'package:bccsasqr_app/app.dart';
import 'package:bccsasqr_app/controllers/settings_controller.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/core/theme/app_colors.dart';
import 'package:bccsasqr_app/models/app_settings.dart';
import 'package:bccsasqr_app/services/app_info.dart';
import 'package:bccsasqr_app/services/device_lock.dart';
import 'package:bccsasqr_app/services/qr_export_service.dart';
import 'package:bccsasqr_app/services/scan_feedback.dart';
import 'package:bccsasqr_app/services/scanner_repository.dart';
import 'package:bccsasqr_app/services/settings_store.dart';
import 'package:bccsasqr_app/services/speech_service.dart';
import 'package:bccsasqr_app/services/student_repository.dart';
import 'package:bccsasqr_app/views/about_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _RecordingSpeech implements SpeechService {
  final List<String> said = [];

  @override
  Future<void> speak(String text) async => said.add(text);

  @override
  Future<void> stop() async {}
}

void main() {
  group('SettingsController', () {
    test('starts from what was saved', () async {
      final c = SettingsController(
        store: MemorySettingsStore(
          const AppSettings(themeMode: ThemeMode.dark, sound: false),
        ),
      );
      await c.load();

      expect(c.themeMode, ThemeMode.dark);
      expect(c.sound, isFalse);
      expect(c.vibration, isTrue);
    });

    test('saves every change', () async {
      final store = MemorySettingsStore();
      final c = SettingsController(store: store);
      await c.load();

      c.setThemeMode(ThemeMode.light);
      c.setVoice(false);
      await Future<void>.delayed(Duration.zero);

      expect(store.saved.themeMode, ThemeMode.light);
      expect(store.saved.voice, isFalse);
    });

    test('an unchanged value does not rebuild the app', () async {
      final c = SettingsController(store: MemorySettingsStore());
      await c.load();
      var notified = 0;
      c.addListener(() => notified++);

      c.setSound(true);
      expect(notified, 0);
    });
  });

  test(
    'the Voice switch silences speech without touching the engine',
    () async {
      final inner = _RecordingSpeech();
      var on = true;
      final speech = ToggleableSpeechService(inner, enabled: () => on);

      await speech.speak('one');
      on = false;
      await speech.speak('two');

      expect(inner.said, ['one']);
    },
  );

  group('screens', () {
    late MemorySettingsStore store;

    setUp(() {
      store = MemorySettingsStore();
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.devicePixelRatio = 1.0;
      view.physicalSize = const Size(420, 1800);
    });

    tearDown(() {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    // The instructor's Settings: the one with the scanner's switches.
    Widget app({AppRole role = AppRole.instructor}) => BccSasqrApp(
      roleStore: MemoryRoleStore(role),
      repository: InMemoryStudentRepository(latency: Duration.zero),
      exportService: _NoExport(),
      speech: const SilentSpeechService(),
      scannerRepository: InMemoryScannerRepository(latency: Duration.zero),
      scanFeedback: const SilentScanFeedback(),
      settingsStore: store,
      deviceLock: const NoDeviceLock(),
      scannerLockStore: MemoryLockSwitchStore(),
      appInfo: () async => const AppInfo(version: '1.1.0', buildNumber: '2'),
      cameraBuilder: (context, onCode) => const SizedBox.shrink(),
      keepAwake: (on) async {},
      showSplash: false,
    );

    Brightness brightnessOf(WidgetTester tester) => Theme.of(
      tester.element(find.text(SettingsStrings.title).first),
    ).brightness;

    Future<void> openSettings(WidgetTester tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await signInAsInstructor(tester);
      await openFromMenu(tester, 'settings');
    }

    testWidgets('the Menu opens Settings, with the version', (tester) async {
      await openSettings(tester);

      expect(find.text(SettingsStrings.appearance), findsOneWidget);
      expect(find.text(SettingsStrings.feedback), findsOneWidget);
      expect(find.text(SettingsStrings.sound), findsOneWidget);
      expect(find.text('1.1.0 (build 2)'), findsOneWidget);
      // No API_BASE_URL in a test build.
      expect(find.text(SettingsStrings.serverDemo), findsOneWidget);
      // A tab, not a page: nothing to go back to.
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    });

    testWidgets('the version opens the About card, which copies it', (
      tester,
    ) async {
      String? copied;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await tester.pumpWidget(app(role: AppRole.student));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home.settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings.version')));
      await tester.pumpAndSettle();

      final card = find.byType(AboutCard);
      Finder inCard(Finder f) => find.descendant(of: card, matching: f);
      expect(card, findsOneWidget);
      expect(
        inCard(find.textContaining('Version 1.1.0', findRichText: true)),
        findsOneWidget,
      );
      expect(inCard(find.text(AboutStrings.demo)), findsOneWidget);
      expect(inCard(find.text(RoleStrings.currentStudent)), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('about.copy')));
      await tester.pump();
      expect(copied, contains('BCC SASQR 1.1.0 (build 2)'));
      expect(copied, contains('${AboutStrings.role}: Student'));
      expect(inCard(find.text(AboutStrings.copied)), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(inCard(find.text(AboutStrings.copy)), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('about.done')));
      await tester.pumpAndSettle();
      expect(card, findsNothing);
    });

    testWidgets('a student\'s Settings has only the voice, no scanner', (
      tester,
    ) async {
      await tester.pumpWidget(app(role: AppRole.student));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home.settings')));
      await tester.pumpAndSettle();

      expect(find.text(SettingsStrings.feedbackStudent), findsOneWidget);
      expect(find.text(SettingsStrings.voice), findsOneWidget);
      expect(find.text(SettingsStrings.feedback), findsNothing);
      expect(find.text(SettingsStrings.sound), findsNothing);
      expect(find.text(SettingsStrings.vibration), findsNothing);
      expect(find.text(RoleStrings.currentStudent), findsOneWidget);
      // A part of the Menu, as on the instructor's side: no back arrow.
      expect(find.byTooltip(AppStrings.homeBack), findsNothing);
    });

    testWidgets('a student turns off the alerts and the card\'s own turns, '
        'and both are saved', (tester) async {
      await tester.pumpWidget(app(role: AppRole.student));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home.settings')));
      await tester.pumpAndSettle();

      expect(find.text(SettingsStrings.notifications), findsOneWidget);
      expect(store.saved.alerts, isTrue);
      expect(store.saved.cardTurns, isTrue);

      await tester.tap(find.byKey(const ValueKey('settings.alerts')));
      await tester.tap(find.byKey(const ValueKey('settings.cardTurns')));
      await tester.pumpAndSettle();

      expect(store.saved.alerts, isFalse);
      expect(store.saved.cardTurns, isFalse);
    });

    testWidgets('an instructor\'s Settings has neither', (tester) async {
      await openSettings(tester);

      expect(find.text(SettingsStrings.notifications), findsNothing);
      expect(find.byKey(const ValueKey('settings.alerts')), findsNothing);
      expect(find.byKey(const ValueKey('settings.cardTurns')), findsNothing);
    });

    testWidgets('picking Dark repaints the app dark, and is remembered', (
      tester,
    ) async {
      await openSettings(tester);
      expect(brightnessOf(tester), Brightness.light);

      await tester.tap(find.text(SettingsStrings.themeDark));
      await tester.pumpAndSettle();

      expect(brightnessOf(tester), Brightness.dark);
      final canvas = tester
          .widget<Scaffold>(find.byType(Scaffold).last)
          .backgroundColor;
      expect(
        canvas ??
            Theme.of(
              tester.element(find.byType(Scaffold).last),
            ).scaffoldBackgroundColor,
        AppPalette.dark.canvas,
      );
      expect(store.saved.themeMode, ThemeMode.dark);
    });

    testWidgets('a saved theme is there from the first screen', (tester) async {
      store = MemorySettingsStore(const AppSettings(themeMode: ThemeMode.dark));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      final context = tester.element(find.text(ScannerStrings.signInHeading));
      expect(Theme.of(context).brightness, Brightness.dark);
    });

    testWidgets('the feedback switches flip and are saved', (tester) async {
      await openSettings(tester);

      await tester.tap(find.text(SettingsStrings.sound));
      await tester.tap(find.text(SettingsStrings.voice));
      await tester.pumpAndSettle();

      expect(store.saved.sound, isFalse);
      expect(store.saved.voice, isFalse);
      expect(store.saved.vibration, isTrue);
    });
  });
}

/// An instructor's phone opens on the sign-in; the bar is behind it.
Future<void> signInAsInstructor(WidgetTester tester) async {
  // The scan line sweeps forever; held still, pumpAndSettle can settle.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.enterText(find.byType(TextField).at(0), 'demo@bcc.test');
  await tester.enterText(find.byType(TextField).at(1), 'secret');
  await tester.tap(find.widgetWithText(FilledButton, ScannerStrings.signIn));
  await tester.pumpAndSettle();
}

/// Opens one of the instructor's tabs the only way there is: the Menu
/// button at the foot of the screen, then the tab's tile.
Future<void> openFromMenu(WidgetTester tester, String tab) async {
  await tester.tap(find.byKey(const ValueKey('nav.menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('menu.$tab')));
  await tester.pumpAndSettle();
}
