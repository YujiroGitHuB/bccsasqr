/// A student's attendance, as the web Attendance Tracker (`Tracker/view.php`)
/// shows it: who they are, the numbers at the top, and every subject with its
/// dates — and, since 2026-10-02, the days each enrolled subject's class met
/// without them.
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
    this.classes,
    this.absences,
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

  /// In name order; each one's days newest first. The subjects the student
  /// is enrolled in are here even before their first scan in one.
  final List<SubjectAttendance> subjects;

  /// Class days so far across the enrolled subjects, and how many of them the
  /// student missed. Null when the server could not count them — no
  /// enrollment on file, or a server from before absences were counted — and
  /// the screens then show the days present alone, as they used to.
  final int? classes;
  final int? absences;

  /// Absences were counted for this student.
  bool get countsAbsences => absences != null;

  /// The record exists, but no scan has been logged for it yet.
  bool get isEmpty => total == 0;

  String get courseAndSection =>
      [course, section].where((part) => part.trim().isNotEmpty).join(' — ');

  /// The server's own shape, so the copy kept on the phone
  /// (attendance_store.dart) is read back by [AttendanceHistory.fromJson],
  /// the one parser.
  Map<String, dynamic> toJson() => {
    'student': {
      'student_no': studentNumber,
      'fullname': fullName,
      'course': course,
      'section': section,
      'photo_url': photoUrl,
    },
    'summary': {
      'total': total,
      'subjects': subjects.length,
      'last_attended': switch (lastAttended) {
        final d? => _ymd(d),
        null => null,
      },
      'classes': classes,
      'absences': absences,
    },
    'subjects': [for (final subject in subjects) subject.toJson()],
  };

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
      classes: summary is Map<String, dynamic> && summary['classes'] is int
          ? summary['classes'] as int
          : null,
      absences: summary is Map<String, dynamic> && summary['absences'] is int
          ? summary['absences'] as int
          : null,
    );
  }
}

/// One subject's card: the instructor, the count and the days — and, for a
/// subject the student is enrolled in, its class and the days missed.
class SubjectAttendance {
  const SubjectAttendance({
    required this.subject,
    required this.instructor,
    required this.count,
    this.days = const [],
    this.section = '',
    this.enrolled = false,
    this.classes,
    this.absentDates = const [],
  });

  final String subject;

  /// Whoever scanned the student — or, in a subject they were never scanned
  /// in, whoever scanned the class last. Empty when nobody has yet.
  final String instructor;
  final int count;

  /// Newest first.
  final List<AttendanceDay> days;

  /// The class's section — "2A" — for an enrolled subject; empty for any
  /// other. An irregular student's differs from the one on their record.
  final String section;

  /// In the student's enrollment, so listed even before their first scan.
  final bool enrolled;

  /// Days the class met so far — today only once the student is marked in
  /// it, a student still in line is not absent. Null when absences are not
  /// counted for this subject: one the student is no longer enrolled in.
  final int? classes;

  /// Days the class met without the student, newest first.
  final List<DateTime> absentDates;

  /// How many of [classes] were missed; null when not counted.
  int? get absences => classes == null ? null : absentDates.length;

  /// How many of [classes] the student was there for.
  int? get attended => switch (classes) {
    final held? => held - absentDates.length,
    null => null,
  };

  /// Every day of the class, newest first: the days present and the days
  /// missed in one list, so a missed day reads where it fell.
  List<ClassDay> get classDays {
    final all = <ClassDay>[];
    var missed = 0;
    for (final day in days) {
      final date = day.date;
      while (missed < absentDates.length &&
          date != null &&
          absentDates[missed].isAfter(date)) {
        all.add(ClassDay(date: absentDates[missed++]));
      }
      all.add(ClassDay(date: date, present: day));
    }
    while (missed < absentDates.length) {
      all.add(ClassDay(date: absentDates[missed++]));
    }
    return all;
  }

  Map<String, dynamic> toJson() => {
    'subject': subject,
    'instructor': instructor,
    'count': count,
    'records': [for (final day in days) day.toJson()],
    'enrolled': enrolled,
    'section': section.isEmpty ? null : section,
    'classes': classes,
    'absences': absences,
    'absent_dates': [for (final day in absentDates) _ymd(day)],
  };

  factory SubjectAttendance.fromJson(Map<String, dynamic> json) {
    final records = json['records'];
    final days = [
      if (records is List)
        for (final record in records)
          if (record is Map<String, dynamic>) AttendanceDay.fromJson(record),
    ];
    final absent = json['absent_dates'];

    return SubjectAttendance(
      subject: _string(json['subject'], fallback: 'No Subject'),
      // Empty from the server means nobody has scanned the class yet; the
      // old fallback stays for a missing one.
      instructor: json['instructor'] is String
          ? (json['instructor'] as String).trim()
          : 'N/A',
      count: json['count'] is int ? json['count'] as int : days.length,
      days: days,
      section: _string(json['section']),
      enrolled: json['enrolled'] == true,
      classes: json['classes'] is int ? json['classes'] as int : null,
      absentDates: [
        if (absent is List)
          for (final day in absent) ?_date(day),
      ]..sort((a, b) => b.compareTo(a)),
    );
  }
}

/// One day of a subject's class, as My Attendance lists them: a day the
/// student was marked [present], or one the class met without them.
class ClassDay {
  const ClassDay({required this.date, this.present});

  /// `null` only for a scan whose date the server sent as something else.
  final DateTime? date;

  /// The scan, on a day the student was there.
  final AttendanceDay? present;

  bool get absent => present == null;
  bool get late => present?.late ?? false;
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

  Map<String, dynamic> toJson() => {
    'date': rawDate,
    'time_in': timeIn,
    'late': late,
  };

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

/// A day as the server writes one — `2026-09-27`.
String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

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
