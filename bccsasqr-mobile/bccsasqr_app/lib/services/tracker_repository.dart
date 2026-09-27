import '../core/utils/student_number.dart';
import '../models/attendance_history.dart';
import 'student_repository.dart';

/// The Attendance Tracker's contract: one student number in, their history
/// out.
///
/// A number with no student behind it returns `null` — an answer, not a
/// failure. Everything else (no signal, the tracker locked in Settings)
/// raises a [StudentLookupException] carrying the server's `code`.
abstract interface class TrackerRepository {
  Future<AttendanceHistory?> fetchAttendance(StudentNumber number);
}

/// What runs when no `API_BASE_URL` was supplied at build time: the same four
/// students as [InMemoryStudentRepository], with a few days each, so the
/// whole screen can be tried without a server — including a student with no
/// scans yet.
class InMemoryTrackerRepository implements TrackerRepository {
  InMemoryTrackerRepository({this.latency = const Duration(milliseconds: 650)});

  final Duration latency;

  static AttendanceDay _day(String date, String time, {bool late = false}) =>
      AttendanceDay(
        date: DateTime.parse(date),
        rawDate: date,
        timeIn: time,
        late: late,
      );

  static final Map<String, AttendanceHistory> _seed = {
    '019-464': AttendanceHistory(
      studentNumber: '019-464',
      fullName: 'Charles Nixon Cayading',
      course: 'BS Information Technology',
      section: 'BSIT 4-A',
      total: 5,
      lastAttended: DateTime(2026, 9, 25),
      subjects: [
        SubjectAttendance(
          subject: 'Capstone Project 2',
          instructor: 'Paolo R. Mendoza',
          count: 3,
          days: [
            _day('2026-09-25', '08:02:41 AM'),
            _day('2026-09-18', '08:21:09 AM', late: true),
            _day('2026-09-11', '07:58:30 AM'),
          ],
        ),
        SubjectAttendance(
          subject: 'Information Assurance and Security',
          instructor: 'Maria Luisa Ramos',
          count: 2,
          days: [
            _day('2026-09-23', '01:05:12 PM'),
            _day('2026-09-16', '01:01:47 PM'),
          ],
        ),
      ],
    ),
    '000-1023': AttendanceHistory(
      studentNumber: '000-1023',
      fullName: 'Maria Isabel Santos',
      course: 'BS Computer Science',
      section: 'BSCS 2-B',
      total: 3,
      lastAttended: DateTime(2026, 9, 27),
      subjects: [
        SubjectAttendance(
          subject: 'Object Oriented Programming',
          instructor: 'Charles Nixon Cayading',
          count: 3,
          days: [
            _day('2026-09-27', '08:04:12 AM'),
            _day('2026-09-20', '08:17:55 AM', late: true),
            _day('2026-09-13', '08:00:03 AM'),
          ],
        ),
      ],
    ),
    '021-318': AttendanceHistory(
      studentNumber: '021-318',
      fullName: 'Jose Rafael Dela Cruz',
      course: 'BS Business Administration',
      section: 'BSBA 3-C',
      total: 1,
      lastAttended: DateTime(2026, 9, 22),
      subjects: [
        SubjectAttendance(
          subject: 'Business Law',
          instructor: 'Ana Villanueva',
          count: 1,
          days: [_day('2026-09-22', '10:30:26 AM')],
        ),
      ],
    ),
    // Enrolled, never scanned — the "No attendance yet" state.
    '023-770': const AttendanceHistory(
      studentNumber: '023-770',
      fullName: 'Angelica Mae Reyes',
      course: 'BS Education',
      section: 'BSED 1-A',
      total: 0,
    ),
  };

  @override
  Future<AttendanceHistory?> fetchAttendance(StudentNumber number) async {
    await Future<void>.delayed(latency);
    return _seed[number.value];
  }
}
