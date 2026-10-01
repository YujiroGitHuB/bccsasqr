import 'dart:math' as math;
import 'dart:typed_data';

import 'package:bccsasqr_app/app.dart';
import 'package:bccsasqr_app/controllers/my_attendance_controller.dart';
import 'package:bccsasqr_app/controllers/notifications_controller.dart';
import 'package:bccsasqr_app/controllers/profile_controller.dart';
import 'package:bccsasqr_app/controllers/settings_controller.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/core/theme/app_colors.dart';
import 'package:bccsasqr_app/core/theme/app_theme.dart';
import 'package:bccsasqr_app/core/utils/student_number.dart';
import 'package:bccsasqr_app/models/app_role.dart';
import 'package:bccsasqr_app/models/app_settings.dart';
import 'package:bccsasqr_app/models/attendance_history.dart';
import 'package:bccsasqr_app/models/live_update.dart';
import 'package:bccsasqr_app/models/student_notice.dart';
import 'package:bccsasqr_app/models/student_profile.dart';
import 'package:bccsasqr_app/models/student_record.dart';
import 'package:bccsasqr_app/services/live_repository.dart';
import 'package:bccsasqr_app/services/notice_store.dart';
import 'package:bccsasqr_app/services/photo_repository.dart';
import 'package:bccsasqr_app/services/profile_store.dart';
import 'package:bccsasqr_app/services/role_store.dart';
import 'package:bccsasqr_app/services/settings_store.dart';
import 'package:bccsasqr_app/services/speech_service.dart';
import 'package:bccsasqr_app/services/student_repository.dart';
import 'package:bccsasqr_app/services/tracker_repository.dart';
import 'package:bccsasqr_app/views/live_notices.dart';
import 'package:bccsasqr_app/views/my_attendance_page.dart';
import 'package:bccsasqr_app/views/notifications_page.dart';
import 'package:bccsasqr_app/views/widgets/island.dart';
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

final _kept = StudentProfile(record: _record, lastName: 'Dela Cruz');

final _now = DateTime(2026, 10, 1, 9);

const _oop = 'Object Oriented Programming';
const _dsa = 'Data Structures and Algorithms';

AttendanceDay _day(DateTime date, String time, {bool late = false}) =>
    AttendanceDay(
      date: date,
      rawDate: '${date.year}-${date.month}-${date.day}',
      timeIn: time,
      late: late,
    );

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

/// The school's records as the test writes them: the live feed and the
/// whole history read the same list, as the server's two endpoints read
/// the same table.
class _Records implements LiveRepository, TrackerRepository {
  final List<LiveRecord> rows = [];
  StudentLookupException? failure;
  int liveAsked = 0;
  int historyAsked = 0;
  final List<String> lastNames = [];

  LiveRecord add(
    int id,
    String time, {
    String subject = _oop,
    bool late = false,
    bool offline = false,
    DateTime? on,
  }) {
    final record = LiveRecord(
      id: id,
      subject: subject,
      instructor: 'Sample Instructor',
      day: _day(on ?? DateTime(2026, 10, 1), time, late: late),
      offline: offline,
    );
    rows.add(record);
    return record;
  }

  void delete(int id) => rows.removeWhere((r) => r.id == id);

  @override
  Future<LiveUpdate> fetchLive(
    StudentNumber number, {
    required String lastName,
    int? since,
  }) async {
    liveAsked++;
    lastNames.add(lastName);
    if (failure case final f?) throw f;
    final newer = since == null
        ? const <LiveRecord>[]
        : [
            for (final r in rows.reversed)
              if (r.id > since) r,
          ];
    return LiveUpdate(
      cursor: rows.fold(0, (top, r) => math.max(top, r.id)),
      count: rows.length,
      records: newer.take(25).toList(),
      more: newer.length > 25,
    );
  }

