import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/settings_store.dart';

/// The Settings screen's state, and the one place the rest of the app asks
/// "is the sound on?". Every change is applied at once and saved in the
/// background — a toggle that waits on storage feels broken.
class SettingsController extends ChangeNotifier {
  SettingsController({required SettingsStore store}) : _store = store;

  final SettingsStore _store;
  AppSettings _settings = const AppSettings();

  AppSettings get settings => _settings;
  ThemeMode get themeMode => _settings.themeMode;
  bool get sound => _settings.sound;
  bool get vibration => _settings.vibration;
  bool get voice => _settings.voice;
  bool get checkInCamera => _settings.checkInCamera;
  bool get alerts => _settings.alerts;
  bool get cardTurns => _settings.cardTurns;

  /// Reads what was saved last time. Called once, while the splash plays.
  Future<void> load() async {
    _settings = await _store.load();
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) =>
      _update(_settings.copyWith(themeMode: mode));
  void setSound(bool on) => _update(_settings.copyWith(sound: on));
  void setVibration(bool on) => _update(_settings.copyWith(vibration: on));
  void setVoice(bool on) => _update(_settings.copyWith(voice: on));
  void setCheckInCamera(bool on) =>
      _update(_settings.copyWith(checkInCamera: on));
  void setAlerts(bool on) => _update(_settings.copyWith(alerts: on));
  void setCardTurns(bool on) => _update(_settings.copyWith(cardTurns: on));

  void _update(AppSettings next) {
    if (next == _settings) return;
    _settings = next;
    notifyListeners();
    unawaited(_store.save(next));
  }
}
