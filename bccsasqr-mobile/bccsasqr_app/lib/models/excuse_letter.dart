import 'package:flutter/foundation.dart';

import '../core/constants/app_strings.dart';
import '../core/utils/date_label.dart';
import 'attendance_history.dart';

/// Why the student missed class: the choices the excuse letter offers, each
/// finishing its "…excuse my absence on [day], ___." sentence.
enum ExcuseReason {
  sick,
  checkUp,
  family,
  weather,
  transport,
  other;

  /// The chip's word for it.
  String get label => switch (this) {
    sick => ExcuseLetterStrings.reasonSick,
    checkUp => ExcuseLetterStrings.reasonCheckUp,
    family => ExcuseLetterStrings.reasonFamily,
    weather => ExcuseLetterStrings.reasonWeather,
    transport => ExcuseLetterStrings.reasonTransport,
    other => ExcuseLetterStrings.reasonOther,
  };

  /// The letter's.
  String get phrase => switch (this) {
    sick => ExcuseLetterStrings.becauseSick,
    checkUp => ExcuseLetterStrings.becauseCheckUp,
    family => ExcuseLetterStrings.becauseFamily,
    weather => ExcuseLetterStrings.becauseWeather,
    transport => ExcuseLetterStrings.becauseTransport,
    other => ExcuseLetterStrings.becauseOther,
  };
}

/// An excuse letter for days a student missed in one subject, written from
/// what My Attendance already holds — the student types nothing but, if they
/// like, a note of their own.
///
/// A template, not a guess: every fact in it — the days, the subject, the
/// class, the instructor — is the record's, as includes/attendance_history.php
/// counted it, so the letter can never name a day the record does not. It
/// decides nothing either: sending it changes nothing on the record, and
/// whether the absence is excused stays the instructor's call.
@immutable
class ExcuseLetter {
  const ExcuseLetter({
    required this.studentName,
    required this.studentNumber,
    required this.course,
    required this.section,
    required this.subject,
    required this.instructor,
    required this.dates,
    required this.reason,
    required this.written,
    this.note = '',
  });

  /// From [history], for the days in [dates] of its [subject].
  factory ExcuseLetter.forSubject({
    required AttendanceHistory history,
    required SubjectAttendance subject,
    required Iterable<DateTime> dates,
    required ExcuseReason reason,
    required DateTime written,
    String note = '',
  }) => ExcuseLetter(
    studentName: history.fullName,
    studentNumber: history.studentNumber,
    course: history.course,
    // The class's own section: an irregular student takes the subject with
    // another section than the one on their record, and the letter goes to
    // that class's instructor.
    section: subject.section.isNotEmpty ? subject.section : history.section,
    subject: subject.subject,
    instructor: subject.instructor,
    dates: dates.toList(),
    reason: reason,
    written: written,
    note: note,
  );

  /// As the school keeps it — "DELA CRUZ, JUAN P." — and signed as
  /// [signatureName] writes it.
  final String studentName;
  final String studentNumber;
  final String course;
  final String section;
  final String subject;

  /// Whoever scanned the class. Empty — or the old "N/A" — when nobody has,
  /// and the letter then goes to the subject's instructor unnamed.
  final String instructor;

  /// The days missed, in any order: the letter lists them oldest first.
  final List<DateTime> dates;
  final ExcuseReason reason;

  /// The day the letter is dated.
  final DateTime written;

  /// The student's own words, a paragraph of their own — left out when
  /// blank.
  final String note;

  /// The email's subject, when the letter is shared to one.
  String get subjectLine => ExcuseLetterStrings.shareSubject(subject);

