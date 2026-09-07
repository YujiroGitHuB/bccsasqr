import 'dart:convert';

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
String fail(String code, [String message = 'nope']) =>
    jsonEncode({
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
          isA<StudentLookupException>().having((e) => e.code, 'code', 'network'),
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

      expect(await repo.issueQrPayload(_number), '019-464');
      expect(seen.toString(), '$_base/students/019-464/qr');
    });

    test('surfaces terms_not_accepted so the controller can act on it', () async {
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
    });

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
}

/// Stands in for a transport-level failure (DNS, TLS, refused connection).
class SocketishFailure implements Exception {
  const SocketishFailure();
}
