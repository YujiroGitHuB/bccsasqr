import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/live_update.dart';
import '../models/student_notice.dart';
import '../services/live_repository.dart';
import '../services/notice_store.dart';
import '../services/student_repository.dart';
import 'my_attendance_controller.dart';
import 'profile_controller.dart';

/// Show to scanner's quicker pace, held until [release].
class NoticeHurry {
  NoticeHurry._(this._onRelease);

  final VoidCallback _onRelease;
  bool _released = false;

  void release() {
    if (_released) return;
    _released = true;
    _onRelease();
  }
}

/// Notifications: the student is told the moment something happens to their
/// attendance — marked present, marked late, a record deleted — with no pull
/// to refresh. Asked for on 2026-10-01.
///
/// While the student's side is open on screen ([setActive]), the phone asks
/// the live feed (`POST /students/{no}/live`) every [every], and every
/// [hurriedEvery] while Show to scanner holds a [hurry]. Each answer carries
/// only what is new since the last; a new record goes on Home and My
/// Attendance at once ([MyAttendanceController.addRecords]), into the list
/// here, and out on [arrivals] for the island.
///
/// Nothing is asked while the app is in the background or locked: there is
/// no push service behind this, so a scan made meanwhile is told the moment
/// the app is opened again — the first look on coming back catches up.
///
/// A refusal slows it down rather than stops it: the server's own wait
/// after "too many requests", longer after each failure in a row. Only a
/// profile the record no longer matches stops it, until My Profile is set
/// up again.
class NotificationsController extends ChangeNotifier {
  NotificationsController({
    required ProfileController profile,
    required LiveRepository repository,
    required NoticeStore store,
    MyAttendanceController? attendance,
    DateTime Function()? clock,
    this.every = const Duration(seconds: 15),
    this.hurriedEvery = const Duration(seconds: 6),
    this.keep = 50,
  }) : _profile = profile,
       _repository = repository,
       _store = store,
       _attendance = attendance,
       _clock = clock ?? DateTime.now {
    _profile.addListener(_onProfile);
    unawaited(_read());
  }

  final ProfileController _profile;
  final LiveRepository _repository;
  final NoticeStore _store;
  final MyAttendanceController? _attendance;
  final DateTime Function() _clock;

  final Duration every;
  final Duration hurriedEvery;

  /// How many notices are kept; the oldest go first.
  final int keep;

  static const Duration _firstBackoff = Duration(seconds: 30);
  static const Duration _maxBackoff = Duration(minutes: 2);

  /// How long a check-in's own record is waited for, to file it quietly.
  static const Duration _quietFor = Duration(minutes: 2);

  final StreamController<List<StudentNotice>> _arrivals =
      StreamController.broadcast();

  /// Apart from the rest, so an answer with nothing new does not rebuild
  /// Home every few seconds.
  final ValueNotifier<DateTime?> _checkedAt = ValueNotifier(null);

  bool _storeRead = false;
  NoticeFeed? _kept;

  /// Whose feed it is, and the last name it is asked with.
  String? _number;
  String? _lastName;

  /// Bumped whenever the student changes, so an answer about the one before
  /// is dropped.
  int _generation = 0;

  int? _cursor;
  int? _count;
  List<StudentNotice> _notices = const [];

  bool _active = false;
  int _hurries = 0;
  Timer? _timer;
  Future<void>? _checking;

  /// Asked for again while a look was under way.
  bool _again = false;
  Duration? _backoff;
  bool _stopped = false;
  bool _disposed = false;

  /// Check-ins just made in Check in, whose records are on their way.
  final List<({String subject, String timeIn, DateTime until})> _quiet = [];

  // ---------------------------------------------------------------- getters

  /// Whether a student is set up on this phone to be told anything.
  bool get hasStudent => _number != null;

  /// Newest first.
  List<StudentNotice> get notices => _notices;

  int get unread => _notices.where((n) => !n.read).length;

  /// When the feed last answered, for "Checked 8:05 AM".
  ValueListenable<DateTime?> get checkedAt => _checkedAt;

  /// The record refused this phone's profile: nothing more is asked until
  /// My Profile is set up again.
  bool get stopped => _stopped;

  /// Notices to show as they come — not the quiet ones, a check-in's own
  /// record, which Check in has already said.
  Stream<List<StudentNotice>> get arrivals => _arrivals.stream;

