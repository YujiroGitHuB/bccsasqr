import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_strings.dart';
import '../models/class_link.dart';
import '../services/check_in_repository.dart';
import '../services/device_lock.dart';
import '../services/student_repository.dart';
import 'profile_controller.dart';

/// Where Check in stands.
enum CheckInStage {
  /// Waiting for a code — the camera is on, if the student turned it on.
  idle,

  /// A code was read or typed; asking which class it is.
  looking,

  /// The class is on screen, waiting for the student to confirm.
  found,

  /// The check-in is on its way.
  sending,
}

/// The length of a class code today (link_generate_code()). Typing stops
/// there and the lookup starts by itself.
const int classCodeLength = 6;

/// Check in's state and rules: read or type the class code, see which class
/// it is, confirm, and the student this phone is set up for is recorded —
/// the web form's steps (pages/daily_attendance.php) without typing a
/// student number.
///
/// On a phone with a screen lock, every check-in asks for it first — the
/// fingerprint, face or PIN of the phone's owner — so a classmate holding an
/// absent student's phone cannot check them in (asked for on 2026-10-01). A
/// phone with no screen lock has nothing to ask for, and sends as before.
class CheckInController extends ChangeNotifier {
  CheckInController({
    required CheckInRepository repository,
    required ProfileController profile,
    required DeviceTokenStore devices,
    DeviceLock deviceLock = const NoDeviceLock(),
  }) : _repository = repository,
       _profile = profile,
       _devices = devices,
       _deviceLock = deviceLock;

  final CheckInRepository _repository;
  final ProfileController _profile;
  final DeviceTokenStore _devices;
  final DeviceLock _deviceLock;

  CheckInStage _stage = CheckInStage.idle;
  String _code = '';
  ClassLink? _link;
  String? _error;
  bool _asksOwner = false;
  int _token = 0;
  bool _disposed = false;

  /// The last thing the camera read that was not a class code, so holding
  /// it in view does not say so twelve times a second.
  String? _ignored;

  CheckInStage get stage => _stage;

  /// The code as typed or read — up to [classCodeLength] characters.
  String get code => _code;
  ClassLink? get link => _link;

  /// Why the last step did not go through, in words to show.
  String? get error => _error;

  /// The class found, on a phone with a screen lock: confirming asks for
  /// it, and the button says so with a fingerprint.
  bool get asksOwner => _asksOwner;

  bool get busy =>
      _stage == CheckInStage.looking || _stage == CheckInStage.sending;

  /// The camera only runs while there is nothing else on screen — and only
  /// when the student has it on (Settings keeps that choice).
  bool get cameraOn => _stage == CheckInStage.idle;

  /// Every keystroke in the code boxes.
  void onCodeTyped(String raw) {
    if (busy) return;
    final letters = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final code = letters.length > classCodeLength
        ? letters.substring(0, classCodeLength)
        : letters;
    _code = code;
    _error = null;
    _link = null;
    _stage = CheckInStage.idle;
    notifyListeners();
    if (code.length == classCodeLength) unawaited(_lookUp(code));
  }

  /// What the student pasted — the instructor's whole message from the
  /// group chat, the link alone, or the code alone. Whatever holds a class
  /// code is looked up at once; anything else says so. True when there was
  /// a code.
  bool onPasted(String? text) {
    if (busy) return false;
    final pasted = text?.trim() ?? '';
    final code = pasted.isEmpty ? null : ClassLink.codeIn(pasted);
    if (code == null) {
      _error = pasted.isEmpty
          ? CheckInStrings.pasteEmpty
          : CheckInStrings.pasteNoCode;
      notifyListeners();
      return false;
    }
    _ignored = null;
    _code = code;
    _link = null;
    unawaited(_lookUp(code));
    return true;
  }

  /// Every code the camera reads — the same one over and over while it is
  /// in view, which is ignored after the first.
  void onScanned(String raw) {
    if (_stage != CheckInStage.idle) return;
    final code = ClassLink.codeFrom(raw);
    if (code == null) {
      if (raw == _ignored) return;
      _ignored = raw;
      _error = CheckInStrings.notAClassQr;
      notifyListeners();
      return;
    }
    _ignored = null;
    _code = code;
    unawaited(_lookUp(code));
  }

