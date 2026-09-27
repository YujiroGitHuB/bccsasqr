import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_strings.dart';
import '../core/utils/student_number.dart';
import '../models/scanner_models.dart';
import '../services/scan_feedback.dart';
import '../services/scanner_repository.dart';
import '../services/speech_service.dart';

/// Where the scanner's sign-in stands.
enum ScannerSession {
  /// Looking for a sign-in saved on this phone.
  checking,
  signedOut,
  signedIn,

  /// A sign-in is saved but the server could not be asked about it.
  unreachable,
}

/// The line under the camera — the web scanner's `#qrResult`. A null [tone]
/// is the idle label, in muted text.
class ScanStatus {
  const ScanStatus(this.text, [this.tone]);

  final String text;
  final ScanTone? tone;
}

/// A dialog the page should put up — the web scanner's SweetAlert.
class ScanAlert {
  const ScanAlert({required this.title, required this.body, this.autoDismiss});

  final String title;
  final String body;

  /// Closes itself after this long, like the web's "Invalid QR Code" (2 s).
  final Duration? autoDismiss;
}

/// Owns the scanner screen's state and every rule about what a scan means for
/// it — the app's port of `Qrscanner/js/scriptV3.js`. The widgets read this
/// and render. What a scan means for the *record* is not decided here at all:
/// the server runs the web scanner's own rules (`includes/scan_attendance.php`)
/// and this only reports the answer.
class ScannerController extends ChangeNotifier {
  ScannerController({
    required ScannerRepository repository,
    SpeechService speech = const SilentSpeechService(),
    ScanFeedback feedback = const SilentScanFeedback(),
    this.resultHold = const Duration(seconds: 5),
    this.repeatGuard = const Duration(milliseconds: 2500),
    this.alertCooldown = const Duration(seconds: 3),
    DateTime Function()? clock,
  }) : _repository = repository,
       _speech = speech,
       _feedback = feedback,
       _clock = clock ?? DateTime.now;

  final ScannerRepository _repository;
  final SpeechService _speech;
  final ScanFeedback _feedback;
  final DateTime Function() _clock;

  /// How long a result stays on screen before the status line goes back to
  /// "Scanning for …" — the web's 5-second card.
  final Duration resultHold;

  /// A code just read is ignored for this long, so a QR held up to the camera
  /// is sent once, not once per frame. Counted from when it was sent, not
  /// from when it was last seen — as the web scanner's 1.5 s guard is — so a
  /// code held there, or shown again, is checked again and answered
  /// ("Already marked today.") instead of silence.
  final Duration repeatGuard;

  /// The web's ERROR_COOLDOWN: at most one "Invalid QR Code" dialog per this.
  final Duration alertCooldown;

  final StreamController<ScanAlert> _alerts =
      StreamController<ScanAlert>.broadcast();
  Timer? _holdTimer;
  bool _disposed = false;

  ScannerSession _session = ScannerSession.checking;
  ScannerUser? _user;
  String? _sessionMessage;
  bool _signingIn = false;
  String? _signInError;

  List<ScanSubject> _subjects = const [];
  bool _loadingSubjects = false;
  String? _subjectsError;
  String? _blocked;
  String? _serverDate;
  ScanSubject? _selected;
  bool _lateBusy = false;

  bool _recording = false;
  String? _lastCode;
  DateTime? _lastCodeAt;
  DateTime? _lastAlertAt;
  ScanStatus? _result;
  ScanRecord? _lastRecord;

  List<AttendanceEntry> _attendance = const [];
  bool _loadingAttendance = false;
  String _search = '';

  // ---------------------------------------------------------------- getters

  ScannerSession get session => _session;
  ScannerUser? get user => _user;

  /// Why the sign-in screen is showing, when it is not the first launch —
  /// "Your sign-in has expired", or why the server could not be reached.
  String? get sessionMessage => _sessionMessage;
  bool get isSigningIn => _signingIn;
  String? get signInError => _signInError;

  List<ScanSubject> get subjects => _subjects;
  bool get isLoadingSubjects => _loadingSubjects;
  String? get subjectsError => _subjectsError;

  /// Set when the server will not let this account scan at all: the QR
  /// pages are locked in Settings, or the scanner permission was taken away.
  String? get blockedMessage => _blocked;
  ScanSubject? get selectedSubject => _selected;
  bool get isLateBusy => _lateBusy;
  bool get isRecording => _recording;

