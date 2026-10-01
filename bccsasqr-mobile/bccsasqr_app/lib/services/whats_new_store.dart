import 'package:shared_preferences/shared_preferences.dart';

/// Which What's New release this phone has already opened — the app's copy
/// of the web's `bcc-whats-new-seen` in localStorage (assets/js/whatsNew.js).
abstract interface class WhatsNewStore {
  /// The version last opened, or its card closed, on this phone — null when
  /// none ever was. Throws when the store cannot be read.
  Future<String?> lastSeen();
  Future<void> markSeen(String version);
}

/// The phone's shared preferences, beside the settings.
class SharedPrefsWhatsNewStore implements WhatsNewStore {
  static const String _key = 'whatsNew.seen';

  @override
  Future<String?> lastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  @override
  Future<void> markSeen(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, version);
    } catch (_) {
      // Seen for this launch; the card comes back on the next one.
    }
  }
}

/// Keeps the mark for the life of the object. For tests.
class MemoryWhatsNewStore implements WhatsNewStore {
  MemoryWhatsNewStore([this.seen]);

  /// The last version marked, or null when none ever was.
  String? seen;

  @override
  Future<String?> lastSeen() async => seen;

  @override
  Future<void> markSeen(String version) async => seen = version;
}
