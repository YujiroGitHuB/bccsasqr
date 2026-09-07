import '../core/utils/student_number.dart';
import '../models/student_record.dart';
import '../models/terms_document.dart';

/// Raised when the records service itself fails (network, parsing, …).
/// A *missing* record is not an error — the repository returns `null`.
class StudentLookupException implements Exception {
  const StudentLookupException(this.message, {this.code});

  /// Safe to show to a student as it is.
  final String message;

  /// The API's machine-readable code (`terms_not_accepted`,
  /// `generator_locked`, `rate_limited`, …) when the failure came from the
  /// server rather than the wire. Branch on this, never on [message].
  final String? code;

  bool get isTermsNotAccepted => code == 'terms_not_accepted';
  bool get isGeneratorLocked => code == 'generator_locked';

  @override
  String toString() => 'StudentLookupException(${code ?? '-'}): $message';
}

/// The contract the controller depends on. Swapping the demo data for a real
/// HTTP client means writing one more implementation of this — nothing above
/// this line changes.
abstract interface class StudentRepository {
  Future<StudentRecord?> findByStudentNumber(StudentNumber number);

  /// The string to encode, decided by the server. See the note in
  /// `models/qr_payload.dart` for why the app must not build it itself.
  Future<String> issueQrPayload(StudentNumber number);

  /// The current Terms and Conditions.
  Future<TermsDocument> fetchTerms();

  /// Records acceptance of the current terms for this student.
  Future<void> acceptTerms(StudentNumber number);
}

/// Demo implementation backed by a fixed verified list, with a small delay so
/// the loading state is visible during development.
///
/// This is what runs when no `API_BASE_URL` was supplied at build time. It
/// answers the same shapes as the real repository so the whole screen can be
/// exercised on a plane — including the QR, which is the bare student number
/// here for the same reason it is on the server.
class InMemoryStudentRepository implements StudentRepository {
  InMemoryStudentRepository({this.latency = const Duration(milliseconds: 650)});

  final Duration latency;

  static final List<StudentRecord> _seed = [
    for (final json in _rawRecords) StudentRecord.fromJson(json),
  ];

  static const List<Map<String, dynamic>> _rawRecords = [
    {
      'student_number': '019-464',
      'full_name': 'Charles Nixon Cayading',
      'course': 'BS Information Technology',
      'section': 'BSIT 4-A',
    },
    {
      'student_number': '025-1023',
      'full_name': 'Maria Isabel Santos',
      'course': 'BS Computer Science',
      'section': 'BSCS 2-B',
    },
    {
      'student_number': '021-318',
      'full_name': 'Jose Rafael Dela Cruz',
      'course': 'BS Business Administration',
      'section': 'BSBA 3-C',
    },
    {
      'student_number': '023-770',
      'full_name': 'Angelica Mae Reyes',
      'course': 'BS Education',
      'section': 'BSED 1-A',
    },
  ];

  /// The seeded numbers, so the demo-mode banner can name them rather than
  /// leaving whoever is testing to guess.
  static List<String> get sampleNumbers => [
    for (final json in _rawRecords) json['student_number'] as String,
  ];

  @override
  Future<StudentRecord?> findByStudentNumber(StudentNumber number) async {
    await Future<void>.delayed(latency);
    for (final record in _seed) {
      if (record.studentNumber == number && record.verified) return record;
    }
    return null;
  }

  @override
  Future<String> issueQrPayload(StudentNumber number) async {
    final record = await findByStudentNumber(number);
    if (record == null) {
      throw const StudentLookupException(
        'No verified record matches that student number.',
        code: 'student_not_found',
      );
    }
    return record.studentNumber.value;
  }

  @override
  Future<TermsDocument> fetchTerms() async {
    await Future<void>.delayed(latency);
    return const TermsDocument(
      version: 0,
      text:
          'Demo mode — this device is not connected to the school\'s server, so '
          'this is placeholder text and no acceptance is recorded.\n\n'
          'The real Terms and Conditions are served by the school and cover: '
          'that your QR identifies you and you alone, that letting someone else '
          'present it is academic dishonesty, what the system records when you '
          'are scanned, and who can see it.\n\n'
          'Build the app with --dart-define=API_BASE_URL=… to read the real '
          'terms.',
    );
  }

  @override
  Future<void> acceptTerms(StudentNumber number) async {
    // Nothing to record without a server. Deliberately silent rather than
    // throwing: demo mode should behave like a working app.
  }
}
