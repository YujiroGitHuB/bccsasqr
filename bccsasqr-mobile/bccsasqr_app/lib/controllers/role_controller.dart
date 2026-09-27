import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_role.dart';
import '../services/role_store.dart';

/// Which half of the app this phone opens: the student's home screen, the
/// instructor's bottom bar, or — until one is picked — the question.
class RoleController extends ChangeNotifier {
  RoleController({required RoleStore store}) : _store = store;

  final RoleStore _store;

  AppRole? _role;
  bool _loaded = false;

  /// Null until a role is picked, and again after [clear].
  AppRole? get role => _role;

  /// The store has answered. Until then nothing is shown: a picker that
  /// flashes up and is replaced a frame later is worse than a blank frame.
  bool get loaded => _loaded;

  /// Reads the role picked last time. Called once, while the splash plays.
  Future<void> load() async {
    _role = await _store.load();
    _loaded = true;
    notifyListeners();
  }

  void choose(AppRole role) => _update(role);

  /// Back to the picker — "Switch role" in Settings.
  void clear() => _update(null);

  void _update(AppRole? next) {
    _loaded = true;
    if (next == _role) return;
    _role = next;
    notifyListeners();
    unawaited(_store.save(next));
  }
}
