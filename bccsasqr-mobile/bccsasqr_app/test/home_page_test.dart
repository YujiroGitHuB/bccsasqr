import 'dart:typed_data';

import 'package:bccsasqr_app/controllers/my_attendance_controller.dart';
import 'package:bccsasqr_app/controllers/my_qr_controller.dart';
import 'package:bccsasqr_app/controllers/profile_controller.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/core/theme/app_colors.dart';
import 'package:bccsasqr_app/core/theme/app_theme.dart';
import 'package:bccsasqr_app/core/utils/student_number.dart';
import 'package:bccsasqr_app/models/attendance_history.dart';
import 'package:bccsasqr_app/models/qr_payload.dart';
import 'package:bccsasqr_app/models/student_profile.dart';
import 'package:bccsasqr_app/models/student_record.dart';
import 'package:bccsasqr_app/models/terms_document.dart';
import 'package:bccsasqr_app/services/photo_repository.dart';
import 'package:bccsasqr_app/services/profile_store.dart';
import 'package:bccsasqr_app/services/saved_qr_store.dart';
import 'package:bccsasqr_app/services/student_repository.dart';
import 'package:bccsasqr_app/services/tracker_repository.dart';
import 'package:bccsasqr_app/views/home_page.dart';
import 'package:bccsasqr_app/views/student_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Made-up students only: year 000 never occurs in the school's numbers.
final _number = StudentNumber.tryParse('000-1023')!;

final _record = StudentRecord(
  studentNumber: _number,
  fullName: 'DELA CRUZ, JUAN P.',
  course: 'BSIT',
  section: '2A',
);

final _today = DateTime(2026, 10, 1, 9);

/// The generator's half of the server: issues a code, or refuses until the
/// terms are accepted.
class _Students implements StudentRepository {
  bool termsAccepted = true;
  int issued = 0;

  @override
  Future<QrPayload> issueQrPayload(StudentNumber number) async {
    if (!termsAccepted) {
      throw const StudentLookupException(
        'Accept the terms first.',
        code: 'terms_not_accepted',
      );
    }
    issued++;
    return QrPayload.forRecord(_record);
  }

  @override
  Future<StudentRecord?> findByStudentNumber(StudentNumber number) async =>
      _record;

  @override
  Future<TermsDocument> fetchTerms() async =>
      const TermsDocument(version: 1, text: '');

  @override
  Future<void> acceptTerms(StudentNumber number) async {}
}

class _Tracker implements TrackerRepository {
  _Tracker(this.history);

  AttendanceHistory? history;
  int asked = 0;

  @override
  Future<AttendanceHistory?> fetchAttendance(StudentNumber number) async {
    asked++;
    return history;
  }
}

class _Photos implements StudentPhotoRepository {
  @override
  Future<PhotoOwner> verifyOwner(StudentNumber number, String lastName) async =>
      (record: _record, photoUrl: null, required: false);

  @override
  Future<PhotoOwner> fetchOwner(StudentNumber number) async =>
      (record: _record, photoUrl: null, required: false);

  @override
  Future<PhotoOwner> uploadPhoto(
    StudentNumber number,
    String lastName,
    Uint8List jpeg,
  ) async => (record: _record, photoUrl: null, required: false);

  @override
  Future<Uint8List> downloadPhoto(String url) async =>
      throw UnimplementedError();
}

AttendanceDay _day(DateTime date, String time, {bool late = false}) =>
    AttendanceDay(date: date, rawDate: '$date', timeIn: time, late: late);

