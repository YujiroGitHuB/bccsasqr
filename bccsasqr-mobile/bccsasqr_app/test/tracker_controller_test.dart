import 'dart:async';

import 'package:bccsasqr_app/controllers/tracker_controller.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/core/utils/student_number.dart';
import 'package:bccsasqr_app/models/attendance_history.dart';
import 'package:bccsasqr_app/services/speech_service.dart';
import 'package:bccsasqr_app/services/student_repository.dart';
import 'package:bccsasqr_app/services/tracker_repository.dart';
import 'package:flutter_test/flutter_test.dart';

final _history = AttendanceHistory(
  studentNumber: '000-1023',
  fullName: 'Maria Isabel Santos',
  course: 'BSCS',
  section: '2-B',
  total: 2,
  lastAttended: DateTime(2026, 9, 27),
  subjects: [
    SubjectAttendance(
      subject: 'Object Oriented Programming',
      instructor: 'Charles Nixon Cayading',
      count: 2,
      days: [
        AttendanceDay(
          date: DateTime(2026, 9, 27),
          rawDate: '2026-09-27',
          timeIn: '08:04:12 AM',
        ),
        AttendanceDay(
          date: DateTime(2026, 9, 20),
          rawDate: '2026-09-20',
          timeIn: '08:17:55 AM',
          late: true,
        ),
      ],
    ),
  ],
);

const _neverScanned = AttendanceHistory(
  studentNumber: '023-770',
  fullName: 'Angelica Mae Reyes',
  course: 'BSED',
  section: '1-A',
  total: 0,
);

class _FakeTracker implements TrackerRepository {
  _FakeTracker([Map<String, AttendanceHistory>? records])
    : records = records ?? {'000-1023': _history, '023-770': _neverScanned};

  final Map<String, AttendanceHistory> records;
  bool offline = false;
  int calls = 0;

  /// When set, the next reply waits for it — to test a reply that arrives
  /// after the student has already typed something else.
  Completer<void>? gate;

  @override
  Future<AttendanceHistory?> fetchAttendance(StudentNumber number) async {
    calls++;
    final wait = gate;
    if (wait != null) await wait.future;
    if (offline) {
      throw const StudentLookupException('offline', code: 'network');
    }
    return records[number.value];
  }
}

/// Writes down what would have been said; `null` stands for a stop.
class _RecordingSpeech implements SpeechService {
  final said = <String?>[];

  @override
  Future<void> speak(String text) async => said.add(text);

  @override
  Future<void> stop() async => said.add(null);
}

TrackerController build(
  TrackerRepository repo, {
  SpeechService speech = const SilentSpeechService(),
}) => TrackerController(
  repository: repo,
  speech: speech,
  debounce: Duration.zero,
);

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('starts idle, with the placeholder showing', () {
    final c = build(_FakeTracker());
    expect(c.status, TrackerStatus.idle);
    expect(c.showPlaceholder, isTrue);
    expect(c.statusMessage, isNull);
  });

  test('a complete number searches on its own', () async {
    final repo = _FakeTracker();
    final c = build(repo);

    c.onStudentNumberChanged('000-1023');
    expect(c.isSearching, isTrue);
    await settle();
    await settle();

    expect(repo.calls, 1);
    expect(c.isFound, isTrue);
    expect(c.history!.total, 2);
    expect(c.statusMessage, TrackerStrings.loaded);
  });

  test('half a number does not search and is not an error', () async {
    final repo = _FakeTracker();
    final c = build(repo);

    c.onStudentNumberChanged('025-1');
    await settle();

    expect(repo.calls, 0);
    expect(c.status, TrackerStatus.idle);
    expect(c.errorMessage, isNull);
  });

  test('an unknown number is "not found", not a failure', () async {
    final c = build(_FakeTracker());

    c.onStudentNumberChanged('019-999');
    await settle();
    await settle();

    expect(c.isNotFound, isTrue);
    expect(c.canRetry, isFalse);
    expect(c.statusMessage, TrackerStrings.notFound);
  });

  test('a record with no scans says so rather than "loaded"', () async {
    final c = build(_FakeTracker());

    c.onStudentNumberChanged('023-770');
    await settle();
    await settle();

    expect(c.isFound, isTrue);
    expect(c.history!.isEmpty, isTrue);
    expect(c.statusMessage, TrackerStrings.noAttendance);
  });

  test('no signal offers a retry, which recovers', () async {
    final repo = _FakeTracker()..offline = true;
    final c = build(repo);

    c.onStudentNumberChanged('000-1023');
    await settle();
    await settle();
    expect(c.status, TrackerStatus.failed);
    expect(c.canRetry, isTrue);
    expect(c.statusMessage, 'offline');

    repo.offline = false;
    await c.searchNow();
    expect(c.isFound, isTrue);
    expect(c.canRetry, isFalse);
  });

  test('a reply for a number already typed over is dropped', () async {
    final repo = _FakeTracker()..gate = Completer<void>();
    final c = build(repo);

    c.onStudentNumberChanged('000-1023');
    await settle();
    // The student clears the field while the first search is in flight.
    c.onStudentNumberChanged('');
    repo.gate!.complete();
    await settle();
    await settle();

    expect(c.history, isNull);
    expect(c.status, TrackerStatus.idle);
  });

  test('says what the web says, in the same order', () async {
    final speech = _RecordingSpeech();
    final c = build(_FakeTracker(), speech: speech);

    c.onStudentNumberChanged('000-1023');
    await settle();
    await settle();

    expect(speech.said, [TrackerStrings.searching, TrackerStrings.loaded]);
  });

  test('pull-to-refresh on an empty field does nothing', () async {
    final repo = _FakeTracker();
    final c = build(repo);

    await c.refresh();

    expect(repo.calls, 0);
  });
}
