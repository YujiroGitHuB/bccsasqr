import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../core/utils/network_error.dart';
import '../models/offline_scan.dart';
import '../models/scanner_models.dart';
import 'scanner_repository.dart';
import 'token_store.dart';

/// Talks to the scanner half of `/api/v1` — the endpoints in
/// `api/v1/handlers/scanner.php`, which run the web scanner's own rules
/// (`includes/scan_attendance.php`).
///
/// Signing in returns a token that is kept in [TokenStore] and sent as
/// `X-Auth-Token` on every call after. A 401 means that token is dead —
/// signed out, idle too long, or the password changed — so it is dropped here
/// and the controller goes back to the sign-in screen.
class HttpScannerRepository implements ScannerRepository {
  HttpScannerRepository({
    required TokenStore tokens,
    http.Client? client,
    String? baseUrl,
    this.timeout = AppConfig.requestTimeout,
  }) : _tokens = tokens,
       _client = client ?? http.Client(),
       _baseUrl = (baseUrl ?? AppConfig.apiBaseUrl).replaceAll(
         RegExp(r'/+$'),
         '',
       );

  final TokenStore _tokens;
  final http.Client _client;
  final Duration timeout;
  final String _baseUrl;

  /// Read once from [TokenStore], then kept here so a scan does not wait on
  /// the keystore.
  String? _token;

  Uri _endpoint(String path) => Uri.parse('$_baseUrl/$path');

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    if (AppConfig.apiKey.isNotEmpty) 'X-API-Key': AppConfig.apiKey,
    'X-Auth-Token': ?_token,
  };

  @override
  Future<ScannerUser?> restoreSession() async {
    _token = await _tokens.read();
    if (_token == null) return null;

    try {
      final data = await _get('auth/me');
      return ScannerUser.fromJson(data['user'] as Map<String, dynamic>);
    } on ScannerException catch (e) {
      // A dead token is "signed out", not an error. Anything else — no
      // signal — keeps the token for the next try.
      if (e.isSignedOut) return null;
      rethrow;
    }
  }

  @override
  Future<ScannerUser> signIn({
    required String email,
    required String password,
  }) async {
    final data = await _post('auth/login', {
      'email': email.trim(),
      'password': password,
      'device': 'BCC SASQR app',
    });

    final token = data['token'];
    final user = data['user'];
    if (token is! String || user is! Map<String, dynamic>) {
      throw const ScannerException(
        'Unexpected response from the server.',
        code: 'bad_response',
      );
    }

    _token = token;
    await _tokens.write(token);
    return ScannerUser.fromJson(user);
  }

  @override
  Future<void> signOut() async {
    try {
      if (_token != null) await _post('auth/logout', const {});
    } on ScannerException {
      // Signed out here regardless. A token the server never heard about
      // expires on its own (includes/api_tokens.php).
    } finally {
      _token = null;
      await _tokens.clear();
    }
  }

  @override
  Future<SubjectList> loadSubjects() async {
    final data = await _get('scanner/subjects');
    final subjects = data['subjects'];
    return (
      user: ScannerUser.fromJson(data['user'] as Map<String, dynamic>),
      subjects: [
        if (subjects is List)
          for (final s in subjects)
            if (s is Map<String, dynamic>) ScanSubject.fromJson(s),
      ],
      date: data['date'] as String? ?? '',
    );
  }

  @override
  Future<ScanRecord> recordScan({
    required String studentNumber,
    required String subjectCode,
  }) async {
    final data = await _post('scanner/scan', {
      'student_no': studentNumber,
      'subject_code': subjectCode,
    });
    final record = data['record'];
    if (record is! Map<String, dynamic>) {
      throw const ScannerException(
        'Unexpected response from the server.',
        code: 'bad_response',
      );
    }
    return ScanRecord.fromJson(record);
  }

  @override
  Future<List<AttendanceEntry>> loadToday() async {
    final data = await _get('scanner/attendance');
    final records = data['records'];
    return [
      if (records is List)
        for (final r in records)
          if (r is Map<String, dynamic>) AttendanceEntry.fromJson(r),
    ];
  }

  @override
  Future<bool> setLateMarking({
    required String subjectCode,
    required bool on,
  }) async {
    final data = await _post('scanner/late', {
      'subject_code': subjectCode,
      'on': on,
    });
    return data['on'] == true;
  }

  @override
  Future<SubjectRoster> loadRoster(String subjectCode) async {
    final data = await _send(
      () => _client.get(
        _endpoint(
          'scanner/roster',
        ).replace(queryParameters: {'subject': subjectCode}),
        headers: _headers,
      ),
    );
    return SubjectRoster.fromJson({'subject_code': subjectCode, ...data});
  }

  @override
  Future<List<SyncOutcome>> syncScans(List<PendingScan> scans) async {
    final data = await _post('scanner/sync', {
      'scans': [for (final s in scans.take(syncBatch)) s.toSyncJson()],
    });
    final results = data['results'];
    return [
      if (results is List)
        for (final r in results)
          if (r is Map<String, dynamic> && r['id'] is String)
            SyncOutcome.fromJson(r),
    ];
  }

  // ------------------------------------------------------------- transport

  Future<Map<String, dynamic>> _get(String path) =>
      _send(() => _client.get(_endpoint(path), headers: _headers));

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) =>
      _send(
        () => _client.post(
          _endpoint(path),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ),
      );

  /// Sends, unwraps the envelope, and turns every failure into a
  /// [ScannerException] — the same unwrapping as HttpStudentRepository.
  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } catch (e) {
      throw ScannerException(NetworkError.messageFor(e), code: 'network');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const ScannerException(
        'The server replied with a page instead of data. Check that '
        'API_BASE_URL points at /api/v1.',
        code: 'bad_response',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const ScannerException(
        'Unexpected response from the server.',
        code: 'bad_response',
      );
    }

    if (decoded['success'] == true) {
      final data = decoded['data'];
      return data is Map<String, dynamic> ? data : const {};
    }

    final error = decoded['error'];
    if (error is! Map<String, dynamic>) {
      throw ScannerException(
        'The server returned HTTP ${response.statusCode}.',
        code: 'unknown',
      );
    }

    final code = error['code'] as String? ?? 'unknown';
    if (code == 'unauthenticated') {
      _token = null;
      await _tokens.clear();
    }

    final details = error['details'];
    throw ScannerException(
      error['message'] as String? ?? 'Something went wrong.',
      code: code,
      name: details is Map<String, dynamic> ? details['name'] as String? : null,
    );
  }

  void dispose() => _client.close();
}