AttendanceHistory _history({bool today = true}) => AttendanceHistory(
  studentNumber: _number.value,
  fullName: _record.fullName,
  course: 'BSIT',
  section: '2A',
  total: 3,
  lastAttended: today ? _today : DateTime(2026, 9, 30),
  subjects: [
    SubjectAttendance(
      subject: 'Object Oriented Programming',
      instructor: 'Sample Instructor',
      count: 2,
      days: [
        if (today) _day(DateTime(2026, 10, 1), '08:04:12 AM'),
        _day(DateTime(2026, 9, 28), '08:11:40 AM', late: true),
        if (!today) _day(DateTime(2026, 9, 24), '07:58:02 AM'),
      ],
    ),
    SubjectAttendance(
      subject: 'Data Structures and Algorithms',
      instructor: 'Sample Instructor',
      count: 1,
      days: [_day(DateTime(2026, 9, 30), '01:02:00 PM')],
    ),
  ],
);

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.devicePixelRatio = 1.0;
    view.physicalSize = const Size(420, 1400);
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  /// Home over its three controllers. [opened] collects the tabs it asks
  /// for; [shown] counts Show to scanner.
  Future<void> pumpHome(
    WidgetTester tester, {
    StudentProfile? profile,
    _Students? students,
    _Tracker? tracker,
    int hour = 9,
    List<StudentTab>? opened,
    List<void>? shown,
  }) async {
    final profiles = ProfileController(
      store: MemoryProfileStore(profile),
      repository: _Photos(),
    );
    final qr = MyQrController(
      profile: profiles,
      saved: WatchedSavedQrStore(MemorySavedQrStore()),
      repository: students ?? _Students(),
    );
    final attendance = MyAttendanceController(
      profile: profiles,
      repository: tracker ?? _Tracker(_history()),
      clock: () => _today,
    );
    addTearDown(() {
      qr.dispose();
      attendance.dispose();
      profiles.dispose();
    });
    await profiles.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPalette.light),
        home: HomePage(
          profile: profiles,
          qr: qr,
          attendance: attendance,
          onOpen: (tab) => opened?.add(tab),
          onShowQr: () => shown?.add(null),
          now: () => DateTime(2026, 10, 1, hour),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final kept = StudentProfile(record: _record, lastName: 'Dela Cruz');

  for (final (hour, greeting) in [
    (8, AppStrings.homeMorning),
    (14, AppStrings.homeAfternoon),
    (20, AppStrings.homeEvening),
  ]) {
    testWidgets('greets by the hour: $greeting at $hour:00', (tester) async {
      await pumpHome(tester, hour: hour);

      expect(find.text(greeting), findsOneWidget);
      expect(find.text(AppStrings.homeQuestion), findsOneWidget);
    });
  }

  testWidgets('before the phone is set up, the QR card asks for it', (
    tester,
  ) async {
    final opened = <StudentTab>[];
    await pumpHome(tester, opened: opened);

    expect(find.text(AppStrings.homeStudentTitle), findsOneWidget);
    expect(find.text(StudentStrings.setUpBody), findsOneWidget);
    // Nothing personal to show yet.
    expect(find.byKey(const ValueKey('home.today')), findsNothing);
    expect(find.text(AppStrings.homeTrackerTitle), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home.setUp')));
    await tester.tap(find.byKey(const ValueKey('home.generator')));
    await tester.tap(find.byKey(const ValueKey('home.tracker')));
    await tester.tap(find.byKey(const ValueKey('home.checkIn')));
    await tester.tap(find.byKey(const ValueKey('home.settings')));
    expect(opened, [
      StudentTab.profile,
      StudentTab.qr,
      StudentTab.tracker,
      StudentTab.checkIn,
      StudentTab.settings,
    ]);
  });

  testWidgets('set up, it greets by name and holds the code itself', (
    tester,
  ) async {
    final shown = <void>[];
    await pumpHome(tester, profile: kept, hour: 20, shown: shown);

    expect(find.text('${AppStrings.homeEvening},'), findsOneWidget);
    expect(find.text('Juan'), findsOneWidget);
    expect(find.text(StudentStrings.qrLabel), findsOneWidget);
    expect(find.text(_record.fullName), findsOneWidget);
    expect(find.text('000-1023'), findsOneWidget);
    expect(find.text(StudentStrings.savedOffline), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home.showQr')));
    expect(shown, hasLength(1));
  });

  testWidgets('says whether today\'s scan reached the records', (tester) async {
    await pumpHome(tester, profile: kept);

    expect(find.text(StudentStrings.presentToday), findsOneWidget);
    expect(find.text('Object Oriented Programming · 8:04 AM'), findsOneWidget);
  });

  testWidgets('and says so when it has not yet', (tester) async {
    await pumpHome(
      tester,
      profile: kept,
      tracker: _Tracker(_history(today: false)),
    );

    expect(find.text(StudentStrings.noScanToday), findsOneWidget);
    expect(find.text(StudentStrings.presentToday), findsNothing);
  });

  testWidgets('without the terms accepted, it sends the student to accept '
      'them', (tester) async {
    final opened = <StudentTab>[];
    await pumpHome(
      tester,
      profile: kept,
      students: _Students()..termsAccepted = false,
      opened: opened,
    );

    expect(find.text(StudentStrings.makeQrTitle), findsOneWidget);
    expect(find.byKey(const ValueKey('home.showQr')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('home.generator')));
    expect(opened, [StudentTab.qr]);
  });

  testWidgets('My Attendance at a glance: days, subjects, late', (
    tester,
  ) async {
    final opened = <StudentTab>[];
    await pumpHome(tester, profile: kept, opened: opened);

    expect(find.text(StudentStrings.daysPresent), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Data Structures and Algorithms'), findsOneWidget);
    expect(find.text(StudentStrings.last('today, 8:04 AM')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home.seeAll')));
    expect(opened, [StudentTab.tracker]);
  });

  group('the card the code is on', () {
    /// The face toward the student: the front has their name, the back
    /// the code's heading.
    bool showsBack() =>
        find.text(StudentStrings.cardScan).evaluate().isNotEmpty;

    testWidgets('swings into place once, then stands still on the front', (
      tester,
    ) async {
      await pumpHome(tester, profile: kept);

      expect(find.byKey(const ValueKey('studentCard')), findsOneWidget);
      expect(find.text(_record.fullName), findsOneWidget);
      expect(showsBack(), isFalse);
      // Settled: nothing left to animate.
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a tap flips it to the code, and back', (tester) async {
      await pumpHome(tester, profile: kept);

      await tester.tap(find.byKey(const ValueKey('studentCard')));
      await tester.pumpAndSettle();
      expect(showsBack(), isTrue);
      expect(find.text(_record.fullName), findsNothing);

      await tester.tap(find.byKey(const ValueKey('studentCard')));
      await tester.pumpAndSettle();
      expect(showsBack(), isFalse);
    });

    testWidgets('the Card / QR code switch turns it, and follows a tap', (
      tester,
    ) async {
      await pumpHome(tester, profile: kept);

      await tester.tap(find.byKey(const ValueKey('home.cardSide.back')));
      await tester.pumpAndSettle();
      expect(showsBack(), isTrue);

      await tester.tap(find.byKey(const ValueKey('studentCard')));
      await tester.pumpAndSettle();
      expect(showsBack(), isFalse);
      final selected = tester
          .widget<SegmentedButton<Object>>(
            find.byWidgetPredicate((w) => w is SegmentedButton),
          )
          .selected;
      expect(selected.single.toString(), endsWith('front'));
    });

    testWidgets('a drag sideways turns it; let go past half and it lands on '
        'the other face', (tester) async {
      await pumpHome(tester, profile: kept);
      final card = find.byKey(const ValueKey('studentCard'));

      // A short drag springs back.
      await tester.timedDrag(
        card,
        const Offset(-60, 0),
        const Duration(milliseconds: 600),
      );
      await tester.pumpAndSettle();
      expect(showsBack(), isFalse);

      // Past a quarter turn — 90 degrees is 150 px of drag.
      await tester.timedDrag(
        card,
        const Offset(-200, 0),
        const Duration(milliseconds: 900),
      );
      await tester.pumpAndSettle();
      expect(showsBack(), isTrue);
    });

    testWidgets('an up-and-down drag on it scrolls Home instead', (
      tester,
    ) async {
      await pumpHome(tester, profile: kept);
      final before = tester.getTopLeft(
        find.byKey(const ValueKey('studentCard')),
      );

      await tester.drag(
        find.byKey(const ValueKey('studentCard')),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      final after = tester.getTopLeft(
        find.byKey(const ValueKey('studentCard')),
      );
      expect(after.dy, lessThan(before.dy));
      expect(showsBack(), isFalse);
    });
  });

  testWidgets('lays out on a small phone without overflowing', (tester) async {
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .views
        .first
        .physicalSize = const Size(
      320,
      640,
    );
    for (final profile in [null, kept]) {
      await pumpHome(tester, profile: profile);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
