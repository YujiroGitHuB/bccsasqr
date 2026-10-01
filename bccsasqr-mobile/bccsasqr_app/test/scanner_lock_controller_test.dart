import 'dart:async';

import 'package:bccsasqr_app/controllers/scanner_lock_controller.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/services/device_lock.dart';
import 'package:flutter_test/flutter_test.dart';

/// A phone whose lock answers from a script: the next results in order,
/// "unlocked" once the script runs out.
class FakeDeviceLock implements DeviceLock {
  FakeDeviceLock({this.available = true});

  bool available;
  final List<DeviceUnlock> script = [];
  final List<String> asked = [];

  /// When set, the next prompt waits for it.
  Completer<void>? gate;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<DeviceUnlock> unlock(String reason) async {
    asked.add(reason);
    final wait = gate;
    if (wait != null) await wait.future;
    return script.isEmpty ? DeviceUnlock.unlocked : script.removeAt(0);
  }
}

void main() {
  late FakeDeviceLock device;
  late MemoryLockSwitchStore store;
  late DateTime now;

  ScannerLockController build() =>
      ScannerLockController(device: device, store: store, clock: () => now);

  setUp(() {
    device = FakeDeviceLock();
    store = MemoryLockSwitchStore();
    now = DateTime(2026, 9, 27, 8);
  });

  group('load', () {
    test('off: nothing is locked', () async {
      final lock = build();
      await lock.load();

      expect(lock.ready, isTrue);
      expect(lock.available, isTrue);
      expect(lock.enabled, isFalse);
      expect(lock.locked, isFalse);
    });

    test('on: the saved sign-in starts locked', () async {
      store.enabled = true;
      final lock = build();
      await lock.load();

      expect(lock.locked, isTrue);
      expect(lock.lost, isFalse);
    });

    test('on, but the phone has no screen lock any more: lost', () async {
      store.enabled = true;
      device.available = false;
      final lock = build();
      await lock.load();

      expect(lock.lost, isTrue);
    });

    test('a sign-out during the read keeps it off', () async {
      store.enabled = true;
      final lock = build();
      final loading = lock.load();
      await lock.forget();
      await loading;

      expect(lock.enabled, isFalse);
      expect(store.enabled, isFalse);
    });
  });

  group('unlock', () {
    late ScannerLockController lock;

    setUp(() async {
      store.enabled = true;
      lock = build();
      await lock.load();
    });

    test('the owner\'s finger opens it', () async {
      await lock.unlock();

      expect(lock.locked, isFalse);
      expect(device.asked, [ScannerStrings.lockReason]);
    });

    test('a closed prompt leaves it locked, with a word why', () async {
      device.script.add(DeviceUnlock.cancelled);
      await lock.unlock();

      expect(lock.locked, isTrue);
      expect(lock.message, ScannerStrings.lockNotUnlocked);

      await lock.unlock();
      expect(lock.locked, isFalse);
      expect(lock.message, isNull);
    });

    test('a phone lock removed meanwhile makes it lost', () async {
      device.script.add(DeviceUnlock.unavailable);
      await lock.unlock();

      expect(lock.lost, isTrue);
    });

    test('one prompt at a time', () async {
      device.gate = Completer<void>();
      final first = lock.unlock();
      expect(lock.unlocking, isTrue);
      await lock.unlock();
      device.gate!.complete();
      await first;

      expect(device.asked, hasLength(1));
    });
  });

  group('turning it on and off', () {
    test('on asks for the phone\'s lock first', () async {
      final lock = build();
      await lock.load();

      expect(await lock.enable(), isTrue);
      expect(device.asked, [ScannerStrings.lockEnableReason]);
      expect(lock.enabled, isTrue);
      // Just proved it is them: not locked on the spot.
      expect(lock.locked, isFalse);
      expect(store.enabled, isTrue);
    });

    test('a closed prompt leaves it off', () async {
      device.script.add(DeviceUnlock.cancelled);
      final lock = build();
      await lock.load();

      expect(await lock.enable(), isFalse);
      expect(lock.enabled, isFalse);
      expect(store.enabled, isFalse);
    });

    test('never on a phone without a screen lock', () async {
      device.available = false;
      final lock = build();
      await lock.load();

      expect(await lock.enable(), isFalse);
      expect(device.asked, isEmpty);
    });

    test('off, and signing out, clear the switch', () async {
      store.enabled = true;
      final lock = build();
      await lock.load();

      await lock.disable();
      expect(lock.enabled, isFalse);
      expect(store.enabled, isFalse);

      await lock.enable();
      await lock.forget();
      expect(lock.enabled, isFalse);
      expect(lock.locked, isFalse);
      expect(store.enabled, isFalse);
    });
  });

  group('coming back to the app', () {
    late ScannerLockController lock;

    setUp(() async {
      store.enabled = true;
      lock = build();
      await lock.load();
      await lock.unlock();
    });

    test('locks again after a minute away', () async {
      lock.onHidden();
      now = now.add(ScannerLockController.relockAfter);
      await lock.onShown();

      expect(lock.locked, isTrue);
    });

    test('a quick look at another app does not', () async {
      lock.onHidden();
      now = now.add(const Duration(seconds: 20));
      await lock.onShown();

      expect(lock.locked, isFalse);
    });

    test('the PIN screen is not "away"', () async {
      store.enabled = true;
      await lock.onShown();
      // Locked again and asking: the PIN screen hides the app.
      lock.onHidden();
      now = now.add(const Duration(minutes: 5));
      await lock.onShown();
      expect(lock.locked, isTrue);

      device.gate = Completer<void>();
      final unlocking = lock.unlock();
      lock.onHidden();
      now = now.add(const Duration(minutes: 2));
      device.gate!.complete();
      await unlocking;
      await lock.onShown();

      expect(lock.locked, isFalse);
    });

    test('notices a screen lock switched off while away', () async {
      lock.onHidden();
      device.available = false;
      await lock.onShown();

      expect(lock.lost, isTrue);
    });
  });
}
