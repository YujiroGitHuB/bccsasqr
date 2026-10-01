import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/student_notice.dart';

/// What the phone keeps of the live feed between launches: whose it is, how
/// far it has read, and the notifications it has shown.
@immutable
class NoticeFeed {
  const NoticeFeed({
    required this.studentNumber,
    this.cursor,
    this.count,
    this.notices = const [],
  });

  final String studentNumber;

  /// The newest record id seen, and how many records there were then.
  /// Null until the first look.
  final int? cursor;
  final int? count;

  /// Newest first.
  final List<StudentNotice> notices;

  Map<String, dynamic> toJson() => {
    'student_no': studentNumber,
    'cursor': cursor,
    'count': count,
    'notices': [for (final n in notices) n.toJson()],
  };

  /// Throws a [FormatException] for anything [toJson] did not write. A
  /// notice it cannot read is left behind, not the whole feed.
  factory NoticeFeed.fromJson(Map<String, dynamic> json) {
    final number = json['student_no'];
    if (number is! String) throw const FormatException('Malformed feed');
    final notices = json['notices'];
    return NoticeFeed(
      studentNumber: number,
      cursor: json['cursor'] as int?,
      count: json['count'] as int?,
      notices: [
        if (notices is List)
          for (final n in notices)
            if (n is Map<String, dynamic>) ?_tryNotice(n),
      ],
    );
  }

  static StudentNotice? _tryNotice(Map<String, dynamic> json) {
    try {
      return StudentNotice.fromJson(json);
    } on FormatException {
      return null;
    }
  }
}

/// Where the [NoticeFeed] lives. One student at a time, as the profile.
abstract interface class NoticeStore {
  Future<NoticeFeed?> load();
  Future<void> save(NoticeFeed feed);
  Future<void> clear();
}

/// The phone's shared preferences, beside the profile.
///
/// A store that cannot be read or written keeps nothing: the feed starts
/// again from where the record stands, and only what was already shown is
/// lost — never a reason for the screen to fail.
class SharedPrefsNoticeStore implements NoticeStore {
  static const String _key = 'notices.v1';

  @override
  Future<NoticeFeed?> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? NoticeFeed.fromJson(decoded)
          : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(NoticeFeed feed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(feed.toJson()));
    } catch (_) {
      // Shown for this launch; the next one starts from the record.
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
class MemoryNoticeStore implements NoticeStore {
  MemoryNoticeStore([this.feed]);

  NoticeFeed? feed;

  @override
  Future<NoticeFeed?> load() async => feed;

  @override
  Future<void> save(NoticeFeed feed) async => this.feed = feed;

  @override
  Future<void> clear() async => feed = null;
}
