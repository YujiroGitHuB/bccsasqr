import 'package:shared_preferences/shared_preferences.dart';

/// Which update this phone was told about and closed — the build Home's
/// "Update available" card was closed for, so it is not shown again until a
/// newer one is uploaded. Settings still offers it.
abstract interface class UpdateStore {
  /// The build last closed, or null when none ever was. Throws when the
  /// store cannot be read.
  Future<int?> dismissedBuild();
  Future<void> dismiss(int build);
}

/// The phone's shared preferences, beside the settings.
class SharedPrefsUpdateStore implements UpdateStore {
  static const String _key = 'update.dismissedBuild';

  @override
  Future<int?> dismissedBuild() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key);
  }

  @override
  Future<void> dismiss(int build) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, build);
    } catch (_) {
      // Closed for this launch; the card comes back on the next one.
    }
  }
}

/// Keeps the mark for the life of the object. For tests, and where no
/// preferences are passed.
class MemoryUpdateStore implements UpdateStore {
  MemoryUpdateStore([this.dismissed]);

  /// The last build closed, or null when none ever was.
  int? dismissed;

  @override
  Future<int?> dismissedBuild() async => dismissed;

  @override
  Future<void> dismiss(int build) async => dismissed = build;
}
