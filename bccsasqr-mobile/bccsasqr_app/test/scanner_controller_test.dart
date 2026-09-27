import 'package:bccsasqr_app/controllers/scanner_controller.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/models/scanner_models.dart';
import 'package:bccsasqr_app/services/scan_feedback.dart';
import 'package:bccsasqr_app/services/scanner_repository.dart';
import 'package:bccsasqr_app/services/speech_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = ScannerUser(
  id: 4,
  name: 'Francis L. Crisostomo',
  email: 'francis@example.test',
  role: 'instructor',
);

const _elec2 = ScanSubject(code: 'ELEC2', name: 'Multimedia Technologies');

ScanRecord _record({
  String number = '025-802',
  String name = 'GARCIA, MICAELLA JANE V.',
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
}

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

  ScannerController build({Duration resultHold = const Duration(seconds: 5)}) {
    final c = ScannerController(
      repository: repo,
      speech: speech,
      feedback: feedback,
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
      await controller.onCodeScanned('025-802');
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
      await controller.onCodeScanned('025-802');

      expect(repo.scanned, ['025-802']);
      expect(controller.lastRecord?.name, 'GARCIA, MICAELLA JANE V.');
      expect(controller.attendance.first.studentNumber, '025-802');
      expect(controller.status.tone, ScanTone.success);
      expect(
        controller.status.text,
        '✓ GARCIA, MICAELLA JANE V. - Multimedia Technologies',
      );
      // Said as a name, not spelled out as capitals.
      expect(speech.said.last, 'Micaella Jane Garcia, recorded.');
      expect(feedback.played.last, ScanTone.success);
    });

    test('a late scan says so', () async {
      await ready();
      repo.scanAnswer = _record(late: true);
      await controller.onCodeScanned('025-802');

      expect(controller.status.tone, ScanTone.warning);
      expect(controller.status.text, endsWith('— LATE'));
      expect(speech.said.last, 'Micaella Jane Garcia, recorded late.');
    });

    test('a scan with no photo on file warns in amber', () async {
      await ready();
      repo.scanAnswer = _record(photoMissing: true);
      await controller.onCodeScanned('025-802');

      expect(controller.status.tone, ScanTone.warning);
      expect(controller.status.text, contains('identity not verified'));
    });

    test('a QR held in view is recorded once', () async {
      await ready();
      await controller.onCodeScanned('025-802');
      now = now.add(const Duration(milliseconds: 700));
      await controller.onCodeScanned('025-802');
      now = now.add(const Duration(milliseconds: 700));
      await controller.onCodeScanned('025-802');

      expect(repo.scanned, hasLength(1));
    });

    test('a QR kept in view is checked again, and answered "already '
        'marked" — not met with silence', () async {
      await ready();
      await controller.onCodeScanned('025-802');
      repo.scanAnswer = const ScannerException(
        'Already marked today.',
        code: 'already_marked',
      );
      // The camera reads a code in view about every 0.7 s.
      for (var i = 0; i < 4; i++) {
        now = now.add(const Duration(milliseconds: 700));
        await controller.onCodeScanned('025-802');
      }

      expect(repo.scanned, hasLength(2));
      expect(controller.status.text, '⚠ Already marked: 025-802');
      expect(speech.said.last, ScannerStrings.sayAlreadyMarked);
    });

    test('the same QR shown again later is checked again', () async {
      await ready();
      await controller.onCodeScanned('025-802');
      now = now.add(const Duration(seconds: 4));
      repo.scanAnswer = const ScannerException(
        'Already marked today.',
        code: 'already_marked',
      );
      await controller.onCodeScanned('025-802');

      expect(repo.scanned, hasLength(2));
      expect(controller.status.text, '⚠ Already marked: 025-802');
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
        'Carlos is not enrolled in Multimedia Technologies',
        code: 'not_enrolled',
      );
      await controller.onCodeScanned('024-1962');
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
        'ABALOS has no photo on file.',
        code: 'photo_required',
        name: 'ABALOS, JAYVEE V.',
      );
      await controller.onCodeScanned('025-1211');
      await _delivered();

      expect(alerts.single.title, ScannerStrings.photoRequiredTitle);
      expect(alerts.single.body, startsWith('ABALOS, JAYVEE V. has no photo'));
    });

    test('a dead sign-in goes back to the sign-in screen', () async {
      await ready();
      repo.scanAnswer = const ScannerException(
        'Your sign-in has expired.',
        code: 'unauthenticated',
      );
      await controller.onCodeScanned('025-802');

      expect(controller.session, ScannerSession.signedOut);
      expect(controller.sessionMessage, ScannerStrings.sessionExpired);
    });

    test('no signal: says so without a dialog', () async {
      await ready();
      repo.scanAnswer = const ScannerException('offline', code: 'network');
      await controller.onCodeScanned('025-802');
      await _delivered();

      expect(controller.status.text, '✗ Network error');
      expect(alerts, isEmpty);
    });

    test('the result goes back to the idle line after a while', () async {
      controller.dispose();
      controller = build(resultHold: const Duration(milliseconds: 10));
      await ready();
      await controller.onCodeScanned('025-802');
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
      _record(number: '025-294', name: 'CENTENO, EDRIAN GABRIEL D.'),
    ];
    await controller.start();

    controller.setSearch('centeno');
    expect(controller.visibleAttendance.single.studentNumber, '025-294');

    controller.setSearch('');
    expect(controller.visibleAttendance, hasLength(2));
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
