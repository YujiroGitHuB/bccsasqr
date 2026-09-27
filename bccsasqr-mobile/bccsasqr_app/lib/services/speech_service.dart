import 'package:flutter_tts/flutter_tts.dart';

/// On-screen text, made to sound right. The words stay the screen's; this
/// only fixes what an engine would mispronounce — the app's counterpart to
/// `TTSManager.nameForSpeech` on the web.
String forSpeech(String text) {
  var s = text.trim();

  // Technical detail in brackets at the end ("…service. (ClientException
  // …)") is there for whoever debugs it, not to be read out.
  if (s.endsWith(')')) {
    final cut = s.indexOf(' (');
    if (cut > 0) s = s.substring(0, cut);
  }

  String digits(String run) => run.split('').join(' ');

  return s
      // 019-464 as digits, not as a subtraction.
      .replaceAllMapped(
        RegExp(r'\b(\d{3})-(\d{3,4})\b'),
        (m) => '${digits(m[1]!)}, dash, ${digits(m[2]!)}',
      )
      .replaceAll(RegExp(r'\be\.g\.'), 'for example')
      .replaceAll('YEAR-', 'year, ')
      .replaceAll(RegExp(r'\bNo\.'), 'number')
      .trim();
}

/// A record's name, made to sound like a person being called — the port of
/// `TTSManager.nameForSpeech` (assets/js/tts.js).
///
/// Names come out of the school's export as "DELA CRUZ, JUAN P.", and every
/// engine reads an all-caps word as an initialism, spelling it out letter by
/// letter. So: "LAST, FIRST" is turned round, each part is title-cased, a lone
/// initial is dropped, and a suffix is said as the word after the surname.
String nameForSpeech(String name) {
  var s = name.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (s.isEmpty) return '';

  final comma = s.indexOf(',');
  if (comma > -1) {
    s = '${s.substring(comma + 1).trim()} ${s.substring(0, comma).trim()}';
  }

  const suffixes = {
    'jr': 'Junior',
    'sr': 'Senior',
    'ii': 'the Second',
    'iii': 'the Third',
    'iv': 'the Fourth',
  };

  final spoken = <String>[];
  var suffix = '';

  for (final word in s.split(' ')) {
    final bare = word.replaceAll(RegExp(r'\.$'), '').toLowerCase();
    if (suffixes.containsKey(bare)) {
      suffix = suffixes[bare]!;
      continue;
    }
    if (RegExp(r'^[A-Za-z]\.?$').hasMatch(word)) continue;
    spoken.add(
      word.toLowerCase().replaceAllMapped(
        RegExp(r"(^|[-'’])([a-zà-ÿ])"),
        (m) => '${m[1]}${m[2]!.toUpperCase()}',
      ),
    );
  }

  if (suffix.isNotEmpty) spoken.add(suffix);
  return spoken.join(' ').trim();
}

/// Reads the form's feedback aloud — the app's counterpart to the web
/// generator's `TTSManager` (assets/js/tts.js). It is handed the very text
/// the screen shows; the controller decides when.
abstract interface class SpeechService {
  /// Cuts off whatever is being said, then says [text] — the web does the
  /// same, so a newer status never waits behind an older one.
  Future<void> speak(String text);

  Future<void> stop();
}

/// Says nothing. The default for tests and anywhere a voice is unwanted.
class SilentSpeechService implements SpeechService {
  const SilentSpeechService();

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}

/// Speaks through [inner] only while [enabled] says so — the Voice switch in
/// Settings. Checked on every call, so turning it off silences the very next
/// message without rebuilding anything.
class ToggleableSpeechService implements SpeechService {
  const ToggleableSpeechService(this.inner, {required this.enabled});

  final SpeechService inner;
  final bool Function() enabled;

  @override
  Future<void> speak(String text) async {
    if (enabled()) await inner.speak(text);
  }

  @override
  Future<void> stop() => inner.stop();
}

/// The phone's own text-to-speech engine.
///
/// Every failure is swallowed: a phone with no engine or no English voice
/// data still shows every message on screen, which is what the web does when
/// `speechSynthesis` is missing.
class DeviceSpeechService implements SpeechService {
  DeviceSpeechService() : _tts = FlutterTts();

  final FlutterTts _tts;
  Future<void>? _ready;

  Future<void> _configure() async {
    await _tts.setLanguage('en-US');
    // 0.5 is the engine's normal pace on Android — the web's rate of 1.
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  @override
  Future<void> speak(String text) async {
    try {
      await (_ready ??= _configure());
      await _tts.stop();
      await _tts.speak(forSpeech(text));
    } catch (_) {
      // See the class note.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // See the class note.
    }
  }
}
