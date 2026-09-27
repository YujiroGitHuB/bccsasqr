import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_role.dart';
import '../services/role_store.dart';

/// Which half of the app this phone opens: the student's home screen, the
/// instructor's sign-in and bar, or — until one is picked — the question.
class RoleController extends ChangeNotifier {
  RoleController({required RoleStore store}) : _store = store;

  final RoleStore _store;

  AppRole? _role;
  AppRole? _saved;
  bool _loaded = false;

  /// Null until a role is picked, and again after [clear].
  AppRole? get role => _role;

  /// The store has answered. Until then nothing is shown: a picker that
  /// flashes up and is replaced a frame later is worse than a blank frame.
  bool get loaded => _loaded;

  /// Reads the role kept last time. Called once, while the splash plays.
  Future<void> load() async {
    _role = _saved = await _store.load();
    _loaded = true;
    notifyListeners();
  }

  /// Shows [role]'s half. [keep] saves it for the next launch too; the
  /// instructor's is kept only once a sign-in has gone through, so a
  /// student who taps the wrong card is asked again next time.
  void choose(AppRole role, {bool keep = true}) {
    _loaded = true;
    if (role != _role) {
      _role = role;
      notifyListeners();
    }
    if (keep) _save(role);
  }

  /// Back to the question — "Switch role" in Settings, and the back arrow on
  /// the instructor's sign-in.
  void clear() {
    _loaded = true;
    if (_role != null) {
      _role = null;
      notifyListeners();
    }
    _save(null);
  }

  void _save(AppRole? role) {
    if (role == _saved) return;
    _saved = role;
    unawaited(_store.save(role));
  }
}
