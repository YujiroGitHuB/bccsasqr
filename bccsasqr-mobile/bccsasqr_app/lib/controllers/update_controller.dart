import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_release.dart';
import '../services/app_info.dart';
import '../services/app_release_repository.dart';
import '../services/update_store.dart';

/// Where this install stands against the app on the download page.
enum UpdateState {
  /// Not asked yet, or no answer came: nothing offered, nothing held back.
  unknown,

  /// The newest build, or a newer one.
  current,

  /// A newer build is on the download page.
  available,

  /// Older than the server still works with: only the way to the update.
  required,
}

/// Tells the phone when the download page has a newer app than the one
/// installed. Asked for on 2026-10-02: the app is installed from the download
/// page, not a store, so nothing else ever would — a student kept whichever
/// build they first downloaded, and the What's New that would have told them
/// is inside the build they never got.
///
/// [check] asks `GET /api/v1/app` — when the app starts and when it comes back
/// to the screen — at most once every [every]. A newer build puts a card on
/// Home until it is closed for that build ([dismiss]), and stays offered in
/// Settings; a build under the server's minimum shows only
/// UpdateRequiredPage.
///
/// No answer — offline, the server down — changes nothing: an update is
/// never invented, and a phone is never locked out for want of a signal.
class UpdateController extends ChangeNotifier {
  UpdateController({
    required AppReleaseRepository? repository,
    required Future<AppInfo> Function() appInfo,
    required UpdateStore store,
    DateTime Function()? clock,
    this.every = const Duration(hours: 1),
  }) : _repository = repository,
       _appInfo = appInfo,
       _store = store,
       _clock = clock ?? DateTime.now;

  /// Null where there is nothing to update — demo mode, a web build — and
  /// nothing is ever asked.
  final AppReleaseRepository? _repository;
  final Future<AppInfo> Function() _appInfo;
  final UpdateStore _store;
  final DateTime Function() _clock;

  /// The least time between two asks that are not forced.
  final Duration every;

  UpdateState _state = UpdateState.unknown;
  AppRelease? _release;
  int? _installed;
  int? _dismissed;
  bool _storeRead = false;
  DateTime? _askedAt;
  Future<void>? _asking;
  bool _disposed = false;

  UpdateState get state => _state;

  /// The server's last answer.
  AppRelease? get release => _release;

  bool get available => _state == UpdateState.available;
  bool get required => _state == UpdateState.required;

  /// Asking right now — the required page's Check again spins meanwhile.
  bool get asking => _asking != null;

  /// Home's card: a newer build, not closed for.
  bool get showCard => available && _release?.build != _dismissed;

  /// Where an update comes from: the download page as the server names it,
  /// else the one beside the API.
  String? get downloadUrl => _release?.downloadUrl ?? AppInfo.downloadPageUrl;

  /// Asks the server, unless it answered less than [every] ago; [force]
  /// asks anyway. A second call while one is under way waits for it.
  Future<void> check({bool force = false}) {
    if (_repository == null || _disposed) return Future.value();
    if (_asking case final asking?) return asking;
    final at = _askedAt;
    if (!force && at != null && _clock().difference(at) < every) {
      return Future.value();
    }

    final asking = _ask();
    _asking = asking;
    notifyListeners();
    return asking.whenComplete(() {
      _asking = null;
      if (!_disposed) notifyListeners();
    });
  }

  Future<void> _ask() async {
    if (_installed == null) {
      try {
        _installed = int.tryParse((await _appInfo()).buildNumber);
      } catch (_) {
        // Unknown below.
      }
    }
    // A build with no number has nothing to compare.
    final installed = _installed;
    if (installed == null || _disposed) return;

    if (!_storeRead) {
      try {
        _dismissed = await _store.dismissedBuild();
      } catch (_) {
        // Never closed, as far as this launch knows.
      }
      _storeRead = true;
    }

    final AppRelease release;
    try {
      release = await _repository!.fetchRelease();
    } catch (_) {
      // Offline, or the server said no: as it was, asked again next time.
      return;
    }
    if (_disposed) return;

    _askedAt = _clock();
    _release = release;
    final latest = release.build;
    _state = installed < release.minBuild
        ? UpdateState.required
        : latest != null && latest > installed
        ? UpdateState.available
        : UpdateState.current;
  }

  /// "Not now" on Home's card: closed for this build — a newer one brings it
  /// back.
  Future<void> dismiss() async {
    final build = _release?.build;
    if (build == null) return;
    _dismissed = build;
    notifyListeners();
    await _store.dismiss(build);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
