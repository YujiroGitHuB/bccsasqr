import 'package:flutter/foundation.dart';

/// The class behind an attendance link, as Check in shows it before the
/// student confirms — `GET /api/v1/checkin/{code}`.
///
/// Every time is the server's: the labels are its clock's, and `in` counts
/// seconds from its now, so the phone's clock never decides whether a
/// student is late.
@immutable
class ClassLink {
  const ClassLink({
    required this.shortCode,
    required this.subjectCode,
    required this.subjectName,
    required this.section,
    required this.instructor,
    this.closesLabel,
    this.lateOn = false,
    this.lateLabel,
    this.lateIn,
  });

  final String shortCode;
  final String subjectCode;
  final String subjectName;
  final String section;
  final String instructor;

  /// "9:00 AM" — when the link stops taking check-ins. Null: it does not
  /// close on its own.
  final String? closesLabel;

  /// A late cutoff is set for today; [lateLabel] is its last on-time minute.
  final bool lateOn;
  final String? lateLabel;

  /// Seconds until check-ins count as late, from the server's now.
  final int? lateIn;

  /// Checking in now would be marked late.
  bool get lateNow => lateOn && (lateIn ?? 1) <= 0;

  factory ClassLink.fromJson(Map<String, dynamic> json) {
    final subject = json['subject'];
    final closes = json['closes'];
    final late = json['late'];
    String text(Object? v) => v is String ? v.trim() : '';
    String? label(Object? map) =>
        map is Map<String, dynamic> && map['label'] is String
        ? (map['label'] as String).trim()
        : null;

    return ClassLink(
      shortCode: text(json['short_code']),
      subjectCode: subject is Map<String, dynamic> ? text(subject['code']) : '',
      subjectName: subject is Map<String, dynamic> ? text(subject['name']) : '',
      section: text(json['section']),
      instructor: text(json['instructor']),
      closesLabel: label(closes),
      lateOn: late is Map<String, dynamic> && late['on'] == true,
      lateLabel: label(late),
      lateIn: late is Map<String, dynamic> && late['in'] is int
          ? late['in'] as int
          : null,
    );
  }

  /// The code in what the camera read: the link's address
  /// (`…/pages/daily_attendance.php?c=K7P2QX`, what the class QR holds) or
  /// the bare code. Null for anything else — a student's own QR, say.
  static String? codeFrom(String scanned) {
    final text = scanned.trim();
    if (_code.hasMatch(text)) return text.toUpperCase();

    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme) return null;
    final code = uri.queryParameters['c'];
    return code != null && _code.hasMatch(code) ? code : null;
  }

  /// link_generate_code()'s six, and a little wider for an older link —
  /// the server's own check (api/v1/handlers/checkin.php).
  static final RegExp _code = RegExp(r'^[A-Za-z0-9]{4,16}$');
}

/// A check-in the records took — `POST /api/v1/checkin/{code}`.
@immutable
class CheckInResult {
  const CheckInResult({
    required this.subject,
    required this.timeIn,
    required this.late,
    required this.message,
  });

  final String subject;

  /// As the server stored it — `08:04:12 AM`.
  final String timeIn;
  final bool late;

  /// The web form's sentence, safe to show as it is.
  final String message;
}
