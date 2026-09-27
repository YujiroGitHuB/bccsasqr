import 'dart:convert';

import 'package:bccsasqr_app/services/http_scanner_repository.dart';
import 'package:bccsasqr_app/services/scanner_repository.dart';
import 'package:bccsasqr_app/services/token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _base = 'https://example.test/bccsasqr/api/v1';
const _token =
    '7ce955c81566e179254a6e2ad1243503a148bfa2636ea779b95c25b1a070a742';

String ok(Map<String, dynamic> data) =>
    jsonEncode({'success': true, 'data': data});

String fail(
  String code, [
  String message = 'nope',
  Map<String, dynamic>? details,
]) => jsonEncode({
  'success': false,
  'error': {'code': code, 'message': message, 'details': ?details},
});

const _user = {
  'id': 4,
  'name': 'Paolo R. Mendoza',
  'email': 'francis@example.test',
  'role': 'instructor',
  'avatar_url': null,
};

/// A repository whose server is [handler].
HttpScannerRepository repo(
  MemoryTokenStore tokens,
  Future<http.Response> Function(http.Request) handler,
) => HttpScannerRepository(
  tokens: tokens,
  baseUrl: _base,
  client: MockClient(handler),
);

http.Response json(String body, [int status = 200]) =>
    http.Response(body, status, headers: {'content-type': 'application/json'});

void main() {
  test('signing in keeps the token and sends it from then on', () async {
    final tokens = MemoryTokenStore();
    final seen = <http.Request>[];
    final r = repo(tokens, (req) async {
      seen.add(req);
      if (req.url.path.endsWith('auth/login')) {
        return json(ok({'token': _token, 'user': _user}), 201);
      }
      return json(ok({'user': _user, 'date': '2026-09-27', 'subjects': []}));
    });

    final user = await r.signIn(email: ' francis@example.test ', password: 'x');
    expect(user.name, 'Paolo R. Mendoza');
    expect(await tokens.read(), _token);

    final body = jsonDecode(seen.first.body) as Map<String, dynamic>;
    expect(body['email'], 'francis@example.test');
    expect(seen.first.headers.containsKey('X-Auth-Token'), isFalse);

    await r.loadSubjects();
    expect(seen.last.headers['X-Auth-Token'], _token);
  });

  test('no saved token: signed out, without asking the server', () async {
    var calls = 0;
    final r = repo(MemoryTokenStore(), (_) async {
      calls++;
      return json(ok({}));
    });

    expect(await r.restoreSession(), isNull);
    expect(calls, 0);
  });

  test('a saved token the server rejects is dropped', () async {
    final tokens = MemoryTokenStore(_token);
    final r = repo(
      tokens,
      (_) async => json(fail('unauthenticated', 'Sign in again.'), 401),
    );

    expect(await r.restoreSession(), isNull);
    expect(await tokens.read(), isNull);
  });

  test('a saved token survives no signal', () async {
    final tokens = MemoryTokenStore(_token);
    final r = repo(tokens, (_) async => throw http.ClientException('offline'));

    await expectLater(
      r.restoreSession(),
      throwsA(isA<ScannerException>().having((e) => e.code, 'code', 'network')),
    );
    expect(await tokens.read(), _token);
  });

  test('a recorded scan comes back as a record', () async {
    final r = repo(
      MemoryTokenStore(_token),
      (req) async => json(
        ok({
          'record': {
            'student_no': '000-802',
            'name': 'VILLAR, CARMINA JOY P.',
            'course': 'BSIT',
            'section': '2G',
            'subject': 'Multimedia Technologies',
            'date': '2026-09-27',
            'time_in': '07:25:54 AM',
            'late': true,
            'photo_url': 'https://example.test/uploads/photos/1.jpg',
            'photo_missing': false,
          },
        }),
        201,
      ),
    );

    final record = await r.recordScan(
      studentNumber: '000-802',
      subjectCode: 'ELEC2',
    );
    expect(record.name, 'VILLAR, CARMINA JOY P.');
    expect(record.late, isTrue);
    expect(record.photoUrl, endsWith('1.jpg'));
    expect(record.courseAndSection, 'BSIT — 2G');
  });

  test('a refused scan carries the code and the name', () async {
    final r = repo(
      MemoryTokenStore(_token),
      (_) async => json(
        fail('photo_required', 'ABALOS has no photo on file.', {
          'name': 'ABALOS, JAYVEE V.',
        }),
        422,
      ),
    );

    await expectLater(
      r.recordScan(studentNumber: '025-1211', subjectCode: 'ELEC2'),
      throwsA(
        isA<ScannerException>()
            .having((e) => e.code, 'code', 'photo_required')
            .having((e) => e.name, 'name', 'ABALOS, JAYVEE V.'),
      ),
    );
  });

  test('an HTML page instead of JSON is reported, not parsed', () async {
    final r = repo(
      MemoryTokenStore(_token),
      (_) async => http.Response('<html>502</html>', 502),
    );

    await expectLater(
      r.loadToday(),
      throwsA(
        isA<ScannerException>().having((e) => e.code, 'code', 'bad_response'),
      ),
    );
  });

  test('signing out forgets the token even with no signal', () async {
    final tokens = MemoryTokenStore(_token);
    final r = repo(tokens, (req) async {
      if (req.url.path.endsWith('auth/me')) return json(ok({'user': _user}));
      throw http.ClientException('offline');
    });
    await r.restoreSession();

    await r.signOut();
    expect(await tokens.read(), isNull);
  });

  test("today's list and the late switch", () async {
    final r = repo(MemoryTokenStore(_token), (req) async {
      if (req.url.path.endsWith('scanner/late')) {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        return json(
          ok({'subject_code': body['subject_code'], 'on': body['on']}),
        );
      }
      return json(
        ok({
          'date': '2026-09-27',
          'records': [
            {
              'date': '2026-09-27',
              'student_no': '025-294',
              'name': 'CENTENO, EDRIAN GABRIEL D.',
              'course': 'BSIT',
              'section': '2E',
              'subject': 'Multimedia Technologies',
              'time_in': '07:25:55 AM',
              'late': true,
            },
          ],
        }),
      );
    });

    final today = await r.loadToday();
    expect(today.single.late, isTrue);
    expect(await r.setLateMarking(subjectCode: 'ELEC2', on: true), isTrue);
  });
}
