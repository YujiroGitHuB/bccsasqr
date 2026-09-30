import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/student_profile.dart';

/// The student this phone belongs to — see [StudentProfile]. One at a time:
/// a phone that verifies someone else forgets the first.
abstract interface class ProfileStore {
  Future<StudentProfile?> load();
  Future<void> save(StudentProfile profile);
  Future<void> clear();
}

/// The phone's shared preferences. The photo rides along as base64 — a
/// 400 px JPEG, about 50 KB.
///
/// A store that cannot be read or written keeps nothing, as the saved QR
/// codes do: the profile is a convenience, never a reason for a screen to
/// fail. The student verifies again.
class SharedPrefsProfileStore implements ProfileStore {
  static const String _key = 'student_profile.v1';

  @override
  Future<StudentProfile?> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? StudentProfile.fromJson(decoded)
          : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(StudentProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(profile.toJson()));
    } catch (_) {
      // Not kept; it is still on screen until the app closes.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {
      // Nothing to forget.
    }
  }
}

/// Keeps it for the life of the object. For tests, and the default when no
/// store is given.
class MemoryProfileStore implements ProfileStore {
  MemoryProfileStore([this.profile]);

  StudentProfile? profile;

  @override
  Future<StudentProfile?> load() async => profile;

  @override
  Future<void> save(StudentProfile profile) async => this.profile = profile;

  @override
  Future<void> clear() async => profile = null;
}
