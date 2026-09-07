import '../core/utils/student_number.dart';

/// A verified enrolment record — the model behind the NAME / COURSE / SECTION
/// rows and the payload that gets encoded into the QR code.
class StudentRecord {
  const StudentRecord({
    required this.studentNumber,
    required this.fullName,
    required this.course,
    required this.section,
    this.verified = true,
  });

  final StudentNumber studentNumber;
  final String fullName;
  final String course;
  final String section;
  final bool verified;

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
    );
  }

  Map<String, dynamic> toJson() => {
    'student_number': studentNumber.value,
    'full_name': fullName,
    'course': course,
    'section': section,
    'verified': verified,
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
      other.verified == verified;

  @override
  int get hashCode =>
      Object.hash(studentNumber, fullName, course, section, verified);
}
