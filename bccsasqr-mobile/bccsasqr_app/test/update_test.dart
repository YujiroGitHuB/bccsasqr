import 'dart:convert';

import 'package:bccsasqr_app/app.dart';
import 'package:bccsasqr_app/controllers/update_controller.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/models/app_release.dart';
import 'package:bccsasqr_app/models/app_role.dart';
import 'package:bccsasqr_app/services/app_info.dart';
import 'package:bccsasqr_app/services/app_release_repository.dart';
import 'package:bccsasqr_app/services/device_lock.dart';
import 'package:bccsasqr_app/services/http_student_repository.dart';
import 'package:bccsasqr_app/services/qr_export_service.dart';
import 'package:bccsasqr_app/services/role_store.dart';
import 'package:bccsasqr_app/services/scan_feedback.dart';
import 'package:bccsasqr_app/services/scanner_repository.dart';
import 'package:bccsasqr_app/services/speech_service.dart';
import 'package:bccsasqr_app/services/student_repository.dart';
import 'package:bccsasqr_app/services/update_store.dart';
import 'package:bccsasqr_app/views/update_required_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The download page, scripted by the test: what is uploaded, the minimum,
/// and whether the server answers at all.
class _Server implements AppReleaseRepository {
  _Server({this.build = 21, this.minBuild = 0});

  int? build;
  int minBuild;
  bool offline = false;
  int asked = 0;

  @override
  Future<AppRelease> fetchRelease() async {
    asked++;
    if (offline) {
      throw const StudentLookupException('No internet.', code: 'network');
    }
    return AppRelease(
      version: build == null ? null : '1.${build! - 4}.0',
      build: build,
      size: 66896838,
      minBuild: minBuild,
      downloadUrl: 'https://example.test/bccsasqr/download/',
    );
  }
}

Future<AppInfo> _installed20() async =>
    const AppInfo(version: '1.16.0', buildNumber: '20');

class _NoExport implements QrExportService {
  @override
  Future<String> export({
    required GlobalKey boundaryKey,
    required String fileName,
    String? shareText,
  }) async => fileName;
}

