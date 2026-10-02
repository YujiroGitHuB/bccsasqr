import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/attendance_history.dart';

/// The student's attendance as the server last gave it, and when — kept on
/// the phone so Home and My Attendance still show it with no signal.
@immutable
class KeptAttendance {
  const KeptAttendance({
    required this.studentNumber,
    required this.at,
    required this.history,
  });

  /// Whose it is: a copy for anyone else is never shown.
  final String studentNumber;

  /// When the server gave it — the "as of" the screens show.
  final DateTime at;
  final AttendanceHistory history;

  Map<String, dynamic> toJson() => {
    'student_no': studentNumber,
    'at': at.toIso8601String(),
    'history': history.toJson(),
  };

  /// Throws a [FormatException] for anything [toJson] did not write.
  factory KeptAttendance.fromJson(Map<String, dynamic> json) {
    final number = json['student_no'];
    final at = DateTime.tryParse(json['at']?.toString() ?? '');
    final history = json['history'];
    if (number is! String || at == null || history is! Map<String, dynamic>) {
      throw const FormatException('Malformed kept attendance');
    }
    return KeptAttendance(
      studentNumber: number,
      at: at,
      history: AttendanceHistory.fromJson(history),
    );
  }
}

/// Where the [KeptAttendance] lives. One student at a time, as the profile:
/// "Not you?" forgets it with them.
abstract interface class AttendanceStore {
  Future<KeptAttendance?> load();
  Future<void> save(KeptAttendance kept);
  Future<void> clear();
}

/// The phone's shared preferences, beside the profile — a term of scans is
/// a few tens of kilobytes.
///
/// A store that cannot be read or written keeps nothing, as the notices do:
/// the screens wait for the server as they did before, never failing for
/// it.
class SharedPrefsAttendanceStore implements AttendanceStore {
  static const String _key = 'attendance.v1';

  @override
  Future<KeptAttendance?> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? KeptAttendance.fromJson(decoded)
          : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(KeptAttendance kept) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(kept.toJson()));
    } catch (_) {
      // On screen for this launch; the next one waits for the server.
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
class MemoryAttendanceStore implements AttendanceStore {
  MemoryAttendanceStore([this.kept]);

  KeptAttendance? kept;

  @override
  Future<KeptAttendance?> load() async => kept;

  @override
  Future<void> save(KeptAttendance kept) async => this.kept = kept;

  @override
  Future<void> clear() async => kept = null;
}
