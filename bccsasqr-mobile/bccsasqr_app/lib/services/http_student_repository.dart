import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../core/utils/student_number.dart';
import '../models/student_record.dart';
import '../models/terms_document.dart';
import 'student_repository.dart';

/// Talks to `/api/v1`, the REST API that sits on the same rules as the web
/// generator page.
///
/// Every endpoint answers with the same envelope, so there is one place below
/// that unwraps it:
///
/// ```json
/// {"success": true,  "data":  { … }}
/// {"success": false, "error": {"code": "student_not_found", "message": "…"}}
/// ```
///
/// A missing record is *not* an error — it returns `null`, matching
/// [StudentRepository]. Everything else raises a [StudentLookupException]
/// carrying the server's `code`, so the controller can act on
/// `terms_not_accepted` instead of merely showing it.
class HttpStudentRepository implements StudentRepository {
  HttpStudentRepository({
    http.Client? client,
    String? baseUrl,
    this.timeout = AppConfig.requestTimeout,
  }) : _client = client ?? http.Client(),
       // A trailing slash in the dart-define is easy to leave in by accident
       // and would produce `…/api/v1//students/019-464`.
       _baseUrl = (baseUrl ?? AppConfig.apiBaseUrl).replaceAll(
         RegExp(r'/+$'),
         '',
       );

  final http.Client _client;
  final Duration timeout;

  /// The versioned API root — `https://host/bccsasqr/api/v1`. Overridable so
  /// tests can point at a mock host without a `--dart-define`.
  final String _baseUrl;

  Uri _endpoint(String path) => Uri.parse('$_baseUrl/$path');

  Uri _studentUri(StudentNumber number) =>
      _endpoint('students/${Uri.encodeComponent(number.value)}');

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    if (AppConfig.apiKey.isNotEmpty) 'X-API-Key': AppConfig.apiKey,
  };

  @override
  Future<StudentRecord?> findByStudentNumber(StudentNumber number) async {
    final Map<String, dynamic> data;
    try {
      data = await _get(_studentUri(number));
    } on StudentLookupException catch (e) {
      // "No such student" is an answer, not a failure.
      if (e.code == 'student_not_found') return null;
      rethrow;
    }

    final student = data['student'];
    if (student is! Map<String, dynamic>) {
      throw const StudentLookupException('Response was missing the record.');
    }

    return _recordFrom(student);
  }

  @override
  Future<String> issueQrPayload(StudentNumber number) async {
    final data = await _get(Uri.parse('${_studentUri(number)}/qr'));

    final qr = data['qr'];
    if (qr is! Map<String, dynamic>) {
      throw const StudentLookupException('Response was missing the QR data.');
    }

    final payload = qr['payload'];
    if (payload is! String || payload.isEmpty) {
      throw const StudentLookupException('The server issued an empty QR code.');
    }

    return payload;
  }

  @override
  Future<TermsDocument> fetchTerms() async =>
      TermsDocument.fromJson(await _get(_endpoint('terms')));

  @override
  Future<void> acceptTerms(StudentNumber number) async {
    await _post(_endpoint('terms/accept'), {'student_no': number.value});
  }

  // ------------------------------------------------------------- transport

  Future<Map<String, dynamic>> _get(Uri uri) =>
      _send(() => _client.get(uri, headers: _headers));

  Future<Map<String, dynamic>> _post(Uri uri, Map<String, dynamic> body) =>
      _send(
        () => _client.post(
          uri,
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ),
      );

  /// Sends, unwraps the envelope, and turns every failure — wire or API — into
  /// a [StudentLookupException]. No caller has to think about status codes.
  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } catch (e) {
      throw StudentLookupException(
        'Could not reach the records service. ($e)',
        code: 'network',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      // The usual cause is a wrong API_BASE_URL: a host that answers with an
      // HTML page — a 404, a login wall, or a free-host anti-bot challenge.
      throw const StudentLookupException(
        'The server replied with a page instead of data. Check that '
        'API_BASE_URL points at /api/v1 and that the host allows non-browser '
        'requests.',
        code: 'bad_response',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const StudentLookupException(
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
      throw StudentLookupException(
        'Records service returned HTTP ${response.statusCode}.',
        code: 'unknown',
      );
    }

    throw StudentLookupException(
      error['message'] as String? ?? 'Something went wrong.',
      code: error['code'] as String? ?? 'unknown',
    );
  }

  /// Maps the API's field names onto the app's model.
  ///
  /// The two disagree on purpose: the database columns are `student_no` and
  /// `fullname`, while the model reads `student_number` and `full_name`. The
  /// translation happens here, once, rather than leaking column names into
  /// every widget.
  StudentRecord _recordFrom(Map<String, dynamic> student) {
    try {
      return StudentRecord.fromJson({
        'student_number': student['student_no'],
        'full_name': student['fullname'],
        'course': student['course'],
        'section': student['section'],
        // The API only ever returns students that exist in the enrolment
        // list, so reaching this point IS the verification.
        'verified': true,
      });
    } on FormatException catch (e) {
      throw StudentLookupException('Malformed record from the server. ($e)');
    } on TypeError {
      throw const StudentLookupException(
        'Record from the server was missing a required field.',
      );
    }
  }

  void dispose() => _client.close();
}
