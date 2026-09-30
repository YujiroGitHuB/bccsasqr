import 'package:bccsasqr_app/controllers/scanner_controller.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/core/theme/app_colors.dart';
import 'package:bccsasqr_app/core/theme/app_theme.dart';
import 'package:bccsasqr_app/models/offline_scan.dart';
import 'package:bccsasqr_app/models/scanner_models.dart';
import 'package:bccsasqr_app/services/offline_scan_store.dart';
import 'package:bccsasqr_app/services/scanner_repository.dart';
import 'package:bccsasqr_app/views/scanner/widgets/attendance_panel.dart';
import 'package:bccsasqr_app/views/scanner/widgets/sync_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = ScannerUser(
  id: 4,
  name: 'Paolo R. Mendoza',
  email: 'paolo@example.test',
  role: 'instructor',
);
const _elec2 = ScanSubject(code: 'ELEC2', name: 'Multimedia Technologies');
const _it101 = ScanSubject(code: 'IT101', name: 'Intro to Computing');

AttendanceEntry _entry(int i, ScanSubject subject) => AttendanceEntry(
  studentNumber: '000-${100 + i}',
  name: 'STUDENT $i, TEST',
  course: 'BSIT',
  section: '2G',
  subject: subject.name,
  date: '2026-09-27',
  timeIn: '07:${(59 - i).toString().padLeft(2, '0')}:00 AM',
);

/// A server with today's list set by the test; sending kept scans fails.
class _Repository implements ScannerRepository {
  _Repository(this.today);

  final List<AttendanceEntry> today;

  @override
  Future<ScannerUser?> restoreSession() async => _user;

  @override
  Future<SubjectList> loadSubjects() async =>
      (user: _user, subjects: const [_elec2, _it101], date: '2026-09-27');

  @override
  Future<List<AttendanceEntry>> loadToday() async => today;

  @override
  Future<List<SyncOutcome>> syncScans(List<PendingScan> scans) async =>
      throw const ScannerException('offline', code: 'network');

  @override
  Future<SubjectRoster> loadRoster(String subjectCode) async =>
      throw const ScannerException('offline', code: 'network');

  @override
  Future<ScanRecord> recordScan({
    required String studentNumber,
    required String subjectCode,
  }) async => throw const ScannerException('offline', code: 'network');

  @override
  Future<ScannerUser> signIn({
    required String email,
    required String password,
  }) async => _user;

  @override
  Future<void> signOut() async {}

  @override
  Future<bool> setLateMarking({
    required String subjectCode,
    required bool on,
  }) async => on;
}

void main() {
  setUp(() {
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

  Future<ScannerController> pump(
    WidgetTester tester,
    List<AttendanceEntry> today, {
    OfflineScanStore? store,
  }) async {
    final controller = ScannerController(
      repository: _Repository(today),
      store: store,
      clock: () => DateTime(2026, 9, 27, 8),
    );
    await controller.start();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPalette.dark),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => Column(
                children: [
                  SyncBanner(controller: controller),
                  AttendancePanel(controller: controller),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('only the newest five sit under the camera; the rest are a '
      'tap away', (tester) async {
    final controller = await pump(tester, [
      for (var i = 0; i < 8; i++) _entry(i, _elec2),
      for (var i = 8; i < 12; i++) _entry(i, _it101),
    ]);

    expect(find.byType(AttendanceRow), findsNWidgets(5));
    expect(find.text('STUDENT 0, TEST'), findsOneWidget);
    expect(find.text('STUDENT 5, TEST'), findsNothing);

    await tester.tap(find.text(ScannerStrings.attendanceViewAll(12)));
    await tester.pumpAndSettle();

    expect(find.text(ScannerStrings.attendanceSheetTitle), findsOneWidget);
    expect(find.text('STUDENT 5, TEST'), findsOneWidget);

    // One subject at a time. The chips scroll sideways; the last is off to
    // the right on a narrow phone.
    final it101 = find.text('${_it101.name} · 4');
    await tester.dragUntilVisible(
      it101,
      find.byType(ChoiceChip).first,
      const Offset(-150, 0),
    );
    await tester.ensureVisible(it101);
    await tester.pumpAndSettle();
    await tester.tap(it101);
    await tester.pumpAndSettle();
    expect(controller.attendanceSubject, _it101.name);
    expect(find.text('STUDENT 5, TEST'), findsNothing);
    expect(find.text('STUDENT 9, TEST'), findsWidgets);

    // And the search within it.
    await tester.enterText(
      find.widgetWithText(TextField, ScannerStrings.attendanceSearch),
      '000-110',
    );
    await tester.pumpAndSettle();
    expect(controller.visibleAttendance.single.studentNumber, '000-110');

    controller.dispose();
  });

  testWidgets('a short list has no View all button', (tester) async {
    final controller = await pump(tester, [
      for (var i = 0; i < 3; i++) _entry(i, _elec2),
    ]);

    expect(find.byType(AttendanceRow), findsNWidgets(3));
    expect(find.byType(OutlinedButton), findsNothing);
    controller.dispose();
  });

  testWidgets('a scan kept on the phone is marked Pending, with the count '
      'waiting and Send now above the list', (tester) async {
    final store = MemoryOfflineScanStore();
    await store.put(
      PendingScan(
        id: 'k1',
        userId: _user.id,
        studentNumber: '000-1023',
        subjectCode: _elec2.code,
        subjectName: _elec2.name,
        scannedAt: DateTime(2026, 9, 27, 7, 45),
        name: 'SANTOS, MARIA ISABEL',
      ),
    );
    final controller = await pump(tester, [_entry(0, _elec2)], store: store);

    expect(find.text(ScannerStrings.pendingTag), findsOneWidget);
    expect(find.text(ScannerStrings.pendingTitle(1)), findsOneWidget);
    expect(find.text(ScannerStrings.sendNow), findsOneWidget);
    expect(find.text('07:45:00 AM'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('a kept scan the server refused says why, until cleared', (
    tester,
  ) async {
    final store = MemoryOfflineScanStore();
    await store.put(
      PendingScan(
        id: 'k1',
        userId: _user.id,
        studentNumber: '000-999',
        subjectCode: _elec2.code,
        subjectName: _elec2.name,
        scannedAt: DateTime(2026, 9, 27, 7, 45),
      ).rejectedWith(
        const ScanRejection(
          code: 'student_not_found',
          message: 'Student 000-999 not found in database',
        ),
      ),
    );
    final controller = await pump(tester, const [], store: store);

    expect(find.text(ScannerStrings.notSavedCountTitle(1)), findsOneWidget);
    await tester.tap(find.text(ScannerStrings.seeWhy));
    await tester.pumpAndSettle();

    expect(find.text('Student 000-999 not found in database'), findsOneWidget);
    await tester.tap(find.text(ScannerStrings.notSavedClear));
    await tester.pumpAndSettle();

    expect(find.text(ScannerStrings.notSavedCountTitle(1)), findsNothing);
    expect(store.kept, isEmpty);
    controller.dispose();
  });
}
