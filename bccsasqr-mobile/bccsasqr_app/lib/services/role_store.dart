import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_role.dart';

/// Where the role picked on the first launch lives between launches.
abstract interface class RoleStore {
  /// The role picked last time, or null when none ever was.
  Future<AppRole?> load();

  /// Saves [role]; null forgets it, so the next launch asks again.
  Future<void> save(AppRole? role);
}

/// The phone's shared preferences, beside the settings. Not secret: it only
/// chooses which screens are shown.
///
/// A store that cannot be read answers null, and the picker is shown — one
/// extra tap is better than opening someone the wrong half of the app.
class SharedPrefsRoleStore implements RoleStore {
  static const String _key = 'app.role';

  @override
  Future<AppRole?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      return AppRole.values.where((r) => r.name == saved).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(AppRole? role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (role == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, role.name);
      }
    } catch (_) {
      // Applied for this launch; the next one asks again.
    }
  }
}

/// Keeps the role for the life of the object. For tests.
class MemoryRoleStore implements RoleStore {
  MemoryRoleStore([this.saved]);

  AppRole? saved;

  @override
  Future<AppRole?> load() async => saved;

  @override
  Future<void> save(AppRole? role) async => saved = role;
}
