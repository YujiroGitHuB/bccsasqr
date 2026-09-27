import 'package:flutter/material.dart';

/// What the person holding the phone chose in Settings. Kept on the phone
/// only: these are preferences about this device, not about the account.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.sound = true,
    this.vibration = true,
    this.voice = true,
  });

  /// Light, Dark, or whatever the phone is set to — the web's theme toggle,
  /// which also follows the system until someone picks.
  final ThemeMode themeMode;

  /// The beep after every scan.
  final bool sound;

  /// The buzz after every scan.
  final bool vibration;

  /// Names and messages read aloud — the scanner and the generator both.
  final bool voice;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? sound,
    bool? vibration,
    bool? voice,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    sound: sound ?? this.sound,
    vibration: vibration ?? this.vibration,
    voice: voice ?? this.voice,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.sound == sound &&
      other.vibration == vibration &&
      other.voice == voice;

  @override
  int get hashCode => Object.hash(themeMode, sound, vibration, voice);
}
