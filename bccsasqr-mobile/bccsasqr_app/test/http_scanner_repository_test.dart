import 'dart:convert';

import 'package:bccsasqr_app/core/utils/network_error.dart';
import 'package:bccsasqr_app/models/offline_scan.dart';
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

  test('no signal says so in plain words, with no exception text', () async {
    final r = repo(
      MemoryTokenStore(),
      (_) async =>
          throw http.ClientException("Failed host lookup: 'lexondev.com'"),
    );

    await expectLater(
      r.signIn(email: 'a@b.c', password: 'x'),
      throwsA(
        isA<ScannerException>()
            .having((e) => e.code, 'code', 'network')
            .having((e) => e.message, 'message', NetworkError.offline),
      ),
    );
  });

  test('a server too slow to answer is told apart from no signal', () async {
    final r = HttpScannerRepository(
      tokens: MemoryTokenStore(),
      baseUrl: _base,
      timeout: const Duration(milliseconds: 10),
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return json(ok({}));
      }),
    );

    await expectLater(
      r.signIn(email: 'a@b.c', password: 'x'),
      throwsA(
        isA<ScannerException>()
            .having((e) => e.code, 'code', 'network')
            .having((e) => e.message, 'message', NetworkError.slow),
      ),
    );
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
        fail('photo_required', 'NAVARRO has no photo on file.', {
          'name': 'NAVARRO, TRISHA MAE V.',
        }),
        422,
      ),
    );

    await expectLater(
      r.recordScan(studentNumber: '000-1211', subjectCode: 'ELEC2'),
      throwsA(
        isA<ScannerException>()
            .having((e) => e.code, 'code', 'photo_required')
            .having((e) => e.name, 'name', 'NAVARRO, TRISHA MAE V.'),
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
              'student_no': '000-294',
              'name': 'BAUTISTA, LORENZO MIGUEL D.',
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

  test('a class list comes by subject, in the query string', () async {
    late Uri seen;
    final r = repo(MemoryTokenStore(_token), (req) async {
      seen = req.url;
      return json(
        ok({
          'date': '2026-09-30',
          'subject_code': 'IT 101',
          'photo_required': true,
          'students': [
            {
              'student_no': '000-1023',
              'name': 'SANTOS, MARIA ISABEL',
              'course': 'BSCS',
              'section': '2B',
              'photo': false,
            },
          ],
        }),
      );
    });

    final roster = await r.loadRoster('IT 101');
    expect(seen.path, endsWith('/scanner/roster'));
    expect(seen.queryParameters['subject'], 'IT 101');
    expect(roster.photoRequired, isTrue);
    expect(roster.date, '2026-09-30');
    expect(roster.students['000-1023']?.hasPhoto, isFalse);
  });

  test(
    'kept scans go as UTC instants, and each answer is read by id',
    () async {
      late Map<String, dynamic> sent;
      final r = repo(MemoryTokenStore(_token), (req) async {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return json(
          ok({
            'results': [
              {
                'id': 'a',
                'status': 'saved',
                'record': {
                  'student_no': '000-1023',
                  'name': 'SANTOS, MARIA ISABEL',
                  'subject': 'Multimedia Technologies',
                  'date': '2026-09-30',
                  'time_in': '07:25:54 AM',
                  'late': false,
                },
              },
              {'id': 'b', 'status': 'already_marked'},
              {
                'id': 'c',
                'status': 'rejected',
                'code': 'too_old',
                'message': 'This scan is more than 3 days old.',
              },
              {'id': 'd', 'status': 'error', 'code': 'scan_failed'},
            ],
          }),
        );
      });

      PendingScan scan(String id) => PendingScan(
        id: id,
        userId: 4,
        studentNumber: '000-1023',
        subjectCode: 'ELEC2',
        subjectName: 'Multimedia Technologies',
        scannedAt: DateTime.utc(2026, 9, 29, 23, 25, 54),
        late: true,
      );

      final answers = await r.syncScans([scan('a'), scan('b'), scan('c')]);
      final first = (sent['scans'] as List).first as Map<String, dynamic>;
      expect(first['scanned_at'], '2026-09-29T23:25:54.000Z');
      expect(first['late'], isTrue);
      expect(first['subject_code'], 'ELEC2');

      expect(answers.map((a) => a.status), [
        SyncStatus.saved,
        SyncStatus.alreadyMarked,
        SyncStatus.rejected,
        SyncStatus.error,
      ]);
      expect(answers.first.record?.timeIn, '07:25:54 AM');
      expect(answers[2].rejection?.code, 'too_old');
    },
  );
}
