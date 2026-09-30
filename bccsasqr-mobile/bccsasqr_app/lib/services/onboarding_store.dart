import 'package:shared_preferences/shared_preferences.dart';

/// Whether this phone has been through the introduction the first launch
/// shows (views/onboarding_page.dart).
abstract interface class OnboardingStore {
  Future<bool> hasSeen();
  Future<void> markSeen();
}

/// The phone's shared preferences, beside the role.
///
/// A store that cannot be read counts as "seen": the introduction is a
/// welcome, and one that came back on every launch would be anything but.
class SharedPrefsOnboardingStore implements OnboardingStore {
  static const String _key = 'onboarding.seen';

  @override
  Future<bool> hasSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (_) {
      // Seen for this launch; the next one shows it again.
    }
  }
}

/// Keeps the mark for the life of the object. For tests.
class MemoryOnboardingStore implements OnboardingStore {
  MemoryOnboardingStore({this.seen = false});

  bool seen;

  @override
  Future<bool> hasSeen() async => seen;

  @override
  Future<void> markSeen() async => seen = true;
}