  /// The camera runs only once a subject is picked — the web scanner's
  /// "Please select a subject first" gate.
  bool get cameraActive =>
      _session == ScannerSession.signedIn &&
      _selected != null &&
      _blocked == null;

  /// The student card under the camera, for [resultHold] after a scan.
  ScanRecord? get lastRecord => _lastRecord;

  ScanStatus get status => _result ?? ScanStatus(_idleLabel);

  Stream<ScanAlert> get alerts => _alerts.stream;

  /// The server's date once it has answered, the phone's until then.
  String get today {
    if (_serverDate != null && _serverDate!.isNotEmpty) return _serverDate!;
    final now = _clock();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  String get _idleLabel => _selected == null
      ? 'Select subject first - $today'
      : 'Scanning for ${_selected!.name} - $today';

  List<AttendanceEntry> get attendance => _attendance;
  bool get isLoadingAttendance => _loadingAttendance;
  String get search => _search;

  /// The Attendance List after the search box — the web DataTable's search,
  /// over the same columns.
  List<AttendanceEntry> get visibleAttendance {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _attendance;
    return [
      for (final e in _attendance)
        if ([
          e.studentNumber,
          e.name,
          e.course,
          e.section,
          e.subject,
          e.timeIn,
        ].any((field) => field.toLowerCase().contains(q)))
          e,
    ];
  }

  // ---------------------------------------------------------------- session

  /// Opens the scanner: a sign-in saved on this phone goes straight to the
  /// camera; otherwise the sign-in screen.
  Future<void> start() async {
    _session = ScannerSession.checking;
    _sessionMessage = null;
    _notify();

    try {
      final user = await _repository.restoreSession();
      if (_disposed) return;
      if (user == null) {
        _session = ScannerSession.signedOut;
        _notify();
        return;
      }
      _user = user;
      _session = ScannerSession.signedIn;
      _notify();
      await refresh();
    } on ScannerException catch (e) {
      if (_disposed) return;
      _session = ScannerSession.unreachable;
      _sessionMessage = e.message;
      _notify();
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    if (_signingIn) return;
    if (email.trim().isEmpty || password.trim().isEmpty) {
      _signInError = ScannerStrings.errorCredentialsEmpty;
      _notify();
      return;
    }

    _signingIn = true;
    _signInError = null;
    _notify();

    try {
      final user = await _repository.signIn(email: email, password: password);
      if (_disposed) return;
      _user = user;
      _session = ScannerSession.signedIn;
      _sessionMessage = null;
      _signingIn = false;
      _notify();
      await refresh();
    } on ScannerException catch (e) {
      if (_disposed) return;
      _signingIn = false;
      _signInError = e.message;
      _notify();
    }
  }

  /// Signs out on this phone. [message] is shown on the sign-in screen —
  /// why the password is being asked for, when it was not the user's idea.
  Future<void> signOut({String? message}) async {
    await _repository.signOut();
    if (_disposed) return;
    _clearScanner();
    _session = ScannerSession.signedOut;
    _sessionMessage = message;
    _notify();
  }

  /// The server no longer accepts this phone's token.
  void _signedOutByServer() {
    // Already signed out on this phone — a request still in flight when it
    // happened comes back refused. The reason already on screen stands.
    if (_session == ScannerSession.signedOut) return;
    _clearScanner();
    _session = ScannerSession.signedOut;
    _sessionMessage = ScannerStrings.sessionExpired;
    unawaited(_speech.stop());
  }

  void _clearScanner() {
    _holdTimer?.cancel();
    _user = null;
    _subjects = const [];
    _selected = null;
    _blocked = null;
    _subjectsError = null;
    _serverDate = null;
    _attendance = const [];
    _search = '';
    _result = null;
    _lastRecord = null;
    _lastCode = null;
    _recording = false;
    _signInError = null;
  }

  // --------------------------------------------------------------- subjects

  /// Reloads the subject picker and today's list — pull-to-refresh, and right
  /// after signing in.
  Future<void> refresh() async {
    await Future.wait([_loadSubjects(), _loadAttendance()]);
  }

  Future<void> _loadSubjects() async {
    _loadingSubjects = true;
    _subjectsError = null;
    _notify();

    try {
      final list = await _repository.loadSubjects();
      if (_disposed) return;
      _user = list.user;
      _subjects = list.subjects;
      _serverDate = list.date;
      _blocked = null;
      // Keep the picked subject across a refresh — with the late state the
      // server now reports — unless it is no longer assigned.
      final code = _selected?.code;
      _selected = code == null
          ? null
          : list.subjects.where((s) => s.code == code).firstOrNull;
    } on ScannerException catch (e) {
      if (_disposed) return;
      if (!_handleBlocking(e)) _subjectsError = e.message;
    }

    _loadingSubjects = false;
    _notify();
  }

  Future<void> _loadAttendance() async {
    _loadingAttendance = true;
    _notify();

    try {
      final today = await _repository.loadToday();
      if (_disposed) return;
      _attendance = today;
    } on ScannerException catch (e) {
      if (_disposed) return;
      // The subject load reports the same failure; saying it twice adds
      // nothing. Only a dead sign-in needs acting on.
      _handleBlocking(e);
    }

    _loadingAttendance = false;
    _notify();
  }

  /// Acts on the failures that stop the scanner as a whole. Returns true when
  /// [e] was one of them.
  bool _handleBlocking(ScannerException e) {
    switch (e.code) {
      case 'unauthenticated':
        _signedOutByServer();
        return true;
      case 'scanner_locked' || 'forbidden':
        _blocked = e.message;
        _selected = null;
        return true;
    }
    return false;
  }

  void selectSubject(ScanSubject? subject) {
    if (_selected == subject) return;
    _selected = subject;
    _result = null;
    _lastRecord = null;
    _holdTimer?.cancel();
    _notify();
  }

  /// Flips late marking for the selected subject at once — the instructor is
  /// mid-class, looking at the camera, not at a spinner — and puts it back if
  /// the server says no. The same as the web switch.
  Future<void> toggleLate() async {
    final subject = _selected;
    if (subject == null || _lateBusy) return;

    final turnOn = !subject.lateMarking;
    _replaceSubject(subject.copyWith(lateMarking: turnOn));
    _lateBusy = true;
    _notify();

    try {
      final on = await _repository.setLateMarking(
        subjectCode: subject.code,
        on: turnOn,
      );
      if (_disposed) return;
      _replaceSubject(subject.copyWith(lateMarking: on));
    } on ScannerException catch (e) {
      if (_disposed) return;
      _replaceSubject(subject.copyWith(lateMarking: !turnOn));
      if (!_handleBlocking(e)) {
        _alert(ScannerStrings.lateNotChanged, e.message);
      }
    }

    _lateBusy = false;
    _notify();
  }

  void _replaceSubject(ScanSubject updated) {
    _subjects = [
      for (final s in _subjects) s.code == updated.code ? updated : s,
    ];
    if (_selected?.code == updated.code) _selected = updated;
  }

  // ---------------------------------------------------------------- scanning

  /// Called with the text of every QR the camera reads.
  Future<void> onCodeScanned(String raw) async {
    final now = _clock();

    // The same code as the one just sent: the same scan, not a new one.
    if (raw == _lastCode &&
        _lastCodeAt != null &&
        now.difference(_lastCodeAt!) < repeatGuard) {
      return;
    }
    // One scan at a time. The next student's code is read again on the next
    // frame, so nothing is lost by not queueing it.
    if (_recording) return;

    _lastCode = raw;
    _lastCodeAt = now;

    final subject = _selected;
    if (subject == null) {
      _show(const ScanStatus(ScannerStrings.saySelectSubject, ScanTone.error));
      _say(ScanTone.error, ScannerStrings.saySelectSubject);
      return;
    }

    // The web scanner's format: YEAR-Registration No., three digits then
    // three or four. Anything else never reaches the server.
    final number = StudentNumber.tryParse(raw);
    if (number == null) {
      _show(const ScanStatus('Invalid QR format!', ScanTone.error));
      _say(ScanTone.error, ScannerStrings.sayInvalid);
      if (_lastAlertAt == null ||
          now.difference(_lastAlertAt!) > alertCooldown) {
        _lastAlertAt = now;
        _alert(
          ScannerStrings.invalidQrTitle,
          ScannerStrings.invalidQrBody,
          autoDismiss: const Duration(seconds: 2),
        );
      }
      return;
    }

    _recording = true;
    _notify();

    try {
      final record = await _repository.recordScan(
        studentNumber: number.value,
        subjectCode: subject.code,
      );
      if (_disposed) return;
      _recorded(record, number.value, subject);
    } on ScannerException catch (e) {
      if (_disposed) return;
      _refused(e, number.value, subject);
    }

    _recording = false;
    _notify();
  }

  void _recorded(ScanRecord record, String number, ScanSubject subject) {
    final name = record.name.isEmpty ? number : record.name;
    final late = record.late;

    _attendance = [record, ..._attendance];
    _lastRecord = record;

    if (record.photoMissing) {
      // Recorded, but there is no face to compare against — said plainly
      // rather than leaving the initials to pass for a photo.
      _show(
        ScanStatus(
          '✓ $name${late ? ' — LATE' : ''} — ⚠ no photo, identity not verified',
          ScanTone.warning,
        ),
      );
    } else if (late) {
      _show(ScanStatus('✓ $name — LATE', ScanTone.warning));
    } else {
      _show(ScanStatus('✓ $name - ${subject.name}', ScanTone.success));
    }

    // The name as a name, not the export's capitals — and one short phrase,
    // so the next scan does not cut it off mid-name.
    final spoken = nameForSpeech(record.name);
    _say(
      ScanTone.success,
      '${spoken.isEmpty ? number : spoken}, recorded${late ? ' late' : ''}.',
    );
  }

  void _refused(ScannerException e, String number, ScanSubject subject) {
    switch (e.code) {
      case 'already_marked':
        _show(ScanStatus('⚠ Already marked: $number', ScanTone.warning));
        _say(ScanTone.warning, ScannerStrings.sayAlreadyMarked);

      case 'not_authorized':
        _show(
          const ScanStatus('✗ Subject not assigned to you', ScanTone.error),
        );
        _say(ScanTone.error, ScannerStrings.sayNotAuthorized);
        _alert(
          ScannerStrings.notAuthorizedTitle,
          ScannerStrings.notAuthorizedBody,
        );

      case 'student_not_found':
        _show(ScanStatus('✗ Student $number not found', ScanTone.error));
        _say(ScanTone.error, ScannerStrings.sayNotFound);
        _alert(
          ScannerStrings.notFoundTitle,
          'Student Number: $number\nNot registered in the system.',
        );

      case 'photo_required':
        _show(
          const ScanStatus(
            '✗ No photo on file — cannot verify identity',
            ScanTone.error,
          ),
        );
        _say(ScanTone.error, ScannerStrings.sayPhotoRequired);
        _alert(
          ScannerStrings.photoRequiredTitle,
          '${e.name ?? number} has no photo on file.\n'
          'Attendance was not recorded. Ask the admin to upload a photo '
          'first.',
        );

      case 'not_enrolled':
        _show(
          ScanStatus(
            '✗ Student not enrolled in ${subject.name}',
            ScanTone.error,
          ),
        );
        _say(ScanTone.error, 'Student is not enrolled in ${subject.name}.');
        _alert(
          ScannerStrings.notEnrolledTitle,
          'Student $number is not enrolled in ${subject.name}',
        );

      case 'network':
        _show(const ScanStatus('✗ Network error', ScanTone.error));
        _say(ScanTone.error, ScannerStrings.sayNetwork);

      default:
        if (_handleBlocking(e)) {
          unawaited(_feedback.play(ScanTone.error));
          return;
        }
        _show(const ScanStatus('✗ Error saving attendance', ScanTone.error));
        _say(ScanTone.error, ScannerStrings.sayError);
        _alert(ScannerStrings.errorTitle, e.message);
    }
  }

  /// Puts [status] under the camera, and takes it (and the student card)
  /// down again after [resultHold].
  void _show(ScanStatus status) {
    _result = status;
    _holdTimer?.cancel();
    _holdTimer = Timer(resultHold, () {
      _result = null;
      _lastRecord = null;
      _notify();
    });
    _notify();
  }

  void _say(ScanTone tone, String text) {
    unawaited(_feedback.play(tone));
    unawaited(_speech.speak(text));
  }

  void _alert(String title, String body, {Duration? autoDismiss}) {
    if (!_alerts.isClosed) {
      _alerts.add(
        ScanAlert(title: title, body: body, autoDismiss: autoDismiss),
      );
    }
  }

  // ------------------------------------------------------------------ misc

  void setSearch(String value) {
    if (_search == value) return;
    _search = value;
    _notify();
  }

  /// Silences the voice — the app left the screen.
  void stopSpeaking() => unawaited(_speech.stop());

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _holdTimer?.cancel();
    unawaited(_alerts.close());
    unawaited(_speech.stop());
    super.dispose();
  }
}
