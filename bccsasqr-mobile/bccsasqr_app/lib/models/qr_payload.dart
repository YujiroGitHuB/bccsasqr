import 'student_record.dart';

/// The exact string encoded into the QR image.
///
/// ⚠️ The app does not invent this string — the server issues it
/// (`GET /api/v1/students/{no}/qr`), and today it is the bare student number,
/// nothing else.
///
/// That is not a style choice. The attendance scanner rejects anything else:
/// `parseStudentFormat()` in `Qrscanner/js/scriptV3.js` tests the decoded text
/// against `^\d{3}-\d{3,4}$` and shows "This QR code is not a valid BCC student
/// QR" for everything that fails. An earlier version of this class encoded a
/// JSON envelope (`{"schema":"BCC-SASQR","v":1,"sn":…}`); every code it
/// produced would have been refused at the classroom door.
///
/// The name, course and section are deliberately *not* in the code. The
/// scanner looks them up from the database at scan time, so a copy inside the
/// QR would only be a second version that can go stale — a student who
/// transfers section would carry the old one on their phone.
class QrPayload {
  const QrPayload({
    required this.record,
    required this.data,
    required this.issuedAt,
  });

  final StudentRecord record;

  /// Exactly what the scanner will read. Server-issued; never built here.
  final String data;

  final DateTime issuedAt;

  factory QrPayload.issued(
    StudentRecord record,
    String data, {
    DateTime? issuedAt,
  }) => QrPayload(
    record: record,
    data: data,
    issuedAt: issuedAt ?? DateTime.now(),
  );

  /// What `QrImageView` renders.
  String encode() => data;

  @override
  String toString() => 'QrPayload($data)';
}
