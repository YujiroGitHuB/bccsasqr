import 'dart:convert';
import 'dart:typed_data';

import 'package:bccsasqr_app/core/utils/network_error.dart';
import 'package:bccsasqr_app/core/utils/student_number.dart';
import 'package:bccsasqr_app/services/http_student_repository.dart';
import 'package:bccsasqr_app/services/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _number = StudentNumber.tryParse('019-464')!;

/// Any absolute host will do — the mock client answers before a packet is
/// sent. Passing it explicitly means the suite does not need a
/// `--dart-define=API_BASE_URL` to run.
const _base = 'https://example.test/bccsasqr/api/v1';

HttpStudentRepository repoReturning(
  String body, {
  int status = 200,
  void Function(http.Request)? onRequest,
}) => HttpStudentRepository(
  baseUrl: _base,
  client: MockClient((request) async {
    onRequest?.call(request);
    return http.Response(
      body,
      status,
      headers: {'content-type': 'application/json'},
    );
  }),
);

/// The API's success envelope: `{"success": true, "data": {…}}`.
String ok(Map<String, dynamic> data) =>
    jsonEncode({'success': true, 'data': data});

/// The API's failure envelope.
String fail(String code, [String message = 'nope']) => jsonEncode({
  'success': false,
  'error': {'code': code, 'message': message},
});

const _student = {
  'student_no': '019-464',
  'fullname': 'Charles Nixon Cayading',
  'course': 'BS Information Technology',
  'section': 'BSIT 4-A',
};

