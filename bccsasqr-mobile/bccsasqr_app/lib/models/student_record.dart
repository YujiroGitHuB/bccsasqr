import 'package:flutter/foundation.dart';

import '../core/utils/student_number.dart';
import 'record_warning.dart';

/// A verified enrolment record — the model behind the NAME / COURSE / SECTION
/// rows and the payload that gets encoded into the QR code.
class StudentRecord {
  const StudentRecord({
    required this.studentNumber,
    required this.fullName,
    required this.course,
    required this.section,
    this.verified = true,
    this.warnings = const [],
  });

  final StudentNumber studentNumber;
  final String fullName;
  final String course;
  final String section;
  final bool verified;

  /// What the server flagged about this record — see [RecordWarning]. Empty
  /// for a student with nothing left to sort out.
  final List<RecordWarning> warnings;

  factory StudentRecord.fromJson(Map<String, dynamic> json) {
    final parsed = StudentNumber.tryParse(json['student_number'] as String);
    if (parsed == null) {
      throw const FormatException('Malformed student_number in record');
    }
    return StudentRecord(
      studentNumber: parsed,
      fullName: json['full_name'] as String,
      course: json['course'] as String,
      section: json['section'] as String,
      verified: json['verified'] as bool? ?? true,
      warnings: RecordWarning.listFrom(json['warnings']),
    );
  }

  Map<String, dynamic> toJson() => {
    'student_number': studentNumber.value,
    'full_name': fullName,
    'course': course,
    'section': section,
    'verified': verified,
    if (warnings.isNotEmpty) 'warnings': [for (final w in warnings) w.toJson()],
  };

  /// Filename-safe stem used when the QR image is written to disk.
  String get fileStem =>
      'BCC-SASQR-${studentNumber.value}-'
      '${fullName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')}';

  @override
  bool operator ==(Object other) =>
      other is StudentRecord &&
      other.studentNumber == studentNumber &&
      other.fullName == fullName &&
      other.course == course &&
      other.section == section &&
      other.verified == verified &&
      listEquals(other.warnings, warnings);

  @override
  int get hashCode => Object.hash(
    studentNumber,
    fullName,
    course,
    section,
    verified,
    Object.hashAll(warnings),
  );
}
