import 'package:bccsasqr_app/app.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/core/utils/student_number.dart';
import 'package:bccsasqr_app/models/student_record.dart';
import 'package:bccsasqr_app/models/terms_document.dart';
import 'package:bccsasqr_app/services/qr_export_service.dart';
import 'package:bccsasqr_app/services/student_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

class _StubRepository implements StudentRepository {
  @override
  Future<StudentRecord?> findByStudentNumber(StudentNumber number) async {
    if (number.value != '019-464') return null;
    return StudentRecord(
      studentNumber: number,
      fullName: 'Charles Nixon Cayading',
      course: 'BS Information Technology',
      section: 'BSIT 4-A',
    );
  }

  @override
  Future<String> issueQrPayload(StudentNumber number) async => number.value;

  @override
  Future<TermsDocument> fetchTerms() async =>
      const TermsDocument(version: 1, text: 'Terms text for the dialog.');

  @override
  Future<void> acceptTerms(StudentNumber number) async {}
}

/// Records the export request instead of touching the file system.
class _StubExportService implements QrExportService {
  String? lastFileStem;

  @override
  Future<String> export({
    required GlobalKey boundaryKey,
    required String fileStem,
    String? shareText,
  }) async {
    lastFileStem = fileStem;
    return 'memory://$fileStem.png';
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

  Widget harness(_StubExportService exporter) =>
      BccSasqrApp(repository: _StubRepository(), exportService: exporter);

  testWidgets('opens on the empty state with the action locked', (
    tester,
  ) async {
    await tester.pumpWidget(harness(_StubExportService()));

    expect(find.text(AppStrings.appTitle), findsOneWidget);
    expect(find.text(AppStrings.emptyQrTitle), findsOneWidget);
    expect(find.text(AppStrings.actionVerifyFirst), findsOneWidget);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull, reason: 'must stay disabled when idle');
  });

  testWidgets('verifies a known number and fills the record rows', (
    tester,
  ) async {
    await tester.pumpWidget(harness(_StubExportService()));

    await tester.enterText(find.byType(TextField), '019464');
    await tester.pumpAndSettle();

    expect(find.text('Charles Nixon Cayading'), findsOneWidget);
    expect(find.text('BS Information Technology'), findsOneWidget);
    expect(find.text('BSIT 4-A'), findsOneWidget);
    expect(find.text(AppStrings.verifiedBadge), findsOneWidget);
  });

  testWidgets('an unknown number reports not found', (tester) async {
    await tester.pumpWidget(harness(_StubExportService()));

    await tester.enterText(find.byType(TextField), '0219999');
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.errorNotFound), findsOneWidget);
    expect(find.text(AppStrings.emptyQrTitle), findsOneWidget);
  });

  testWidgets('full flow: verify, accept terms, generate, download', (
    tester,
  ) async {
    final exporter = _StubExportService();
    await tester.pumpWidget(harness(exporter));

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

    expect(exporter.lastFileStem, contains('019-464'));
  });

  testWidgets('a connected build shows no demo notice', (tester) async {
    await tester.pumpWidget(harness(_StubExportService()));

    expect(find.text(AppStrings.demoModeTitle), findsNothing);
  });

  testWidgets('the demo fallback says so instead of lying', (tester) async {
    // The failure this guards against: with no API_BASE_URL the app answers a
    // real student number with "No verified record matches" — the same words
    // an unknown number gets — so the API looks broken when it was never
    // called. The notice must name the four numbers that do work.
    await tester.pumpWidget(
      BccSasqrApp(
        repository: InMemoryStudentRepository(latency: Duration.zero),
        exportService: _StubExportService(),
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

    await tester.pumpWidget(harness(_StubExportService()));
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
    await tester.pumpWidget(harness(_StubExportService()));

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