  @override
  Future<AttendanceHistory?> fetchAttendance(StudentNumber number) async {
    historyAsked++;
    final bySubject = <String, List<AttendanceDay>>{};
    for (final r in rows) {
      (bySubject[r.subject] ??= []).insert(0, r.day);
    }
    final names = bySubject.keys.toList()..sort();
    return AttendanceHistory(
      studentNumber: _number.value,
      fullName: _record.fullName,
      course: 'BSIT',
      section: '2A',
      total: rows.length,
      subjects: [
        for (final name in names)
          SubjectAttendance(
            subject: name,
            instructor: 'Sample Instructor',
            count: bySubject[name]!.length,
            days: bySubject[name]!,
          ),
      ],
    );
  }
}

/// Lets what the controllers read on start, and what the feed sends out,
/// arrive — microtasks only, so it works the same under testWidgets' clock,
/// where a zero-length timer would wait for a pump.
Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.value();
  }
}

void main() {
  Future<ProfileController> profileOf(StudentProfile? kept) async {
    final profile = ProfileController(
      store: MemoryProfileStore(kept),
      repository: _Photos(),
    );
    addTearDown(profile.dispose);
    await profile.load();
    return profile;
  }

  /// The feed over [records], with Home's attendance under it, once both
  /// have read what they keep.
  Future<(NotificationsController, MyAttendanceController)> feedOf(
    ProfileController profile,
    _Records records, {
    NoticeStore? store,
    Duration every = const Duration(seconds: 15),
    int keep = 50,
  }) async {
    final attendance = MyAttendanceController(
      profile: profile,
      repository: records,
      clock: () => _now,
    );
    addTearDown(attendance.dispose);
    await attendance.refresh();
    final notices = NotificationsController(
      profile: profile,
      repository: records,
      store: store ?? MemoryNoticeStore(),
      attendance: attendance,
      clock: () => _now,
      every: every,
      keep: keep,
    );
    addTearDown(notices.dispose);
    await settle();
    return (notices, attendance);
  }

  group('the feed', () {
    test('the first look is quiet; a scan after it is told once, and is on '
        "Home's history without asking for all of it", () async {
      final records = _Records()
        ..add(1, '01:02:00 PM', subject: _dsa, on: DateTime(2026, 9, 30));
      final (notices, attendance) = await feedOf(
        await profileOf(_kept),
        records,
      );
      final told = <List<StudentNotice>>[];
      notices.arrivals.listen(told.add);

      await notices.checkNow();
      await settle();
      expect(notices.notices, isEmpty);
      expect(told, isEmpty);
      expect(records.lastNames.single, 'Dela Cruz');

      // The instructor scans.
      records.add(2, '08:04:12 AM');
      await notices.checkNow();
      await settle();

      final notice = notices.notices.single;
      expect(notice.kind, NoticeKind.present);
      expect(notice.subject, _oop);
      expect(notice.read, isFalse);
      expect(notices.unread, 1);
      expect(told.single.single.id, notice.id);
      // On Home at once, from the feed — not from the whole history again.
      expect(attendance.today.single.day.timeIn, '08:04:12 AM');
      expect(attendance.history!.total, 2);
      expect(records.historyAsked, 1);

      // Never told twice.
      await notices.checkNow();
      await settle();
      expect(notices.notices, hasLength(1));
      expect(told, hasLength(1));
    });

    test('a late record says so', () async {
      final records = _Records();
      final (notices, _) = await feedOf(await profileOf(_kept), records);
      await notices.checkNow();

      records.add(1, '08:16:40 AM', late: true);
      await notices.checkNow();

      expect(notices.notices.single.kind, NoticeKind.late);
      expect(notices.notices.single.line(_now), '$_oop · 8:16 AM · late');
    });

    test('a check-in Check in already told of is filed, read, with no second '
        'island', () async {
      final records = _Records();
      final (notices, _) = await feedOf(await profileOf(_kept), records);
      final told = <List<StudentNotice>>[];
      notices.arrivals.listen(told.add);
      await notices.checkNow();

      records.add(1, '08:04:12 AM');
      notices.acknowledge(_oop, '08:04:12 AM');
      await notices.checkNow();
      await settle();

      expect(notices.notices.single.read, isTrue);
      expect(notices.unread, 0);
      expect(told, isEmpty);
    });

    test(
      'a record an instructor deleted is told, found in the history',
      () async {
        final records = _Records()
          ..add(1, '01:02:00 PM', subject: _dsa, on: DateTime(2026, 9, 30))
          ..add(2, '08:04:12 AM');
        final (notices, attendance) = await feedOf(
          await profileOf(_kept),
          records,
        );
        await notices.checkNow();

        records.delete(1);
        await notices.checkNow();
        await settle();

        final notice = notices.notices.single;
        expect(notice.kind, NoticeKind.removed);
        expect(notice.subject, _dsa);
        expect(notice.line(_now), '$_dsa · Wed, Sep 30, 1:02 PM');
        expect(attendance.history!.total, 1);
      },
    );

    test('a scan sent later from the instructor\'s phone says so', () async {
      final records = _Records();
      final (notices, _) = await feedOf(await profileOf(_kept), records);
      await notices.checkNow();

      records.add(1, '08:04:12 AM', offline: true, on: DateTime(2026, 9, 30));
      await notices.checkNow();

      final notice = notices.notices.single;
      expect(notice.offline, isTrue);
      expect(notice.line(_now), '$_oop · Wed, Sep 30, 8:04 AM · on time');
    });

    test(
      'opened again later, what came meanwhile is news, newest first',
      () async {
        final store = MemoryNoticeStore();
        final records = _Records()
          ..add(1, '08:00:00 AM', on: DateTime(2026, 9, 30));
        final profile = await profileOf(_kept);

        final (before, _) = await feedOf(profile, records, store: store);
        await before.checkNow();

        // While the app was closed.
        records
          ..add(2, '08:04:12 AM')
          ..add(3, '10:20:00 AM', subject: _dsa, late: true);

        final (after, _) = await feedOf(profile, records, store: store);
        final told = <List<StudentNotice>>[];
        after.arrivals.listen(told.add);
        await after.checkNow();
        await settle();

        expect([for (final n in after.notices) n.subject], [_dsa, _oop]);
        expect(told.single, hasLength(2));
        expect(store.feed!.cursor, 3);
        expect(store.feed!.notices, hasLength(2));
      },
    );

    test("another student's feed is dropped; a forgotten one too", () async {
      final store = MemoryNoticeStore(
        NoticeFeed(
          studentNumber: '000-9999',
          cursor: 4,
          count: 4,
          notices: [
            StudentNotice(
              id: StudentNotice.recordId(4),
              kind: NoticeKind.present,
              subject: _oop,
              day: _day(DateTime(2026, 9, 30), '08:00:00 AM'),
              at: _now,
            ),
          ],
        ),
      );
      final records = _Records();
      final profile = await profileOf(_kept);
      final (notices, _) = await feedOf(profile, records, store: store);
      expect(notices.notices, isEmpty);
      expect(store.feed, isNull);

      await notices.checkNow();
      records.add(1, '08:04:12 AM');
      await notices.checkNow();
      expect(notices.notices, hasLength(1));

      await profile.forget();
      await settle();
      expect(notices.hasStudent, isFalse);
      expect(notices.notices, isEmpty);
      expect(store.feed, isNull);
    });

    test('a profile the record no longer matches stops it, until set up '
        'again', () async {
      final records = _Records();
      final profile = await profileOf(_kept);
      final (notices, _) = await feedOf(profile, records);
      records.failure = const StudentLookupException(
        'This phone’s profile no longer matches the school record.',
        code: 'identity_mismatch',
      );

      await notices.checkNow();
      expect(notices.stopped, isTrue);
      final asked = records.liveAsked;
      await notices.checkNow();
      expect(records.liveAsked, asked);

      // Set up again in My Profile, with the name as the record has it.
      records.failure = null;
      await profile.verify('000-1023', 'DELA CRUZ');
      await settle();
      expect(notices.stopped, isFalse);
      await notices.checkNow();
      expect(records.lastNames.last, 'DELA CRUZ');
    });

    test('keeps the newest, and opening the list reads them all', () async {
      final records = _Records();
      final (notices, _) = await feedOf(
        await profileOf(_kept),
        records,
        keep: 3,
      );
      await notices.checkNow();

      for (var id = 1; id <= 5; id++) {
        records.add(id, '08:0$id:00 AM', subject: 'Subject $id');
      }
      await notices.checkNow();

      expect(
        [for (final n in notices.notices) n.subject],
        ['Subject 5', 'Subject 4', 'Subject 3'],
      );
      expect(notices.unread, 3);
      notices.markAllRead();
      expect(notices.unread, 0);
    });

    testWidgets('asks on its own while open, not while away; coming back looks '
        'at once', (tester) async {
      final records = _Records();
      final (notices, _) = await feedOf(await profileOf(_kept), records);

      notices.setActive(true);
      await tester.pump();
      expect(records.liveAsked, 1);

      await tester.pump(const Duration(seconds: 15));
      expect(records.liveAsked, 2);
      await tester.pump(const Duration(seconds: 15));
      expect(records.liveAsked, 3);

      // In the background, or under the lock.
      notices.setActive(false);
      await tester.pump(const Duration(minutes: 2));
      expect(records.liveAsked, 3);

      notices.setActive(true);
      await tester.pump();
      expect(records.liveAsked, 4);
      notices.setActive(false);
    });

    testWidgets('no signal slows it down, longer each time; an answer puts '
        'it back on pace', (tester) async {
      final records = _Records();
      final (notices, _) = await feedOf(await profileOf(_kept), records);
      records.failure = const StudentLookupException('', code: 'network');

      notices.setActive(true);
      await tester.pump();
      expect(records.liveAsked, 1);

      // 30 s after the first failure, then 60 s.
      await tester.pump(const Duration(seconds: 29));
      expect(records.liveAsked, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(records.liveAsked, 2);
      await tester.pump(const Duration(seconds: 59));
      expect(records.liveAsked, 2);
      records.failure = null;
      await tester.pump(const Duration(seconds: 1));
      expect(records.liveAsked, 3);

      await tester.pump(const Duration(seconds: 15));
      expect(records.liveAsked, 4);
      notices.setActive(false);
    });
  });

  group('My Attendance, kept current', () {
    test('a new record joins its subject, newest first; a new subject is '
        'filed by name; the same one is not added twice', () async {
      final records = _Records()
        ..add(1, '08:11:40 AM', on: DateTime(2026, 9, 28))
        ..add(2, '01:02:00 PM', subject: _dsa, on: DateTime(2026, 9, 30));
      final profile = await profileOf(_kept);
      final attendance = MyAttendanceController(
        profile: profile,
        repository: records,
        clock: () => _now,
      );
      addTearDown(attendance.dispose);
      await attendance.refresh();

      final scan = LiveRecord(
        id: 3,
        subject: _oop,
        instructor: 'Sample Instructor',
        day: _day(DateTime(2026, 10, 1), '08:04:12 AM'),
      );
      final other = LiveRecord(
        id: 4,
        subject: 'Business Law',
        instructor: 'Sample Instructor',
        day: _day(DateTime(2026, 10, 1), '10:30:26 AM'),
      );
      attendance.addRecords([scan, other]);
      attendance.addRecords([scan]);

      final history = attendance.history!;
      expect(history.total, 4);
      expect(
        [for (final s in history.subjects) s.subject],
        ['Business Law', _dsa, _oop],
      );
      final oop = history.subjects.last;
      expect(oop.count, 2);
      expect(
        [for (final d in oop.days) d.timeIn],
        ['08:04:12 AM', '08:11:40 AM'],
      );
      expect(history.lastAttended, DateTime(2026, 10, 1));
      expect(attendance.today, hasLength(2));
    });
  });

  group('the page', () {
    StudentNotice notice(
      int id,
      NoticeKind kind, {
      required DateTime at,
      String subject = _oop,
      bool read = false,
    }) => StudentNotice(
      id: StudentNotice.recordId(id),
      kind: kind,
      subject: subject,
      day: _day(DateTime(2026, 10, 1), '08:0$id:00 AM'),
      at: at,
      read: read,
    );

    Future<NotificationsController> feedWith(
      List<StudentNotice> kept, {
      bool setUp = true,
    }) async {
      final notices = NotificationsController(
        profile: await profileOf(setUp ? _kept : null),
        repository: _Records(),
        store: MemoryNoticeStore(
          NoticeFeed(
            studentNumber: _number.value,
            cursor: 9,
            count: 9,
            notices: kept,
          ),
        ),
        clock: () => _now,
      );
      addTearDown(notices.dispose);
      await settle();
      return notices;
    }

    Widget page(
      NotificationsController controller, {
      VoidCallback? onOpen,
      VoidCallback? onSetUp,
    }) => MaterialApp(
      theme: AppTheme.build(AppPalette.light),
      home: NotificationsPage(
        controller: controller,
        onOpenAttendance: onOpen,
        onSetUp: onSetUp,
        now: () => _now,
      ),
    );

    testWidgets('lists them under the day they came, and reading clears the '
        'count but keeps NEW on what was new', (tester) async {
      final notices = await feedWith([
        notice(
          3,
          NoticeKind.late,
          at: _now.subtract(const Duration(minutes: 5)),
        ),
        notice(
          2,
          NoticeKind.present,
          at: _now.subtract(const Duration(hours: 2)),
        ),
        notice(
          4,
          NoticeKind.removed,
          at: DateTime(2026, 9, 30, 16, 5),
          read: true,
        ),
        notice(
          1,
          NoticeKind.present,
          subject: _dsa,
          at: DateTime(2026, 9, 29, 13),
          read: true,
        ),
      ]);
      var opened = 0;

      await tester.pumpWidget(page(notices, onOpen: () => opened++));
      await tester.pumpAndSettle();

      expect(find.text(NoticeStrings.today), findsOneWidget);
      expect(find.text(NoticeStrings.earlier), findsOneWidget);
      expect(find.text(NoticeStrings.yesterday), findsOneWidget);
      expect(find.text(NoticeStrings.removed), findsOneWidget);
      // Under YESTERDAY, the time: the heading already says the day.
      expect(find.text('4:05 PM'), findsOneWidget);
      expect(find.text(NoticeStrings.late), findsOneWidget);
      expect(find.text(NoticeStrings.present), findsNWidgets(2));
      expect(find.text(NoticeStrings.minutesAgo(5)), findsOneWidget);
      expect(find.text(NoticeStrings.hoursAgo(2)), findsOneWidget);
      expect(find.text('Tue, Sep 29'), findsOneWidget);

      // Read on sight; the two that were new keep their mark.
      expect(notices.unread, 0);
      expect(find.text(NoticeStrings.newBadge), findsNWidgets(2));

      await tester.tap(find.byKey(const ValueKey('notifications.r3')));
      expect(opened, 1);
    });

    testWidgets('with none yet, says what will show there', (tester) async {
      final notices = await feedWith(const []);

      await tester.pumpWidget(page(notices));
      await tester.pumpAndSettle();

      expect(find.text(NoticeStrings.emptyTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('notifications.live')), findsOneWidget);
    });

    testWidgets('before the phone is set up, sends the student to My Profile', (
      tester,
    ) async {
      final notices = await feedWith(const [], setUp: false);
      var setUp = 0;

      await tester.pumpWidget(page(notices, onSetUp: () => setUp++));
      await tester.pumpAndSettle();

      expect(find.text(NoticeStrings.setUpTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('notifications.live')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('notifications.setUp')));
      expect(setUp, 1);
    });

    testWidgets('lays out on a small phone without overflowing', (
      tester,
    ) async {
      final view = tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(320, 640);
      addTearDown(view.reset);
      final notices = await feedWith([
        for (var i = 1; i <= 6; i++)
          notice(
            i,
            i.isEven ? NoticeKind.late : NoticeKind.removed,
            subject: 'A subject with a rather long name, number $i',
            at: _now.subtract(Duration(days: i - 1)),
          ),
      ]);

      await tester.pumpWidget(page(notices));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('the island', () {
    Future<(NotificationsController, _Records, SettingsController)> live(
      WidgetTester tester, {
      bool alerts = true,
    }) async {
      final records = _Records();
      final (notices, _) = await feedOf(await profileOf(_kept), records);
      final settings = SettingsController(
        store: MemorySettingsStore(AppSettings(alerts: alerts)),
      );
      await settings.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppPalette.light),
          builder: (context, child) => IslandHost(child: child!),
          home: LiveNotices(
            controller: notices,
            settings: settings,
            now: () => _now,
            child: const Scaffold(body: SizedBox.expand()),
          ),
        ),
      );
      // The first look.
      await tester.pump();
      return (notices, records, settings);
    }

    testWidgets('says a scan the moment the feed brings it', (tester) async {
      final (_, records, _) = await live(tester);

      records.add(1, '08:04:12 AM');
      await tester.pump(const Duration(seconds: 15));
      await tester.pump();

      expect(find.text(NoticeStrings.present), findsOneWidget);
      expect(find.text('$_oop · 8:04 AM · on time'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text(NoticeStrings.present), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('several at once are one island', (tester) async {
      final (_, records, _) = await live(tester);

      records
        ..add(1, '08:04:12 AM')
        ..add(2, '10:20:00 AM', subject: _dsa, late: true);
      await tester.pump(const Duration(seconds: 15));
      await tester.pump();

      expect(find.text(NoticeStrings.several(2)), findsOneWidget);
      expect(
        find.text(NoticeStrings.severalBody('$_dsa · 10:20 AM · late', 1)),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('with Attendance alerts off, the list fills and the island '
        'stays away', (tester) async {
      final (notices, records, _) = await live(tester, alerts: false);

      records.add(1, '08:04:12 AM');
      await tester.pump(const Duration(seconds: 15));
      await tester.pump();

      expect(find.text(NoticeStrings.present), findsNothing);
      expect(notices.unread, 1);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('in the app: a scan while Home is open is on the island, on the '
      'bell, and in Notifications', (tester) async {
    final view = tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(420, 1000);
    addTearDown(view.reset);
    final records = _Records()
      ..add(1, '08:00:00 AM', on: DateTime(2026, 9, 30));

    await tester.pumpWidget(
      BccSasqrApp(
        roleStore: MemoryRoleStore(AppRole.student),
        profileStore: MemoryProfileStore(_kept),
        photoRepository: _Photos(),
        trackerRepository: records,
        liveRepository: records,
        settingsStore: MemorySettingsStore(),
        speech: const SilentSpeechService(),
        cameraBuilder: (context, onCode) => const SizedBox(),
        showSplash: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studentHome')), findsOneWidget);
    expect(records.liveAsked, greaterThanOrEqualTo(1));

    records.add(2, '08:04:12 AM');
    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    expect(find.text(NoticeStrings.present), findsOneWidget);
    await tester.pumpAndSettle();

    final bell = find.byKey(const ValueKey('home.notifications'));
    final count = find.descendant(of: bell, matching: find.text('1'));
    expect(count, findsOneWidget);
    await tester.tap(bell);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('notifications')), findsOneWidget);
    expect(find.text(NoticeStrings.present), findsOneWidget);

    // Opened is read: back on Home, the bell has nothing to count.
    await tester.tap(find.byKey(const ValueKey('notifications.back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studentHome')), findsOneWidget);
    expect(count, findsNothing);

    // A notice opens My Attendance, down on the shell.
    await tester.tap(bell);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notifications.r2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('notifications')), findsNothing);
    expect(find.byType(MyAttendancePage), findsOneWidget);
  });
}
