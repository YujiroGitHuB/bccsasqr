import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/constants/app_strings.dart';
import '../core/utils/student_number.dart';
import '../models/offline_scan.dart';
import '../models/scanner_models.dart';
import '../services/offline_scan_store.dart';
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

/// A message the page should put up — the web scanner's SweetAlert, shown
/// on the island.
class ScanAlert {
  const ScanAlert({
    required this.title,
    required this.body,
    this.autoDismiss,
    this.tone = ScanTone.error,
  });

  final String title;
  final String body;

  /// Closes itself after this long, like the web's "Invalid QR Code" (2 s).
  final Duration? autoDismiss;

  /// Nearly always a refusal; scans sent after being offline are good news.
  final ScanTone tone;
}

/// Owns the scanner screen's state and every rule about what a scan means for
/// it — the app's port of `Qrscanner/js/scriptV3.js`. The widgets read this
/// and render. What a scan means for the *record* is not decided here at all:
/// the server runs the web scanner's own rules (`includes/scan_attendance.php`)
/// and this only reports the answer.
///
/// With no internet the scanner keeps going: a scan is checked against the
/// class list downloaded for its subject, kept on the phone
/// ([OfflineScanStore]) and sent when the server can be reached — where the
/// same rules are run on it again.
class ScannerController extends ChangeNotifier {
  ScannerController({
    required ScannerRepository repository,
    SpeechService speech = const SilentSpeechService(),
    ScanFeedback feedback = const SilentScanFeedback(),
    OfflineScanStore? store,
    Stream<bool>? online,
    this.resultHold = const Duration(seconds: 5),
    this.repeatGuard = const Duration(milliseconds: 2500),
    this.alertCooldown = const Duration(seconds: 3),
    this.retryEvery = const Duration(seconds: 30),
    DateTime Function()? clock,
  }) : _repository = repository,
       _speech = speech,
       _feedback = feedback,
       _store = store ?? MemoryOfflineScanStore(),
       _clock = clock ?? DateTime.now {
    _onlineChanges = online?.listen(_onConnectivity);
  }

  final ScannerRepository _repository;
  final SpeechService _speech;
  final ScanFeedback _feedback;
  final OfflineScanStore _store;
  final DateTime Function() _clock;
  final Random _random = Random();

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

  /// While scans are kept on the phone, how often sending them is tried.
  final Duration retryEvery;

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

  bool _cameraOn = true;
  bool _recording = false;
  String? _lastCode;
  DateTime? _lastCodeAt;
  DateTime? _lastAlertAt;
  ScanStatus? _result;
  ScanRecord? _lastRecord;

  List<AttendanceEntry> _attendance = const [];
  bool _loadingAttendance = false;
  String _search = '';
  String? _attendanceSubject;

  /// Scans made with no internet, oldest first, not yet answered for.
  final List<PendingScan> _queue = [];

  /// Kept scans the server refused, until the instructor has seen why.
  final List<PendingScan> _notSaved = [];

  /// The server could not be reached last time: scans go straight to
  /// [_queue] instead of each waiting out another timeout.
  bool _offline = false;
  bool _syncing = false;

  /// Class lists by subject code, to check a scan against with no internet.
  final Map<String, SubjectRoster> _rosters = {};
  final Map<String, Future<void>> _rosterLoads = {};

  StreamSubscription<bool>? _onlineChanges;
  Timer? _retry;

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
  /// "Please select a subject first" gate — and only while the instructor
  /// has not switched it off.
  bool get cameraActive => _canScan && _cameraOn;

  /// A subject is picked, but the instructor switched the camera off —
  /// between classes, or with nobody left in the queue. The camera, the
  /// light beside it and the screen's stay-awake are all let go.
  bool get cameraPaused => _canScan && !_cameraOn;

