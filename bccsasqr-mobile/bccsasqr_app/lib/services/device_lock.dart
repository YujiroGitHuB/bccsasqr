import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How asking for the phone's lock came out.
enum DeviceUnlock {
  /// The owner's fingerprint, face or screen lock was given.
  unlocked,

  /// The prompt was closed, or the finger was not recognised. Ask again.
  cancelled,

  /// The phone has no screen lock any more — nothing left to ask for.
  unavailable,
}

/// The phone's own lock — fingerprint, face, or the PIN, pattern or password
/// behind them — used to open a sign-in saved on it.
abstract interface class DeviceLock {
  /// Whether the phone has any screen lock to ask for.
  Future<bool> isAvailable();

  /// Shows the system prompt with [reason] under it.
  Future<DeviceUnlock> unlock(String reason);
}

/// The system prompt, through local_auth.
///
/// Biometrics are not required: a phone locked with only a PIN or pattern
/// uses that, and a finger that will not read can fall back to it. What
/// matters is that it is the phone's owner — the same person who signed in.
class LocalAuthDeviceLock implements DeviceLock {
  LocalAuthDeviceLock([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      // A plugin that never answers must not hold the scanner on its
      // splash. Silence counts as no lock — and a lock that was on then
      // asks for the password, which is the safe way to be wrong.
      return await _auth.isDeviceSupported().timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );
    } catch (_) {
      // No plugin (the web build), or a phone that will not say.
      return false;
    }
  }

  @override
  Future<DeviceUnlock> unlock(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        // Leaving for the PIN screen and coming back is part of unlocking,
        // not a reason to fail it.
        persistAcrossBackgrounding: true,
      );
      return ok ? DeviceUnlock.unlocked : DeviceUnlock.cancelled;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.noCredentialsSet => DeviceUnlock.unavailable,
        // Cancelled, timed out, locked out for a while, a prompt already up:
        // all of them are "not yet", and the lock screen offers a retry.
        _ => DeviceUnlock.cancelled,
      };
    } catch (_) {
      return DeviceUnlock.cancelled;
    }
  }
}

/// A phone with no lock — the web build, and the default in tests.
class NoDeviceLock implements DeviceLock {
  const NoDeviceLock();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<DeviceUnlock> unlock(String reason) async => DeviceUnlock.unavailable;
}

/// Whether something saved on the phone is behind the phone's lock: the
/// scanner's sign-in, or the student's side of the app. Each has its own.
///
/// Only a switch, not a secret — the sign-in itself is in the keystore
/// (token_store.dart) — so it sits in plain preferences.
abstract interface class LockSwitchStore {
  Future<bool> read();
  Future<void> write(bool enabled);
}

class SharedPrefsLockSwitchStore implements LockSwitchStore {
  /// The scanner's, under the key it has always had.
  const SharedPrefsLockSwitchStore.scanner() : _key = 'scanner.lock';

  /// The student's side's.
  const SharedPrefsLockSwitchStore.student() : _key = 'student.lock';

  final String _key;

  @override
  Future<bool> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> write(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, enabled);
    } catch (_) {
      // On for this launch only.
    }
  }
}

/// Keeps the switch for the life of the object. For tests.
class MemoryLockSwitchStore implements LockSwitchStore {
  MemoryLockSwitchStore([this.enabled = false]);

  bool enabled;

  @override
  Future<bool> read() async => enabled;

  @override
  Future<void> write(bool value) async => enabled = value;
}
