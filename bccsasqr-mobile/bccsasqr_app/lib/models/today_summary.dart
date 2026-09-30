import 'package:flutter/foundation.dart';

import 'scanner_models.dart';

/// One subject's scans today, as the instructor's Home lists them.
@immutable
class SubjectToday {
  const SubjectToday({
    required this.name,
    this.subject,
    this.scanned = 0,
    this.late = 0,
    this.lastTimeIn,
  });

  /// The subject as the scans name it: the attendance table keeps the name,
  /// not the code.
  final String name;

  /// The picker's entry for it — its code, and whether late marking is on.
  /// Null for a subject this account no longer has.
  final ScanSubject? subject;

  final int scanned;
  final int late;

  /// The newest scan's time, as stored (`08:14:03 AM`). Null before the
  /// first one.
  final String? lastTimeIn;
}

/// Today's scans by this account, counted — the top of the instructor's
/// Home. Worked out from the scanner's own list rather than asked for again,
/// so Home and the scanner never disagree, and a scan counts on Home the
/// moment it is made.
@immutable
class TodaySummary {
  const TodaySummary._({
    required this.total,
    required this.late,
    required this.subjects,
  });

  /// [entries] newest first, as [ScannerController.attendance] keeps them.
  ///
  /// Only [today]'s count. A scan kept offline on an earlier day and still
  /// waiting to be sent is in that list too, but it is not part of today.
  /// [selected] — the subject being scanned — is listed first even before
  /// its first scan, so Home shows where the next one will go.
  factory TodaySummary.of({
    required List<AttendanceEntry> entries,
    required String today,
    List<ScanSubject> subjects = const [],
    ScanSubject? selected,
  }) {
    final known = {for (final s in subjects) s.name: s};
    final counted = <String, SubjectToday>{};
    var total = 0;
    var late = 0;

    for (final e in entries) {
      if (e.date != today) continue;
      total++;
      if (e.late) late++;
      if (e.subject.isEmpty) continue;

      final seen = counted[e.subject];
      counted[e.subject] = SubjectToday(
        name: e.subject,
        subject: known[e.subject],
        scanned: (seen?.scanned ?? 0) + 1,
        late: (seen?.late ?? 0) + (e.late ? 1 : 0),
        // Newest first: the first one met is the latest.
        lastTimeIn: seen?.lastTimeIn ?? e.timeIn,
      );
    }

    final list = counted.values.toList();
    if (selected != null && !counted.containsKey(selected.name)) {
      list.insert(0, SubjectToday(name: selected.name, subject: selected));
    }
    return TodaySummary._(total: total, late: late, subjects: list);
  }

  final int total;
  final int late;
  int get onTime => total - late;

  /// Each subject scanned today, the most recently scanned first.
  final List<SubjectToday> subjects;

  /// How many subjects have at least one scan today.
  int get subjectsScanned => subjects.where((s) => s.scanned > 0).length;
}
