import 'dart:async';

import 'package:bccsasqr_app/controllers/scanner_lock_controller.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/core/theme/app_colors.dart';
import 'package:bccsasqr_app/core/theme/app_theme.dart';
import 'package:bccsasqr_app/models/scanner_models.dart';
import 'package:bccsasqr_app/services/device_lock.dart';
import 'package:bccsasqr_app/views/scanner/scanner_lock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A phone whose prompt stays up until the test answers it.
class _HeldDeviceLock implements DeviceLock {
  Completer<DeviceUnlock> answer = Completer();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<DeviceUnlock> unlock(String reason) => answer.future;
}

void main() {
  late _HeldDeviceLock device;
  late ScannerLockController lock;

  /// Made in the test itself, not in setUp: the held prompt has to be
  /// answered inside the test's fake time, or the await on it never wakes.
  Future<void> setUpLock() async {
    device = _HeldDeviceLock();
    lock = ScannerLockController(
      device: device,
      store: MemoryScannerLockStore(true),
    );
    addTearDown(lock.dispose);
    await lock.load();
  }

  Widget screen() => MaterialApp(
    theme: AppTheme.build(AppPalette.dark),
    home: ScannerLockScreen(
      lock: lock,
      user: const ScannerUser(
        id: 1,
        name: 'Demo Instructor',
        email: 'demo@bcc.test',
        role: 'instructor',
      ),
      onUsePassword: () {},
    ),
  );

  final lit = find.descendant(
    of: find.byType(ScannerLockScreen),
    matching: find.byType(ShaderMask),
  );

  testWidgets('whose scanner it is, then the fingerprint read while the '
      'prompt is up', (tester) async {
    await setUpLock();
    await tester.pumpWidget(screen());
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Demo Instructor'), findsOneWidget);
    expect(find.text(ScannerStrings.lockTitle), findsOneWidget);
    expect(lit, findsNothing);

    // The prompt goes up by itself.
    await tester.pump(ScannerLockScreen.promptDelay);
    await tester.pump();
    expect(lock.unlocking, isTrue);
    expect(lit, findsOneWidget);

    device.answer.complete(DeviceUnlock.unlocked);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(lit, findsNothing);
    expect(lock.locked, isFalse);
  });

  testWidgets('a prompt closed without a finger shakes it and says so', (
    tester,
  ) async {
    await setUpLock();
    await tester.pumpWidget(screen());
    await tester.pump(ScannerLockScreen.promptDelay);
    await tester.pump(const Duration(milliseconds: 400));
    final print = find.byIcon(Icons.fingerprint_rounded).first;
    final rest = tester.getCenter(print).dx;

    device.answer.complete(DeviceUnlock.cancelled);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(tester.getCenter(print).dx, isNot(rest));
    expect(find.text(ScannerStrings.lockNotUnlocked), findsOneWidget);

    // And then sits still: nothing loops with the prompt down.
    await tester.pumpAndSettle();
    expect(tester.getCenter(print).dx, rest);
    expect(lit, findsNothing);
  });
}
