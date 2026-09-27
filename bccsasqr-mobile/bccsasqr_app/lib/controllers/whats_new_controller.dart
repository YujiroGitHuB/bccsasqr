import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/whats_new_log.dart';
import '../services/whats_new_store.dart';

/// Whether this phone has opened the newest What's New yet — what puts the
/// "New in this update" card and the dot on the home screen.
class WhatsNewController extends ChangeNotifier {
  WhatsNewController({
    required WhatsNewStore store,
    this.version = WhatsNewLog.version,
  }) : _store = store;

  final WhatsNewStore _store;

  /// The newest release's version. Overridable for tests.
  final String version;

  // Nothing is announced until the store has answered: a card that appears
  // and then vanishes a frame later is worse than one that appears late.
  bool _unread = false;

  bool get unread => _unread;

  /// Reads the mark. Called once, while the splash plays.
  Future<void> load() async {
    _unread = !await _store.hasSeen(version);
    notifyListeners();
  }

  /// Opening the page is reading it; so is closing the card.
  void markSeen() {
    if (!_unread) return;
    _unread = false;
    notifyListeners();
    unawaited(_store.markSeen(version));
  }
}