void main() {
  group('the check', () {
    UpdateController controllerOf(
      _Server? server, {
      UpdateStore? store,
      Future<AppInfo> Function() appInfo = _installed20,
      DateTime Function()? clock,
    }) {
      final c = UpdateController(
        repository: server,
        appInfo: appInfo,
        store: store ?? MemoryUpdateStore(),
        clock: clock,
      );
      addTearDown(c.dispose);
      return c;
    }

    test('a newer build on the download page is offered; the same or an '
        'older one is not', () async {
      for (final (build, state) in [
        (21, UpdateState.available),
        (20, UpdateState.current),
        (19, UpdateState.current),
      ]) {
        final c = controllerOf(_Server(build: build));
        await c.check();
        expect(c.state, state, reason: 'build $build');
        expect(c.showCard, state == UpdateState.available);
      }
    });

    test('under the minimum, only the update', () async {
      final c = controllerOf(_Server(build: 21, minBuild: 21));
      await c.check();
      expect(c.state, UpdateState.required);
      expect(c.showCard, isFalse);
    });

    test('closing the card hides it for that build only — a newer one '
        'brings it back — and Settings still offers it', () async {
      final store = MemoryUpdateStore();
      final server = _Server(build: 21);
      final c = controllerOf(server, store: store);
      await c.check();
      await c.dismiss();
      expect(c.showCard, isFalse);
      expect(c.available, isTrue);
      expect(store.dismissed, 21);

      // The next launch remembers it.
      final again = controllerOf(server, store: store);
      await again.check();
      expect(again.showCard, isFalse);

      server.build = 22;
      await again.check(force: true);
      expect(again.showCard, isTrue);
    });

    test(
      'no answer changes nothing: no update made up, none taken back',
      () async {
        final server = _Server(build: 21)..offline = true;
        final c = controllerOf(server);
        await c.check();
        expect(c.state, UpdateState.unknown);

        server.offline = false;
        await c.check();
        expect(c.state, UpdateState.available);

        server.offline = true;
        await c.check(force: true);
        expect(c.state, UpdateState.available);
      },
    );

    test('asks at most once an hour, unless forced', () async {
      var now = DateTime(2026, 10, 2, 8);
      final server = _Server();
      final c = controllerOf(server, clock: () => now);

      await c.check();
      await c.check();
      expect(server.asked, 1);

      now = now.add(const Duration(minutes: 59));
      await c.check();
      expect(server.asked, 1);

      now = now.add(const Duration(minutes: 2));
      await c.check();
      expect(server.asked, 2);

      await c.check(force: true);
      expect(server.asked, 3);
    });

    test(
      'nothing is asked without a server, or for a build with no number',
      () async {
        final idle = controllerOf(null);
        await idle.check();
        expect(idle.state, UpdateState.unknown);

        final server = _Server();
        final unnumbered = controllerOf(
          server,
          appInfo: () async => const AppInfo(version: '—', buildNumber: ''),
        );
        await unnumbered.check();
        expect(server.asked, 0);
        expect(unnumbered.state, UpdateState.unknown);
      },
    );

    test('no APK on the server: nothing to offer', () async {
      final c = controllerOf(_Server(build: null));
      await c.check();
      expect(c.state, UpdateState.current);
      expect(c.showCard, isFalse);
    });
  });

  group('GET /app', () {
    test('asks for it, and reads the uploaded build and the minimum', () async {
      Uri? seen;
      final repo = HttpStudentRepository(
        baseUrl: 'https://example.test/bccsasqr/api/v1',
        client: MockClient((request) async {
          seen = request.url;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'latest': {
                  'version': '1.17.0',
                  'build': 21,
                  'size': 66896838,
                  'updated': '2026-10-02T09:00:00+08:00',
                },
                'min_build': 18,
                'download_url': 'https://example.test/bccsasqr/download/',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final release = await repo.fetchRelease();

      expect(seen.toString(), 'https://example.test/bccsasqr/api/v1/app');
      expect(release.version, '1.17.0');
      expect(release.build, 21);
      expect(release.megabytes, 64);
      expect(release.minBuild, 18);
      expect(release.downloadUrl, 'https://example.test/bccsasqr/download/');
    });

    test('no APK uploaded: no version, the minimum still read', () {
      final release = AppRelease.fromJson({
        'latest': null,
        'min_build': 0,
        'download_url': 'https://example.test/bccsasqr/download/',
      });
      expect(release.version, isNull);
      expect(release.build, isNull);
      expect(release.megabytes, isNull);
      expect(release.minBuild, 0);
    });
  });

  group('screens', () {
    setUp(() {
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

    Widget app(
      _Server server, {
      AppRole role = AppRole.student,
      UpdateStore? store,
    }) => BccSasqrApp(
      roleStore: MemoryRoleStore(role),
      repository: InMemoryStudentRepository(latency: Duration.zero),
      exportService: _NoExport(),
      speech: const SilentSpeechService(),
      scannerRepository: InMemoryScannerRepository(latency: Duration.zero),
      scanFeedback: const SilentScanFeedback(),
      deviceLock: const NoDeviceLock(),
      scannerLockStore: MemoryLockSwitchStore(),
      appInfo: _installed20,
      cameraBuilder: (context, onCode) => const SizedBox.shrink(),
      keepAwake: (on) async {},
      appReleaseRepository: server,
      updateStore: store ?? MemoryUpdateStore(),
      showSplash: false,
    );

    testWidgets('a student\'s Home offers the update until it is closed, and '
        'Settings keeps offering it', (tester) async {
      final store = MemoryUpdateStore();
      await tester.pumpWidget(app(_Server(build: 21), store: store));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('update.card')), findsOneWidget);
      expect(find.text(UpdateStrings.cardTitle), findsOneWidget);
      expect(find.text(UpdateStrings.cardBody('1.17.0', 64)), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('update.close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('update.card')), findsNothing);
      expect(store.dismissed, 21);

      await tester.tap(find.byKey(const ValueKey('nav.menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu.settings')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings.update')), findsOneWidget);
      expect(find.text(UpdateStrings.settingsTitle('1.17.0')), findsOneWidget);
      expect(find.text(UpdateStrings.settingsBody), findsOneWidget);
    });

    testWidgets('the newest build offers nothing', (tester) async {
      await tester.pumpWidget(app(_Server(build: 20)));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('studentHome')), findsOneWidget);
      expect(find.byKey(const ValueKey('update.card')), findsNothing);
    });

    testWidgets('an instructor\'s Home offers it too', (tester) async {
      await tester.pumpWidget(
        app(_Server(build: 21), role: AppRole.instructor),
      );
      await tester.pumpAndSettle();
      // The scan line sweeps forever; held still, pumpAndSettle can settle.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.enterText(find.byType(TextField).at(0), 'demo@bcc.test');
      await tester.enterText(find.byType(TextField).at(1), 'secret');
      await tester.tap(
        find.widgetWithText(FilledButton, ScannerStrings.signIn),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('instructorHome')), findsOneWidget);
      expect(find.byKey(const ValueKey('update.card')), findsOneWidget);
    });

    testWidgets('a build under the minimum shows only the update, and Check '
        'again lets it back in once the server allows it', (tester) async {
      final server = _Server(build: 21, minBuild: 21);
      await tester.pumpWidget(app(server));
      await tester.pumpAndSettle();

      expect(find.byType(UpdateRequiredPage), findsOneWidget);
      expect(find.text(UpdateStrings.requiredTitle), findsOneWidget);
      expect(find.text(UpdateStrings.requiredNewest('1.17.0')), findsOneWidget);
      expect(
        find.text(UpdateStrings.requiredInstalled('1.16.0 (build 20)')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('studentHome')), findsNothing);

      server.minBuild = 0;
      await tester.tap(find.byKey(const ValueKey('updateRequired.retry')));
      await tester.pumpAndSettle();

      expect(find.byType(UpdateRequiredPage), findsNothing);
      expect(find.byKey(const ValueKey('studentHome')), findsOneWidget);
      // Still newer, so offered on Home now.
      expect(find.byKey(const ValueKey('update.card')), findsOneWidget);
    });

    testWidgets('the required page lays out on a small phone', (tester) async {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(320, 568);

      await tester.pumpWidget(app(_Server(build: 21, minBuild: 21)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(UpdateRequiredPage), findsOneWidget);
    });
  });
}
