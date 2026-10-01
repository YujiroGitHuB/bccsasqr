import 'package:flutter/foundation.dart';

import 'attendance_history.dart';

/// What a notification says happened to the student's record.
enum NoticeKind {
  /// A new record, on time.
  present,

  /// A new record, marked late.
  late,

  /// A record the student had is gone — an instructor deleted it.
  removed,
}

/// One entry in Notifications: something that happened to the student's
/// attendance, told the moment the phone heard of it.
///
/// Kept on the phone (notice_store.dart) — the server keeps no list of what
/// a phone was told.
@immutable
class StudentNotice {
  const StudentNotice({
    required this.id,
    required this.kind,
    required this.subject,
    required this.day,
    required this.at,
    this.instructor = '',
    this.offline = false,
    this.read = false,
  });

  /// `r<record id>` for a new record, so the same one is never told twice.
  final String id;
  final NoticeKind kind;
  final String subject;
  final String instructor;

  /// The record's day and time.
  final AttendanceDay day;

  /// When the phone heard of it.
  final DateTime at;

  /// The instructor's phone kept the scan with no signal and sent it later.
  final bool offline;

  final bool read;

  /// The notice for a new record [id].
  static String recordId(int id) => 'r$id';

  StudentNotice markRead() => read
      ? this
      : StudentNotice(
          id: id,
          kind: kind,
          subject: subject,
          instructor: instructor,
          day: day,
          at: at,
          offline: offline,
          read: true,
        );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'subject': subject,
    'instructor': instructor,
    'date': day.rawDate,
    'time_in': day.timeIn,
    'late': day.late,
    'at': at.toIso8601String(),
    'offline': offline,
    'read': read,
  };

  /// Throws a [FormatException] for anything [toJson] did not write.
  factory StudentNotice.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final kind = NoticeKind.values
        .where((k) => k.name == json['kind'])
        .firstOrNull;
    final subject = json['subject'];
    final at = DateTime.tryParse(json['at']?.toString() ?? '');
    if (id is! String || kind == null || subject is! String || at == null) {
      throw const FormatException('Malformed notice');
    }
    return StudentNotice(
      id: id,
      kind: kind,
      subject: subject,
      instructor: json['instructor'] as String? ?? '',
      day: AttendanceDay.fromJson(json),
      at: at,
      offline: json['offline'] == true,
      read: json['read'] == true,
    );
  }
}
