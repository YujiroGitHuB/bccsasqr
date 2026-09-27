import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// Where [AppSettings] live between launches.
abstract interface class SettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

/// The phone's shared preferences. Nothing here is secret — unlike the
/// scanner's sign-in, which is in the keystore (token_store.dart).
///
/// A store that cannot be read answers the defaults: a theme that did not
/// load is not worth stopping the app over.
class SharedPrefsSettingsStore implements SettingsStore {
  static const String _theme = 'settings.theme';
  static const String _sound = 'settings.sound';
  static const String _vibration = 'settings.vibration';
  static const String _voice = 'settings.voice';

  @override
  Future<AppSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const defaults = AppSettings();
      return AppSettings(
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == prefs.getString(_theme),
          orElse: () => defaults.themeMode,
        ),
        sound: prefs.getBool(_sound) ?? defaults.sound,
        vibration: prefs.getBool(_vibration) ?? defaults.vibration,
        voice: prefs.getBool(_voice) ?? defaults.voice,
      );
    } catch (_) {
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_theme, settings.themeMode.name);
      await prefs.setBool(_sound, settings.sound);
      await prefs.setBool(_vibration, settings.vibration);
      await prefs.setBool(_voice, settings.voice);
    } catch (_) {
      // Applied for this launch; the next one starts from the defaults.
    }
  }
}

/// Keeps the settings for the life of the object. For tests.
class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([this._settings = const AppSettings()]);

  AppSettings _settings;

  AppSettings get saved => _settings;

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<void> save(AppSettings settings) async => _settings = settings;
}
