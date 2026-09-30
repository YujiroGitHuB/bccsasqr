/// The shapes the scanner works with, read from `/api/v1/auth/*` and
/// `/api/v1/scanner/*`. The field names on the wire are the database's
/// (`student_no`, `time_in`); the translation to Dart names happens in the
/// `fromJson` constructors, once.
library;

/// The instructor or admin behind the camera.
class ScannerUser {
  const ScannerUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
  });

  factory ScannerUser.fromJson(Map<String, dynamic> json) => ScannerUser(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String,
    email: json['email'] as String? ?? '',
    role: json['role'] as String? ?? 'instructor',
    avatarUrl: json['avatar_url'] as String?,
  );

  final int id;
  final String name;
  final String email;
  final String role;
  final String? avatarUrl;

  /// An admin may scan for every subject, as on the web.
  bool get isAdmin => role == 'admin';

  /// The wire's own shape, so [ScannerUser.fromJson] reads it back — how the
  /// offline store keeps it.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role,
    'avatar_url': avatarUrl,
  };
}

/// One entry in the subject picker.
class ScanSubject {
  const ScanSubject({
    required this.code,
    required this.name,
    this.lateMarking = false,
  });

  factory ScanSubject.fromJson(Map<String, dynamic> json) => ScanSubject(
    code: json['code'] as String,
    name: json['name'] as String,
    lateMarking: json['late'] == true,
  );

  final String code;
  final String name;

  /// Whether scans for this subject are being saved as late today. The
  /// switch is per instructor and per subject, and off again tomorrow — the
  /// server decides, see `includes/late.php`.
  final bool lateMarking;

  /// "Object Oriented Programming (ITE211)" — the web picker's wording.
  String get label => '$name ($code)';

  ScanSubject copyWith({bool? lateMarking}) => ScanSubject(
    code: code,
    name: name,
    lateMarking: lateMarking ?? this.lateMarking,
  );

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'late': lateMarking,
  };

  @override
  bool operator ==(Object other) => other is ScanSubject && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// What `GET /scanner/subjects` answers: who is signed in, the subjects they
/// may scan for, and the server's date — the one the records are filed under.
typedef SubjectList = ({
  ScannerUser user,
  List<ScanSubject> subjects,
  String date,
});

/// One row of the Attendance List.
class AttendanceEntry {
  const AttendanceEntry({
    required this.studentNumber,
    required this.name,
    required this.course,
    required this.section,
    required this.subject,
    required this.date,
    required this.timeIn,
    this.late = false,
    this.pending = false,
  });

  factory AttendanceEntry.fromJson(Map<String, dynamic> json) =>
      AttendanceEntry(
        studentNumber: json['student_no'] as String,
        name: json['name'] as String? ?? '',
        course: json['course'] as String? ?? '',
        section: json['section'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        date: json['date'] as String? ?? '',
        timeIn: json['time_in'] as String? ?? '',
        late: json['late'] == true,
      );

  final String studentNumber;
  final String name;
  final String course;
  final String section;
  final String subject;

  /// As stored — `2026-09-27`.
  final String date;

  /// As stored — `07:25:54 AM`, the server's clock. A scan kept on the phone
  /// while offline carries the phone's instead, and so does its row once
  /// sent (see `includes/offline_scan.php`).
  final String timeIn;
  final bool late;

  /// Kept on this phone, not yet on the server — scanned with no internet.
  final bool pending;

  /// "BSIT — 2G", leaving out whichever half is blank.
  String get courseAndSection =>
      [course, section].where((s) => s.trim().isNotEmpty).join(' — ');
}

/// A scan the server accepted: the stored row, plus what the result card
/// needs to show a face. Or one kept on the phone with no internet, [pending]
/// until it is sent (`PendingScan.toRecord`).
class ScanRecord extends AttendanceEntry {
  const ScanRecord({
    required super.studentNumber,
    required super.name,
    required super.course,
    required super.section,
    required super.subject,
    required super.date,
    required super.timeIn,
    super.late,
    super.pending,
    this.photoUrl,
    this.photoMissing = false,
  });

  factory ScanRecord.fromJson(Map<String, dynamic> json) {
    final entry = AttendanceEntry.fromJson(json);
    return ScanRecord(
      studentNumber: entry.studentNumber,
      name: entry.name,
      course: entry.course,
      section: entry.section,
      subject: entry.subject,
      date: entry.date,
      timeIn: entry.timeIn,
      late: entry.late,
      photoUrl: json['photo_url'] as String?,
      photoMissing: json['photo_missing'] == true,
    );
  }

  final String? photoUrl;

  /// Recorded, but there is no photo on file — the instructor cannot confirm
  /// the person holding the QR is its owner. The web scanner says so in amber.
  final bool photoMissing;
}
