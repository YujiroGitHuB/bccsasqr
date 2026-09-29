import 'package:bccsasqr_app/app.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/core/utils/student_number.dart';
import 'package:bccsasqr_app/models/qr_payload.dart';
import 'package:bccsasqr_app/models/record_warning.dart';
import 'package:bccsasqr_app/models/student_record.dart';
import 'package:bccsasqr_app/models/terms_document.dart';
import 'package:bccsasqr_app/services/qr_export_service.dart';
import 'package:bccsasqr_app/services/saved_qr_store.dart';
import 'package:bccsasqr_app/services/student_repository.dart';
import 'package:bccsasqr_app/views/generator_splash.dart';
import 'package:bccsasqr_app/views/splash_page.dart';
import 'package:bccsasqr_app/views/widgets/qr_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:bccsasqr_app/models/app_role.dart';
import 'package:bccsasqr_app/services/role_store.dart';

class _StubRepository implements StudentRepository {
  @override
  Future<StudentRecord?> findByStudentNumber(StudentNumber number) async {
    if (number.value == '025-1102') {
      return StudentRecord(
        studentNumber: number,
        fullName: 'No Photo Yet',
        course: 'BSIT',
        section: '1A',
        warnings: const [
          RecordWarning(
            code: 'photo_missing',
            message: 'You need to upload your photo first.',
            actionLabel: 'Upload your photo',
            actionUrl: 'https://example.test/student/StudentPhotoProfile.php',
          ),
        ],
      );
    }
    if (number.value != '019-464') return null;
    return StudentRecord(
      studentNumber: number,
      fullName: 'Charles Nixon Cayading',
      course: 'BS Information Technology',
      section: 'BSIT 4-A',
    );
  }

  @override
  Future<QrPayload> issueQrPayload(StudentNumber number) async {
    final record = await findByStudentNumber(number);
    return QrPayload.forRecord(record!);
  }

  @override
  Future<TermsDocument> fetchTerms() async =>
      const TermsDocument(version: 1, text: 'Terms text for the dialog.');

  @override
  Future<void> acceptTerms(StudentNumber number) async {}
}

/// No signal for the first lookup, back for the next.
class _DroppedSignalRepository extends _StubRepository {
  int _lookups = 0;

  @override
  Future<StudentRecord?> findByStudentNumber(StudentNumber number) async {
    if (_lookups++ == 0) {
      throw const StudentLookupException(
        'Could not reach the records service.',
        code: 'network',
      );
    }
    return super.findByStudentNumber(number);
  }
}

/// Records the export request instead of touching the file system.
class _StubExportService implements QrExportService {
  String? lastFileName;

  @override
  Future<String> export({
    required GlobalKey boundaryKey,
    required String fileName,
    String? shareText,
  }) async {
    lastFileName = fileName;
    return 'memory://$fileName';
  }
}

