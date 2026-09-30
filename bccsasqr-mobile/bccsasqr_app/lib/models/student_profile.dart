import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'student_record.dart';

/// A record and the photo on file for it, as the server answers
/// `/students/{no}`, `/verify` and `/photo`.
typedef PhotoOwner = ({StudentRecord record, String? photoUrl, bool required});

/// The student this phone belongs to, once they have proved it with their
/// last name: My Profile, and the face on the home screen.
///
/// Kept on the phone so the home screen greets them by name and shows their
/// photo offline. The photo itself is kept too — the bytes, not only the
/// link — for the same reason.
@immutable
class StudentProfile {
  const StudentProfile({
    required this.record,
    required this.lastName,
    this.photoUrl,
    this.photo,
    this.photoRequired = false,
  });

  final StudentRecord record;

  /// As the student typed it and the server accepted it. Every new photo is
  /// sent with it again: the API keeps no session between the two steps.
  final String lastName;

  /// Where the server serves the photo, stamped with its time — a new photo
  /// gets a new link.
  final String? photoUrl;

  /// The photo, for showing it with no internet. Null while it has not been
  /// downloaded yet, or when there is none.
  final Uint8List? photo;

  /// Settings → Student Photo Requirement on the web: without a photo, the
  /// scanner refuses this student.
  final bool photoRequired;

  bool get hasPhoto => photo != null || photoUrl != null;

  /// "DELA CRUZ, JUAN CARLO P." → "Juan Carlo": the name the home screen
  /// greets them by. The school keeps names surname first; a name with no
  /// comma is taken to start with the given name.
  String get givenName => givenNameOf(record.fullName);

  static String givenNameOf(String fullName) {
    final comma = fullName.indexOf(',');
    final given = comma >= 0 ? fullName.substring(comma + 1) : fullName;
    final words = given
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (comma < 0 && words.length > 1) words.removeRange(1, words.length);
    // The middle initial — "P." — is not what anyone is called.
    while (words.length > 1 &&
        RegExp(r'^\p{L}\.?$', unicode: true).hasMatch(words.last)) {
      words.removeLast();
    }
    return words.take(2).map(_titleCase).join(' ');
  }

  static String _titleCase(String word) => word
      .split('-')
      .map(
        (part) => part.isEmpty
            ? part
            : part[0].toUpperCase() + part.substring(1).toLowerCase(),
      )
      .join('-');

  StudentProfile copyWith({
    StudentRecord? record,
    String? photoUrl,
    Uint8List? photo,
    bool? photoRequired,
    bool clearPhoto = false,
  }) => StudentProfile(
    record: record ?? this.record,
    lastName: lastName,
    photoUrl: clearPhoto ? null : photoUrl ?? this.photoUrl,
    photo: clearPhoto ? null : photo ?? this.photo,
    photoRequired: photoRequired ?? this.photoRequired,
  );

  Map<String, dynamic> toJson() => {
    // Warnings are left behind, as with a saved QR: whether something is
    // still missing is only known online.
    'record': {...record.toJson()}..remove('warnings'),
    'last_name': lastName,
    'photo_url': photoUrl,
    if (photo != null) 'photo': base64Encode(photo!),
    'photo_required': photoRequired,
  };

  /// Throws a [FormatException] for anything [toJson] did not write.
  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    final record = json['record'];
    final lastName = json['last_name'];
    if (record is! Map<String, dynamic> || lastName is! String) {
      throw const FormatException('Malformed student profile');
    }
    final photo = json['photo'];
    return StudentProfile(
      record: StudentRecord.fromJson(record),
      lastName: lastName,
      photoUrl: json['photo_url'] as String?,
      photo: photo is String ? base64Decode(photo) : null,
      photoRequired: json['photo_required'] as bool? ?? false,
    );
  }
}
