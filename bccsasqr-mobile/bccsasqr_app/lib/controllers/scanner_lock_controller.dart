import 'package:flutter/foundation.dart';

import '../core/constants/app_strings.dart';
import '../services/device_lock.dart';

/// The phone's lock in front of a saved instructor sign-in.
///
/// Only ever a second door: there is nothing to unlock until an instructor
/// has signed in with their email and password, and signing out takes the
/// lock away with the sign-in. Off until the instructor turns it on — the
/// scanner offers it once, right after a sign-in.
class ScannerLockController extends ChangeNotifier {
  ScannerLockController({
    required DeviceLock device,
    required ScannerLockStore store,
    DateTime Function()? clock,
  }) : _device = device,
       _store = store,
       _clock = clock ?? DateTime.now;

  final DeviceLock _device;
  final ScannerLockStore _store;
  final DateTime Function() _clock;

  /// Away from the app this long, and the scanner locks again. Long enough
  /// that answering a message between two students does not ask for a finger;
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

  /// The instructor turned the lock on.
  bool get enabled => _enabled;

  /// The lock is on and has not been opened yet this time.
  bool get locked => _enabled && _locked;

  /// The system prompt is up.
  bool get unlocking => _unlocking;

  /// The lock was on, but the phone no longer has a screen lock: the saved
  /// sign-in must not open without the password now.
  bool get lost => _lost;

  /// Under the Unlock button after a prompt that was closed.
  String? get message => _message;

  Future<void> load() async {
    final enabled = await _store.read();
    final available = await _device.isAvailable();
    if (_disposed) return;
    // A sign-out while this was reading has already said "off"; a switch
    // read before it must not turn the lock back on for the next sign-in.
    _enabled = enabled && !_forgotten;
    _available = available;
    _locked = enabled;
    _lost = enabled && !available;
    _ready = true;
    _notify();
  }

  Future<void> unlock() async {
    if (_unlocking || !locked) return;
    _unlocking = true;
    _message = null;
    _notify();

    final result = await _device.unlock(ScannerStrings.lockReason);
    if (_disposed) return;
    _unlocking = false;
    switch (result) {
      case DeviceUnlock.unlocked:
        _locked = false;
      case DeviceUnlock.cancelled:
        _message = ScannerStrings.lockNotUnlocked;
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

    final result = await _device.unlock(ScannerStrings.lockEnableReason);
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

  /// Signed out: the lock went with the sign-in it was guarding. The next
  /// instructor on this phone decides for themselves.
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