  Future<void> _lookUp(String code) async {
    final token = ++_token;
    _stage = CheckInStage.looking;
    _error = null;
    notifyListeners();

    try {
      // Asked alongside, so the class card knows whether its button will
      // ask for a finger.
      final asksOwner = _deviceLock.isAvailable();
      final link = await _repository.findClass(code);
      final asks = await asksOwner;
      if (_disposed || token != _token) return;
      _link = link;
      _asksOwner = asks;
      _stage = CheckInStage.found;
    } on StudentLookupException catch (e) {
      if (_disposed || token != _token) return;
      _error = e.message;
      _stage = CheckInStage.idle;
    }
    notifyListeners();
  }

  /// "Check in as …". The result for the island, or null when it did not
  /// go through — [error] says why.
  Future<CheckInResult?> confirm() async {
    final link = _link;
    final profile = _profile.profile;
    if (_stage != CheckInStage.found || link == null || profile == null) {
      return null;
    }

    final token = ++_token;
    _stage = CheckInStage.sending;
    _error = null;
    notifyListeners();

    // The phone's owner, not whoever is holding it. Asked again each time,
    // not trusted from the lookup: a screen lock set or removed in between
    // counts. One taken away mid-prompt leaves nothing to ask for.
    if (await _deviceLock.isAvailable()) {
      final answer = await _deviceLock.unlock(CheckInStrings.lockReason);
      if (_disposed || token != _token) return null;
      if (answer == DeviceUnlock.cancelled) {
        // Nothing sent; the class stays up to try again.
        _error = CheckInStrings.lockNotConfirmed;
        _stage = CheckInStage.found;
        notifyListeners();
        return null;
      }
    }
    if (_disposed || token != _token) return null;

    try {
      final result = await _repository.checkIn(
        link.shortCode,
        number: profile.record.studentNumber,
        lastName: profile.lastName,
        device: await _devices.load(),
        onDevice: (device) => unawaited(_devices.save(device)),
      );
      if (_disposed || token != _token) return null;
      _clear();
      return result;
    } on StudentLookupException catch (e) {
      if (_disposed || token != _token) return null;
      _error = e.code == 'photo_required'
          ? CheckInStrings.photoRequired
          : e.message;
      // Nothing left to try with this code — closed, already in, not this
      // student's class. A dropped connection keeps the class to try again.
      _stage = e.code == 'network' ? CheckInStage.found : CheckInStage.idle;
      if (_stage == CheckInStage.idle) {
        _link = null;
        _code = '';
      }
      notifyListeners();
      return null;
    }
  }

  /// Pull to refresh. The class on screen is asked about again — its late
  /// and closing times move on, and a link closed or renewed meanwhile says
  /// so. With none, the page starts fresh: the last message and a code half
  /// typed are cleared. Nothing while a look-up or a check-in is on its way.
  Future<void> refresh() async {
    switch (_stage) {
      case CheckInStage.looking || CheckInStage.sending:
        return;
      case CheckInStage.idle:
        reset();
      case CheckInStage.found:
        final link = _link;
        if (link == null) return;
        final token = ++_token;
        try {
          final asksOwner = _deviceLock.isAvailable();
          final fresh = await _repository.findClass(link.shortCode);
          final asks = await asksOwner;
          if (_disposed || token != _token) return;
          _link = fresh;
          _asksOwner = asks;
          _error = null;
        } on StudentLookupException catch (e) {
          if (_disposed || token != _token) return;
          _error = e.message;
          // No signal keeps the class to try again; anything else — closed,
          // renewed — leaves nothing to check in to.
          if (e.code != 'network') _clear();
        }
        notifyListeners();
    }
  }

  /// Back to the camera — "Scan another code", or after a check-in.
  void reset() {
    _token++;
    _clear();
    _error = null;
    notifyListeners();
  }

  void _clear() {
    _stage = CheckInStage.idle;
    _link = null;
    _code = '';
    _ignored = null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
