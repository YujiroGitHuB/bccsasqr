import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/student_number.dart';
import '../models/qr_payload.dart';
import '../models/student_record.dart';

/// One QR code made on this phone: the verified record, the card exactly as
/// the server issued it, and when.
class SavedQr {
  const SavedQr({
    required this.record,
    required this.payload,
    required this.savedAt,
  });

  final StudentRecord record;
  final QrPayload payload;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
    // Warnings are left behind: whether a photo is still missing is only
    // known online, and an old one would be read as current.
    'record': {...record.toJson()}..remove('warnings'),
    'payload': payload.toJson(),
    'saved_at': savedAt.toIso8601String(),
  };

  /// Throws a [FormatException] for anything [toJson] did not write.
  factory SavedQr.fromJson(Map<String, dynamic> json) {
    final record = json['record'];
    final payload = json['payload'];
    final savedAt = DateTime.tryParse(json['saved_at'] as String? ?? '');
    if (record is! Map<String, dynamic> ||
        payload is! Map<String, dynamic> ||
        savedAt == null) {
      throw const FormatException('Malformed saved QR code');
    }
    return SavedQr(
      record: StudentRecord.fromJson(record),
      payload: QrPayload.fromJson(payload),
      savedAt: savedAt,
    );
  }
}

/// The QR codes made on this phone, so My QR Code can open them without
/// internet.
///
/// Only a code the server issued is ever kept — for a record it verified,
/// after the terms were accepted — so an offline copy is never less checked
/// than the one made online. A number never looked up on this phone still
/// needs the internet once.
abstract interface class SavedQrStore {
  Future<SavedQr?> find(StudentNumber number);
  Future<void> save(SavedQr qr);
}

/// The phone's shared preferences. The card is the same name, course and
/// section the student sees printed on it — nothing more private than that.
///
/// A store that cannot be read or written finds nothing and keeps nothing:
/// the offline copy is a convenience, never a reason for the page to fail.
class SharedPrefsSavedQrStore implements SavedQrStore {
  static const String _key = 'saved_qr.v1';

  /// An instructor's phone makes codes for whoever asks; the oldest go first.
  static const int keep = 20;

  Future<Map<String, SavedQr>> _read(SharedPreferences prefs) async {
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return {};
    }
    if (decoded is! Map<String, dynamic>) return {};

    final saved = <String, SavedQr>{};
    for (final MapEntry(:key, :value) in decoded.entries) {
      if (value is! Map<String, dynamic>) continue;
      try {
        saved[key] = SavedQr.fromJson(value);
      } on FormatException {
        // One unreadable entry is dropped, not the lot.
      } on TypeError {
        // Likewise.
      }
    }
    return saved;
  }

  @override
  Future<SavedQr?> find(StudentNumber number) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (await _read(prefs))[number.value];
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(SavedQr qr) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await _read(prefs)
        ..[qr.record.studentNumber.value] = qr;

      final newestFirst = saved.values.toList()
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
      await prefs.setString(
        _key,
        jsonEncode({
          for (final s in newestFirst.take(keep))
            s.record.studentNumber.value: s.toJson(),
        }),
      );
    } catch (_) {
      // Not kept; the next code made online tries again.
    }
  }
}

/// Keeps them for the life of the object. For tests, and the default when
/// no store is given.
class MemorySavedQrStore implements SavedQrStore {
  final Map<String, SavedQr> saved = {};

  @override
  Future<SavedQr?> find(StudentNumber number) async => saved[number.value];

  @override
  Future<void> save(SavedQr qr) async =>
      saved[qr.record.studentNumber.value] = qr;
}
