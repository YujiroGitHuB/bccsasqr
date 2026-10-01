import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_strings.dart';
import '../models/attendance_history.dart';
import '../services/student_repository.dart';
import '../services/tracker_repository.dart';
import 'profile_controller.dart';

/// One scan of today's, for the Home card and Show to scanner's island.
typedef TodayScan = ({String subject, AttendanceDay day});

/// The attendance of the student this phone is set up for: Home's summary,
/// My Attendance, and the check Show to scanner makes while the code is up.
///
/// The Attendance Tracker's history (`GET /students/{no}/attendance`), asked
/// for the profile's number instead of a typed one, and quietly — nothing
/// here speaks: it loads on its own, and a voice reading out every refresh
/// of the home screen would be noise.
class MyAttendanceController extends ChangeNotifier {
  MyAttendanceController({
    required ProfileController profile,
    required TrackerRepository repository,
    DateTime Function()? clock,
  }) : _profile = profile,
       _repository = repository,
       _clock = clock ?? DateTime.now {
    _profile.addListener(_onProfile);
    _onProfile();
  }

  final ProfileController _profile;
  final TrackerRepository _repository;
  final DateTime Function() _clock;

  String? _number;
  AttendanceHistory? _history;
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  String? _errorCode;
  int _token = 0;
  bool _disposed = false;

  /// Whether a student is set up on this phone at all.
  bool get hasStudent => _number != null;

  AttendanceHistory? get history => _history;
  bool get isLoading => _loading;

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
    _token++;
    _history = null;
    _loaded = false;
    _error = null;
    _errorCode = null;
    _loading = false;
    notifyListeners();
    if (number != null) unawaited(refresh());
  }

  /// Asks again — on a pull, when Home shows, and every few seconds while
  /// the code is on screen for the scanner.
  Future<void> refresh() async {
    final number = _profile.profile?.record.studentNumber;
    if (number == null || _loading) return;
    final token = ++_token;

    _loading = true;
    notifyListeners();

    try {
      final found = await _repository.fetchAttendance(number);
      if (_disposed || token != _token) return;
      _history = found;
      _error = null;
      _errorCode = null;
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
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _profile.removeListener(_onProfile);
    super.dispose();
  }
}
