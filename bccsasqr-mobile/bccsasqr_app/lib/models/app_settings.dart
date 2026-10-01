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
    this.checkInCamera = false,
    this.alerts = true,
    this.cardTurns = true,
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

  /// Check in starts its camera by itself. Off until the student turns it
  /// on there, and kept the way they leave it: a student who pastes the
  /// code from the group chat never has the camera start (2026-10-01).
  final bool checkInCamera;

  /// The island when the live feed brings something — "Marked present" —
  /// on any page of the student's side. Notifications keeps the list either
  /// way (2026-10-01).
  final bool alerts;

  /// Home's card turns over by itself every few seconds, front to code and
  /// back, until the student turns it (2026-10-01).
  final bool cardTurns;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? sound,
    bool? vibration,
    bool? voice,
    bool? checkInCamera,
    bool? alerts,
    bool? cardTurns,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    sound: sound ?? this.sound,
    vibration: vibration ?? this.vibration,
    voice: voice ?? this.voice,
    checkInCamera: checkInCamera ?? this.checkInCamera,
    alerts: alerts ?? this.alerts,
    cardTurns: cardTurns ?? this.cardTurns,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.sound == sound &&
      other.vibration == vibration &&
      other.voice == voice &&
      other.checkInCamera == checkInCamera &&
      other.alerts == alerts &&
      other.cardTurns == cardTurns;

  @override
  int get hashCode => Object.hash(
    themeMode,
    sound,
    vibration,
    voice,
    checkInCamera,
    alerts,
    cardTurns,
  );
}
