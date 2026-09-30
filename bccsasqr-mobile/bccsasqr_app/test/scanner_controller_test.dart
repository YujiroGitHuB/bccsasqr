import 'package:bccsasqr_app/controllers/scanner_controller.dart';
import 'dart:async';

import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/models/offline_scan.dart';
import 'package:bccsasqr_app/models/scanner_models.dart';
import 'package:bccsasqr_app/services/offline_scan_store.dart';
import 'package:bccsasqr_app/services/scan_feedback.dart';
import 'package:bccsasqr_app/services/scanner_repository.dart';
import 'package:bccsasqr_app/services/speech_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = ScannerUser(
  id: 4,
  name: 'Paolo R. Mendoza',
  email: 'francis@example.test',
  role: 'instructor',
);

const _elec2 = ScanSubject(code: 'ELEC2', name: 'Multimedia Technologies');

ScanRecord _record({
  String number = '000-802',
  String name = 'VILLAR, CARMINA JOY P.',
  bool late = false,
  bool photoMissing = false,
}) => ScanRecord(
  studentNumber: number,
  name: name,
  course: 'BSIT',
  section: '2G',
  subject: _elec2.name,
  date: '2026-09-27',
  timeIn: '07:25:54 AM',
  late: late,
  photoUrl: photoMissing ? null : 'https://example.test/photo.jpg',
  photoMissing: photoMissing,
);

/// Answers from fields the test sets, with no latency.
class _FakeRepository implements ScannerRepository {
  ScannerUser? saved;
  Object? restoreThrows;
  Object? signInThrows;
  Object? subjectsThrow;
  Object? lateThrows;
  List<ScanSubject> subjects = const [_elec2];
  List<AttendanceEntry> today = const [];

  /// What the next scan answers: a [ScanRecord] or a [ScannerException].
  Object scanAnswer = _record();
  final List<String> scanned = [];
  bool signedOut = false;

  @override
  Future<ScannerUser?> restoreSession() async {
    if (restoreThrows != null) throw restoreThrows!;
    return saved;
  }

  @override
  Future<ScannerUser> signIn({
    required String email,
    required String password,
  }) async {
    if (signInThrows != null) throw signInThrows!;
    return saved = _user;
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
    saved = null;
  }

  @override
  Future<SubjectList> loadSubjects() async {
    if (subjectsThrow != null) throw subjectsThrow!;
    return (user: _user, subjects: subjects, date: '2026-09-27');
  }

  @override
  Future<ScanRecord> recordScan({
    required String studentNumber,
    required String subjectCode,
  }) async {
    scanned.add(studentNumber);
    final answer = scanAnswer;
    if (answer is ScanRecord) return answer;
    throw answer;
  }

  @override
  Future<List<AttendanceEntry>> loadToday() async => today;

  @override
  Future<bool> setLateMarking({
    required String subjectCode,
    required bool on,
  }) async {
    if (lateThrows != null) throw lateThrows!;
    return on;
  }

  /// The class lists the server has, by subject code. A subject left out
  /// answers with an error, so a test has none unless it sets one.
  Map<String, SubjectRoster> rosters = {};
  int rosterLoads = 0;

  @override
  Future<SubjectRoster> loadRoster(String subjectCode) async {
    rosterLoads++;
    final roster = rosters[subjectCode];
    if (roster == null) {
      throw const ScannerException('No such subject.', code: 'not_found');
    }
    return roster;
  }

  /// Every batch sent, and what each scan in the next one answers.
  final List<List<PendingScan>> synced = [];
  Object? syncThrows;
  SyncOutcome Function(PendingScan scan) syncAnswer = (scan) =>
      SyncOutcome(id: scan.id, status: SyncStatus.saved);

  @override
  Future<List<SyncOutcome>> syncScans(List<PendingScan> scans) async {
    synced.add(scans);
    if (syncThrows != null) throw syncThrows!;
    return [for (final s in scans) syncAnswer(s)];
  }
}

const _network = ScannerException('No internet connection.', code: 'network');

