import 'package:shared_preferences/shared_preferences.dart';

/// Which What's New release this phone has already opened — the app's copy
/// of the web's `bcc-whats-new-seen` in localStorage (assets/js/whatsNew.js).
abstract interface class WhatsNewStore {
  /// Whether [version] was opened, or its card closed, on this phone.
  Future<bool> hasSeen(String version);
  Future<void> markSeen(String version);
}

/// The phone's shared preferences, beside the settings.
///
/// A store that cannot be read counts as "seen": a card that cannot be
/// dismissed would come back on every launch, which is worse than one missed
/// announcement.
class SharedPrefsWhatsNewStore implements WhatsNewStore {
  static const String _key = 'whatsNew.seen';

  @override
  Future<bool> hasSeen(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_key) == version;
    } catch (_) {
      return true;
    }
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
  Future<bool> hasSeen(String version) async => seen == version;

  @override
  Future<void> markSeen(String version) async => seen = version;
}
