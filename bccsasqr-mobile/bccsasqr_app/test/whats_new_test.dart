import 'package:bccsasqr_app/app.dart';
import 'package:bccsasqr_app/controllers/whats_new_controller.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/core/constants/whats_new_log.dart';
import 'package:bccsasqr_app/models/whats_new.dart';
import 'package:bccsasqr_app/services/app_info.dart';
import 'package:bccsasqr_app/services/qr_export_service.dart';
import 'package:bccsasqr_app/services/scan_feedback.dart';
import 'package:bccsasqr_app/services/scanner_repository.dart';
import 'package:bccsasqr_app/services/settings_store.dart';
import 'package:bccsasqr_app/services/speech_service.dart';
import 'package:bccsasqr_app/services/student_repository.dart';
import 'package:bccsasqr_app/services/tracker_repository.dart';
import 'package:bccsasqr_app/services/whats_new_store.dart';
import 'package:bccsasqr_app/views/tracker_splash.dart';
import 'package:bccsasqr_app/views/whats_new_page.dart';
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
  group('the log', () {
    test('is newest first, and the version is the newest release', () {
      final ids = [for (final r in WhatsNewLog.releases) r.id];
      expect(ids, [...ids]..sort((a, b) => b.compareTo(a)));
      expect(ids.toSet(), hasLength(ids.length));
      // `2026-09-27` or `2026-09-27.2` — the date part must be the newest.
      expect(WhatsNewLog.version.split('.').first, ids.first);
    });

    test('every release has items and every date parses', () {
      for (final release in WhatsNewLog.releases) {
        expect(release.items, isNotEmpty, reason: release.id);
        expect(release.date.year, greaterThanOrEqualTo(2026));
      }
    });

    test('bold markers come in pairs', () {
      for (final release in WhatsNewLog.releases) {
        for (final item in release.items) {
          expect(
            '**'.allMatches(item.text).length.isEven,
            isTrue,
            reason: item.title,
          );
        }
      }
    });
  });

  group('WhatsNewController', () {
    test('a phone that never opened it has news', () async {
      final c = WhatsNewController(store: MemoryWhatsNewStore());
      await c.load();
      expect(c.unread, isTrue);
    });

    test('an older release seen is still news', () async {
      final c = WhatsNewController(
        store: MemoryWhatsNewStore('2026-09-25'),
        version: '2026-09-27',
      );
      await c.load();
      expect(c.unread, isTrue);
    });

    test('opening it is remembered', () async {
      final store = MemoryWhatsNewStore();
      final c = WhatsNewController(store: store, version: '2026-09-27.2');
      await c.load();

      c.markSeen();
      await Future<void>.delayed(Duration.zero);

      expect(c.unread, isFalse);
      expect(store.seen, '2026-09-27.2');

      final again = WhatsNewController(store: store, version: '2026-09-27.2');
      await again.load();
      expect(again.unread, isFalse);
    });
  });

  group('screens', () {
    late MemoryWhatsNewStore store;

    setUp(() {
      store = MemoryWhatsNewStore();
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.devicePixelRatio = 1.0;
      view.physicalSize = const Size(420, 2400);
    });

    tearDown(() {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    Widget app() => BccSasqrApp(
      repository: InMemoryStudentRepository(latency: Duration.zero),
      trackerRepository: InMemoryTrackerRepository(latency: Duration.zero),
      exportService: _NoExport(),
      speech: const SilentSpeechService(),
      scannerRepository: InMemoryScannerRepository(latency: Duration.zero),
      scanFeedback: const SilentScanFeedback(),
      settingsStore: MemorySettingsStore(),
      whatsNewStore: store,
      appInfo: () async => const AppInfo(version: '1.5.0', buildNumber: '9'),
      cameraBuilder: (context, onCode) => const SizedBox.shrink(),
      keepAwake: (on) async {},
      showSplash: false,
    );

    final card = find.byKey(const ValueKey('home.whatsNewCard'));
    final latestTitle = find.text(WhatsNewLog.releases.first.title);

    testWidgets('a new release shows the card; opening it clears it', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      expect(find.text(WhatsNewStrings.cardTitle), findsOneWidget);

      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(WhatsNewPage), findsOneWidget);
      expect(latestTitle, findsOneWidget);
      expect(store.seen, WhatsNewLog.version);

      await tester.tap(find.byTooltip(AppStrings.homeBack));
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      expect(find.text(AppStrings.homeStudentTitle), findsOneWidget);
    });

    testWidgets('closing the card counts as seen, without opening it', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('home.whatsNewClose')));
      await tester.pumpAndSettle();

      expect(card, findsNothing);
      expect(find.byType(WhatsNewPage), findsNothing);
      expect(store.seen, WhatsNewLog.version);
    });

    testWidgets('a phone that has seen it gets no card, only the button', (
      tester,
    ) async {
      store = MemoryWhatsNewStore(WhatsNewLog.version);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(card, findsNothing);

      await tester.tap(find.byKey(const ValueKey('home.whatsNew')));
      await tester.pumpAndSettle();
      expect(latestTitle, findsOneWidget);
    });

    testWidgets('the filter shows one part of the app at a time', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home.whatsNew')));
      await tester.pumpAndSettle();

      final tracker = find.text('Check your own attendance');
      final scanner = find.text('Lock the scanner with your fingerprint');
      final qr = find.text('Make and save your QR on your phone');
      expect(tracker, findsOneWidget);
      expect(scanner, findsOneWidget);
      await tester.scrollUntilVisible(qr, 300);
      expect(qr, findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('whatsNew.filter.tracker')),
        -300,
      );
      await tester.tap(find.byKey(const ValueKey('whatsNew.filter.tracker')));
      await tester.pumpAndSettle();
      expect(tracker, findsOneWidget);
      expect(scanner, findsNothing);
      expect(qr, findsNothing);
      // The Sep 25 release had nothing for the tracker, so it is not shown.
      expect(find.text(WhatsNewLog.releases.last.title), findsNothing);

      await tester.tap(find.byKey(const ValueKey('whatsNew.filter.qr')));
      await tester.pumpAndSettle();
      expect(tracker, findsNothing);
      expect(qr, findsOneWidget);
    });

    testWidgets('an item opens the part of the app it is about', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home.whatsNew')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('whatsNew.filter.tracker')));
      await tester.pumpAndSettle();

      await tester.tap(find.text(WhatsNewStrings.openTracker));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(TrackerIntro), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('a fix with nowhere to go has no Open button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WhatsNewPage(
            releases: [
              WhatsNewRelease(
                id: '2026-09-27',
                icon: Icons.qr_code_scanner_rounded,
                title: 'Release',
                summary: 'Summary',
                items: [
                  WhatsNewItem(
                    kind: WhatsNewKind.fixed,
                    area: WhatsNewArea.scanner,
                    icon: Icons.replay_rounded,
                    title: 'A fix',
                    text: 'It says **Already marked** again.',
                    link: false,
                  ),
                ],
              ),
            ],
            onOpen: _ignore,
          ),
        ),
      );

      expect(find.text('A fix'), findsOneWidget);
      expect(find.text(WhatsNewStrings.kindFixed), findsOneWidget);
      expect(find.text(WhatsNewStrings.openScanner), findsNothing);
      // The markers are gone; the phrase between them is still there.
      expect(
        find.textContaining(
          'It says Already marked again.',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('Settings opens it too, without links', (tester) async {
      store = MemoryWhatsNewStore(WhatsNewLog.version);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home.settings')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('settings.whatsNew')));
      await tester.pumpAndSettle();

      expect(latestTitle, findsOneWidget);
      expect(find.text(WhatsNewStrings.openTracker), findsNothing);
      expect(find.text(WhatsNewStrings.openScanner), findsNothing);
    });

    testWidgets('lays out on a small phone without overflowing', (
      tester,
    ) async {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(320, 640);

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('home.whatsNew')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}

void _ignore(WhatsNewArea area) {}