  // ---------------------------------------------------------------- intents

  /// On while the student's side is on screen and open; off in the
  /// background and under the lock. Coming back on looks at once: whatever
  /// happened meanwhile is news now.
  void setActive(bool on) {
    if (_disposed || on == _active) return;
    _active = on;
    if (on) {
      unawaited(checkNow());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Asks every [hurriedEvery] instead of [every] until the hold is let go
  /// — Show to scanner, while the scan is only seconds away.
  NoticeHurry hurry() {
    _hurries++;
    _schedule();
    return NoticeHurry._(() {
      _hurries--;
      _schedule();
    });
  }

  /// Looks now — a pull to refresh, a check-in just made, a student just
  /// set up. Called while a look is under way, it waits for that one and
  /// looks once more straight after: the look under way may have started
  /// before what it was called for — before the record was written, or
  /// before the phone knew whose feed it is.
  Future<void> checkNow() {
    final under = _checking;
    if (under != null) {
      _again = true;
      return under;
    }
    _timer?.cancel();
    _timer = null;
    final check = _check().whenComplete(() {
      _checking = null;
      if (_again) {
        _again = false;
        unawaited(checkNow());
      } else {
        _schedule();
      }
    });
    return _checking = check;
  }

  /// Check in recorded [subject] at [timeIn] and said so on its island:
  /// when the record comes through here it is filed, already read, with no
  /// second island for it.
  void acknowledge(String subject, String timeIn) {
    final now = _clock();
    _quiet
      ..removeWhere((q) => q.until.isBefore(now))
      ..add((subject: subject, timeIn: timeIn, until: now.add(_quietFor)));
    unawaited(checkNow());
  }

  void markRead(String id) {
    final at = _notices.indexWhere((n) => n.id == id && !n.read);
    if (at < 0) return;
    _notices = [..._notices]..[at] = _notices[at].markRead();
    notifyListeners();
    unawaited(_save());
  }

  /// Opening Notifications is reading them.
  void markAllRead() {
    if (unread == 0) return;
    _notices = [for (final n in _notices) n.markRead()];
    notifyListeners();
    unawaited(_save());
  }

  // ---------------------------------------------------------------- the loop

  Future<void> _read() async {
    final kept = await _store.load();
    if (_disposed) return;
    _kept = kept;
    _storeRead = true;
    _onProfile();
  }

  void _onProfile() {
    if (!_storeRead || !_profile.loaded) return;
    final profile = _profile.profile;
    final number = profile?.record.studentNumber.value;

    if (number != null && number == _number) {
      // The same student, set up again with a corrected last name: worth
      // asking with it.
      if (profile!.lastName != _lastName) {
        _lastName = profile.lastName;
        _backoff = null;
        if (_stopped) {
          _stopped = false;
          notifyListeners();
        }
        if (_active) unawaited(checkNow());
      }
      return;
    }

    _generation++;
    _timer?.cancel();
    _timer = null;
    _number = number;
    _lastName = profile?.lastName;
    _stopped = false;
    _backoff = null;
    _quiet.clear();

    final kept = _kept;
    if (number != null && kept != null && kept.studentNumber == number) {
      _cursor = kept.cursor;
      _count = kept.count;
      _notices = kept.notices;
    } else {
      // Someone else's, or the student was forgotten: nothing of theirs
      // stays on the phone.
      _cursor = null;
      _count = null;
      _notices = const [];
      if (kept != null) {
        _kept = null;
        unawaited(_store.clear());
      }
    }
    notifyListeners();
    if (_active && number != null) unawaited(checkNow());
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (_disposed || !_active || _stopped || _number == null) return;
    // The check under way schedules the next when it ends.
    if (_checking != null) return;
    final wait = _backoff ?? (_hurries > 0 ? hurriedEvery : every);
    _timer = Timer(wait, () {
      _timer = null;
      unawaited(checkNow());
    });
  }

  Future<void> _check() async {
    final profile = _profile.profile;
    if (_disposed || _stopped || profile == null || _number == null) return;
    final generation = _generation;

    final LiveUpdate update;
    try {
      update = await _repository.fetchLive(
        profile.record.studentNumber,
        lastName: profile.lastName,
        since: _cursor,
      );
    } on StudentLookupException catch (e) {
      if (!_disposed && generation == _generation) _failed(e);
      return;
    } catch (_) {
      if (!_disposed && generation == _generation) {
        _failed(const StudentLookupException('', code: 'unknown'));
      }
      return;
    }
    if (_disposed || generation != _generation) return;

    _backoff = null;
    _checkedAt.value = _clock();
    await _apply(update, generation);
  }

  void _failed(StudentLookupException e) {
    switch (e.code) {
      case 'rate_limited':
        final after = e.details?['retry_after'];
        _backoff = Duration(seconds: after is int && after > 0 ? after : 60);
      case 'identity_mismatch' ||
          'student_not_found' ||
          'invalid_student_no' ||
          'missing_last_name':
        // Asking again will not change the answer; My Profile will.
        _stopped = true;
        notifyListeners();
      case 'tracker_locked':
        _backoff = _maxBackoff;
      default:
        // No signal, or the server busy: longer each time, never long.
        final last = _backoff;
        _backoff = last == null
            ? _firstBackoff
            : Duration(
                microseconds: math.min(
                  last.inMicroseconds * 2,
                  _maxBackoff.inMicroseconds,
                ),
              );
    }
  }

  Future<void> _apply(LiveUpdate update, int generation) async {
    final first = _cursor == null;
    final expected = (_count ?? 0) + update.records.length;
    final counted = _count != null;
    _cursor = update.cursor;
    _count = update.count;

    if (first) {
      // Only where the record stands: nothing from before this phone was
      // set up is news.
      unawaited(_save());
      return;
    }

    final now = _clock();
    final known = {for (final n in _notices) n.id};
    final fresh = [
      for (final r in update.records)
        if (!known.contains(StudentNotice.recordId(r.id))) r,
    ];

    final added = <StudentNotice>[];
    final told = <StudentNotice>[];
    for (final record in fresh) {
      final quiet = _takeQuiet(record, now);
      final notice = StudentNotice(
        id: StudentNotice.recordId(record.id),
        kind: record.day.late ? NoticeKind.late : NoticeKind.present,
        subject: record.subject,
        instructor: record.instructor,
        day: record.day,
        at: now,
        offline: record.offline,
        read: quiet,
      );
      added.add(notice);
      if (!quiet) told.add(notice);
    }
    if (fresh.isNotEmpty) _attendance?.addRecords(fresh);

    if (counted && !update.more && update.count < expected) {
      // Fewer than there were with the new ones: a record was deleted.
      // The history says which.
      final gone =
          await _attendance?.refreshFindingRemoved() ?? const <TodayScan>[];
      if (_disposed || generation != _generation) return;
      for (final scan in gone) {
        final notice = StudentNotice(
          id:
              'x${now.microsecondsSinceEpoch}|${scan.subject}|'
              '${scan.day.rawDate}|${scan.day.timeIn}',
          kind: NoticeKind.removed,
          subject: scan.subject,
          day: scan.day,
          at: now,
        );
        added.add(notice);
        told.add(notice);
      }
    } else if (update.more || (counted && update.count > expected)) {
      // More came than one answer carries: the history is asked for whole.
      unawaited(_attendance?.refresh());
    }

    if (added.isNotEmpty) {
      _notices = [...added, ..._notices].take(keep).toList();
      notifyListeners();
    }
    unawaited(_save());
    if (told.isNotEmpty) _arrivals.add(told);
  }

  /// Whether [record] is a check-in Check in has already told of.
  bool _takeQuiet(LiveRecord record, DateTime now) {
    final at = _quiet.indexWhere(
      (q) =>
          q.subject == record.subject &&
          q.timeIn == record.day.timeIn &&
          !q.until.isBefore(now),
    );
    if (at < 0) return false;
    _quiet.removeAt(at);
    return true;
  }

  Future<void> _save() async {
    final number = _number;
    if (number == null || _disposed) return;
    final feed = NoticeFeed(
      studentNumber: number,
      cursor: _cursor,
      count: _count,
      notices: _notices,
    );
    _kept = feed;
    await _store.save(feed);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _profile.removeListener(_onProfile);
    unawaited(_arrivals.close());
    _checkedAt.dispose();
    super.dispose();
  }
}
