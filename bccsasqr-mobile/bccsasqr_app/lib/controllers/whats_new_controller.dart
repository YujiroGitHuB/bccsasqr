import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/whats_new_log.dart';
import '../models/whats_new.dart';
import '../services/whats_new_store.dart';

/// Whether this phone has news in What's New — what puts the "New in this
/// update" card and the dot on the home screen.
class WhatsNewController extends ChangeNotifier {
  WhatsNewController({
    required WhatsNewStore store,
    this.version = WhatsNewLog.version,
    this.releases = WhatsNewLog.releases,
    this.areas,
  }) : _store = store;

  final WhatsNewStore _store;

  /// The newest release's version. Overridable for tests.
  final String version;

  /// The releases [version] belongs to, newest first. Overridable for tests.
  final List<WhatsNewRelease> releases;

  /// The parts of the app the person holding the phone reads about — a
  /// student's or an instructor's, which can change while the app runs.
  /// Null reads about all of them.
  final Set<WhatsNewArea> Function()? areas;

  // Nothing is announced until the store has answered: a card that appears
  // and then vanishes a frame later is worse than one that appears late.
  bool _loaded = false;

  /// The version last opened here, or null when none ever was.
  String? _seen;

  /// News: a release this phone has not opened, with something in it for its
  /// reader. A release only about the instructor's side puts no dot on a
  /// student's phone — their page would not even show it — but one they
  /// have not seen still does, however old.
  bool get unread {
    if (!_loaded || _seen == version) return false;
    final reader = areas?.call();
    if (reader == null) return true;
    final newest = releases
        .where((r) => r.items.any((item) => item.isFor(reader)))
        .firstOrNull;
    if (newest == null) return false;
    final seen = _seen;
    // Never opened; or the newest release has their items, and the version
    // moved on since — a same-day addition among them too.
    if (seen == null || identical(newest, releases.first)) return true;
    // Theirs came after the day they last opened it: `2026-09-30.3` was
    // opened on the 30th.
    return newest.id.compareTo(seen.split('.').first) > 0;
  }

  /// Reads the mark. Called once, while the splash plays.
  Future<void> load() async {
    try {
      _seen = await _store.lastSeen();
    } catch (_) {
      // A store that cannot be read counts as seen: a card that cannot be
      // dismissed would come back on every launch, which is worse than one
      // missed announcement.
      _seen = version;
    }
    _loaded = true;
    notifyListeners();
  }

  /// Opening the page is reading it; so is closing the card.
  void markSeen() {
    if (_seen == version) return;
    final news = unread;
    _seen = version;
    if (news) notifyListeners();
    unawaited(_store.markSeen(version));
  }
}