  bool get _canScan =>
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
    return scanDate(_clock());
  }

  String get _idleLabel => _selected == null
      ? 'Select subject first - $today'
      : !_cameraOn
      ? ScannerStrings.cameraOffStatus
      : 'Scanning for ${_selected!.name} - $today';

  /// Today's scans, newest first: the ones still kept on this phone, then
  /// the server's.
  List<AttendanceEntry> get attendance => _queue.isEmpty
      ? _attendance
      : [for (final s in _queue.reversed) s.toRecord(), ..._attendance];
  bool get isLoadingAttendance => _loadingAttendance;
  String get search => _search;

  /// The subject the full Attendance List shows — the one being scanned,
  /// until another, or all (null), is picked there.
  String? get attendanceSubject => _attendanceSubject;

  /// The Attendance List after the subject and the search box — the web
  /// DataTable's search, over the same columns.
  List<AttendanceEntry> get visibleAttendance {
    final q = _search.trim().toLowerCase();
    final subject = _attendanceSubject;
    return [
      for (final e in attendance)
        if ((subject == null || e.subject == subject) &&
            (q.isEmpty ||
                [
                  e.studentNumber,
                  e.name,
                  e.course,
                  e.section,
                  e.subject,
                  e.timeIn,
                ].any((field) => field.toLowerCase().contains(q))))
          e,
    ];
  }

  /// Scans waiting on this phone to be sent.
  int get pendingCount => _queue.length;

  /// Scans sent after being offline and refused, each with why.
  List<PendingScan> get notSaved => List.unmodifiable(_notSaved);

  /// The server could not be reached: scans are being kept on the phone.
  bool get isOffline => _offline;
  bool get isSyncing => _syncing;

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
      await _loadKept();
      await refresh();
    } on ScannerException catch (e) {
      if (_disposed) return;
      if (e.code == 'network' && await _openOffline()) return;
      if (_disposed) return;
      _session = ScannerSession.unreachable;
      _sessionMessage = e.message;
      _notify();
    }
  }

  /// A saved sign-in and no internet to check it with: the scanner opens on
  /// what this phone last loaded — the account, its subjects, their class
  /// lists — so the class at the door can still be scanned. The sign-in is
  /// checked the moment the server answers again.
  ///
  /// False when there is nothing to open on: this phone never loaded the
  /// subjects, or the last sign-out cleared them.
  Future<bool> _openOffline() async {
    SubjectList? kept;
    try {
      kept = await _store.session();
    } catch (_) {
      kept = null;
    }
    if (_disposed || kept == null) return false;

    _user = kept.user;
    _subjects = _keptToday(kept);
    _offline = true;
    _session = ScannerSession.signedIn;
    _sessionMessage = null;

    for (final subject in _subjects) {
      try {
        final roster = await _store.roster(kept.user.id, subject.code);
        if (roster != null) _rosters[subject.code] = roster;
      } catch (_) {
        // Scanned without it, then: kept unchecked, checked when sent.
      }
    }
    if (_disposed) return true;
    _notify();
    await _loadKept();
    return true;
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
      await _loadKept();
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
  ///
  /// Scans still kept on the phone stay, under this account, and are sent
  /// the next time it signs in here. The class lists go.
  Future<void> signOut({String? message}) async {
    await _repository.signOut();
    await _quietly(_store.forget);
    if (_disposed) return;
    _clearScanner();
    _session = ScannerSession.signedOut;
    _sessionMessage = message;
    _notify();
  }

  /// Another tab on this sign-in — Links — was refused for a dead token:
  /// back to the sign-in form, as a refused scan would send it.
  void sessionExpired() {
    if (_disposed) return;
    _signedOutByServer();
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
    unawaited(_quietly(_store.forget));
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
    _attendanceSubject = null;
    _queue.clear();
    _notSaved.clear();
    _rosters.clear();
    _offline = false;
    _stopRetry();
    _result = null;
    _lastRecord = null;
    _lastCode = null;
    _recording = false;
    _cameraOn = true;
    _signInError = null;
  }

  // --------------------------------------------------------------- subjects

  /// Sends whatever was kept offline, then reloads the subject picker and
  /// today's list — pull-to-refresh, right after signing in, and when the
  /// phone is back online. The class lists follow in the background.
  Future<void> refresh() async {
    await sync();
    if (_disposed || _session != ScannerSession.signedIn) return;
    await Future.wait([_loadSubjects(), _loadAttendance()]);
    unawaited(_downloadRosters());
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
      _offline = false;
      // What a saved sign-in opens on next time, if there is no internet.
      unawaited(_quietly(() => _store.saveSession(list)));
      // Keep the picked subject across a refresh — with the late state the
      // server now reports — unless it is no longer assigned.
      final code = _selected?.code;
      _selected = code == null
          ? null
          : list.subjects.where((s) => s.code == code).firstOrNull;
    } on ScannerException catch (e) {
      if (_disposed) return;
      if (e.code == 'network') {
        _offline = true;
        // The sign-in answered but the connection dropped before the
        // subjects came: the ones this phone last loaded, rather than
        // nothing to scan for.
        if (_subjects.isEmpty && await _keptSubjects()) {
          _loadingSubjects = false;
          _notify();
          return;
        }
      }
      if (!_handleBlocking(e)) _subjectsError = e.message;
    }

    _loadingSubjects = false;
    _notify();
  }

  /// This account's subjects as the phone last loaded them. False when there
  /// are none, or they are another account's.
  Future<bool> _keptSubjects() async {
    final user = _user;
    SubjectList? kept;
    try {
      kept = await _store.session();
    } catch (_) {
      kept = null;
    }
    if (_disposed || kept == null || user == null) return false;
    if (kept.user.id != user.id) return false;
    _subjects = _keptToday(kept);
    return true;
  }

  /// Kept subjects, with a late switch from an earlier day off: it lasts
  /// only the day it was turned on.
  List<ScanSubject> _keptToday(SubjectList kept) =>
      kept.date == scanDate(_clock())
      ? kept.subjects
      : [for (final s in kept.subjects) s.copyWith(lateMarking: false)];

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
    // The full list opens on the class being scanned.
    _attendanceSubject = subject?.name;
    // Picking a subject is getting ready to scan: a camera switched off for
    // the last class comes back on for this one, and its class list is
    // fetched now, while there may still be internet.
    if (subject != null) {
      _cameraOn = true;
      unawaited(_ensureRoster(subject));
    }
    _notify();
  }

  /// The camera's own switch, under the picture. Off lets the camera go —
  /// and with it the screen's stay-awake — without losing the subject.
  void setCameraOn(bool on) {
    if (_cameraOn == on) return;
    _cameraOn = on;
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

    if (_offline) {
      await _keep(number.value, subject, now);
    } else if (_isKept(number.value, subject, now)) {
      // Kept on this phone earlier and not yet sent: the server has not
      // heard of it, and would take it twice.
      _refused(_alreadyMarked, number.value, subject);
    } else {
      try {
        final record = await _repository.recordScan(
          studentNumber: number.value,
          subjectCode: subject.code,
        );
        if (_disposed) return;
        _offline = false;
        _recorded(record, number.value, subject);
        // It went through, so the kept ones can follow.
        if (_queue.isNotEmpty) unawaited(sync());
      } on ScannerException catch (e) {
        if (_disposed) return;
        if (e.code == 'network') {
          // No answer: this scan is kept on the phone instead, and the next
          // ones go straight there until the server is back.
          _offline = true;
          await _keep(number.value, subject, now);
        } else {
          _refused(e, number.value, subject);
        }
      }
    }

    if (_disposed) return;
    _recording = false;
    _notify();
  }

  static const ScannerException _alreadyMarked = ScannerException(
    'Already marked today.',
    code: 'already_marked',
  );

  // ---------------------------------------------------------------- offline

  /// A scan made with no internet: checked against what this phone knows —
  /// the scans already made, and the class list downloaded for [subject] —
  /// then kept, to be sent later. The server checks it again then.
  Future<void> _keep(String number, ScanSubject subject, DateTime at) async {
    final user = _user;
    if (user == null) return;

    final day = scanDate(at);
    if (_isKept(number, subject, at) ||
        _attendance.any(
          (e) =>
              e.studentNumber == number &&
              e.subject == subject.name &&
              e.date == day,
        )) {
      _refused(_alreadyMarked, number, subject);
      return;
    }

    // No class list (never downloaded for this subject): kept unchecked, and
    // the server answers for it when it is sent.
    final roster = _rosters[subject.code];
    final student = roster?.students[number];
    if (roster != null && student == null) {
      _refused(
        ScannerException(
          '$number is not on the class list of ${subject.name}.',
          code: 'not_enrolled',
        ),
        number,
        subject,
      );
      return;
    }
    if (student != null && roster!.photoRequired && !student.hasPhoto) {
      _refused(
        ScannerException(
          '${student.name} has no photo on file.',
          code: 'photo_required',
          name: student.name,
        ),
        number,
        subject,
      );
      return;
    }

    final scan = PendingScan(
      id:
          '${at.microsecondsSinceEpoch.toRadixString(36)}-'
          '${_random.nextInt(1 << 32).toRadixString(36)}',
      userId: user.id,
      studentNumber: number,
      subjectCode: subject.code,
      subjectName: subject.name,
      scannedAt: at,
      late: subject.lateMarking,
      name: student?.name ?? '',
      course: student?.course ?? '',
      section: student?.section ?? '',
      photoMissing: student != null && !student.hasPhoto,
    );
    _queue.add(scan);
    // Written at once: this is the copy that survives the app being closed.
    await _quietly(() => _store.put(scan));
    if (_disposed) return;
    _kept(scan);
    _startRetry();
  }

  /// [number] is kept on this phone for [subject], on [at]'s day.
  bool _isKept(String number, ScanSubject subject, DateTime at) {
    final day = scanDate(at);
    return _queue.any(
      (s) =>
          s.studentNumber == number &&
          s.subjectCode == subject.code &&
          scanDate(s.scannedAt) == day,
    );
  }

  void _kept(PendingScan scan) {
    final name = scan.label;
    const offline = ScannerStrings.savedOffline;
    _lastRecord = scan.toRecord();

    if (scan.photoMissing) {
      _show(
        ScanStatus(
          '✓ $name${scan.late ? ' — LATE' : ''} — $offline — ⚠ no photo',
          ScanTone.warning,
        ),
      );
    } else if (scan.late) {
      _show(ScanStatus('✓ $name — LATE — $offline', ScanTone.warning));
    } else {
      _show(ScanStatus('✓ $name — $offline', ScanTone.success));
    }

    final spoken = nameForSpeech(scan.name);
    _say(
      ScanTone.success,
      '${spoken.isEmpty ? scan.studentNumber : spoken}, saved offline'
      '${scan.late ? ', late' : ''}.',
    );
  }

  /// Sends the scans kept on this phone. Runs when the phone is back online,
  /// every [retryEvery] while any are waiting, when the app comes back to
  /// the front, after a live scan goes through, on pull-to-refresh, and from
  /// **Send now**.
  ///
  /// True when the server was reached, false when it was not, null when
  /// there was nothing to send or no way to send it.
  Future<bool?> sync() async {
    final user = _user;
    if (_syncing ||
        user == null ||
        _session != ScannerSession.signedIn ||
        _blocked != null ||
        _queue.isEmpty) {
      return null;
    }

    _syncing = true;
    _notify();

    var sent = 0;
    final refused = <PendingScan>[];
    var reached = true;

    try {
      while (_queue.isNotEmpty) {
        final batch = _queue.take(syncBatch).toList();
        final answers = {
          for (final o in await _repository.syncScans(batch)) o.id: o,
        };
        if (_disposed || _user?.id != user.id) return true;

        final saved = <String>{};
        final done = <String>{};
        for (final scan in batch) {
          final answer = answers[scan.id];
          switch (answer?.status) {
            case SyncStatus.saved || SyncStatus.alreadyMarked:
              saved.add(scan.id);
              done.add(scan.id);
            case SyncStatus.rejected:
              final why = scan.rejectedWith(
                answer!.rejection ??
                    const ScanRejection(code: 'unknown', message: 'Not saved.'),
              );
              refused.add(why);
              done.add(scan.id);
              await _quietly(() => _store.put(why));
            // Failed on the server, or no answer for it: sent again later.
            case SyncStatus.error || null:
              break;
          }
        }
        sent += saved.length;
        _queue.removeWhere((s) => done.contains(s.id));
        await _quietly(() => _store.remove(saved));

        // The server failed on every one of them: later, not in a loop.
        if (done.isEmpty) break;
      }
      _offline = false;
    } on ScannerException catch (e) {
      if (_disposed) return false;
      reached = e.code != 'network';
      if (reached) {
        _handleBlocking(e);
      } else {
        _offline = true;
      }
    } finally {
      _syncing = false;
    }
    if (_disposed || _user?.id != user.id) return reached;

    _notSaved.addAll(refused);
    if (_queue.isEmpty) _stopRetry();

    if (sent > 0) {
      // The list, now from the server, with them in it.
      await _loadAttendance();
      if (refused.isEmpty) {
        _alert(
          ScannerStrings.syncedTitle(sent),
          ScannerStrings.syncedBody,
          tone: ScanTone.success,
        );
      }
    }
    if (refused.isNotEmpty) {
      _alert(
        ScannerStrings.notSavedCountTitle(refused.length),
        ScannerStrings.notSavedCountBody,
      );
    }
    _notify();
    return reached;
  }

  /// The instructor has read why: the refused scans are let go.
  Future<void> dismissNotSaved() async {
    final ids = [for (final s in _notSaved) s.id];
    _notSaved.clear();
    _notify();
    await _quietly(() => _store.remove(ids));
  }

  /// The app is back in front: whatever is kept is tried again at once.
  void onResumed() => unawaited(sync());

  /// This account's scans kept on the phone from before — made offline and
  /// not yet sent, or refused and not yet seen.
  Future<void> _loadKept() async {
    final user = _user;
    if (user == null) return;
    final List<PendingScan> kept;
    try {
      kept = await _store.scans(user.id);
    } catch (_) {
      return;
    }
    if (_disposed || _user?.id != user.id) return;

    _queue
      ..clear()
      ..addAll(kept.where((s) => s.rejection == null));
    _notSaved
      ..clear()
      ..addAll(kept.where((s) => s.rejection != null));
    if (_queue.isNotEmpty) _startRetry();
    _notify();
  }

  /// [subject]'s class list on hand: today's from the server when there is
  /// internet, else the last one this phone kept.
  Future<void> _ensureRoster(ScanSubject subject) =>
      _rosterLoads[subject.code] ??= _loadRoster(
        subject,
      ).whenComplete(() => _rosterLoads.remove(subject.code));

  Future<void> _loadRoster(ScanSubject subject) async {
    final user = _user;
    if (user == null) return;
    final code = subject.code;
    if (_rosters[code]?.date == today) return;

    if (!_offline) {
      try {
        final roster = await _repository.loadRoster(code);
        if (_disposed || _user?.id != user.id) return;
        _rosters[code] = roster;
        await _quietly(() => _store.saveRoster(user.id, roster));
        return;
      } on ScannerException {
        // An older one, below, if there is one. The scan is checked when it
        // is sent either way.
      }
    }
    if (_rosters.containsKey(code)) return;
    try {
      final kept = await _store.roster(user.id, code);
      if (kept != null && !_disposed && _user?.id == user.id) {
        _rosters[code] = kept;
      }
    } catch (_) {
      // None, then.
    }
  }

  /// Every subject's class list, one after another, in the background — so
  /// a class can be scanned offline even if its subject was never picked
  /// while there was internet. An admin, who may scan every subject in the
  /// school, gets only the one picked.
  Future<void> _downloadRosters() async {
    final user = _user;
    if (user == null) return;
    final subjects = user.isAdmin
        ? [?_selected]
        : List<ScanSubject>.of(_subjects);
    for (final subject in subjects) {
      if (_disposed || _offline || _user?.id != user.id) return;
      await _ensureRoster(subject);
    }
  }

  /// The phone's own word on its network. Losing it sends scans straight to
  /// the phone; getting it back sends them on and reloads the rest.
  void _onConnectivity(bool up) {
    if (_session != ScannerSession.signedIn) return;
    if (!up) {
      if (_offline) return;
      _offline = true;
      _notify();
      return;
    }
    final was = _offline;
    _offline = false;
    _notify();
    if (was || _queue.isNotEmpty) unawaited(refresh());
  }

  /// While offline, the whole of [refresh]: the server coming back is also
  /// when the sign-in is checked again and the subjects reloaded — the phone
  /// may never report a change, when it was the server that was away.
  void _startRetry() {
    _retry ??= Timer.periodic(retryEvery, (_) {
      if (_queue.isEmpty) {
        _stopRetry();
      } else {
        unawaited(_offline ? refresh() : sync());
      }
    });
  }

  void _stopRetry() {
    _retry?.cancel();
    _retry = null;
  }

  /// The store is the phone's memory for when there is no internet. A write
  /// that fails costs that, never the scan in hand: it stays in memory until
  /// sent.
  Future<void> _quietly(Future<void> Function() write) async {
    try {
      await write();
    } catch (_) {
      // See above.
    }
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

  void _alert(
    String title,
    String body, {
    Duration? autoDismiss,
    ScanTone tone = ScanTone.error,
  }) {
    if (!_alerts.isClosed) {
      _alerts.add(
        ScanAlert(
          title: title,
          body: body,
          autoDismiss: autoDismiss,
          tone: tone,
        ),
      );
    }
  }

  // ------------------------------------------------------------------ misc

  void setSearch(String value) {
    if (_search == value) return;
    _search = value;
    _notify();
  }

  /// The subject the full list shows; null for all of them.
  void setAttendanceSubject(String? subject) {
    if (_attendanceSubject == subject) return;
    _attendanceSubject = subject;
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
    _stopRetry();
    unawaited(_onlineChanges?.cancel());
    unawaited(_alerts.close());
    unawaited(_speech.stop());
    super.dispose();
  }
}
