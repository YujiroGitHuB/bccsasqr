/// A student's attendance, as the web Attendance Tracker (`Tracker/view.php`)
/// shows it: who they are, the three numbers at the top, and every subject
/// with its dates.
///
/// Built from `GET /api/v1/students/{no}/attendance`, whose rules live in
/// `includes/attendance_history.php` — the file the web tracker reads too, so
/// the phone and the browser cannot count differently.
class AttendanceHistory {
  const AttendanceHistory({
    required this.studentNumber,
    required this.fullName,
    required this.course,
    required this.section,
    this.photoUrl,
    required this.total,
    this.lastAttended,
    this.subjects = const [],
  });

  final String studentNumber;
  final String fullName;
  final String course;
  final String section;

  /// `null` without a photo on file — the avatar falls back to initials.
  final String? photoUrl;

  /// How many times the student was marked present, across every subject.
  final int total;
  final DateTime? lastAttended;

  /// In name order; each one's days newest first.
  final List<SubjectAttendance> subjects;

  /// The record exists, but no scan has been logged for it yet.
  bool get isEmpty => total == 0;

  String get courseAndSection =>
      [course, section].where((part) => part.trim().isNotEmpty).join(' — ');

  factory AttendanceHistory.fromJson(Map<String, dynamic> json) {
    final student = json['student'];
    if (student is! Map<String, dynamic>) {
      throw const FormatException('Missing student in attendance history');
    }
    final summary = json['summary'];
    final subjects = json['subjects'];

    return AttendanceHistory(
      studentNumber: _string(student['student_no']),
      fullName: _string(student['fullname']),
      course: _string(student['course']),
      section: _string(student['section']),
      photoUrl: switch (student['photo_url']) {
        final String url when url.isNotEmpty => url,
        _ => null,
      },
      total: summary is Map<String, dynamic> && summary['total'] is int
          ? summary['total'] as int
          : 0,
      lastAttended: summary is Map<String, dynamic>
          ? _date(summary['last_attended'])
          : null,
      subjects: [
        if (subjects is List)
          for (final subject in subjects)
            if (subject is Map<String, dynamic>)
              SubjectAttendance.fromJson(subject),
      ],
    );
  }
}

/// One subject's card: the instructor, the count and the days.
class SubjectAttendance {
  const SubjectAttendance({
    required this.subject,
    required this.instructor,
    required this.count,
    this.days = const [],
  });

  final String subject;
  final String instructor;
  final int count;

  /// Newest first.
  final List<AttendanceDay> days;

  factory SubjectAttendance.fromJson(Map<String, dynamic> json) {
    final records = json['records'];
    final days = [
      if (records is List)
        for (final record in records)
          if (record is Map<String, dynamic>) AttendanceDay.fromJson(record),
    ];

    return SubjectAttendance(
      subject: _string(json['subject'], fallback: 'No Subject'),
      instructor: _string(json['instructor'], fallback: 'N/A'),
      count: json['count'] is int ? json['count'] as int : days.length,
      days: days,
    );
  }
}

/// One scan: the day, and the time the scanner stored.
class AttendanceDay {
  const AttendanceDay({
    required this.date,
    required this.rawDate,
    required this.timeIn,
    this.late = false,
  });

  /// `null` only when the server sent something that is not a date; the row
  /// then shows [rawDate] as it came.
  final DateTime? date;
  final String rawDate;

  /// As the scanner stored it — `08:04:12 AM`.
  final String timeIn;
  final bool late;

  factory AttendanceDay.fromJson(Map<String, dynamic> json) {
    final raw = _string(json['date']);
    return AttendanceDay(
      date: _date(raw),
      rawDate: raw,
      timeIn: _string(json['time_in']),
      late: json['late'] == true,
    );
  }
}

String _string(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

/// `2026-09-27` → a date. Read as a calendar day, not an instant: no time
/// zone may move it to the day before.
DateTime? _date(Object? value) {
  if (value is! String) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
  if (match == null) return null;
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}