void main() {
  group('findByStudentNumber', () {
    test('parses a found record', () async {
      final repo = repoReturning(
        ok({
          'student': _student,
          'terms': {'version': 1, 'accepted': false},
          'can_generate': false,
        }),
      );

      final record = await repo.findByStudentNumber(_number);

      expect(record, isNotNull);
      expect(record!.fullName, 'Charles Nixon Cayading');
      expect(record.section, 'BSIT 4-A');
    });

    test('asks for the student as a path segment', () async {
      Uri? seen;
      final repo = repoReturning(
        ok({'student': _student}),
        onRequest: (r) => seen = r.url,
      );

      await repo.findByStudentNumber(_number);

      expect(seen.toString(), '$_base/students/019-464');
    });

    test('student_not_found returns null rather than throwing', () async {
      final repo = repoReturning(
        fail('student_not_found', 'Student not found.'),
        status: 404,
      );

      expect(await repo.findByStudentNumber(_number), isNull);
    });

    test('any other API error keeps its code', () async {
      final repo = repoReturning(
        fail('rate_limited', 'Too many requests.'),
        status: 429,
      );

      await expectLater(
        () => repo.findByStudentNumber(_number),
        throwsA(
          isA<StudentLookupException>()
              .having((e) => e.code, 'code', 'rate_limited')
              .having((e) => e.message, 'message', 'Too many requests.'),
        ),
      );
    });

    test('a 503 with no envelope still raises a lookup exception', () async {
      final repo = repoReturning('{"nope":true}', status: 503);

      expect(
        () => repo.findByStudentNumber(_number),
        throwsA(isA<StudentLookupException>()),
      );
    });

    test('an HTML page (free-host challenge) gives a readable error', () async {
      // InfinityFree and similar hosts answer non-browser requests with an
      // anti-bot HTML page. This must not surface as a raw JSON parse crash.
      final repo = repoReturning(
        '<html><head><script>document.cookie="__test=1"</script></head></html>',
      );

      await expectLater(
        () => repo.findByStudentNumber(_number),
        throwsA(
          isA<StudentLookupException>().having(
            (e) => e.message,
            'message',
            contains('page instead of data'),
          ),
        ),
      );
    });

    test('carries the server warnings with the record, action and all', () async {
      final repo = repoReturning(
        ok({
          'student': _student,
          'warnings': [
            {
              'code': 'photo_missing',
              'message': 'Upload your photo first.',
              'action': {
                'label': 'Upload your photo',
                'url':
                    'https://example.test/bccsasqr/student/StudentPhotoProfile.php',
              },
            },
          ],
        }),
      );

      final record = await repo.findByStudentNumber(_number);

      expect(record!.warnings, hasLength(1));
      final warning = record.warnings.single;
      expect(warning.code, 'photo_missing');
      expect(warning.message, 'Upload your photo first.');
      expect(warning.actionLabel, 'Upload your photo');
      expect(warning.actionUrl, endsWith('/student/StudentPhotoProfile.php'));
    });

    test('a malformed warning is dropped, not fatal', () async {
      // A warning is advice. One the app cannot read must not cost the
      // student their record — and an action that is not a web link must
      // never reach the system browser.
      final repo = repoReturning(
        ok({
          'student': _student,
          'warnings': [
            'not an object',
            {'code': 'no_message'},
            {
              'code': 'odd_link',
              'message': 'Still worth showing.',
              'action': {'label': 'Open', 'url': 'javascript:alert(1)'},
            },
          ],
        }),
      );

      final record = await repo.findByStudentNumber(_number);

      expect(record!.warnings, hasLength(1));
      expect(record.warnings.single.message, 'Still worth showing.');
      expect(record.warnings.single.hasAction, isFalse);
    });

    test('no warnings key means no warnings', () async {
      final repo = repoReturning(ok({'student': _student}));

      expect((await repo.findByStudentNumber(_number))!.warnings, isEmpty);
    });

    test('a record missing a field reports it instead of crashing', () async {
      final repo = repoReturning(
        ok({
          'student': {'student_no': '019-464'},
        }),
      );

      expect(
        () => repo.findByStudentNumber(_number),
        throwsA(isA<StudentLookupException>()),
      );
    });

    test('a network failure is wrapped, not leaked', () async {
      final repo = HttpStudentRepository(
        baseUrl: _base,
        client: MockClient((_) async => throw const SocketishFailure()),
      );

      expect(
        () => repo.findByStudentNumber(_number),
        throwsA(
          isA<StudentLookupException>()
              .having((e) => e.code, 'code', 'network')
              // The student reads this: what to do, not what was thrown.
              .having((e) => e.message, 'message', NetworkError.offline),
        ),
      );
    });
  });

  group('issueQrPayload', () {
    test('returns the payload the server issued', () async {
      Uri? seen;
      final repo = repoReturning(
        ok({
          'student': _student,
          'qr': {
            'payload': '019-464',
            'spec': {'size': 250},
          },
        }),
        onRequest: (r) => seen = r.url,
      );

      expect((await repo.issueQrPayload(_number)).data, '019-464');
      expect(seen.toString(), '$_base/students/019-464/qr');
    });

    test('reads the drawing spec and the card the server issued', () async {
      final repo = repoReturning(
        ok({
          'student': _student,
          'qr': {
            'payload': '019-464',
            'spec': {
              'size': 250,
              'error_correction': 'M',
              'foreground': '#38bdf8',
              'background': '#0f172a',
            },
            'card': {
              'filename': '019-464_qr.png',
              'details': [
                {'label': 'Student No.', 'value': '019-464'},
                {'label': 'Course', 'value': 'BSIT'},
              ],
            },
          },
        }),
      );

      final qr = await repo.issueQrPayload(_number);

      expect(qr.spec.size, 250);
      expect(qr.spec.errorCorrection, 'M');
      expect(qr.spec.foreground.toARGB32(), 0xFF38BDF8);
      expect(qr.spec.background.toARGB32(), 0xFF0F172A);
      expect(qr.fileName, '019-464_qr.png');
      expect(qr.details.map((r) => r.label), ['Student No.', 'Course']);
      expect(qr.details.last.value, 'BSIT');
    });

    test('a missing spec or card falls back to the web page look', () async {
      // An older server sends only the payload. The card must still come out
      // the way the web page draws it, not blank.
      final repo = repoReturning(
        ok({
          'student': _student,
          'qr': {'payload': '019-464'},
        }),
      );

      final qr = await repo.issueQrPayload(_number);

      expect(qr.spec.foreground.toARGB32(), 0xFF38BDF8);
      expect(qr.fileName, '019-464_qr.png');
      expect(qr.details.map((r) => r.value), [
        '019-464',
        'Charles Nixon Cayading',
        'BS INFORMATION TECHNOLOGY',
        'BSIT 4-A',
      ]);
    });

    test('a file name from the server cannot leave the app folder', () async {
      final repo = repoReturning(
        ok({
          'student': _student,
          'qr': {
            'payload': '019-464',
            'card': {'filename': '../../evil.sh', 'details': []},
          },
        }),
      );

      expect((await repo.issueQrPayload(_number)).fileName, 'evilsh.png');
    });

    test(
      'surfaces terms_not_accepted so the controller can act on it',
      () async {
        final repo = repoReturning(
          fail('terms_not_accepted', 'You must accept the terms.'),
          status: 409,
        );

        await expectLater(
          () => repo.issueQrPayload(_number),
          throwsA(
            isA<StudentLookupException>().having(
              (e) => e.isTermsNotAccepted,
              'isTermsNotAccepted',
              isTrue,
            ),
          ),
        );
      },
    );

    test('an empty payload is refused rather than rendered', () async {
      final repo = repoReturning(
        ok({
          'qr': {'payload': ''},
        }),
      );

      expect(
        () => repo.issueQrPayload(_number),
        throwsA(isA<StudentLookupException>()),
      );
    });
  });

  group('terms', () {
    test('reads the served text and version', () async {
      final repo = repoReturning(
        ok({
          'version': 3,
          'contact': 'registrar@example.edu',
          'html': '<h4>1. …</h4>',
          'text': '1. Your QR code is personal',
        }),
      );

      final terms = await repo.fetchTerms();

      expect(terms.version, 3);
      expect(terms.text, '1. Your QR code is personal');
      expect(terms.contact, 'registrar@example.edu');
    });

    test('acceptance POSTs the student number', () async {
      http.Request? seen;
      final repo = repoReturning(
        ok({
          'student_no': '019-464',
          'terms': {'version': 1, 'accepted': true},
          'can_generate': true,
        }),
        status: 201,
        onRequest: (r) => seen = r,
      );

      await repo.acceptTerms(_number);

      expect(seen!.method, 'POST');
      expect(seen!.url.toString(), '$_base/terms/accept');
      expect(jsonDecode(seen!.body), {'student_no': '019-464'});
    });
  });

  group('fetchAttendance', () {
    // What api/v1/handlers/tracker.php answered for a real record.
    final body = ok({
      'student': {..._student, 'photo_url': 'https://example.test/p/1.jpg'},
      'summary': {'total': 3, 'subjects': 2, 'last_attended': '2026-08-24'},
      'subjects': [
        {
          'subject': 'Multimedia Technologies',
          'instructor': 'Paolo R. Mendoza',
          'count': 1,
          'records': [
            {'date': '2026-08-24', 'time_in': '03:32:26 PM', 'late': false},
          ],
        },
        {
          'subject': 'Object Oriented Programming',
          'instructor': 'Charles Nixon Cayading',
          'count': 2,
          'records': [
            {'date': '2026-08-24', 'time_in': '10:07:17 AM', 'late': true},
            {'date': '2026-08-17', 'time_in': '11:59:50 AM', 'late': false},
          ],
        },
      ],
    });

    test('asks for the attendance under the student', () async {
      Uri? seen;
      final repo = repoReturning(body, onRequest: (r) => seen = r.url);

      await repo.fetchAttendance(_number);

      expect(seen.toString(), '$_base/students/019-464/attendance');
    });

    test('parses the summary, subjects and days', () async {
      final history = (await repoReturning(body).fetchAttendance(_number))!;

      expect(history.fullName, 'Charles Nixon Cayading');
      expect(history.photoUrl, 'https://example.test/p/1.jpg');
      expect(history.total, 3);
      expect(history.lastAttended, DateTime(2026, 8, 24));
      expect(history.subjects, hasLength(2));

      final oop = history.subjects[1];
      expect(oop.count, 2);
      expect(oop.days.first.date, DateTime(2026, 8, 24));
      expect(oop.days.first.timeIn, '10:07:17 AM');
      expect(oop.days.first.late, isTrue);
      expect(oop.days.last.late, isFalse);
    });

    test('a record with no scans is empty, not missing', () async {
      final repo = repoReturning(
        ok({
          'student': {..._student, 'photo_url': null},
          'summary': {'total': 0, 'subjects': 0, 'last_attended': null},
          'subjects': [],
        }),
      );

      final history = (await repo.fetchAttendance(_number))!;

      expect(history.isEmpty, isTrue);
      expect(history.photoUrl, isNull);
      expect(history.lastAttended, isNull);
    });

    test('student_not_found returns null', () async {
      final repo = repoReturning(fail('student_not_found'), status: 404);
      expect(await repo.fetchAttendance(_number), isNull);
    });

    test('a locked tracker raises with its code', () async {
      final repo = repoReturning(
        fail('tracker_locked', 'The attendance tracker is closed.'),
        status: 503,
      );

      expect(
        () => repo.fetchAttendance(_number),
        throwsA(
          isA<StudentLookupException>()
              .having((e) => e.code, 'code', 'tracker_locked')
              .having(
                (e) => e.message,
                'message',
                'The attendance tracker is closed.',
              ),
        ),
      );
    });
  });

  group('photo', () {
    // A made-up student: year 000 never occurs in the school's numbers.
    final number = StudentNumber.tryParse('000-1023')!;
    const student = {
      'student_no': '000-1023',
      'fullname': 'SANTOS, MARIA ISABEL B.',
      'course': 'BSCS',
      'section': '2B',
    };
    const url =
        'https://example.test/bccsasqr/uploads/photos/student_1.jpg?v=7';

    test('verify posts the last name and reads the record and photo', () async {
      late http.Request sent;
      final repo = repoReturning(
        ok({
          'student': student,
          'photo': {'required': true, 'has_photo': true, 'url': url},
          'warnings': [],
        }),
        onRequest: (r) => sent = r,
      );

      final owner = await repo.verifyOwner(number, 'Santos');

      expect(sent.method, 'POST');
      expect(sent.url.path, '/bccsasqr/api/v1/students/000-1023/verify');
      expect(jsonDecode(sent.body), {'last_name': 'Santos'});
      expect(owner.record.fullName, 'SANTOS, MARIA ISABEL B.');
      expect(owner.photoUrl, url);
      expect(owner.required, isTrue);
    });

    test('a wrong last name raises identity_mismatch', () async {
      final repo = repoReturning(
        fail('identity_mismatch', 'Incorrect student number or last name.'),
        status: 403,
      );

      expect(
        () => repo.verifyOwner(number, 'Reyes'),
        throwsA(
          isA<StudentLookupException>().having(
            (e) => e.code,
            'code',
            'identity_mismatch',
          ),
        ),
      );
    });

    test('the photo goes up as a file part, with the last name', () async {
      late http.Request sent;
      final repo = repoReturning(
        ok({
          'student': student,
          'photo': {'required': false, 'has_photo': true, 'url': url},
        }),
        status: 201,
        onRequest: (r) => sent = r,
      );
      final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);

      final owner = await repo.uploadPhoto(number, 'Santos', jpeg);

      expect(sent.method, 'POST');
      expect(sent.url.path, '/bccsasqr/api/v1/students/000-1023/photo');
      expect(sent.headers['content-type'], startsWith('multipart/form-data'));
      final body = latin1.decode(sent.bodyBytes);
      expect(body, contains('name="last_name"'));
      expect(body, contains('Santos'));
      expect(body, contains('name="photo"; filename="photo.jpg"'));
      expect(owner.photoUrl, url);
    });

    test('no photo on file reads as none', () async {
      final repo = repoReturning(
        ok({
          'student': student,
          'photo': {'required': false, 'has_photo': false, 'url': null},
        }),
      );

      final owner = await repo.fetchOwner(number);
      expect(owner.photoUrl, isNull);
      expect(owner.required, isFalse);
    });

    test('downloads the picture as bytes', () async {
      final repo = HttpStudentRepository(
        baseUrl: _base,
        client: MockClient(
          (request) async => http.Response.bytes([0xFF, 0xD8, 9], 200),
        ),
      );
      expect(await repo.downloadPhoto(url), [0xFF, 0xD8, 9]);
    });

    test('a missing picture raises rather than keeping nothing', () async {
      final repo = HttpStudentRepository(
        baseUrl: _base,
        client: MockClient((request) async => http.Response('', 404)),
      );
      expect(
        () => repo.downloadPhoto(url),
        throwsA(isA<StudentLookupException>()),
      );
    });
  });

  group('fetchLive', () {
    // A made-up student: year 000 never occurs in the school's numbers.
    final number = StudentNumber.tryParse('000-1023')!;

    test('the first look sends the last name and no cursor', () async {
      late http.Request sent;
      final repo = repoReturning(
        ok({'cursor': 6950, 'count': 42, 'records': [], 'more': false}),
        onRequest: (r) => sent = r,
      );

      final update = await repo.fetchLive(number, lastName: 'Santos');

      expect(sent.method, 'POST');
      expect(sent.url.path, '/bccsasqr/api/v1/students/000-1023/live');
      expect(jsonDecode(sent.body), {'last_name': 'Santos'});
      expect(update.cursor, 6950);
      expect(update.count, 42);
      expect(update.records, isEmpty);
    });

    test('a later look sends the cursor and reads the new records', () async {
      late http.Request sent;
      final repo = repoReturning(
        ok({
          'cursor': 6957,
          'count': 43,
          'more': false,
          'records': [
            {
              'id': 6957,
              'subject': 'Object Oriented Programming',
              'instructor': 'Sample Instructor',
              'date': '2026-10-01',
              'time_in': '08:16:40 AM',
              'late': true,
              'offline': true,
            },
            // No subject on the row: the tracker's name for it.
            {'id': 6956, 'date': '2026-10-01', 'time_in': '07:58:02 AM'},
            {'subject': 'no id — left out'},
          ],
        }),
        onRequest: (r) => sent = r,
      );

      final update = await repo.fetchLive(
        number,
        lastName: 'Santos',
        since: 6950,
      );

      expect(jsonDecode(sent.body), {'last_name': 'Santos', 'since': 6950});
      expect(update.records, hasLength(2));
      final record = update.records.first;
      expect(record.id, 6957);
      expect(record.day.date, DateTime(2026, 10, 1));
      expect(record.day.timeIn, '08:16:40 AM');
      expect(record.day.late, isTrue);
      expect(record.offline, isTrue);
      expect(update.records.last.subject, 'No Subject');
      expect(update.records.last.instructor, 'N/A');
    });

    test('a refusal keeps its code and its wait', () async {
      final repo = repoReturning(
        jsonEncode({
          'success': false,
          'error': {
            'code': 'rate_limited',
            'message': 'Too many requests.',
            'details': {'retry_after': 12},
          },
        }),
        status: 429,
      );

      expect(
        () => repo.fetchLive(number, lastName: 'Santos', since: 1),
        throwsA(
          isA<StudentLookupException>()
              .having((e) => e.code, 'code', 'rate_limited')
              .having((e) => e.details?['retry_after'], 'retry_after', 12),
        ),
      );
    });

    test('an answer with no cursor is a bad response, not a crash', () async {
      final repo = repoReturning(ok({'records': []}));

      expect(
        () => repo.fetchLive(number, lastName: 'Santos'),
        throwsA(
          isA<StudentLookupException>().having(
            (e) => e.code,
            'code',
            'bad_response',
          ),
        ),
      );
    });
  });
}

/// Stands in for a transport-level failure (DNS, TLS, refused connection).
class SocketishFailure implements Exception {
  const SocketishFailure();
}
