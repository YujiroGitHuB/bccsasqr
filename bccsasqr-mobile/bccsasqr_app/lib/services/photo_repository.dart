import 'dart:typed_data';

import '../core/utils/student_number.dart';
import '../models/student_profile.dart';
import 'student_repository.dart';

/// My Profile's half of the API: the web's photo page
/// (`student/StudentPhotoProfile.php`) as calls. Failures are
/// [StudentLookupException]s, as for the rest of the student side.
abstract interface class StudentPhotoRepository {
  /// Step 1: the record, for someone who knows its last name. A wrong number
  /// and a wrong name are both `identity_mismatch`.
  Future<PhotoOwner> verifyOwner(StudentNumber number, String lastName);

  /// The record and photo as they are now — no last name, like the
  /// generator's lookup. For a profile already on the phone.
  Future<PhotoOwner> fetchOwner(StudentNumber number);

  /// Step 2: saves [jpeg] as this student's photo. Answers with the new link.
  Future<PhotoOwner> uploadPhoto(
    StudentNumber number,
    String lastName,
    Uint8List jpeg,
  );

  /// The photo at [url], to keep on the phone.
  Future<Uint8List> downloadPhoto(String url);
}

/// Demo mode: the bundled sample records, whose last name is the part before
/// the comma — or, with none, the last word ("Maria Isabel Santos" →
/// Santos). An upload is accepted and kept nowhere but the profile: there is
/// no server to hold it, so it has no link.
class InMemoryPhotoRepository implements StudentPhotoRepository {
  InMemoryPhotoRepository({
    required this.records,
    this.latency = const Duration(milliseconds: 650),
  });

  /// Where the sample records come from — the generator's demo list.
  final StudentRepository records;
  final Duration latency;

  static String lastNameOf(String fullName) {
    final comma = fullName.indexOf(',');
    final last = comma >= 0
        ? fullName.substring(0, comma)
        : fullName.trim().split(RegExp(r'\s+')).last;
    return last.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
  }

  Future<PhotoOwner> _owner(StudentNumber number) async {
    final record = await records.findByStudentNumber(number);
    if (record == null) {
      throw const StudentLookupException(
        'Incorrect student number or last name. Use the spelling on your '
        'school record.',
        code: 'identity_mismatch',
      );
    }
    return (record: record, photoUrl: null, required: false);
  }

  @override
  Future<PhotoOwner> verifyOwner(StudentNumber number, String lastName) async {
    final owner = await _owner(number);
    final typed = lastName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (typed.toUpperCase() != lastNameOf(owner.record.fullName)) {
      throw const StudentLookupException(
        'Incorrect student number or last name. Use the spelling on your '
        'school record.',
        code: 'identity_mismatch',
      );
    }
    return owner;
  }

  @override
  Future<PhotoOwner> fetchOwner(StudentNumber number) => _owner(number);

  @override
  Future<PhotoOwner> uploadPhoto(
    StudentNumber number,
    String lastName,
    Uint8List jpeg,
  ) async {
    final owner = await verifyOwner(number, lastName);
    await Future<void>.delayed(latency);
    return owner;
  }

  @override
  Future<Uint8List> downloadPhoto(String url) async =>
      throw const StudentLookupException('No photos in demo mode.');
}