/// ELEC2's class list, as downloaded: one student with a photo, one without.
final _roster = SubjectRoster(
  subjectCode: 'ELEC2',
  date: '2026-09-27',
  students: {
    '000-802': const RosterStudent(
      studentNumber: '000-802',
      name: 'VILLAR, CARMINA JOY P.',
      course: 'BSIT',
      section: '2G',
    ),
    '000-803': const RosterStudent(
      studentNumber: '000-803',
      name: 'SORIANO, DANTE L.',
      course: 'BSIT',
      section: '2G',
      hasPhoto: false,
    ),
  },
);

class _RecordingSpeech implements SpeechService {
  final List<String> said = [];

  @override
  Future<void> speak(String text) async => said.add(text);

  @override
  Future<void> stop() async {}
}

class _RecordingFeedback implements ScanFeedback {
  final List<ScanTone> played = [];

  @override
  Future<void> play(ScanTone tone) async => played.add(tone);
}

/// Lets the alert stream deliver: broadcast events arrive after the call that
/// added them has returned.
Future<void> _delivered() => Future<void>.delayed(Duration.zero);

void main() {
  late _FakeRepository repo;
  late _RecordingSpeech speech;
  late _RecordingFeedback feedback;
  late DateTime now;
  late ScannerController controller;
  late List<ScanAlert> alerts;
  late MemoryOfflineScanStore store;

  ScannerController build({
    Duration resultHold = const Duration(seconds: 5),
    Stream<bool>? online,
  }) {
    final c = ScannerController(
      repository: repo,
      speech: speech,
      feedback: feedback,
      store: store,
      online: online,
      resultHold: resultHold,
      clock: () => now,
    );
    c.alerts.listen(alerts.add);
    return c;
  }

  /// Signed in, subject picked, camera running.
  Future<void> ready() async {
    repo.saved = _user;
    await controller.start();
    controller.selectSubject(_elec2);
  }

  setUp(() {
    repo = _FakeRepository();
    speech = _RecordingSpeech();
    feedback = _RecordingFeedback();
    now = DateTime(2026, 9, 27, 7, 30);
    alerts = [];
    store = MemoryOfflineScanStore();
    controller = build();
  });

  tearDown(() => controller.dispose());

  group('session', () {
    test('no sign-in on this phone opens the sign-in screen', () async {
      await controller.start();
      expect(controller.session, ScannerSession.signedOut);
      expect(controller.sessionMessage, isNull);
    });

    test('a saved sign-in goes straight to the scanner', () async {
      repo.saved = _user;
      repo.today = [_record()];
      await controller.start();

      expect(controller.session, ScannerSession.signedIn);
      expect(controller.user?.name, _user.name);
      expect(controller.subjects, [_elec2]);
      expect(controller.attendance, hasLength(1));
    });

    test('no signal keeps the saved sign-in and offers a retry', () async {
      repo.restoreThrows = const ScannerException('offline', code: 'network');
      await controller.start();

      expect(controller.session, ScannerSession.unreachable);
      expect(controller.sessionMessage, 'offline');
      expect(repo.signedOut, isFalse);
    });

    test('empty fields never reach the server', () async {
      await controller.start();
      await controller.signIn(email: ' ', password: '');
      expect(controller.signInError, ScannerStrings.errorCredentialsEmpty);
      expect(controller.session, ScannerSession.signedOut);
    });

    test("a refused sign-in shows the server's message", () async {
      repo.signInThrows = const ScannerException(
        'Incorrect email or password.',
        code: 'invalid_credentials',
      );
      await controller.start();
      await controller.signIn(email: 'a@b.c', password: 'x');

      expect(controller.signInError, 'Incorrect email or password.');
      expect(controller.isSigningIn, isFalse);
    });

    test('signing in loads the subjects', () async {
      await controller.start();
      await controller.signIn(email: 'a@b.c', password: 'secret');

      expect(controller.session, ScannerSession.signedIn);
      expect(controller.subjects, [_elec2]);
      expect(controller.today, '2026-09-27');
    });

    test('signing out forgets everything', () async {
      await ready();
      await controller.onCodeScanned('000-802');
      await controller.signOut();

      expect(repo.signedOut, isTrue);
      expect(controller.session, ScannerSession.signedOut);
      expect(controller.attendance, isEmpty);
      expect(controller.selectedSubject, isNull);
    });
  });

  group('subjects', () {
    test('the camera waits for a subject', () async {
      repo.saved = _user;
      await controller.start();
      expect(controller.cameraActive, isFalse);
      expect(controller.status.text, 'Select subject first - 2026-09-27');

      controller.selectSubject(_elec2);
      expect(controller.cameraActive, isTrue);
      expect(
        controller.status.text,
        'Scanning for Multimedia Technologies - 2026-09-27',
      );
    });

    test('the camera can be switched off and on without losing the '
        'subject', () async {
      await ready();
      expect(controller.cameraActive, isTrue);
      expect(controller.cameraPaused, isFalse);

      controller.setCameraOn(false);
      expect(controller.cameraActive, isFalse);
      expect(controller.cameraPaused, isTrue);
      expect(controller.selectedSubject, _elec2);
      expect(controller.status.text, ScannerStrings.cameraOffStatus);

      controller.setCameraOn(true);
      expect(controller.cameraActive, isTrue);
      expect(
        controller.status.text,
        'Scanning for Multimedia Technologies - 2026-09-27',
      );
    });

    test('picking a subject turns a switched-off camera back on', () async {
      await ready();
      controller.setCameraOn(false);

      controller.selectSubject(null);
      expect(controller.cameraPaused, isFalse);
      controller.selectSubject(_elec2);
      expect(controller.cameraActive, isTrue);
    });

    test('no subject: nothing to switch off', () async {
      repo.saved = _user;
      await controller.start();
      controller.setCameraOn(false);

      expect(controller.cameraActive, isFalse);
      expect(controller.cameraPaused, isFalse);
      expect(controller.status.text, 'Select subject first - 2026-09-27');
    });

    test('a locked scanner says why and keeps the camera off', () async {
      repo.saved = _user;
      repo.subjectsThrow = const ScannerException(
        'The QR scanner has been closed by the administrator.',
        code: 'scanner_locked',
      );
      await controller.start();

      expect(controller.blockedMessage, contains('closed'));
      controller.selectSubject(_elec2);
      expect(controller.cameraActive, isFalse);
    });

    test('late marking flips at once', () async {
      await ready();
      await controller.toggleLate();

      expect(controller.selectedSubject!.lateMarking, isTrue);
      expect(controller.subjects.single.lateMarking, isTrue);
    });

    test('late marking goes back if the server refuses', () async {
      await ready();
      repo.lateThrows = const ScannerException(
        'That subject is not assigned to you.',
        code: 'late_not_changed',
      );
      await controller.toggleLate();
      await _delivered();

      expect(controller.selectedSubject!.lateMarking, isFalse);
      expect(alerts.single.title, ScannerStrings.lateNotChanged);
    });
  });

  group('scanning', () {
    test('a recorded scan shows, lists and says the name', () async {
      await ready();
      await controller.onCodeScanned('000-802');

      expect(repo.scanned, ['000-802']);
      expect(controller.lastRecord?.name, 'VILLAR, CARMINA JOY P.');
      expect(controller.attendance.first.studentNumber, '000-802');
      expect(controller.status.tone, ScanTone.success);
      expect(
        controller.status.text,
        '✓ VILLAR, CARMINA JOY P. - Multimedia Technologies',
      );
      // Said as a name, not spelled out as capitals.
      expect(speech.said.last, 'Carmina Joy Villar, recorded.');
      expect(feedback.played.last, ScanTone.success);
    });

    test('a late scan says so', () async {
      await ready();
      repo.scanAnswer = _record(late: true);
      await controller.onCodeScanned('000-802');

      expect(controller.status.tone, ScanTone.warning);
      expect(controller.status.text, endsWith('— LATE'));
      expect(speech.said.last, 'Carmina Joy Villar, recorded late.');
    });

    test('a scan with no photo on file warns in amber', () async {
      await ready();
      repo.scanAnswer = _record(photoMissing: true);
      await controller.onCodeScanned('000-802');

      expect(controller.status.tone, ScanTone.warning);
      expect(controller.status.text, contains('identity not verified'));
    });

    test('a QR held in view is recorded once', () async {
      await ready();
      await controller.onCodeScanned('000-802');
      now = now.add(const Duration(milliseconds: 700));
      await controller.onCodeScanned('000-802');
      now = now.add(const Duration(milliseconds: 700));
      await controller.onCodeScanned('000-802');

      expect(repo.scanned, hasLength(1));
    });

    test('a QR kept in view is checked again, and answered "already '
        'marked" — not met with silence', () async {
      await ready();
      await controller.onCodeScanned('000-802');
      repo.scanAnswer = const ScannerException(
        'Already marked today.',
        code: 'already_marked',
      );
      // The camera reads a code in view about every 0.7 s.
      for (var i = 0; i < 4; i++) {
        now = now.add(const Duration(milliseconds: 700));
        await controller.onCodeScanned('000-802');
      }

      expect(repo.scanned, hasLength(2));
      expect(controller.status.text, '⚠ Already marked: 000-802');
      expect(speech.said.last, ScannerStrings.sayAlreadyMarked);
    });

    test('the same QR shown again later is checked again', () async {
      await ready();
      await controller.onCodeScanned('000-802');
      now = now.add(const Duration(seconds: 4));
      repo.scanAnswer = const ScannerException(
        'Already marked today.',
        code: 'already_marked',
      );
      await controller.onCodeScanned('000-802');

      expect(repo.scanned, hasLength(2));
      expect(controller.status.text, '⚠ Already marked: 000-802');
      expect(speech.said.last, ScannerStrings.sayAlreadyMarked);
      expect(feedback.played.last, ScanTone.warning);
    });

    test('a code in the wrong format never reaches the server', () async {
      await ready();
      await controller.onCodeScanned('https://example.com');
      await _delivered();

      expect(repo.scanned, isEmpty);
      expect(controller.status.text, 'Invalid QR format!');
      expect(alerts.single.title, ScannerStrings.invalidQrTitle);
      expect(alerts.single.autoDismiss, isNotNull);
      expect(speech.said.last, ScannerStrings.sayInvalid);
    });

    test('the invalid-QR dialog is not repeated within the cooldown', () async {
      await ready();
      await controller.onCodeScanned('not a student');
      now = now.add(const Duration(seconds: 1));
      await controller.onCodeScanned('also not one');
      await _delivered();

      expect(alerts, hasLength(1));
    });

    test('not enrolled: says so and names the subject', () async {
      await ready();
      repo.scanAnswer = const ScannerException(
        'Lorenzo is not enrolled in Multimedia Technologies',
        code: 'not_enrolled',
      );
      await controller.onCodeScanned('000-1962');
      await _delivered();

      expect(
        controller.status.text,
        '✗ Student not enrolled in Multimedia Technologies',
      );
      expect(alerts.single.title, ScannerStrings.notEnrolledTitle);
      expect(
        speech.said.last,
        'Student is not enrolled in Multimedia Technologies.',
      );
      expect(controller.attendance, isEmpty);
    });

    test('photo required: the dialog names the student', () async {
      await ready();
      repo.scanAnswer = const ScannerException(
        'NAVARRO has no photo on file.',
        code: 'photo_required',
        name: 'NAVARRO, TRISHA MAE V.',
      );
      await controller.onCodeScanned('000-1211');
      await _delivered();

      expect(alerts.single.title, ScannerStrings.photoRequiredTitle);
      expect(
        alerts.single.body,
        startsWith('NAVARRO, TRISHA MAE V. has no photo'),
      );
    });

    test('a dead sign-in goes back to the sign-in screen', () async {
      await ready();
      repo.scanAnswer = const ScannerException(
        'Your sign-in has expired.',
        code: 'unauthenticated',
      );
      await controller.onCodeScanned('000-802');

      expect(controller.session, ScannerSession.signedOut);
      expect(controller.sessionMessage, ScannerStrings.sessionExpired);
    });

    test('the result goes back to the idle line after a while', () async {
      controller.dispose();
      controller = build(resultHold: const Duration(milliseconds: 10));
      await ready();
      await controller.onCodeScanned('000-802');
      expect(controller.lastRecord, isNotNull);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(controller.lastRecord, isNull);
      expect(controller.status.tone, isNull);
    });
  });

  test('the search box filters the list', () async {
    repo.saved = _user;
    repo.today = [
      _record(),
      _record(number: '000-294', name: 'BAUTISTA, LORENZO MIGUEL D.'),
    ];
    await controller.start();

    controller.setSearch('bautista');
    expect(controller.visibleAttendance.single.studentNumber, '000-294');

    controller.setSearch('');
    expect(controller.visibleAttendance, hasLength(2));
  });

  test('the full list follows the subject being scanned', () async {
    const other = ScanSubject(code: 'IT101', name: 'Intro to Computing');
    repo.saved = _user;
    repo.subjects = const [_elec2, other];
    repo.today = [
      _record(),
      _record(number: '000-294', name: 'BAUTISTA, LORENZO MIGUEL D.'),
      AttendanceEntry(
        studentNumber: '000-900',
        name: 'DIZON, RAFA',
        course: 'BSIT',
        section: '1A',
        subject: other.name,
        date: '2026-09-27',
        timeIn: '07:10:00 AM',
      ),
    ];
    await controller.start();

    controller.selectSubject(other);
    expect(controller.attendanceSubject, other.name);
    expect(controller.visibleAttendance.single.studentNumber, '000-900');

    controller.setAttendanceSubject(null);
    expect(controller.visibleAttendance, hasLength(3));
  });

  group('offline', () {
    /// Signed in with ELEC2 picked — and, unless [roster] is false, its class
    /// list downloaded — then the internet goes.
    Future<void> offline({bool roster = true}) async {
      if (roster) repo.rosters = {'ELEC2': _roster};
      await ready();
      await _delivered();
      repo.scanAnswer = _network;
      repo.syncThrows = _network;
    }

    test('picking a subject downloads its class list', () async {
      repo.rosters = {'ELEC2': _roster};
      await ready();
      await _delivered();
      expect(repo.rosterLoads, 1);

      // Once a day is enough.
      controller.selectSubject(null);
      controller.selectSubject(_elec2);
      await _delivered();
      expect(repo.rosterLoads, 1);
    });

    test('no signal: the scan is kept on the phone, named from the class '
        'list, and listed as pending', () async {
      await offline();
      await controller.onCodeScanned('000-802');

      expect(controller.isOffline, isTrue);
      expect(controller.pendingCount, 1);
      expect(controller.status.tone, ScanTone.success);
      expect(
        controller.status.text,
        '✓ VILLAR, CARMINA JOY P. — ${ScannerStrings.savedOffline}',
      );
      expect(speech.said.last, 'Carmina Joy Villar, saved offline.');
      expect(controller.lastRecord?.pending, isTrue);

      final row = controller.attendance.first;
      expect(row.studentNumber, '000-802');
      expect(row.pending, isTrue);
      expect(row.timeIn, '07:30:00 AM');
      expect(store.kept, hasLength(1));
    });

    test('once offline, scans go straight to the phone — no waiting on the '
        'server for each', () async {
      await offline();
      await controller.onCodeScanned('000-802');
      now = now.add(const Duration(seconds: 5));
      await controller.onCodeScanned('000-803');

      expect(repo.scanned, ['000-802']);
      expect(controller.pendingCount, 2);
    });

    test('a student not on the class list is refused, as online', () async {
      await offline();
      await controller.onCodeScanned('000-999');
      await _delivered();

      expect(controller.pendingCount, 0);
      expect(
        controller.status.text,
        '✗ Student not enrolled in Multimedia Technologies',
      );
      expect(alerts.single.title, ScannerStrings.notEnrolledTitle);
    });

    test('with no class list, the scan is kept unchecked', () async {
      await offline(roster: false);
      await controller.onCodeScanned('000-999');

      expect(controller.pendingCount, 1);
      expect(controller.status.text, contains('000-999'));
      expect(speech.said.last, '000-999, saved offline.');
    });

    test('a student already kept is "already marked"', () async {
      await offline();
      await controller.onCodeScanned('000-802');
      now = now.add(const Duration(seconds: 4));
      await controller.onCodeScanned('000-802');

      expect(controller.pendingCount, 1);
      expect(controller.status.text, '⚠ Already marked: 000-802');
    });

    test('a student already on today\'s list is "already marked"', () async {
      repo.today = [_record()];
      await offline();
      await controller.onCodeScanned('000-802');

      expect(controller.pendingCount, 0);
      expect(controller.status.text, '⚠ Already marked: 000-802');
    });

    test(
      'no photo on file warns, or refuses when a photo is required',
      () async {
        await offline();
        await controller.onCodeScanned('000-803');
        expect(controller.status.tone, ScanTone.warning);
        expect(controller.status.text, contains('no photo'));

        await controller.signOut();
        repo.rosters = {
          'ELEC2': SubjectRoster(
            subjectCode: 'ELEC2',
            date: '2026-09-27',
            photoRequired: true,
            students: _roster.students,
          ),
        };
        repo.scanAnswer = _record();
        repo.syncThrows = null;
        await ready();
        await _delivered();
        repo.scanAnswer = _network;
        await controller.onCodeScanned('000-803');
        await _delivered();

        expect(alerts.last.title, ScannerStrings.photoRequiredTitle);
      },
    );

    test('a kept scan carries the late switch as it was', () async {
      repo.rosters = {'ELEC2': _roster};
      await ready();
      await controller.toggleLate();
      repo.scanAnswer = _network;
      repo.syncThrows = _network;
      await controller.onCodeScanned('000-802');

      expect(store.kept.values.single.late, isTrue);
      expect(controller.status.text, contains('LATE'));
    });

    test(
      'back online, the kept scans are sent and the list reloaded',
      () async {
        await offline();
        await controller.onCodeScanned('000-802');
        repo.syncThrows = null;
        repo.today = [_record()];

        expect(await controller.sync(), isTrue);
        await _delivered();

        expect(repo.synced.single.single.studentNumber, '000-802');
        expect(
          repo.synced.single.single.scannedAt,
          DateTime(2026, 9, 27, 7, 30),
        );
        expect(controller.pendingCount, 0);
        expect(controller.isOffline, isFalse);
        expect(store.kept, isEmpty);
        expect(controller.attendance.single.pending, isFalse);
        expect(alerts.last.title, ScannerStrings.syncedTitle(1));
        expect(alerts.last.tone, ScanTone.success);
      },
    );

    test('"already marked" from the server counts as sent', () async {
      await offline();
      await controller.onCodeScanned('000-802');
      repo.syncThrows = null;
      repo.syncAnswer = (s) =>
          SyncOutcome(id: s.id, status: SyncStatus.alreadyMarked);
      await controller.sync();

      expect(controller.pendingCount, 0);
      expect(controller.notSaved, isEmpty);
    });

    test(
      'a scan the server refuses is listed with why, until cleared',
      () async {
        await offline(roster: false);
        await controller.onCodeScanned('000-999');
        repo.syncThrows = null;
        repo.syncAnswer = (s) => SyncOutcome(
          id: s.id,
          status: SyncStatus.rejected,
          rejection: const ScanRejection(
            code: 'student_not_found',
            message: 'Student 000-999 not found in database',
          ),
        );
        await controller.sync();
        await _delivered();

        expect(controller.pendingCount, 0);
        expect(controller.notSaved.single.rejection?.code, 'student_not_found');
        expect(alerts.last.title, ScannerStrings.notSavedCountTitle(1));
        // Kept until seen, even across a restart.
        expect(store.kept.values.single.rejection, isNotNull);

        await controller.dismissNotSaved();
        expect(controller.notSaved, isEmpty);
        expect(store.kept, isEmpty);
      },
    );

    test('a scan the server failed on is kept for the next try', () async {
      await offline();
      await controller.onCodeScanned('000-802');
      repo.syncThrows = null;
      repo.syncAnswer = (s) => SyncOutcome(id: s.id, status: SyncStatus.error);
      await controller.sync();

      expect(controller.pendingCount, 1);
      expect(controller.notSaved, isEmpty);
      expect(repo.synced, hasLength(1));
    });

    test('still no signal: everything stays', () async {
      await offline();
      await controller.onCodeScanned('000-802');

      expect(await controller.sync(), isFalse);
      expect(controller.pendingCount, 1);
      expect(controller.isOffline, isTrue);
    });

    test('a live scan of a student kept offline is answered at once', () async {
      await offline();
      await controller.onCodeScanned('000-802');
      // The server is back, but the kept scan has not gone yet.
      repo.syncThrows = _network;
      controller.dispose();
      controller = build();
      repo.scanAnswer = _record();
      await ready();
      now = now.add(const Duration(seconds: 4));
      await controller.onCodeScanned('000-802');

      expect(repo.scanned, ['000-802']);
      expect(controller.status.text, '⚠ Already marked: 000-802');
    });

    test('a kept scan survives the app being closed', () async {
      await offline();
      await controller.onCodeScanned('000-802');
      controller.dispose();

      controller = build();
      repo.syncThrows = _network;
      repo.scanAnswer = _record();
      await controller.start();

      expect(controller.pendingCount, 1);
      expect(controller.attendance.first.pending, isTrue);
    });

    test('signing out keeps the kept scans for the next sign-in, and '
        'forgets the class lists', () async {
      await offline();
      await controller.onCodeScanned('000-802');
      await controller.signOut();

      expect(store.kept, hasLength(1));
      expect(store.rosters, isEmpty);
      expect(store.saved, isNull);

      repo.syncThrows = null;
      await controller.signIn(email: 'a@b.c', password: 'secret');
      expect(repo.synced, isNotEmpty);
      expect(controller.pendingCount, 0);
    });

    test('a saved sign-in opens with no signal, on what the phone last '
        'loaded', () async {
      repo.rosters = {'ELEC2': _roster};
      await ready();
      await _delivered();
      controller.dispose();

      repo.restoreThrows = _network;
      repo.syncThrows = _network;
      controller = build();
      await controller.start();

      expect(controller.session, ScannerSession.signedIn);
      expect(controller.isOffline, isTrue);
      expect(controller.subjects, [_elec2]);

      controller.selectSubject(_elec2);
      await controller.onCodeScanned('000-802');
      expect(controller.lastRecord?.name, 'VILLAR, CARMINA JOY P.');
      expect(controller.pendingCount, 1);
    });

    test('the phone getting its network back sends the kept scans', () async {
      final network = StreamController<bool>();
      addTearDown(network.close);
      controller.dispose();
      controller = build(online: network.stream);

      await offline();
      network.add(false);
      await _delivered();
      await controller.onCodeScanned('000-802');
      expect(controller.pendingCount, 1);

      repo.syncThrows = null;
      network.add(true);
      await _delivered();
      await _delivered();

      expect(controller.pendingCount, 0);
      expect(controller.isOffline, isFalse);
    });
  });

  group('nameForSpeech', () {
    test('turns "LAST, FIRST M." round and out of capitals', () {
      expect(nameForSpeech('DELA CRUZ, JUAN P.'), 'Juan Dela Cruz');
    });

    test('says a suffix as a word, after the surname', () {
      expect(nameForSpeech('SANTOS, JOSE JR.'), 'Jose Santos Junior');
    });

    test('keeps hyphenated parts capitalised', () {
      expect(nameForSpeech('REYES-SANTOS, ANA'), 'Ana Reyes-Santos');
    });
  });
}
