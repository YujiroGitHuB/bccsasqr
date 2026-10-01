import 'package:flutter/foundation.dart';

import 'attendance_history.dart';

/// One record the phone had not seen: an instructor's scan, a check-in
/// through a link, or a scan the instructor's phone kept with no signal and
/// sent later.
@immutable
class LiveRecord {
  const LiveRecord({
    required this.id,
    required this.subject,
    required this.instructor,
    required this.day,
    this.offline = false,
  });

  /// The record's id on the server — what the next look starts after.
  final int id;
  final String subject;
  final String instructor;

  /// The day and the time the scanner stored, as My Attendance lists them.
  final AttendanceDay day;

  /// Sent later from the instructor's phone: [day] is when it was scanned,
  /// not when the server heard of it.
  final bool offline;

  /// Throws a [FormatException] for a record with no id.
  factory LiveRecord.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! int) throw const FormatException('Live record without an id');
    final subject = json['subject']?.toString().trim() ?? '';
    final instructor = json['instructor']?.toString().trim() ?? '';
    return LiveRecord(
      id: id,
      // The tracker's fallbacks (AttendanceHistory), so the record is filed
      // under the subject My Attendance already shows.
      subject: subject.isEmpty ? 'No Subject' : subject,
      instructor: instructor.isEmpty ? 'N/A' : instructor,
      day: AttendanceDay.fromJson(json),
      offline: json['offline'] == true,
    );
  }
}

/// What `POST /students/{no}/live` answers: how far the student's record
/// goes, and what is new on it since the phone last looked.
@immutable
class LiveUpdate {
  const LiveUpdate({
    required this.cursor,
    required this.count,
    this.records = const [],
    this.more = false,
  });

  /// The newest record's id, 0 with none: where the next look starts.
  final int cursor;

  /// Every record of the student's. Fewer than the last count and the new
  /// records together means one was deleted.
  final int count;

  /// Newer than the look before, newest first. Empty on a first look.
  final List<LiveRecord> records;

  /// There were more new records than came back.
  final bool more;

  factory LiveUpdate.fromJson(Map<String, dynamic> json) {
    final cursor = json['cursor'];
    final count = json['count'];
    if (cursor is! int || count is! int) {
      throw const FormatException('Live update without a cursor');
    }
    final records = json['records'];
    return LiveUpdate(
      cursor: cursor,
      count: count,
      records: [
        if (records is List)
          for (final record in records)
            if (record is Map<String, dynamic> && record['id'] is int)
              LiveRecord.fromJson(record),
      ],
      more: json['more'] == true,
    );
  }
}
