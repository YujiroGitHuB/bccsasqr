/// What the scanner keeps on the phone so it can go on scanning with no
/// internet: the scans waiting to be sent, and the class lists they are
/// checked against. Read from `/api/v1/scanner/roster` and sent to
/// `/api/v1/scanner/sync`; see `includes/offline_scan.php` for the server's
/// side of it.
library;

import 'scanner_models.dart';

/// `2026-09-30`, from the phone's clock — the way the server files a date.
String scanDate(DateTime at) => '${at.year}-${_two(at.month)}-${_two(at.day)}';

/// `07:25:54 AM` — the server's `h:i:s A`, so a kept scan's time reads the
/// same as a sent one's.
String scanTime(DateTime at) {
  final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
  return '${_two(hour)}:${_two(at.minute)}:${_two(at.second)} '
      '${at.hour < 12 ? 'AM' : 'PM'}';
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Why the server would not take a kept scan, once it was sent. Final: the
/// scan is not sent again.
class ScanRejection {
  const ScanRejection({required this.code, required this.message});

  /// The same codes a live scan is refused with — `not_enrolled`,
  /// `student_not_found`, … — plus `too_old` and `bad_time`.
  final String code;

  /// Safe to show as it is.
  final String message;
}

/// One scan made with no internet, kept on this phone until the server has
/// answered for it.
class PendingScan {
  const PendingScan({
    required this.id,
    required this.userId,
    required this.studentNumber,
    required this.subjectCode,
    required this.subjectName,
    required this.scannedAt,
    this.late = false,
    this.name = '',
    this.course = '',
    this.section = '',
    this.photoMissing = false,
    this.rejection,
  });

  /// Made on the phone. The server answers each scan in a batch by it.
  final String id;

  /// Whose sign-in it was made under: only that account may send it.
  final int userId;
  final String studentNumber;
  final String subjectCode;
  final String subjectName;

  /// The phone's clock at the moment of the scan.
  final DateTime scannedAt;

  /// The late switch, as this phone knew it then.
  final bool late;

  /// From the class list, when there was one for the subject; blank when the
  /// scan was kept without one — the server fills them in when it is sent.
  final String name;
  final String course;
  final String section;
  final bool photoMissing;

  /// Set once the server has refused it; kept until the instructor has seen
  /// why.
  final ScanRejection? rejection;

  /// The student's name, or their number when the class list had not been
  /// downloaded.
  String get label => name.isEmpty ? studentNumber : name;

  PendingScan rejectedWith(ScanRejection why) => PendingScan(
    id: id,
    userId: userId,
    studentNumber: studentNumber,
    subjectCode: subjectCode,
    subjectName: subjectName,
    scannedAt: scannedAt,
    late: late,
    name: name,
    course: course,
    section: section,
    photoMissing: photoMissing,
    rejection: why,
  );

  /// How it shows under the camera and in the Attendance List until sent.
  ScanRecord toRecord() => ScanRecord(
    studentNumber: studentNumber,
    name: label,
    course: course,
    section: section,
    subject: subjectName,
    date: scanDate(scannedAt),
    timeIn: scanTime(scannedAt),
    late: late,
    pending: true,
    photoMissing: photoMissing,
  );

  /// One entry of `POST /scanner/sync`. The time goes as UTC with its `Z`,
  /// so the phone's own time zone setting never matters.
  Map<String, dynamic> toSyncJson() => {
    'id': id,
    'student_no': studentNumber,
    'subject_code': subjectCode,
    'scanned_at': scannedAt.toUtc().toIso8601String(),
    'late': late,
  };

  Map<String, dynamic> toJson() => {
    ...toSyncJson(),
    'user_id': userId,
    'subject_name': subjectName,
    'name': name,
    'course': course,
    'section': section,
    'photo_missing': photoMissing,
    if (rejection case final why?)
      'rejection': {'code': why.code, 'message': why.message},
  };

  /// Throws for anything [toJson] did not write.
  factory PendingScan.fromJson(Map<String, dynamic> json) {
    final why = json['rejection'];
    return PendingScan(
      id: json['id'] as String,
      userId: (json['user_id'] as num).toInt(),
      studentNumber: json['student_no'] as String,
      subjectCode: json['subject_code'] as String,
      subjectName: json['subject_name'] as String? ?? '',
      scannedAt: DateTime.parse(json['scanned_at'] as String).toLocal(),
      late: json['late'] == true,
      name: json['name'] as String? ?? '',
      course: json['course'] as String? ?? '',
      section: json['section'] as String? ?? '',
      photoMissing: json['photo_missing'] == true,
      rejection: why is Map<String, dynamic>
          ? ScanRejection(
              code: why['code'] as String? ?? 'unknown',
              message: why['message'] as String? ?? '',
            )
          : null,
    );
  }
}

/// One student on a subject's class list.
class RosterStudent {
  const RosterStudent({
    required this.studentNumber,
    required this.name,
    this.course = '',
    this.section = '',
    this.hasPhoto = true,
  });

  factory RosterStudent.fromJson(Map<String, dynamic> json) => RosterStudent(
    studentNumber: json['student_no'] as String,
    name: json['name'] as String? ?? '',
    course: json['course'] as String? ?? '',
    section: json['section'] as String? ?? '',
    hasPhoto: json['photo'] != false,
  );

  final String studentNumber;
  final String name;
  final String course;
  final String section;

  /// Whether one is on file — never the photo itself.
  final bool hasPhoto;

  Map<String, dynamic> toJson() => {
    'student_no': studentNumber,
    'name': name,
    'course': course,
    'section': section,
    'photo': hasPhoto,
  };
}

/// Who is enrolled in one subject, as the server said on [date]. What an
/// offline scan is checked against, so it still names the student and still
/// refuses one from another class.
class SubjectRoster {
  const SubjectRoster({
    required this.subjectCode,
    required this.date,
    required this.students,
    this.photoRequired = false,
  });

  factory SubjectRoster.fromJson(Map<String, dynamic> json) {
    final list = json['students'];
    return SubjectRoster(
      subjectCode: json['subject_code'] as String,
      date: json['date'] as String? ?? '',
      photoRequired: json['photo_required'] == true,
      students: {
        if (list is List)
          for (final s in list)
            if (s is Map<String, dynamic>)
              s['student_no'] as String: RosterStudent.fromJson(s),
      },
    );
  }

  final String subjectCode;

  /// The server's date when it was downloaded. One from an earlier day is
  /// downloaded again when there is internet.
  final String date;

  /// The Settings switch that refuses a student with no photo on file.
  final bool photoRequired;

  /// By student number.
  final Map<String, RosterStudent> students;

  Map<String, dynamic> toJson() => {
    'subject_code': subjectCode,
    'date': date,
    'photo_required': photoRequired,
    'students': [for (final s in students.values) s.toJson()],
  };
}

/// What the server did with one kept scan.
enum SyncStatus {
  /// Stored.
  saved,

  /// Already in — sent before with the answer lost, or scanned on the web.
  alreadyMarked,

  /// Refused for good.
  rejected,

  /// Not this time; sent again later.
  error,
}

/// The server's answer for one scan in a `POST /scanner/sync`.
class SyncOutcome {
  const SyncOutcome({
    required this.id,
    required this.status,
    this.record,
    this.rejection,
  });

  factory SyncOutcome.fromJson(Map<String, dynamic> json) {
    final status = switch (json['status']) {
      'saved' => SyncStatus.saved,
      'already_marked' => SyncStatus.alreadyMarked,
      'rejected' => SyncStatus.rejected,
      _ => SyncStatus.error,
    };
    final record = json['record'];
    return SyncOutcome(
      id: json['id'] as String,
      status: status,
      record: record is Map<String, dynamic>
          ? ScanRecord.fromJson(record)
          : null,
      rejection: status == SyncStatus.rejected
          ? ScanRejection(
              code: json['code'] as String? ?? 'unknown',
              message: json['message'] as String? ?? 'Not saved.',
            )
          : null,
    );
  }

  final String id;
  final SyncStatus status;

  /// For [SyncStatus.saved]: the row as stored.
  final ScanRecord? record;

  /// For [SyncStatus.rejected].
  final ScanRejection? rejection;
}
