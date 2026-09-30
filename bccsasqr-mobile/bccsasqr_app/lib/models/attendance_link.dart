/// The attendance links an instructor hands out, read from `/api/v1/links`:
/// the web's Attendance Links page (`pages/generate_attendance_link.php`) on
/// a phone. Students open a link — or scan its QR code — and record their own
/// attendance on `pages/daily_attendance.php`.
///
/// Every time here was measured by the server's database clock. The app only
/// counts down from it, as the web page does: the phone's clock never decides
/// whether a link is open.
library;

import 'package:flutter/foundation.dart';

/// When a link closes.
@immutable
class LinkExpiry {
  const LinkExpiry({
    this.at,
    this.label,
    this.short,
    this.secondsLeft,
    this.expired = false,
  });

  factory LinkExpiry.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return const LinkExpiry();
    return LinkExpiry(
      at: json['at'] as String?,
      label: json['label'] as String?,
      short: json['short'] as String?,
      secondsLeft: (json['in'] as num?)?.toInt(),
      expired: json['expired'] == true,
    );
  }

  /// As stored — `2026-09-30 17:00:00`. Null: the link never closes.
  final String? at;

  /// `Sep 30, 2026 5:00 PM`.
  final String? label;

  /// `5:00 PM` when it closes today, `Oct 1, 5:00 PM` otherwise.
  final String? short;

  /// Seconds until it closes, when the server answered; negative once it
  /// has.
  final int? secondsLeft;
  final bool expired;

  bool get isSet => at != null;
}

/// The late cutoff: submissions after [label] are recorded as late. The link
/// stays open either way.
@immutable
class LinkLate {
  const LinkLate({this.on = false, this.secondsLeft, this.label});

  factory LinkLate.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return const LinkLate();
    return LinkLate(
      on: json['on'] == true,
      secondsLeft: (json['in'] as num?)?.toInt(),
      label: json['label'] as String?,
    );
  }

  /// A cutoff is set for today. One from an earlier day counts as none.
  final bool on;

  /// Seconds until submissions start counting as late, when the server
  /// answered; zero or less: they already do.
  final int? secondsLeft;

  /// `8:15 AM` — the last on-time minute.
  final String? label;
}

/// What changing a link answers: its code and address — new ones after a
/// renewal — and its times.
@immutable
class LinkState {
  const LinkState({
    required this.shortCode,
    required this.url,
    this.expiry = const LinkExpiry(),
    this.late = const LinkLate(),
  });

  factory LinkState.fromJson(Map<String, dynamic> json) => LinkState(
    shortCode: json['short_code'] as String,
    url: json['url'] as String? ?? '',
    expiry: LinkExpiry.fromJson(json['expiry']),
    late: LinkLate.fromJson(json['late']),
  );

  /// Six characters with no 0/O or 1/I — read off a wall and typed.
  final String shortCode;
  final String url;
  final LinkExpiry expiry;
  final LinkLate late;
}

/// One class's link: a subject, for one section, under one instructor.
@immutable
class AttendanceLink extends LinkState {
  const AttendanceLink({
    required super.shortCode,
    required super.url,
    super.expiry,
    super.late,
    required this.subjectCode,
    required this.subjectName,
    required this.section,
    required this.instructor,
    this.mine = true,
  });

  factory AttendanceLink.fromJson(Map<String, dynamic> json) {
    final state = LinkState.fromJson(json);
    return AttendanceLink(
      shortCode: state.shortCode,
      url: state.url,
      expiry: state.expiry,
      late: state.late,
      subjectCode: json['subject_code'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      section: json['section'] as String? ?? '',
      instructor: json['instructor'] as String? ?? '',
      mine: json['mine'] != false,
    );
  }

  final String subjectCode;
  final String subjectName;

  /// `BSIT-2A` — course and section, as the web card shows it.
  final String section;
  final String instructor;

  /// The signed-in account's own class. Only an admin sees anyone else's.
  final bool mine;

  /// The same class with what the server said after a change.
  AttendanceLink withState(LinkState state) => AttendanceLink(
    shortCode: state.shortCode,
    url: state.url,
    expiry: state.expiry,
    late: state.late,
    subjectCode: subjectCode,
    subjectName: subjectName,
    section: section,
    instructor: instructor,
    mine: mine,
  );

  /// The search box: subject, code, section or instructor, any case.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '$subjectName $subjectCode $section $instructor $shortCode'
        .toLowerCase()
        .contains(q);
  }
}

/// A link that expired on an earlier day and was given a new code when the
/// list was opened: the old address no longer works.
typedef RotatedLink = ({String oldCode, String newCode});

/// What `GET /links` answers.
typedef LinkList = ({
  List<AttendanceLink> links,
  List<RotatedLink> rotated,

  /// An admin sees every instructor's links, with a filter for their own.
  bool admin,
});

/// What `POST /links/renew` answers: the code that stopped working, and the
/// link that took its place.
typedef RenewedLink = ({String oldCode, LinkState link});

/// A time to set, as the web page's buttons send it.
@immutable
class LinkTime {
  const LinkTime._(this.json);

  /// From now: `minutes: 60` closes the link in an hour; on the late cutoff,
  /// students are on time for the next [minutes].
  LinkTime.minutes(int minutes) : this._({'minutes': minutes});

  /// Until 11:59 PM today — the expiry only.
  const LinkTime.endOfDay() : this._(const {'preset': 'eod'});

  /// A date and time on the phone's calendar — the expiry only. Sent as the
  /// wall-clock time the instructor picked; the server reads it in
  /// Philippine time, as the web page's picker does.
  LinkTime.closesAt(DateTime at) : this._({'at': _wallClock(at)});

  /// On time until [hour]:[minute] today — the late cutoff only.
  LinkTime.onTimeUntil(int hour, int minute)
    : this._({'at': '${_two(hour)}:${_two(minute)}'});

  /// No expiry, or no late cutoff.
  const LinkTime.clear() : this._(const {'clear': true});

  /// The fields added to the request body.
  final Map<String, Object> json;

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _wallClock(DateTime t) =>
      '${t.year}-${_two(t.month)}-${_two(t.day)}T${_two(t.hour)}:${_two(t.minute)}';
}
