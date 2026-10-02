import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_strings.dart';
import '../core/utils/student_number.dart';
import '../models/attendance_history.dart';
import '../models/live_update.dart';
import '../services/attendance_store.dart';
import '../services/student_repository.dart';
import '../services/tracker_repository.dart';
import 'profile_controller.dart';

/// One scan of today's, for the Home card and Show to scanner's island.
typedef TodayScan = ({String subject, AttendanceDay day});

/// The attendance of the student this phone is set up for: Home's summary
/// and My Attendance.
///
/// The Attendance Tracker's history (`GET /students/{no}/attendance`), asked
/// for the profile's number instead of a typed one, and quietly — nothing
/// here speaks: it loads on its own, and a voice reading out every refresh
/// of the home screen would be noise.
///
/// Between loads the live feed keeps it current (notifications_controller.
/// dart): a new record is added to the history on screen as it arrives
/// ([addRecords]), so a scan shows on Home with no pull to refresh.
///
/// Every answer is kept on the phone ([AttendanceStore], since 2026-10-02):
/// the next launch shows it at once while the server is asked, and with no
/// signal — a school's usual state — it stays on screen, marked with when
/// it is from ([stale], [asOf]) instead of "Could not load". "Not you?"
/// forgets it with the student.
class MyAttendanceController extends ChangeNotifier {
  MyAttendanceController({
    required ProfileController profile,
    required TrackerRepository repository,
    AttendanceStore? store,
    Stream<bool>? online,
    DateTime Function()? clock,
  }) : _profile = profile,
       _repository = repository,
       _store = store ?? MemoryAttendanceStore(),
       _clock = clock ?? DateTime.now {
    _profile.addListener(_onProfile);
    _onProfile();
    _online = online?.listen(_onOnline);
  }

  final ProfileController _profile;
  final TrackerRepository _repository;
  final AttendanceStore _store;
  final DateTime Function() _clock;

  /// The phone's network (services/connectivity.dart), when it can tell.
  StreamSubscription<bool>? _online;

  String? _number;
  AttendanceHistory? _history;
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  String? _errorCode;
  int _token = 0;
  bool _disposed = false;

  /// Bumped whenever the student changes, so the copy read for the one
  /// before is dropped.
  int _generation = 0;

  /// When the server gave the history on screen.
  DateTime? _asOf;

  /// The server has answered for this student since it was set.
  bool _fresh = false;

  /// The load under way, for a second caller to wait on.
  Future<void>? _loadingNow;

  /// Whether a student is set up on this phone at all.
  bool get hasStudent => _number != null;

  AttendanceHistory? get history => _history;
  bool get isLoading => _loading;

  /// When the server gave the history on screen — the kept copy's time
  /// until it answers again.
  DateTime? get asOf => _asOf;

  /// What is on screen is not the server's word right now: the copy kept on
  /// the phone, or the last answer before an ask that failed. The screens
  /// then say when it is from.
  bool get stale => _history != null && (!_fresh || _error != null);

  /// Answered at least once for this student — with a history or without.
  bool get loaded => _loaded;

  /// Why the last load failed; the history before it, if any, stays shown.
  String? get error => _error;

  /// The server's code for [error] — `rate_limited`, `network`, …
  String? get errorCode => _errorCode;

  /// Every scan dated today, newest subject first as the history lists them.
  List<TodayScan> get today {
    final history = _history;
    if (history == null) return const [];
    final now = _clock();
    return [
      for (final subject in history.subjects)
        for (final day in subject.days)
          if (day.date case final d?
              when d.year == now.year &&
                  d.month == now.month &&
                  d.day == now.day)
            (subject: subject.subject, day: day),
    ];
  }

  /// How many of the student's days were marked late.
  int get lateCount => [
    for (final subject in _history?.subjects ?? const <SubjectAttendance>[])
      for (final day in subject.days)
        if (day.late) day,
  ].length;

  void _onProfile() {
    if (!_profile.loaded) return;
    final number = _profile.profile?.record.studentNumber.value;
    if (number == _number) return;
    _number = number;
    _generation++;
    _token++;
    _history = null;
    _asOf = null;
    _fresh = false;
    _loaded = false;
    _error = null;
    _errorCode = null;
    _loading = false;
    _loadingNow = null;
    notifyListeners();
    if (number == null) {
      // "Not you?": the phone forgets their attendance with them.
      unawaited(_store.clear());
      return;
    }
    unawaited(_restore(number, _generation));
    unawaited(refresh());
  }

  /// The copy kept on the phone, on screen until the server answers — or in
  /// its place, with no signal.
  Future<void> _restore(String number, int generation) async {
    final KeptAttendance? kept;
    try {
      kept = await _store.load();
    } catch (_) {
      return;
    }
    if (_disposed || generation != _generation || kept == null) return;
    if (kept.studentNumber != number) {
      // The student before this one: not this one's to see.
      unawaited(_store.clear());
      return;
    }
    // The server was quicker.
    if (_fresh || _history != null) return;
    _history = kept.history;
    _asOf = kept.at;
    notifyListeners();
  }

  /// Back on a network with the kept copy on screen: asks at once, so it is
  /// the server's word again without a pull.
  void _onOnline(bool online) {
    if (online && stale) unawaited(refresh());
  }

  /// Keeps what is on screen for the next launch, and for no signal.
  void _keep() {
    final number = _number;
    final history = _history;
    final at = _asOf;
    if (number == null || history == null || at == null) return;
    unawaited(
      _store.save(
        KeptAttendance(studentNumber: number, at: at, history: history),
      ),
    );
  }

