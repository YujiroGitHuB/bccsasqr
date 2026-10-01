import 'dart:convert';
import 'dart:typed_data';

import 'package:bccsasqr_app/app.dart';
import 'package:bccsasqr_app/controllers/check_in_controller.dart';
import 'package:bccsasqr_app/controllers/my_attendance_controller.dart';
import 'package:bccsasqr_app/controllers/profile_controller.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/core/theme/app_colors.dart';
import 'package:bccsasqr_app/core/theme/app_theme.dart';
import 'package:bccsasqr_app/core/utils/student_number.dart';
import 'package:bccsasqr_app/models/app_role.dart';
import 'package:bccsasqr_app/models/attendance_history.dart';
import 'package:bccsasqr_app/models/class_link.dart';
import 'package:bccsasqr_app/models/qr_payload.dart';
import 'package:bccsasqr_app/models/student_profile.dart';
import 'package:bccsasqr_app/models/student_record.dart';
import 'package:bccsasqr_app/models/whats_new.dart';
import 'package:bccsasqr_app/services/check_in_repository.dart';
import 'package:bccsasqr_app/services/http_student_repository.dart';
import 'package:bccsasqr_app/services/photo_repository.dart';
import 'package:bccsasqr_app/services/profile_store.dart';
import 'package:bccsasqr_app/services/qr_export_service.dart';
import 'package:bccsasqr_app/services/role_store.dart';
import 'package:bccsasqr_app/services/saved_qr_store.dart';
import 'package:bccsasqr_app/services/speech_service.dart';
import 'package:bccsasqr_app/services/student_repository.dart';
import 'package:bccsasqr_app/services/tracker_repository.dart';
import 'package:bccsasqr_app/views/check_in_page.dart';
import 'package:bccsasqr_app/views/my_attendance_page.dart';
import 'package:bccsasqr_app/views/show_qr_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Made-up students only: year 000 never occurs in the school's numbers.
final _number = StudentNumber.tryParse('000-1023')!;

final _record = StudentRecord(
  studentNumber: _number,
  fullName: 'DELA CRUZ, JUAN P.',
  course: 'BSIT',
  section: '2A',
);

final _kept = StudentProfile(record: _record, lastName: 'Dela Cruz');

final _now = DateTime(2026, 10, 1, 8);

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

/// A tracker whose answer the test changes between asks — a scan landing.
class _Tracker implements TrackerRepository {
  _Tracker(this.history);

  AttendanceHistory? history;
  StudentLookupException? failure;
  int asked = 0;

  @override
  Future<AttendanceHistory?> fetchAttendance(StudentNumber number) async {
    asked++;
    if (failure case final f?) throw f;
    return history;
  }
}

AttendanceDay _day(DateTime d, String time, {bool late = false}) =>
    AttendanceDay(date: d, rawDate: '$d', timeIn: time, late: late);

AttendanceHistory _history(List<AttendanceDay> days) => AttendanceHistory(
  studentNumber: _number.value,
  fullName: _record.fullName,
  course: 'BSIT',
  section: '2A',
  total: days.length,
  subjects: [
    SubjectAttendance(
      subject: 'Object Oriented Programming',
      instructor: 'Sample Instructor',
      count: days.length,
      days: days,
    ),
  ],
);

class _Export implements QrExportService {
  int saved = 0;

  @override
  Future<String> export({
    required GlobalKey boundaryKey,
    required String fileName,
    String? shareText,
  }) async {
    saved++;
    return 'memory://$fileName';
  }
}

/// Check in's server, scripted by the test.
class _CheckIns implements CheckInRepository {
  final List<String> lookedUp = [];
  final List<String?> devicesSent = [];
  StudentLookupException? refusal;

  static const ClassLink link = ClassLink(
    shortCode: 'K7P2QX',
    subjectCode: 'ITE211',
    subjectName: 'Object Oriented Programming',
    section: 'BSIT-2A',
    instructor: 'Sample Instructor',
    closesLabel: '9:00 AM',
    lateOn: true,
    lateLabel: '8:15 AM',
    lateIn: 600,
  );

  @override
  Future<ClassLink> findClass(String code) async {
    lookedUp.add(code);
    if (code != link.shortCode) {
      throw const StudentLookupException(
        'This attendance link is not valid.',
        code: 'link_not_found',
      );
    }
    return link;
  }

  @override
  Future<CheckInResult> checkIn(
    String code, {
    required StudentNumber number,
    required String lastName,
    String? device,
    void Function(String device)? onDevice,
  }) async {
    devicesSent.add(device);
    onDevice?.call('tok-1');
    if (refusal case final r?) throw r;
    return const CheckInResult(
      subject: 'Object Oriented Programming',
      timeIn: '08:04:12 AM',
      late: false,
      message: 'Attendance submitted successfully!',
    );
  }
}