void main() {
  // The default 800x600 test surface clips the form; use a tall phone-sized
  // viewport so every control is laid out and hit-testable.
  setUp(() {
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

  Widget harness(_StubExportService exporter) => BccSasqrApp(
    roleStore: MemoryRoleStore(AppRole.student),
    repository: _StubRepository(),
    exportService: exporter,
    showSplash: false,
  );

  /// Pumps the app and opens the generator from the home screen — where a
  /// student lands once the splash has gone.
  Future<void> openGenerator(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home.generator')));
    await tester.pumpAndSettle();
  }

  /// Lets the splash play out — the wait for the logo, the animation, the
  /// hold — then the cross-fade. Fails the test if it has not handed over
  /// within six seconds: a splash that never ends is a locked app.
  Future<void> playSplash(WidgetTester tester) async {
    for (var i = 0; i < 60; i++) {
      if (find.byType(SplashPage).evaluate().isEmpty) break;
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the splash, then hands over to the home screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      BccSasqrApp(
        roleStore: MemoryRoleStore(AppRole.student),
        repository: _StubRepository(),
        exportService: _StubExportService(),
      ),
    );

    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.text(AppStrings.splashTagline), findsOneWidget);
    expect(find.text(AppStrings.studentNumberLabel), findsNothing);

    await playSplash(tester);

    expect(find.byType(SplashPage), findsNothing);
    expect(find.text(AppStrings.homeStudentTitle), findsOneWidget);
    expect(find.text(AppStrings.homeTrackerTitle), findsOneWidget);

    // Students are one tap from the generator.
    await tester.tap(find.byKey(const ValueKey('home.generator')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.studentNumberLabel), findsOneWidget);
  });

  testWidgets('the generator plays its own splash before the form', (
    tester,
  ) async {
    await tester.pumpWidget(
      BccSasqrApp(
        roleStore: MemoryRoleStore(AppRole.student),
        repository: _StubRepository(),
        exportService: _StubExportService(),
        showSplash: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home.generator')));
    // The new route's first frame is laid out offstage, for heroes.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.byType(GeneratorSplash), findsOneWidget);
    expect(find.text(AppStrings.generatorSplashTagline), findsOneWidget);
    expect(find.text(AppStrings.generatorStepSave), findsOneWidget);
    expect(find.text(AppStrings.studentNumberLabel), findsNothing);

    await tester.pumpAndSettle();
    expect(find.byType(GeneratorSplash), findsNothing);
    expect(find.text(AppStrings.studentNumberLabel), findsOneWidget);
  });

  testWidgets('with reduce motion on, the splash still ends', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(
      BccSasqrApp(
        roleStore: MemoryRoleStore(AppRole.student),
        repository: _StubRepository(),
        exportService: _StubExportService(),
      ),
    );
    await playSplash(tester);

    expect(find.byType(SplashPage), findsNothing);
    expect(find.text(AppStrings.homeStudentTitle), findsOneWidget);
  });

  testWidgets('opens on the empty state with the action locked', (
    tester,
  ) async {
    await openGenerator(tester, harness(_StubExportService()));

    expect(find.text(AppStrings.appTitle), findsOneWidget);
    expect(find.text(AppStrings.emptyQrTitle), findsOneWidget);
    expect(find.text(AppStrings.actionVerifyFirst), findsOneWidget);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull, reason: 'must stay disabled when idle');
  });

  testWidgets('verifies a known number and fills the record rows', (
    tester,
  ) async {
    await openGenerator(tester, harness(_StubExportService()));

    await tester.enterText(find.byType(TextField), '019464');
    await tester.pumpAndSettle();

    expect(find.text('Charles Nixon Cayading'), findsOneWidget);
    expect(find.text('BS Information Technology'), findsOneWidget);
    expect(find.text('BSIT 4-A'), findsOneWidget);
    expect(find.text(AppStrings.verifiedBadge), findsOneWidget);
  });

  testWidgets('a missing photo warns, with the upload page one tap away', (
    tester,
  ) async {
    await openGenerator(tester, harness(_StubExportService()));

    await tester.enterText(find.byType(TextField), '0251102');
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.verifiedBadge), findsOneWidget);
    expect(find.text('You need to upload your photo first.'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Upload your photo'),
      findsOneWidget,
    );
  });

  testWidgets('a student with a photo sees no warning', (tester) async {
    await openGenerator(tester, harness(_StubExportService()));

    await tester.enterText(find.byType(TextField), '019464');
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });

  testWidgets('a dropped connection offers Try again, and it works', (
    tester,
  ) async {
    await openGenerator(
      tester,
      BccSasqrApp(
        roleStore: MemoryRoleStore(AppRole.student),
        repository: _DroppedSignalRepository(),
        exportService: _StubExportService(),
        showSplash: false,
      ),
    );

    await tester.enterText(find.byType(TextField), '019464');
    await tester.pumpAndSettle();

    // With nothing saved on this phone, the reason and where offline still
    // works.
    expect(
      find.text(
        'Could not reach the records service. ${AppStrings.offlineNoCopy}',
      ),
      findsOneWidget,
    );
    final retry = find.widgetWithText(OutlinedButton, AppStrings.actionRetry);
    expect(retry, findsOneWidget);

    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.verifiedBadge), findsOneWidget);
    expect(retry, findsNothing);
  });

  testWidgets('offline, a code made on this phone before opens, said to be '
      'the saved copy', (tester) async {
    final number = StudentNumber.tryParse('000-1023')!;
    final record = StudentRecord(
      studentNumber: number,
      fullName: 'Maria Isabel Santos',
      course: 'BS Computer Science',
      section: 'BSCS 2-B',
    );
    final saved = MemorySavedQrStore()
      ..saved['000-1023'] = SavedQr(
        record: record,
        payload: QrPayload.forRecord(record),
        savedAt: DateTime(2026, 9, 29),
      );

    await openGenerator(
      tester,
      BccSasqrApp(
        roleStore: MemoryRoleStore(AppRole.student),
        repository: _DroppedSignalRepository(),
        exportService: _StubExportService(),
        savedQrStore: saved,
        showSplash: false,
      ),
    );

    await tester.enterText(find.byType(TextField), '0001023');
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.offlineCopy('Sep 29, 2026')), findsOneWidget);
    expect(find.text(AppStrings.verifiedBadge), findsNothing);
    expect(find.text('Maria Isabel Santos'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.actionGenerate),
    );
    await tester.pumpAndSettle();

    expect(find.byType(QrCard), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, AppStrings.actionDownload),
      findsOneWidget,
    );
  });

  testWidgets('pulling the page down looks the number up again', (
    tester,
  ) async {
    await openGenerator(
      tester,
      BccSasqrApp(
        roleStore: MemoryRoleStore(AppRole.student),
        repository: _DroppedSignalRepository(),
        exportService: _StubExportService(),
        showSplash: false,
      ),
    );

    await tester.enterText(find.byType(TextField), '019464');
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.verifiedBadge), findsNothing);

    await tester.fling(
      find.text(AppStrings.appTitle),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.verifiedBadge), findsOneWidget);
  });

  testWidgets('an unknown number reports not found', (tester) async {
    await openGenerator(tester, harness(_StubExportService()));

    await tester.enterText(find.byType(TextField), '0219999');
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.errorNotFound), findsOneWidget);
    expect(find.text(AppStrings.emptyQrTitle), findsOneWidget);
  });

  testWidgets('full flow: verify, accept terms, generate, download', (
    tester,
  ) async {
    final exporter = _StubExportService();
    await openGenerator(tester, harness(exporter));

    await tester.enterText(find.byType(TextField), '019464');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.actionGenerate), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text(AppStrings.emptyQrTitle), findsNothing);
    expect(find.text(AppStrings.actionDownload), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // The name the web page downloads under.
    expect(exporter.lastFileName, '019-464_qr.png');
  });

  testWidgets('a connected build shows no demo notice', (tester) async {
    await openGenerator(tester, harness(_StubExportService()));

    expect(find.text(AppStrings.demoModeTitle), findsNothing);
  });

  testWidgets('the demo fallback says so instead of lying', (tester) async {
    // The failure this guards against: with no API_BASE_URL the app answers a
    // real student number with "No verified record matches" — the same words
    // an unknown number gets — so the API looks broken when it was never
    // called. The notice must name the four numbers that do work.
    await openGenerator(
      tester,
      BccSasqrApp(
        roleStore: MemoryRoleStore(AppRole.student),
        repository: InMemoryStudentRepository(latency: Duration.zero),
        exportService: _StubExportService(),
        showSplash: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.demoModeTitle), findsOneWidget);

    // The seeded numbers also appear in the field hint and the format line,
    // so anchor on the notice's own label rather than on a number.
    final listed = find.textContaining(AppStrings.demoModeNumbers);
    expect(listed, findsOneWidget);
    expect(
      tester.widget<Text>(listed).data,
      contains(InMemoryStudentRepository.sampleNumbers.first),
    );
  });

  testWidgets('lays out on a small phone without overflowing', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(320, 1800); // narrowest phone we support

    await openGenerator(tester, harness(_StubExportService()));
    await tester.enterText(find.byType(TextField), '019464');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // A RenderFlex overflow reports through the test framework, so reaching
    // here with a rendered QR means the narrow layout holds together.
    expect(tester.takeException(), isNull);
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('start over clears the form back to the empty state', (
    tester,
  ) async {
    await openGenerator(tester, harness(_StubExportService()));

    await tester.enterText(find.byType(TextField), '019464');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.actionReset));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.emptyQrTitle), findsOneWidget);
    expect(find.text(AppStrings.actionVerifyFirst), findsOneWidget);
    expect(find.text('Charles Nixon Cayading'), findsNothing);
  });
}
