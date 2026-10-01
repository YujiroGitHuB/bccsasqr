import 'package:flutter/foundation.dart';

import '../services/device_lock.dart';

/// The phone's own lock — fingerprint, face or screen lock — in front of
/// what is saved on it: an instructor's sign-in (ScannerLockController), or
/// the student's side of the app (StudentLockGate).
///
/// Only ever a second door, and off until whoever holds the phone turns it
/// on. Turning it on asks for the lock first, so the finger that opens it
/// later is the owner's. Taking away what it guards — a sign-out, a
/// forgotten profile — takes the lock with it.
class PhoneLockController extends ChangeNotifier {
  PhoneLockController({
    required DeviceLock device,
    required LockSwitchStore store,
    required this.reason,
    required this.enableReason,
    required this.notUnlocked,
    DateTime Function()? clock,
  }) : _device = device,
       _store = store,
       _clock = clock ?? DateTime.now;

  final DeviceLock _device;
  final LockSwitchStore _store;
  final DateTime Function() _clock;

  /// Under the system prompt: when it opens the lock, and when it turns the
  /// lock on.
  final String reason;
  final String enableReason;

  /// Under the Unlock button after a prompt that was closed.
  final String notUnlocked;

  /// Away from the app this long, and it locks again. Long enough that
  /// answering a message between two students does not ask for a finger;
  /// short enough that a phone left on the desk does not stay open.
  static const Duration relockAfter = Duration(minutes: 1);

  bool _ready = false;
  bool _available = false;
  bool _enabled = false;
  bool _locked = false;
  bool _unlocking = false;
  bool _lost = false;
  bool _disposed = false;
  bool _forgotten = false;
  String? _message;
  DateTime? _hiddenAt;

  /// The switch and the phone have both been read.
  bool get ready => _ready;

  /// The phone has a screen lock to ask for.
  bool get available => _available;

  /// Whoever holds the phone turned the lock on.
  bool get enabled => _enabled;

  /// The lock is on and has not been opened yet this time.
  bool get locked => _enabled && _locked;

  /// The system prompt is up.
  bool get unlocking => _unlocking;

  /// The lock was on, but the phone no longer has a screen lock: there is
  /// nothing left to ask for. The scanner's saved sign-in then wants the
  /// password; the student's lock turns itself off and says so.
  bool get lost => _lost;

  /// Under the Unlock button after a prompt that was closed.
  String? get message => _message;

  Future<void> load() async {
    final enabled = await _store.read();
    if (_disposed) return;
    // A sign-out (or a forgotten profile) while this was reading has already
    // said "off"; a switch read before it must not turn the lock back on for
    // whoever is next.
    _enabled = enabled && !_forgotten;
    _locked = enabled;
    if (!_enabled) {
      // Off: nothing to wait for before opening. Whether the phone could
      // lock only matters to the switch, and can come a moment later.
      _ready = true;
      _notify();
    }

    final available = await _device.isAvailable();
    if (_disposed) return;
    _available = available;
    _lost = _enabled && !available;
    _ready = true;
    _notify();
  }

  Future<void> unlock() async {
    if (_unlocking || !locked) return;
    _unlocking = true;
    _message = null;
    _notify();

    final result = await _device.unlock(reason);
    if (_disposed) return;
    _unlocking = false;
    switch (result) {
      case DeviceUnlock.unlocked:
        _locked = false;
      case DeviceUnlock.cancelled:
        _message = notUnlocked;
      case DeviceUnlock.unavailable:
        _available = false;
        _lost = true;
    }
    _notify();
  }

  /// Turns the lock on — once the phone's owner has proved it is them, so a
  /// finger that is not theirs cannot be the one that opens it later.
  /// Returns whether it is on.
  Future<bool> enable() async {
    if (!_available || _enabled || _unlocking) return _enabled;
    _unlocking = true;
    _notify();

    final result = await _device.unlock(enableReason);
    if (_disposed) return false;
    _unlocking = false;
    if (result == DeviceUnlock.unlocked) {
      _enabled = true;
      _locked = false;
      await _store.write(true);
    } else if (result == DeviceUnlock.unavailable) {
      _available = false;
    }
    _notify();
    return _enabled;
  }

  Future<void> disable() async {
    _enabled = false;
    _locked = false;
    _message = null;
    _notify();
    await _store.write(false);
  }

  /// What it was guarding is gone — the scanner signed out, the student's
  /// profile forgotten — and the lock goes with it. Whoever is next on this
  /// phone decides for themselves.
  Future<void> forget() async {
    final wasOn = _enabled || _lost;
    _forgotten = true;
    _enabled = false;
    _locked = false;
    _lost = false;
    _message = null;
    if (wasOn) _notify();
    await _store.write(false);
  }

  /// The app went to the background.
  void onHidden() {
    // The PIN screen is another app, as far as the lifecycle can tell.
    if (_unlocking) return;
    _hiddenAt = _clock();
  }

  /// The app came back: lock again if it was away long enough, and notice a
  /// screen lock that was switched off meanwhile.
  Future<void> onShown() async {
    final away = _hiddenAt;
    _hiddenAt = null;
    if (away == null || !_enabled) return;

    if (_clock().difference(away) >= relockAfter) {
      _locked = true;
      _message = null;
      _notify();
    }

    final available = await _device.isAvailable();
    if (_disposed || available || !_enabled) return;
    _available = false;
    _lost = true;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