Widget _app(Widget home) =>
    MaterialApp(theme: AppTheme.build(AppPalette.light), home: home);

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.devicePixelRatio = 1.0;
    view.physicalSize = const Size(420, 1000);
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<ProfileController> profileOf(StudentProfile? kept) async {
    final profile = ProfileController(
      store: MemoryProfileStore(kept),
      repository: _Photos(),
    );
    addTearDown(profile.dispose);
    await profile.load();
    return profile;
  }

  group('class codes', () {
    test('read from the link the class QR holds, or typed bare', () {
      expect(
        ClassLink.codeFrom(
          'https://example.test/bccsasqr/pages/daily_attendance.php?c=K7P2QX',
        ),
        'K7P2QX',
      );
      expect(ClassLink.codeFrom(' k7p2qx '), 'K7P2QX');
      // A student's own QR is not a class's.
      expect(ClassLink.codeFrom('000-1023'), isNull);
      expect(ClassLink.codeFrom('https://example.test/?q=1'), isNull);
    });
  });

  test("What's New keeps a student-only change off an instructor's phone", () {
    const item = WhatsNewItem(
      kind: WhatsNewKind.improved,
      area: WhatsNewArea.qr,
      side: WhatsNewSide.student,
      icon: Icons.qr_code_2_rounded,
      title: 'Your QR code, right on Home',
      text: '',
    );
    const student = {
      WhatsNewArea.qr,
      WhatsNewArea.tracker,
      WhatsNewArea.profile,
      WhatsNewArea.checkIn,
    };
    const instructor = {
      WhatsNewArea.qr,
      WhatsNewArea.scanner,
      WhatsNewArea.tracker,
      WhatsNewArea.links,
    };
    expect(item.isFor(student), isTrue);
    expect(item.isFor(instructor), isFalse);
  });

  group('My Attendance', () {
    test(
      'picks out today\'s scans, and follows the student on the phone',
      () async {
        final profile = await profileOf(_kept);
        final tracker = _Tracker(
          _history([
            _day(DateTime(2026, 10, 1), '08:04:12 AM'),
            _day(DateTime(2026, 9, 28), '08:11:40 AM', late: true),
          ]),
        );
        final attendance = MyAttendanceController(
          profile: profile,
          repository: tracker,
          clock: () => _now,
        );
        addTearDown(attendance.dispose);
        await attendance.refresh();

        expect(attendance.today.single.day.timeIn, '08:04:12 AM');
        expect(attendance.lateCount, 1);

        await profile.forget();
        expect(attendance.hasStudent, isFalse);
        expect(attendance.history, isNull);
      },
    );

    testWidgets('the Late chip leaves only the late days', (tester) async {
      final profile = await profileOf(_kept);
      final attendance = MyAttendanceController(
        profile: profile,
        repository: _Tracker(
          _history([
            _day(DateTime(2026, 10, 1), '08:04:12 AM'),
            _day(DateTime(2026, 9, 28), '08:11:40 AM', late: true),
          ]),
        ),
        clock: () => _now,
      );
      addTearDown(attendance.dispose);

      await tester.pumpWidget(
        _app(MyAttendancePage(controller: attendance, now: () => _now)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thu, Oct 1'), findsOneWidget);
      expect(find.text('Mon, Sep 28'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('myAttendance.filter.late')));
      await tester.pumpAndSettle();
      expect(find.text('Thu, Oct 1'), findsNothing);
      expect(find.text('Mon, Sep 28'), findsOneWidget);
    });
  });

  group('Show to scanner', () {
    final code = SavedQr(
      record: _record,
      payload: QrPayload.forRecord(_record),
      savedAt: _now,
    );

    testWidgets('holds the screen on, and says when the scan lands', (
      tester,
    ) async {
      final profile = await profileOf(_kept);
      final tracker = _Tracker(_history([]));
      final attendance = MyAttendanceController(
        profile: profile,
        repository: tracker,
        clock: () => _now,
      );
      addTearDown(attendance.dispose);
      await attendance.refresh();
      final awake = <bool>[];

      await tester.pumpWidget(
        _app(
          ShowQrPage(
            code: code,
            exportService: _Export(),
            attendance: attendance,
            keepAwake: (on) async => awake.add(on),
            watchEvery: const Duration(seconds: 1),
          ),
        ),
      );
      expect(awake, [true]);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text(ShowQrStrings.marked), findsNothing);

      // The instructor scans.
      tracker.history = _history([_day(DateTime(2026, 10, 1), '08:04:12 AM')]);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.textContaining(ShowQrStrings.marked), findsOneWidget);

      // Said once, then the asking stops.
      final asked = tracker.asked;
      await tester.pump(const Duration(seconds: 5));
      expect(tracker.asked, asked);

      await tester.pumpWidget(const SizedBox());
      expect(awake, [true, false]);
    });

    testWidgets('stops asking when the server says slow down', (tester) async {
      final profile = await profileOf(_kept);
      final tracker = _Tracker(_history([]));
      final attendance = MyAttendanceController(
        profile: profile,
        repository: tracker,
        clock: () => _now,
      );
      addTearDown(attendance.dispose);

      await tester.pumpWidget(
        _app(
          ShowQrPage(
            code: code,
            exportService: _Export(),
            attendance: attendance,
            watchEvery: const Duration(seconds: 1),
          ),
        ),
      );
      tracker.failure = const StudentLookupException(
        'Too many requests.',
        code: 'rate_limited',
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      final asked = tracker.asked;
      await tester.pump(const Duration(seconds: 5));
      expect(tracker.asked, asked);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('saves the same card My QR Code saves', (tester) async {
      final export = _Export();
      await tester.pumpWidget(
        _app(ShowQrPage(code: code, exportService: export)),
      );
      await tester.tap(find.byKey(const ValueKey('showQr.save')));
      await tester.pumpAndSettle();
      expect(export.saved, 1);
    });
  });

  group('Check in', () {
    Future<(CheckInController, _CheckIns, MemoryDeviceTokenStore)> setUpCheckIn(
      StudentProfile? kept,
    ) async {
      final profile = await profileOf(kept);
      final server = _CheckIns();
      final devices = MemoryDeviceTokenStore();
      final controller = CheckInController(
        repository: server,
        profile: profile,
        devices: devices,
      );
      addTearDown(controller.dispose);
      return (controller, server, devices);
    }

    test('six typed letters look the class up', () async {
      final (controller, server, _) = await setUpCheckIn(_kept);

      controller.onCodeTyped('k7p2q');
      expect(server.lookedUp, isEmpty);
      controller.onCodeTyped('k7p2qx');
      await pumpEventQueue();

      expect(server.lookedUp, ['K7P2QX']);
      expect(controller.stage, CheckInStage.found);
      expect(controller.link?.subjectName, 'Object Oriented Programming');
    });

    test(
      'a student\'s QR in the camera is not a class code — said once',
      () async {
        final (controller, server, _) = await setUpCheckIn(_kept);
        var told = 0;
        controller.addListener(() => told++);

        controller.onScanned('000-1023');
        controller.onScanned('000-1023');
        expect(controller.error, CheckInStrings.notAClassQr);
        expect(told, 1);
        expect(server.lookedUp, isEmpty);
      },
    );

    test('confirming keeps the device token, refusals included', () async {
      final (controller, server, devices) = await setUpCheckIn(_kept);

      controller.onScanned(
        'https://example.test/pages/daily_attendance.php?c=K7P2QX',
      );
      await pumpEventQueue();
      final result = await controller.confirm();
      await pumpEventQueue();

      expect(result?.subject, 'Object Oriented Programming');
      expect(server.devicesSent, [null]);
      expect(devices.token, 'tok-1');
      expect(controller.stage, CheckInStage.idle);

      server.refusal = const StudentLookupException(
        'You have already submitted your attendance for this subject today.',
        code: 'already_checked_in',
      );
      controller.onCodeTyped('K7P2QX');
      await pumpEventQueue();
      expect(await controller.confirm(), isNull);
      expect(server.devicesSent, [null, 'tok-1']);
      expect(controller.error, contains('already submitted'));
      expect(controller.stage, CheckInStage.idle);
    });

    testWidgets('before the phone is set up, the page asks for My Profile', (
      tester,
    ) async {
      final (controller, _, _) = await setUpCheckIn(null);
      final profile = await profileOf(null);
      var setUp = 0;

      await tester.pumpWidget(
        _app(
          CheckInPage(
            controller: controller,
            profile: profile,
            cameraBuilder: (context, onCode) => const SizedBox(),
            onSetUp: () => setUp++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(CheckInStrings.setUpTitle), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('checkIn.setUp')));
      expect(setUp, 1);
    });

    testWidgets('a code from the camera shows the class, and one tap checks '
        'in', (tester) async {
      final (controller, _, _) = await setUpCheckIn(_kept);
      final profile = await profileOf(_kept);
      ValueChanged<String>? camera;
      var checkedIn = 0;

      await tester.pumpWidget(
        _app(
          CheckInPage(
            controller: controller,
            profile: profile,
            cameraBuilder: (context, onCode) {
              camera = onCode;
              return const SizedBox();
            },
            onSetUp: () {},
            onCheckedIn: () => checkedIn++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      camera!('https://example.test/pages/daily_attendance.php?c=K7P2QX');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('checkIn.class')), findsOneWidget);
      expect(find.text(CheckInStrings.onTimeUntil('8:15 AM')), findsOneWidget);
      expect(find.text(CheckInStrings.confirm('Juan')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('checkIn.confirm')));
      await tester.pumpAndSettle();
      expect(checkedIn, 1);
      expect(find.byKey(const ValueKey('checkIn.class')), findsNothing);
    });

    test(
      'the API client sends the token and keeps the one it is given',
      () async {
        final sent = <Map<String, dynamic>>[];
        var refuse = false;
        final repo = HttpStudentRepository(
          baseUrl: 'https://example.test/bccsasqr/api/v1',
          client: MockClient((request) async {
            expect(request.url.path, '/bccsasqr/api/v1/checkin/K7P2QX');
            sent.add(jsonDecode(request.body) as Map<String, dynamic>);
            return http.Response(
              jsonEncode(
                refuse
                    ? {
                        'success': false,
                        'error': {
                          'code': 'device_reuse',
                          'message':
                              'This device has already recorded '
                              'attendance for another student today.',
                          'details': {'device': 'tok-2'},
                        },
                      }
                    : {
                        'success': true,
                        'data': {
                          'subject': 'Object Oriented Programming',
                          'time_in': '08:04:12 AM',
                          'late': false,
                          'message': 'Attendance submitted successfully!',
                          'device': 'tok-1',
                        },
                      },
              ),
              refuse ? 409 : 200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        final kept = <String>[];

        final result = await repo.checkIn(
          'K7P2QX',
          number: _number,
          lastName: 'Dela Cruz',
          onDevice: kept.add,
        );
        expect(result.timeIn, '08:04:12 AM');
        expect(sent.single, {
          'student_no': '000-1023',
          'last_name': 'Dela Cruz',
        });

        refuse = true;
        await expectLater(
          repo.checkIn(
            'K7P2QX',
            number: _number,
            lastName: 'Dela Cruz',
            device: 'tok-1',
            onDevice: kept.add,
          ),
          throwsA(
            isA<StudentLookupException>().having(
              (e) => e.code,
              'code',
              'device_reuse',
            ),
          ),
        );
        expect(sent.last['device'], 'tok-1');
        expect(kept, ['tok-1', 'tok-2']);
      },
    );
  });

  group('the student\'s Menu', () {
    Widget appWith(StudentProfile? kept) => BccSasqrApp(
      roleStore: MemoryRoleStore(AppRole.student),
      profileStore: MemoryProfileStore(kept),
      photoRepository: _Photos(),
      trackerRepository: _Tracker(_history([])),
      speech: const SilentSpeechService(),
      // No camera in a test.
      cameraBuilder: (context, onCode) => const SizedBox(),
      showSplash: false,
    );

    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('nav.menu')));
      await tester.pumpAndSettle();
    }

    testWidgets('opens every part, Home marked', (tester) async {
      await tester.pumpWidget(appWith(_kept));
      await tester.pumpAndSettle();
      await openMenu(tester);

      expect(find.text(MenuStrings.title), findsOneWidget);
      for (final name in [
        'home',
        'qr',
        'tracker',
        'checkIn',
        'profile',
        'settings',
      ]) {
        expect(find.byKey(ValueKey('menu.$name')), findsOneWidget);
      }
      expect(
        tester.getSemantics(find.byKey(const ValueKey('menu.home'))),
        containsSemantics(isSelected: true),
      );

      await tester.tap(find.byKey(const ValueKey('menu.checkIn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('checkIn')), findsOneWidget);
      expect(find.text(MenuStrings.title), findsNothing);
    });

    testWidgets('its big card puts the code full screen', (tester) async {
      await tester.pumpWidget(appWith(_kept));
      await tester.pumpAndSettle();
      await openMenu(tester);

      expect(find.text(StudentStrings.showQrBody('000-1023')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('menu.showQr')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('showQr')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('showQr.close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('studentHome')), findsOneWidget);
    });

    testWidgets('"Not you?" asks, then the phone forgets the student', (
      tester,
    ) async {
      await tester.pumpWidget(appWith(_kept));
      await tester.pumpAndSettle();
      await openMenu(tester);

      await tester.tap(find.byKey(const ValueKey('menu.notYou')));
      await tester.pumpAndSettle();
      expect(find.text(StudentStrings.forgetTitle), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('menu.notYou.confirm')));
      await tester.pumpAndSettle();

      expect(find.text(StudentStrings.setUpBody), findsOneWidget);
    });

    testWidgets('lays out on a small phone without overflowing', (
      tester,
    ) async {
      TestWidgetsFlutterBinding
          .instance
          .platformDispatcher
          .views
          .first
          .physicalSize = const Size(
        320,
        640,
      );
      for (final kept in [null, _kept]) {
        await tester.pumpWidget(appWith(kept));
        await tester.pumpAndSettle();
        await openMenu(tester);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });
}
