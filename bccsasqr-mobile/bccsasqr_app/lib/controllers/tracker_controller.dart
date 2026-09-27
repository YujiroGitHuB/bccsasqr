import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_strings.dart';
import '../core/utils/student_number.dart';
import '../models/attendance_history.dart';
import '../services/speech_service.dart';
import '../services/student_repository.dart';
import '../services/tracker_repository.dart';

/// Where the search currently stands.
enum TrackerStatus { idle, searching, found, notFound, failed }

/// The Attendance Tracker's state and rules — the port of
/// `Tracker/js/script.js`. The search runs on its own once the student stops
/// typing; there is no button to press, as on the web.
class TrackerController extends ChangeNotifier {
  TrackerController({
    required TrackerRepository repository,
    SpeechService speech = const SilentSpeechService(),
    this.debounce = const Duration(milliseconds: 600),
  }) : _repository = repository,
       _speech = speech;

  final TrackerRepository _repository;
  final SpeechService _speech;

  /// How long typing must pause before the search fires. The web waits a
  /// second and then three more for effect; a phone keyboard does not need
  /// either.
  final Duration debounce;

  Timer? _debounceTimer;
  int _searchToken = 0;
  bool _disposed = false;

  String _input = '';
  TrackerStatus _status = TrackerStatus.idle;
  AttendanceHistory? _history;
  String? _errorMessage;

  // ---------------------------------------------------------------- getters

  String get input => _input;
  TrackerStatus get status => _status;
  AttendanceHistory? get history => _history;
  String? get errorMessage => _errorMessage;

  bool get isSearching => _status == TrackerStatus.searching;
  bool get isFound => _status == TrackerStatus.found && _history != null;
  bool get isNotFound => _status == TrackerStatus.notFound;

  /// The search never got an answer; the same number may well work on retry.
  bool get canRetry => _status == TrackerStatus.failed;

  /// Nothing searched yet — the "No record shown yet" card.
  bool get showPlaceholder =>
      _status == TrackerStatus.idle && _errorMessage == null;

  // ---------------------------------------------------------------- intents

  /// Called on every keystroke: clears what is shown, then schedules one
  /// search for when the typing stops.
  void onStudentNumberChanged(String value) {
    _input = value;
    _history = null;
    _errorMessage = null;
    _debounceTimer?.cancel();
    _searchToken++;

    if (value.trim().isEmpty) {
      _status = TrackerStatus.idle;
      unawaited(_speech.stop());
      notifyListeners();
      return;
    }

    if (!StudentNumber.isValid(value)) {
      // Half a number is not an error yet.
      _status = TrackerStatus.idle;
      notifyListeners();
      return;
    }

    _status = TrackerStatus.searching;
    notifyListeners();
    _debounceTimer = Timer(debounce, () => searchNow());
  }

  /// Searches immediately — the keyboard's done key, a retry, a pull.
  Future<void> searchNow() async {
    _debounceTimer?.cancel();
    final number = StudentNumber.tryParse(_input);

    if (number == null) {
      _history = null;
      _status = TrackerStatus.idle;
      _errorMessage = _input.trim().isEmpty
          ? AppStrings.errorEmpty
          : AppStrings.errorFormat;
      unawaited(_speech.speak(_errorMessage!));
      notifyListeners();
      return;
    }

    final token = ++_searchToken;
    _status = TrackerStatus.searching;
    _errorMessage = null;
    unawaited(_speech.speak(TrackerStrings.searching));
    notifyListeners();

    try {
      final found = await _repository.fetchAttendance(number);
      // A newer keystroke has already moved on from this number.
      if (_disposed || token != _searchToken) return;

      _history = found;
      _status = found == null ? TrackerStatus.notFound : TrackerStatus.found;
    } on StudentLookupException catch (e) {
      if (_disposed || token != _searchToken) return;
      _history = null;
      _status = TrackerStatus.failed;
      _errorMessage = e.message;
    } catch (_) {
      if (_disposed || token != _searchToken) return;
      _history = null;
      _status = TrackerStatus.failed;
      _errorMessage = TrackerStrings.failed;
    }

    unawaited(_speech.speak(statusMessage ?? TrackerStrings.failed));
    notifyListeners();
  }

  /// The line under the field once a search has answered — the web's
  /// message box. Also what is read aloud.
  String? get statusMessage => switch (_status) {
    TrackerStatus.found when _history!.isEmpty => TrackerStrings.noAttendance,
    TrackerStatus.found => TrackerStrings.loaded,
    TrackerStatus.notFound => TrackerStrings.notFound,
    _ => _errorMessage,
  };

  /// Pull-to-refresh: the same number again, for a scan made a minute ago.
  Future<void> refresh() async {
    if (_input.trim().isEmpty) return;
    await searchNow();
  }

  /// Silences the voice — the app left the screen.
  void stopSpeaking() => unawaited(_speech.stop());

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    unawaited(_speech.stop());
    super.dispose();
  }
}
