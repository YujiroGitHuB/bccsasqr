import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_assets.dart';

/// How a scan went, as far as the hand holding the phone is concerned.
enum ScanTone { success, warning, error }

/// The beep and the buzz after every scan — the app's counterpart to the web
/// scanner's `playBeep()` and `navigator.vibrate()`. The instructor is looking
/// at the student, not the screen; this is how they know the scan landed.
abstract interface class ScanFeedback {
  Future<void> play(ScanTone tone);
}

/// Makes no sound. The default for tests.
class SilentScanFeedback implements ScanFeedback {
  const SilentScanFeedback();

  @override
  Future<void> play(ScanTone tone) async {}
}

/// The bundled beep plus a vibration whose pattern says how it went: a double
/// tap for recorded, one long buzz for a warning, two for a refusal — the web
/// scanner's `[50, 30, 50]`, `200` and `[100, 50, 100]`.
///
/// Every failure is swallowed: a phone on silent, or with haptics off, still
/// shows the result on screen.
///
/// [sound] and [vibration] are the Settings switches, asked on every scan so
/// a change counts from the next one.
class DeviceScanFeedback implements ScanFeedback {
  DeviceScanFeedback({bool Function()? sound, bool Function()? vibration})
    : _player = AudioPlayer(),
      _sound = sound ?? _always,
      _vibration = vibration ?? _always;

  static bool _always() => true;

  final AudioPlayer _player;
  final bool Function() _sound;
  final bool Function() _vibration;
  Future<void>? _ready;

  Future<void> _configure() async {
    // Low latency: the beep has to land with the scan, not a beat after.
    await _player.setPlayerMode(PlayerMode.lowLatency);
    await _player.setReleaseMode(ReleaseMode.stop);
  }

  @override
  Future<void> play(ScanTone tone) async {
    if (_sound()) unawaited(_beep());
    if (!_vibration()) return;

    try {
      switch (tone) {
        case ScanTone.success:
          await HapticFeedback.mediumImpact();
          await Future<void>.delayed(const Duration(milliseconds: 80));
          await HapticFeedback.mediumImpact();
        case ScanTone.warning:
          await HapticFeedback.heavyImpact();
        case ScanTone.error:
          await HapticFeedback.heavyImpact();
          await Future<void>.delayed(const Duration(milliseconds: 150));
          await HapticFeedback.heavyImpact();
      }
    } catch (_) {
      // See the class note.
    }
  }

  Future<void> _beep() async {
    try {
      await (_ready ??= _configure());
      // Stopped first, so back-to-back scans each get their own beep — the
      // web rewinds its Audio element for the same reason.
      await _player.stop();
      await _player.play(AssetSource(AppAssets.scanBeepSource));
    } catch (_) {
      // See the class note.
    }
  }

  void dispose() => unawaited(_player.dispose());
}