  /// Asks again — on a pull, when Home shows, and when the live feed sees a
  /// record go. A second ask while one is under way waits for that one.
  Future<void> refresh() {
    final number = _profile.profile?.record.studentNumber;
    if (number == null) return Future.value();
    if (_loading) return _loadingNow ?? Future.value();
    return _loadingNow = _load(number);
  }

  Future<void> _load(StudentNumber number) async {
    final token = ++_token;

    _loading = true;
    notifyListeners();

    try {
      final found = await _repository.fetchAttendance(number);
      if (_disposed || token != _token) return;
      _history = found;
      _asOf = found == null ? null : _clock();
      _fresh = true;
      _error = null;
      _errorCode = null;
      if (found == null) {
        // The record is gone from the school's list: so is the copy.
        unawaited(_store.clear());
      } else {
        _keep();
      }
    } on StudentLookupException catch (e) {
      if (_disposed || token != _token) return;
      _error = e.message;
      _errorCode = e.code;
    } catch (_) {
      if (_disposed || token != _token) return;
      _error = TrackerStrings.failed;
      _errorCode = 'unknown';
    }
    _loading = false;
    _loaded = true;
    _loadingNow = null;
    notifyListeners();
  }

  /// Records the live feed just brought, added to the history on screen
  /// without asking for all of it again: a class scanned in the same minute
  /// would otherwise ask for every student's whole history at once, from one
  /// school Wi-Fi.
  ///
  /// Filed as the server files them (includes/attendance_history.php) —
  /// subjects in name order, each one's days newest first — and a record
  /// already there is not added twice: a refresh may have brought it first.
  void addRecords(Iterable<LiveRecord> records) {
    final history = _history;
    if (history == null) {
      unawaited(refresh());
      return;
    }

    final subjects = [...history.subjects];
    var total = history.total;
    var last = history.lastAttended;

    for (final record in records) {
      final day = record.day;
      final at = subjects.indexWhere((s) => s.subject == record.subject);
      if (at < 0) {
        // A subject the last load did not list: its absences are not known
        // here, so none are claimed until the next load counts them.
        subjects
          ..add(
            SubjectAttendance(
              subject: record.subject,
              instructor: record.instructor,
              count: 1,
              days: [day],
            ),
          )
          ..sort(
            (a, b) =>
                a.subject.toLowerCase().compareTo(b.subject.toLowerCase()),
          );
      } else {
        final subject = subjects[at];
        if (subject.days.any((d) => _same(d, day))) continue;
        subjects[at] = _attended(subject, day);
      }
      total++;
      final date = day.date;
      if (date != null && (last == null || date.isAfter(last))) last = date;
    }

    if (total == history.total) return;
    final counted = subjects.where((s) => s.classes != null);
    _history = AttendanceHistory(
      studentNumber: history.studentNumber,
      fullName: history.fullName,
      course: history.course,
      section: history.section,
      photoUrl: history.photoUrl,
      total: total,
      lastAttended: last,
      subjects: subjects,
      classes: history.countsAbsences
          ? counted.fold<int>(0, (n, s) => n + s.classes!)
          : null,
      absences: history.countsAbsences
          ? counted.fold<int>(0, (n, s) => n + s.absentDates.length)
          : null,
    );
    // The feed is the server's word too: current as of now, and kept.
    _asOf = _clock();
    _keep();
    notifyListeners();
  }

  /// [subject] with [day] marked present. A day it was counted absent on —
  /// a scan the instructor's phone kept offline, sent later — is no longer
  /// missed; a day not counted yet, today's class mostly, is one more class.
  static SubjectAttendance _attended(
    SubjectAttendance subject,
    AttendanceDay day,
  ) {
    final date = day.date;
    final classes = subject.classes;
    final wasMissed = date != null && subject.absentDates.contains(date);
    final sameDay = date != null && subject.days.any((d) => d.date == date);

    return SubjectAttendance(
      subject: subject.subject,
      instructor: subject.instructor,
      count: subject.count + 1,
      days: _withDay(subject.days, day),
      section: subject.section,
      enrolled: subject.enrolled,
      classes: classes == null || wasMissed || sameDay ? classes : classes + 1,
      absentDates: wasMissed
          ? [
              for (final d in subject.absentDates)
                if (d != date) d,
            ]
          : subject.absentDates,
    );
  }

  /// Asks again, and says which records the answer no longer has — what an
  /// instructor deleted. Nothing when there was no history to compare.
  Future<List<TodayScan>> refreshFindingRemoved() async {
    final before = _history;
    await refresh();
    final after = _history;
    if (before == null || after == null || identical(before, after)) {
      return const [];
    }

    String key(String subject, AttendanceDay d) =>
        '$subject|${d.rawDate}|${d.timeIn}';
    final kept = {
      for (final s in after.subjects)
        for (final d in s.days) key(s.subject, d),
    };
    return [
      for (final s in before.subjects)
        for (final d in s.days)
          if (!kept.contains(key(s.subject, d))) (subject: s.subject, day: d),
    ];
  }

  static bool _same(AttendanceDay a, AttendanceDay b) =>
      a.timeIn == b.timeIn &&
      (a.date != null && b.date != null
          ? a.date == b.date
          : a.rawDate == b.rawDate);

  /// [days] with [day] in its place: newest first, and ahead of the others
  /// of its date — it is the newer record.
  static List<AttendanceDay> _withDay(
    List<AttendanceDay> days,
    AttendanceDay day,
  ) {
    final date = day.date;
    final at = date == null
        ? days.length
        : days.indexWhere((d) => d.date == null || !d.date!.isAfter(date));
    return [...days]..insert(at < 0 ? days.length : at, day);
  }

  @override
  void dispose() {
    _disposed = true;
    _profile.removeListener(_onProfile);
    unawaited(_online?.cancel());
    super.dispose();
  }
}