  /// The letter, its paragraphs a blank line apart.
  String get text {
    final name = signatureName(studentName);
    final klass = classOf(course, section);
    final to = instructor.trim();
    final extra = note.trim();
    final days = {...dates}.toList()..sort();

    return [
      _long(written),
      [
        if (to.isNotEmpty && to != 'N/A') to,
        ExcuseLetterStrings.instructorOf(subject),
        ExcuseLetterStrings.school,
      ].join('\n'),
      ExcuseLetterStrings.salutation,
      ExcuseLetterStrings.opening(name, klass, subject),
      ExcuseLetterStrings.request(
        days.length,
        datesPhrase(days),
        reason.phrase,
      ),
      if (extra.isNotEmpty) extra,
      ExcuseLetterStrings.closing,
      [
        ExcuseLetterStrings.signOff,
        '',
        name,
        if (klass.isNotEmpty) klass,
        if (studentNumber.isNotEmpty) studentNumber,
      ].join('\n'),
    ].join('\n\n');
  }

  /// "DELA CRUZ, JUAN P." → "Juan P. Dela Cruz": the school keeps names
  /// surname first and in capitals, and a letter is signed given name first.
  /// A suffix — "JR.", "III" — goes after the surname; a name with no comma
  /// keeps its order.
  static String signatureName(String fullName) {
    List<String> words(String s) =>
        s.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    final comma = fullName.indexOf(',');
    if (comma < 0) return words(fullName).map(_word).join(' ');

    final surname = words(fullName.substring(0, comma));
    final given = words(fullName.substring(comma + 1));
    final suffix = <String>[];
    while (given.length > 1 &&
        _suffixes.contains(given.last.replaceAll('.', '').toUpperCase())) {
      suffix.insert(0, given.removeLast());
    }
    return [...given, ...surname, ...suffix].map(_word).join(' ');
  }

  /// Not "V": in "SANTOS, MARIA V." that is her middle initial.
  static const Set<String> _suffixes = {'JR', 'SR', 'II', 'III', 'IV'};

  static const Set<String> _numerals = {'II', 'III', 'IV'};

  /// One word of a name, out of the export's capitals: "DELA" → "Dela",
  /// "MA." → "Ma.", "O'NEIL" → "O'Neil". A numeral stays capitals, and a
  /// word already in mixed case was written by a person, so it is kept.
  static String _word(String word) {
    if (_numerals.contains(word.replaceAll('.', '').toUpperCase())) {
      return word.toUpperCase();
    }
    if (word != word.toUpperCase() && word != word.toLowerCase()) return word;
    return word.toLowerCase().replaceAllMapped(
      RegExp(r"(^|[-'’])(\p{L})", unicode: true),
      (m) => '${m[1]}${m[2]!.toUpperCase()}',
    );
  }

  /// "BSIT" and "2A" → "BSIT 2A", joined by a no-break space: a line that
  /// ends between the two reads as two things. A section that already starts
  /// with the course — "BSIT-2A" — is said alone.
  static String classOf(String course, String section) {
    final c = course.trim();
    final s = section.trim();
    if (c.isEmpty) return s;
    if (s.isEmpty) return c;
    return s.toUpperCase().startsWith(c.toUpperCase()) ? s : '$c $s';
  }

  /// "Monday, September 28, 2026" for one day; "September 21 and 28, 2026"
  /// for days in one month; "September 28 and October 1, 2026" across
  /// months; each day with its year when the years differ. Oldest first.
  static String datesPhrase(List<DateTime> dates) {
    final days = [...dates]..sort();
    if (days.length == 1) {
      return '${DateLabel.weekday(days.single)}, ${_long(days.single)}';
    }

    final first = days.first;
    if (days.any((d) => d.year != first.year)) {
      return _list([for (final d in days) _long(d)]);
    }
    if (days.every((d) => d.month == first.month)) {
      return '${DateLabel.month(first)} '
          '${_list([for (final d in days) '${d.day}'])}, ${first.year}';
    }
    return '${_list([for (final d in days) '${DateLabel.month(d)} ${d.day}'])}'
        ', ${first.year}';
  }

  /// "September 28, 2026".
  static String _long(DateTime d) =>
      '${DateLabel.month(d)} ${d.day}, ${d.year}';

  /// "a", "a and b", "a, b and c".
  static String _list(List<String> parts) => parts.length == 1
      ? parts.single
      : '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
}
