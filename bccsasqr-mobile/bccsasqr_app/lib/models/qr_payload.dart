import 'dart:ui' show Color;

import 'student_record.dart';

/// Everything needed to draw and save one student's QR card, as issued by
/// `GET /api/v1/students/{no}/qr`.
///
/// ⚠️ The app does not invent any of this — the server issues it, and today
/// the encoded string is the bare student number, nothing else.
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
/// transfers section would carry the old one on their phone. They are printed
/// *under* the code instead, from [details].
class QrPayload {
  const QrPayload({
    required this.data,
    required this.details,
    required this.fileName,
    this.spec = const QrSpec(),
  });

  /// What the demo repository issues, and the fallback when a server sends no
  /// `card`: the same rows, casing and file name `api/v1` would have sent (see
  /// `gen_qr_resource()` in `api/v1/lib/generator.php`).
  factory QrPayload.forRecord(StudentRecord record) {
    final number = record.studentNumber.value;
    return QrPayload(
      data: number,
      details: [
        (label: 'Student No.', value: number),
        (label: 'Name', value: record.fullName.trim()),
        (label: 'Course', value: record.course.trim().toUpperCase()),
        (label: 'Section', value: record.section.trim().toUpperCase()),
      ],
      fileName: safeFileName('${number}_qr.png'),
    );
  }

  /// Exactly what the scanner will read. Server-issued; never built here.
  final String data;

  /// The label/value rows printed under the code, in order.
  final List<QrCardRow> details;

  /// What the saved PNG is called — the same name the web page downloads.
  final String fileName;

  final QrSpec spec;

  /// What `QrImageView` renders.
  String encode() => data;

  /// The server's file name made safe to write to disk: no folders, no
  /// surprises, always a `.png`.
  static String safeFileName(String raw) {
    final stem = raw
        .replaceAll(RegExp(r'\.png$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '');
    return '${stem.isEmpty ? 'qr' : stem}.png';
  }

  @override
  String toString() => 'QrPayload($data)';
}

/// One label/value line printed on the card.
typedef QrCardRow = ({String label, String value});

/// How the code must be drawn — `qr.spec` from the server.
///
/// The browser draws with the same values (`QRgenerator/js/scriptv2.js`), so a
/// code saved from the app and one downloaded from the web page are the same
/// picture. The defaults ARE the web's values, and are only used for a field
/// the server leaves out or sends malformed.
class QrSpec {
  const QrSpec({
    this.size = 250,
    this.errorCorrection = 'M',
    this.foreground = const Color(0xFF38BDF8),
    this.background = const Color(0xFF0F172A),
  });

  factory QrSpec.fromJson(Object? json) {
    const web = QrSpec();
    if (json is! Map<String, dynamic>) return web;

    final size = json['size'];
    final level = json['error_correction'];

    return QrSpec(
      size: size is num && size >= 100 && size <= 1000
          ? size.toDouble()
          : web.size,
      errorCorrection: level is String && _levels.contains(level)
          ? level
          : web.errorCorrection,
      foreground: _hex(json['foreground']) ?? web.foreground,
      background: _hex(json['background']) ?? web.background,
    );
  }

  static const _levels = {'L', 'M', 'Q', 'H'};

  /// Side of the code in logical pixels — the web's canvas pixels.
  final double size;

  /// `L`, `M`, `Q` or `H`.
  final String errorCorrection;

  /// The modules. Light on dark, like the web page: the attendance scanner
  /// (jsQR, `attemptBoth`) reads inverted codes.
  final Color foreground;

  /// Behind the code AND behind the whole card. If the two ever differ, a
  /// visible square seam appears around the code.
  final Color background;

  static Color? _hex(Object? value) {
    if (value is! String) return null;
    final match = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(value);
    if (match == null) return null;
    return Color(0xFF000000 | int.parse(match[1]!, radix: 16));
  }
}
