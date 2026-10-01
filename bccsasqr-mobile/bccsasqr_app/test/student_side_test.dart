import 'dart:convert';

import 'package:bccsasqr_app/app.dart';
import 'package:bccsasqr_app/controllers/check_in_controller.dart';
import 'package:bccsasqr_app/controllers/my_attendance_controller.dart';
import 'package:bccsasqr_app/controllers/profile_controller.dart';
import 'package:bccsasqr_app/controllers/settings_controller.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/core/theme/app_colors.dart';
import 'package:bccsasqr_app/core/theme/app_theme.dart';
import 'package:bccsasqr_app/core/utils/student_number.dart';
import 'package:bccsasqr_app/models/app_role.dart';
import 'package:bccsasqr_app/models/app_settings.dart';
import 'package:bccsasqr_app/models/attendance_history.dart';
import 'package:bccsasqr_app/models/class_link.dart';
import 'package:bccsasqr_app/models/qr_payload.dart';
import 'package:bccsasqr_app/models/student_profile.dart';
import 'package:bccsasqr_app/models/student_record.dart';
import 'package:bccsasqr_app/models/whats_new.dart';
import 'package:bccsasqr_app/services/check_in_repository.dart';
import 'package:bccsasqr_app/services/device_lock.dart';
import 'package:bccsasqr_app/services/http_student_repository.dart';
import 'package:bccsasqr_app/services/photo_repository.dart';
import 'package:bccsasqr_app/services/profile_store.dart';
import 'package:bccsasqr_app/services/qr_export_service.dart';
import 'package:bccsasqr_app/services/role_store.dart';
import 'package:bccsasqr_app/services/saved_qr_store.dart';
import 'package:bccsasqr_app/services/settings_store.dart';
import 'package:bccsasqr_app/services/speech_service.dart';
import 'package:bccsasqr_app/services/student_repository.dart';
import 'package:bccsasqr_app/services/tracker_repository.dart';
import 'package:bccsasqr_app/views/check_in_page.dart';
import 'package:bccsasqr_app/views/check_in_splash.dart';
import 'package:bccsasqr_app/views/my_attendance_page.dart';
import 'package:bccsasqr_app/views/show_qr_page.dart';
import 'package:bccsasqr_app/views/student_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// What the next look-ups answer instead of the class — the link closed
  /// meanwhile, say.
  StudentLookupException? lookupRefusal;

  @override
  Future<ClassLink> findClass(String code) async {
    lookedUp.add(code);
    if (lookupRefusal case final r?) throw r;
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

/// A phone whose lock answers from a script: the next results in order,
/// "unlocked" once the script runs out.
class _PhoneLock implements DeviceLock {
  bool available = true;
  final List<DeviceUnlock> script = [];
  final List<String> asked = [];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<DeviceUnlock> unlock(String reason) async {
    asked.add(reason);
    return script.isEmpty ? DeviceUnlock.unlocked : script.removeAt(0);
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
    test('found in whatever is pasted: the message, the link, the code', () {
      const link =
          'https://example.test/bccsasqr/pages/daily_attendance.php?c=K7P2QX';
      expect(ClassLink.codeIn(link), 'K7P2QX');
      expect(ClassLink.codeIn(' k7p2qx\n'), 'K7P2QX');
      // The app's Share, and the older one with no code line.
      expect(
        ClassLink.codeIn(
          LinksStrings.shareText('OOP', 'BSIT-2A', link, 'K7P2QX'),
        ),
        'K7P2QX',
      );
      expect(ClassLink.codeIn('Attendance for OOP (BSIT-2A): $link'), 'K7P2QX');
      // The sentence's full stop is not part of the link.
      expect(ClassLink.codeIn('Check in here: $link.'), 'K7P2QX');
      expect(ClassLink.codeIn('Class code: K7P2QX'), 'K7P2QX');
      // A word that only follows "code" is not one.
      expect(ClassLink.codeIn('Bring the QR code here tomorrow'), isNull);
      expect(ClassLink.codeIn('000-1023'), isNull);
    });

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
    /// The phone's preferences, with the camera on or — as Check in first
    /// opens — off.
    Future<SettingsController> settingsWith({
      bool camera = false,
      MemorySettingsStore? store,
    }) async {
      final settings = SettingsController(
        store: store ?? MemorySettingsStore(AppSettings(checkInCamera: camera)),
      );
      addTearDown(settings.dispose);
      await settings.load();
      return settings;
    }

    /// What Paste finds on the clipboard.
    void clipboardHolds(WidgetTester tester, String? text) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        // An empty clipboard answers nothing at all.
        (call) async => call.method == 'Clipboard.getData' && text != null
            ? <String, Object?>{'text': text}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
    }

    /// The instructor's Share, as it lands in the group chat.
    final shared = LinksStrings.shareText(
      'Object Oriented Programming',
      'BSIT-2A',
      'https://example.test/pages/daily_attendance.php?c=K7P2QX',
      'K7P2QX',
    );

    Future<(CheckInController, _CheckIns, MemoryDeviceTokenStore)> setUpCheckIn(
      StudentProfile? kept, {
      DeviceLock lock = const NoDeviceLock(),
    }) async {
      final profile = await profileOf(kept);
      final server = _CheckIns();
      final devices = MemoryDeviceTokenStore();
      final controller = CheckInController(
        repository: server,
        profile: profile,
        devices: devices,
        deviceLock: lock,
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

    test('a paste is looked up — the whole message too — or says why '
        'not', () async {
      final (controller, server, _) = await setUpCheckIn(_kept);

      expect(controller.onPasted('   '), isFalse);
      expect(controller.error, CheckInStrings.pasteEmpty);
      expect(controller.onPasted('see you in class!'), isFalse);
      expect(controller.error, CheckInStrings.pasteNoCode);
      expect(server.lookedUp, isEmpty);

      expect(controller.onPasted(shared), isTrue);
      await pumpEventQueue();
      expect(server.lookedUp, ['K7P2QX']);
      expect(controller.stage, CheckInStage.found);
      expect(controller.error, isNull);
    });

    test('on a phone with a screen lock, every check-in asks for it '
        'first', () async {
      final lock = _PhoneLock();
      final (controller, server, _) = await setUpCheckIn(_kept, lock: lock);
      controller.onCodeTyped('K7P2QX');
      await pumpEventQueue();
      expect(controller.asksOwner, isTrue);

      // Closed without a finger: nothing sent, the class kept to try again.
      lock.script.add(DeviceUnlock.cancelled);
      expect(await controller.confirm(), isNull);
      expect(lock.asked, [CheckInStrings.lockReason]);
      expect(server.devicesSent, isEmpty);
      expect(controller.error, CheckInStrings.lockNotConfirmed);
      expect(controller.stage, CheckInStage.found);

      final result = await controller.confirm();
      expect(result?.subject, 'Object Oriented Programming');
      expect(lock.asked, [
        CheckInStrings.lockReason,
        CheckInStrings.lockReason,
      ]);
      expect(server.devicesSent, hasLength(1));
    });

    test('a pull to refresh asks about the class again; with none, the page '
        'starts fresh', () async {
      final (controller, server, _) = await setUpCheckIn(_kept);
      controller.onCodeTyped('K7P2QX');
      await pumpEventQueue();

      await controller.refresh();
      expect(server.lookedUp, ['K7P2QX', 'K7P2QX']);
      expect(controller.stage, CheckInStage.found);

      // Closed meanwhile: nothing left to check in to, and it says why.
      server.lookupRefusal = const StudentLookupException(
        'This attendance link has expired.',
        code: 'link_closed',
      );
      await controller.refresh();
      expect(controller.stage, CheckInStage.idle);
      expect(controller.link, isNull);
      expect(controller.error, 'This attendance link has expired.');

      // Nothing on screen: the message and the half-typed code go.
      controller.onCodeTyped('AB');
      await controller.refresh();
      expect(controller.error, isNull);
      expect(controller.code, isEmpty);
      expect(server.lookedUp, hasLength(3));
    });

    test('a phone with no screen lock sends without asking', () async {
      final lock = _PhoneLock()..available = false;
      final (controller, server, _) = await setUpCheckIn(_kept, lock: lock);
      controller.onCodeTyped('K7P2QX');
      await pumpEventQueue();
      expect(controller.asksOwner, isFalse);

      final result = await controller.confirm();
      expect(result?.subject, 'Object Oriented Programming');
      expect(lock.asked, isEmpty);
      expect(server.devicesSent, hasLength(1));
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
            settings: await settingsWith(),
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
            // Turned on before, and kept.
            settings: await settingsWith(camera: true),
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

    testWidgets('Paste takes the link the instructor shared', (tester) async {
      final (controller, server, _) = await setUpCheckIn(_kept);
      final profile = await profileOf(_kept);
      final settings = await settingsWith();

      await tester.pumpWidget(
        _app(
          CheckInPage(
            controller: controller,
            profile: profile,
            settings: settings,
            cameraBuilder: (context, onCode) => const SizedBox(),
            onSetUp: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Nothing copied yet.
      clipboardHolds(tester, null);
      await tester.tap(find.byKey(const ValueKey('checkIn.paste')));
      await tester.pumpAndSettle();
      expect(find.text(CheckInStrings.pasteEmpty), findsOneWidget);

      // The whole message from the group chat.
      clipboardHolds(tester, shared);
      await tester.tap(find.byKey(const ValueKey('checkIn.paste')));
      await tester.pumpAndSettle();
      expect(server.lookedUp, ['K7P2QX']);
      expect(find.byKey(const ValueKey('checkIn.class')), findsOneWidget);
      expect(find.text(CheckInStrings.pasteEmpty), findsNothing);
      // The boxes show the code it found.
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('checkIn.code')))
            .controller!
            .text,
        'K7P2QX',
      );
    });

    testWidgets('the message pasted from the keyboard leaves just the code '
        'in the boxes', (tester) async {
      final (controller, server, _) = await setUpCheckIn(_kept);
      final profile = await profileOf(_kept);

      await tester.pumpWidget(
        _app(
          CheckInPage(
            controller: controller,
            profile: profile,
            settings: await settingsWith(),
            cameraBuilder: (context, onCode) => const SizedBox(),
            onSetUp: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The keyboard's clipboard chip puts the whole message in at once.
      await tester.enterText(
        find.byKey(const ValueKey('checkIn.code')),
        shared,
      );
      await tester.pumpAndSettle();

      expect(server.lookedUp, ['K7P2QX']);
      expect(find.byKey(const ValueKey('checkIn.class')), findsOneWidget);
    });

    testWidgets('the camera is off until the student turns it on, and stays '
        'the way they leave it', (tester) async {
      final (controller, _, _) = await setUpCheckIn(_kept);
      final profile = await profileOf(_kept);
      final store = MemorySettingsStore();
      final camera = find.byKey(const ValueKey('camera'));

      await tester.pumpWidget(
        _app(
          CheckInPage(
            controller: controller,
            profile: profile,
            settings: await settingsWith(store: store),
            cameraBuilder: (context, onCode) =>
                const SizedBox(key: ValueKey('camera')),
            onSetUp: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(camera, findsNothing);

      await tester.tap(find.byKey(const ValueKey('checkIn.cameraOn')));
      await tester.pumpAndSettle();
      expect(camera, findsOneWidget);
      expect(store.saved.checkInCamera, isTrue);

      // Stop is in the card's header, where the camera icon was: above the
      // picture, not on it.
      final stop = find.byKey(const ValueKey('checkIn.cameraOff'));
      final picture = find.byKey(const ValueKey('checkIn.camera'));
      expect(
        tester.getRect(stop).bottom,
        lessThanOrEqualTo(tester.getRect(picture).top),
      );

      await tester.tap(stop);
      await tester.pumpAndSettle();
      expect(camera, findsNothing);
      expect(store.saved.checkInCamera, isFalse);
    });

    testWidgets('pulling the page down refreshes the class on it', (
      tester,
    ) async {
      final (controller, server, _) = await setUpCheckIn(_kept);
      final profile = await profileOf(_kept);

      await tester.pumpWidget(
        _app(
          CheckInPage(
            controller: controller,
            profile: profile,
            settings: await settingsWith(),
            cameraBuilder: (context, onCode) => const SizedBox(),
            onSetUp: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      controller.onCodeTyped('K7P2QX');
      await tester.pumpAndSettle();
      expect(server.lookedUp, hasLength(1));

      await tester.fling(
        find.byType(SingleChildScrollView),
        const Offset(0, 400),
        1200,
      );
      await tester.pumpAndSettle();
      expect(server.lookedUp, hasLength(2));
      expect(find.byKey(const ValueKey('checkIn.class')), findsOneWidget);
    });

    testWidgets('lays out on a small phone, camera on and off, without '
        'overflowing', (tester) async {
      TestWidgetsFlutterBinding
          .instance
          .platformDispatcher
          .views
          .first
          .physicalSize = const Size(
        320,
        640,
      );
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final (controller, _, _) = await setUpCheckIn(_kept);
      final profile = await profileOf(_kept);

      for (final on in [false, true]) {
        await tester.pumpWidget(
          _app(
            CheckInPage(
              controller: controller,
              profile: profile,
              settings: await settingsWith(camera: on),
              cameraBuilder: (context, onCode) => const SizedBox(),
              onSetUp: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'camera $on');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('the button shows the finger it will ask for, and a closed '
        'prompt sends nothing', (tester) async {
      final lock = _PhoneLock()..script.add(DeviceUnlock.cancelled);
      final (controller, server, _) = await setUpCheckIn(_kept, lock: lock);
      final profile = await profileOf(_kept);

      await tester.pumpWidget(
        _app(
          CheckInPage(
            controller: controller,
            profile: profile,
            settings: await settingsWith(),
            cameraBuilder: (context, onCode) => const SizedBox(),
            onSetUp: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('checkIn.code')),
        'K7P2QX',
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('checkIn.confirm')),
          matching: find.byIcon(Icons.fingerprint_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.text(CheckInStrings.sendsConfirmed('000-1023')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('checkIn.confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.textContaining(CheckInStrings.lockNotConfirmed),
        findsOneWidget,
      );
      expect(server.devicesSent, isEmpty);
      expect(find.byKey(const ValueKey('checkIn.class')), findsOneWidget);
      await tester.pumpAndSettle();
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

    testWidgets('Check in plays its own splash the first time it opens', (
      tester,
    ) async {
      await tester.pumpWidget(appWith(_kept));
      await tester.pumpAndSettle();
      await openMenu(tester);
      await tester.tap(find.byKey(const ValueKey('menu.checkIn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.byType(CheckInSplash), findsOneWidget);
      expect(find.text(CheckInStrings.splashTagline), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(CheckInSplash), findsNothing);
      expect(find.byKey(const ValueKey('checkIn')), findsOneWidget);

      // Only the first time: the tab is kept after that.
      await openMenu(tester);
      await tester.tap(find.byKey(const ValueKey('menu.home')));
      await tester.pumpAndSettle();
      await openMenu(tester);
      await tester.tap(find.byKey(const ValueKey('menu.checkIn')));
      await tester.pump();
      expect(find.byType(CheckInSplash), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('puts each part under the name of its group', (tester) async {
      await tester.pumpWidget(appWith(_kept));
      await tester.pumpAndSettle();
      await openMenu(tester);

      for (final (name, label, items) in [
        ('inClass', MenuStrings.inClass, ['showQr', 'checkIn']),
        ('records', MenuStrings.myRecords, ['qr', 'tracker', 'profile']),
        (
          'general',
          MenuStrings.general,
          ['home', 'whatsNew', 'settings', 'tour'],
        ),
      ]) {
        final group = find.byKey(ValueKey('menu.group.$name'));
        expect(
          find.descendant(of: group, matching: find.text(label)),
          findsOneWidget,
          reason: name,
        );
        for (final item in items) {
          expect(
            find.descendant(
              of: group,
              matching: find.byKey(ValueKey('menu.$item')),
            ),
            findsOneWidget,
            reason: '$name: $item',
          );
        }
      }

      // Whose phone this is, under its own name at the foot.
      final account = find.descendant(
        of: find.byType(StudentMenu),
        matching: find.text(MenuStrings.account),
      );
      expect(account, findsOneWidget);
      expect(
        tester.getRect(find.byKey(const ValueKey('menu.notYou'))).top,
        greaterThan(tester.getRect(account).bottom),
      );
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
