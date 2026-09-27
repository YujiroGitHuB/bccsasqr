import '../core/utils/student_number.dart';
import '../models/scanner_models.dart';

/// A scanner request that did not go through.
///
/// [code] is what the web scanner branches on — `already_marked`,
/// `not_enrolled`, `photo_required`, … — plus the transport's own `network`
/// and `bad_response`. Branch on it, never on [message].
class ScannerException implements Exception {
  const ScannerException(this.message, {this.code, this.name});

  /// Safe to show as it is.
  final String message;
  final String? code;

  /// The student's name, when the server knew it (`photo_required`).
  final String? name;

  /// The token is gone — expired, signed out elsewhere, or the password
  /// changed. The only way forward is the sign-in screen.
  bool get isSignedOut => code == 'unauthenticated';

  @override
  String toString() => 'ScannerException(${code ?? '-'}): $message';
}

/// The contract the scanner controller depends on.
abstract interface class ScannerRepository {
  /// The account behind a sign-in saved on this phone, or `null` when there
  /// is none (or it no longer works).
  Future<ScannerUser?> restoreSession();

  Future<ScannerUser> signIn({required String email, required String password});

  /// Forgets this phone's sign-in, on the server and here.
  Future<void> signOut();

  Future<SubjectList> loadSubjects();

  /// Records one scan. Throws a [ScannerException] for every refusal.
  Future<ScanRecord> recordScan({
    required String studentNumber,
    required String subjectCode,
  });

  /// Today's scans by the signed-in account, newest first.
  Future<List<AttendanceEntry>> loadToday();

  /// Switches late marking for one subject and returns the state the server
  /// settled on.
  Future<bool> setLateMarking({required String subjectCode, required bool on});
}

/// What runs when no `API_BASE_URL` was supplied at build time: any email and
/// password sign in, and scans are kept on this phone only. It answers the
/// same shapes and refusals as the server, so the whole screen can be tried
/// without one.
class InMemoryScannerRepository implements ScannerRepository {
  InMemoryScannerRepository({
    this.latency = const Duration(milliseconds: 350),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration latency;
  final DateTime Function() _clock;

  ScannerUser? _user;
  final List<ScanRecord> _records = [];
  final Set<String> _lateOn = {};

  static const List<ScanSubject> _subjects = [
    ScanSubject(code: 'CC121', name: 'Introduction to Computing'),
    ScanSubject(code: 'ITE211', name: 'Object Oriented Programming'),
  ];

  /// The generator's demo students, so a QR made in demo mode scans here.
  static const List<
    ({
      String number,
      String name,
      String course,
      String section,
      bool photo,
      Set<String> subjects,
    })
  >
  _students = [
    (
      number: '019-464',
      name: 'Charles Nixon Cayading',
      course: 'BSIT',
      section: '4-A',
      photo: true,
      subjects: {'CC121', 'ITE211'},
    ),
    (
      number: '025-1023',
      name: 'Maria Isabel Santos',
      course: 'BSCS',
      section: '2-B',
      photo: true,
      subjects: {'ITE211'},
    ),
    (
      number: '021-318',
      name: 'Jose Rafael Dela Cruz',
      course: 'BSBA',
      section: '3-C',
      photo: true,
      subjects: {'CC121', 'ITE211'},
    ),
    (
      number: '023-770',
      name: 'Angelica Mae Reyes',
      course: 'BSED',
      section: '1-A',
      photo: false,
      subjects: {'CC121', 'ITE211'},
    ),
  ];

  /// The seeded numbers, for the demo banner.
  static List<String> get sampleNumbers => [
    for (final s in _students) s.number,
  ];

  String get _today {
    final now = _clock();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  String get _timeNow {
    final now = _clock();
    String two(int n) => n.toString().padLeft(2, '0');
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    return '${two(hour)}:${two(now.minute)}:${two(now.second)} '
        '${now.hour < 12 ? 'AM' : 'PM'}';
  }

  ScannerUser _requireUser() {
    final user = _user;
    if (user == null) {
      throw const ScannerException(
        'Your sign-in has expired. Please sign in again.',
        code: 'unauthenticated',
      );
    }
    return user;
  }

  @override
  Future<ScannerUser?> restoreSession() async => _user;

  @override
  Future<ScannerUser> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(latency);
    if (email.trim().isEmpty || password.trim().isEmpty) {
      throw const ScannerException(
        'Enter your email and password.',
        code: 'missing_credentials',
      );
    }
    return _user = ScannerUser(
      id: 0,
      name: 'Demo Instructor',
      email: email.trim(),
      role: 'instructor',
    );
  }

  @override
  Future<void> signOut() async => _user = null;

  @override
  Future<SubjectList> loadSubjects() async {
    await Future<void>.delayed(latency);
    return (
      user: _requireUser(),
      subjects: [
        for (final s in _subjects)
          s.copyWith(lateMarking: _lateOn.contains(s.code)),
      ],
      date: _today,
    );
  }

  @override
  Future<ScanRecord> recordScan({
    required String studentNumber,
    required String subjectCode,
  }) async {
    await Future<void>.delayed(latency);
    _requireUser();

    final subject = _subjects.firstWhere(
      (s) => s.code == subjectCode,
      orElse: () => throw const ScannerException(
        'That subject does not exist.',
        code: 'missing_data',
      ),
    );

    final number = StudentNumber.tryParse(studentNumber);
    final matches = _students.where((s) => s.number == number?.value);
    if (matches.isEmpty) {
      throw ScannerException(
        'Student $studentNumber not found in database',
        code: 'student_not_found',
      );
    }
    final student = matches.first;

    if (!student.subjects.contains(subject.code)) {
      throw ScannerException(
        '${student.name} is not enrolled in ${subject.name}',
        code: 'not_enrolled',
      );
    }

    final today = _today;
    if (_records.any(
      (r) =>
          r.studentNumber == student.number &&
          r.subject == subject.name &&
          r.date == today,
    )) {
      throw const ScannerException(
        'Already marked today.',
        code: 'already_marked',
      );
    }

    final record = ScanRecord(
      studentNumber: student.number,
      name: student.name,
      course: student.course,
      section: student.section,
      subject: subject.name,
      date: today,
      timeIn: _timeNow,
      late: _lateOn.contains(subject.code),
      photoMissing: !student.photo,
    );
    _records.insert(0, record);
    return record;
  }

  @override
  Future<List<AttendanceEntry>> loadToday() async {
    await Future<void>.delayed(latency);
    _requireUser();
    final today = _today;
    return [
      for (final r in _records)
        if (r.date == today) r,
    ];
  }

  @override
  Future<bool> setLateMarking({
    required String subjectCode,
    required bool on,
  }) async {
    await Future<void>.delayed(latency);
    _requireUser();
    on ? _lateOn.add(subjectCode) : _lateOn.remove(subjectCode);
    return on;
  }
}
