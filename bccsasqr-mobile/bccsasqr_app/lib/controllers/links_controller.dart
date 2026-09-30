import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_strings.dart';
import '../models/attendance_link.dart';
import '../services/link_repository.dart';
import '../services/scanner_repository.dart';

/// Whose links the list shows — the web page's "My Subjects Only" filter,
/// which only an admin has: an instructor only ever sees their own.
enum LinkOwner { all, mine, others }

/// What a notice on the island is about.
enum LinkTone { success, info, warning, error }

/// A message for the island — the web page's SweetAlerts, in its words.
@immutable
class LinkNotice {
  const LinkNotice({
    required this.title,
    this.body,
    this.tone = LinkTone.success,
    this.long = false,
  });

  final String title;
  final String? body;
  final LinkTone tone;

  /// Worth more than a glance: the web waits for OK on these.
  final bool long;
}

/// The Links tab's state and rules — the port of
/// `assets/js/generate_link.js`. What a time means, which links exist and
/// who may change one are all decided on the server (`includes/links.php`);
/// this keeps the list, the filters and the countdowns.
class LinksController extends ChangeNotifier {
  LinksController({
    required LinkRepository repository,
    this.onSignedOut,
    DateTime Function()? clock,
  }) : _repository = repository,
       _clock = clock ?? DateTime.now;

  final LinkRepository _repository;
  final DateTime Function() _clock;

  /// The server refused the sign-in: the whole instructor side goes back to
  /// the sign-in form, not just this tab.
  final VoidCallback? onSignedOut;

  late final StreamController<LinkNotice> _notices =
      StreamController<LinkNotice>.broadcast(onListen: _flushUnheard);

  /// Notices from before anyone listened — a list loaded under the splash
  /// can already carry "2 links were renewed". Said once the page is up.
  final List<LinkNotice> _unheard = [];
  bool _disposed = false;

  Future<void>? _loading;
  bool _loaded = false;
  String? _error;
  String? _blocked;
  List<AttendanceLink> _links = const [];
  bool _admin = false;

  /// When each link's times were measured — its countdowns run from here.
  final Map<String, DateTime> _measuredAt = {};

  /// Links whose countdown reached zero on this phone and have been asked
  /// about once. Kept so a server that cannot be reached is not asked again
  /// every second.
  final Set<String> _closedSeen = {};
  final Set<String> _busy = {};

  String _search = '';
  String? _section;
  LinkOwner _owner = LinkOwner.all;

  // ---------------------------------------------------------------- getters

  /// Messages to put on the island.
  Stream<LinkNotice> get notices => _notices.stream;

  bool get isLoading => _loading != null;

  /// A list has arrived at least once. Until then there is a spinner, or
  /// [error] in its place.
  bool get hasList => _loaded;

  /// Why there is no list: the first load failed.
  String? get error => _error;

  /// The account may not manage links (Manage Access on the web).
  String? get blocked => _blocked;

  List<AttendanceLink> get links => _links;
  bool get admin => _admin;

  String get search => _search;
  String? get section => _section;
  LinkOwner get owner => _owner;

  bool isBusy(AttendanceLink link) => _busy.contains(link.shortCode);

  /// Every section on the list, in the order the server sorted them.
  List<String> get sections => {for (final l in _links) l.section}.toList();

  /// The list through the search box and the filters.
  List<AttendanceLink> get visible => [
    for (final l in _links)
      if ((_section == null || l.section == _section) &&
          switch (_owner) {
            LinkOwner.all => true,
            LinkOwner.mine => l.mine,
            LinkOwner.others => !l.mine,
          } &&
          l.matches(_search))
        l,
  ];

  // ------------------------------------------------------------ countdowns

  int _elapsed(LinkState link) {
    final now = _clock();
    return now.difference(_measuredAt[link.shortCode] ?? now).inSeconds;
  }

  /// Seconds until [link] closes, counted down from the server's figure;
  /// null when it never does.
  int? expiresIn(LinkState link) {
    final left = link.expiry.secondsLeft;
    return left == null ? null : left - _elapsed(link);
  }

  bool isExpired(LinkState link) =>
      link.expiry.expired || (expiresIn(link) ?? 1) <= 0;

  /// Seconds until submissions count as late; null with no cutoff.
  int? lateIn(LinkState link) {
    final left = link.late.secondsLeft;
    return !link.late.on || left == null ? null : left - _elapsed(link);
  }

  /// Submissions right now are recorded as late.
  bool isLate(LinkState link) => link.late.on && (lateIn(link) ?? 0) <= 0;

  /// Something on the list is counting down. The page ticks once a second
  /// while this is true, and stops when nothing is.
  bool get counting => _links.any(
    (l) =>
        (!l.expiry.expired && (expiresIn(l) ?? 0) > 0) ||
        (!isExpired(l) && (lateIn(l) ?? 0) > 0),
  );

  /// Once a second while [counting]: repaints the countdowns. When a link
  /// reaches zero the server is asked what it looks like now, as the web page
  /// does, rather than the phone guessing.
  void tick() {
    var closed = false;
    for (final l in _links) {
      if (l.expiry.expired) continue;
      final left = expiresIn(l);
      if (left != null && left <= 0 && _closedSeen.add(l.shortCode)) {
        closed = true;
      }
    }
    _notify();
    if (closed) unawaited(load());
  }

  // ---------------------------------------------------------------- intents

  /// The list, fresh. Also the pull-to-refresh and the retry; a second call
  /// while one is on its way waits for that one.
  Future<void> load() => _loading ??= _load().whenComplete(() {
    _loading = null;
    _notify();
  });

  Future<void> _load() async {
    _notify();
    try {
      final list = await _repository.loadLinks();
      if (_disposed) return;

      final now = _clock();
      _links = list.links;
      _admin = list.admin;
      _measuredAt
        ..clear()
        ..addAll({for (final l in list.links) l.shortCode: now});
      _closedSeen.clear();
      _loaded = true;
      _error = null;
      _blocked = null;
      if (!_admin) _owner = LinkOwner.all;
      if (_section != null && !sections.contains(_section)) _section = null;

      if (list.rotated.isNotEmpty) {
        _emit(
          LinkNotice(
            title: LinksStrings.rotatedTitle(list.rotated.length),
            body: LinksStrings.rotatedBody,
            tone: LinkTone.info,
            long: true,
          ),
        );
      }
    } on ScannerException catch (e) {
      if (_disposed || _refused(e)) return;
      if (_loaded) {
        _emit(
          LinkNotice(
            title: LinksStrings.loadFailed,
            body: e.message,
            tone: LinkTone.error,
          ),
        );
      } else {
        _error = e.message;
      }
    } catch (_) {
      if (_disposed) return;
      if (!_loaded) _error = LinksStrings.loadFailed;
    }
  }

  void setSearch(String value) {
    if (value == _search) return;
    _search = value;
    _notify();
  }

  void setSection(String? section) {
    if (section == _section) return;
    _section = section;
    _notify();
  }

  void setOwner(LinkOwner owner) {
    if (owner == _owner) return;
    _owner = owner;
    _notify();
  }

  /// Sets, extends or removes when [link] closes. The code stays: the
  /// students in front of you already have this address.
  Future<bool> setExpiry(AttendanceLink link, LinkTime time) async {
    final state = await _change(
      link,
      () => _repository.setExpiry(link.shortCode, time),
      LinksStrings.expiryFailed,
    );
    if (state == null) return false;

    _emit(
      state.expiry.isSet
          ? LinkNotice(
              title: LinksStrings.expirySet,
              body: LinksStrings.expirySetBody(
                state.expiry.label ?? state.expiry.short ?? '',
              ),
            )
          : const LinkNotice(
              title: LinksStrings.expiryRemoved,
              body: LinksStrings.expiryRemovedBody,
            ),
    );
    return true;
  }

  /// Sets or removes the late cutoff. The link stays open either way.
  Future<bool> setLate(AttendanceLink link, LinkTime time) async {
    final state = await _change(
      link,
      () => _repository.setLate(link.shortCode, time),
      LinksStrings.lateFailed,
    );
    if (state == null) return false;

    final label = state.late.label ?? '';
    _emit(switch (state.late) {
      // A time already behind us is allowed, but it is far more often a
      // slip — 8:15 picked at 3 PM, AM where PM was meant — than a wish to
      // mark the whole class late. So it is a warning, and it stays.
      LinkLate(on: true, secondsLeft: final left?) when left <= 0 => LinkNotice(
        title: LinksStrings.latePassed(label),
        body: LinksStrings.latePassedBody,
        tone: LinkTone.warning,
        long: true,
      ),
      LinkLate(on: true) => LinkNotice(
        title: LinksStrings.lateSet,
        body: LinksStrings.lateSetBody(label),
      ),
      _ => const LinkNotice(
        title: LinksStrings.lateRemoved,
        body: LinksStrings.lateRemovedBody,
      ),
    });
    return true;
  }

  /// A new code for [link]'s class — a new address and QR. The old ones stop
  /// working at once. Returns the new link, which has no expiry yet.
  Future<AttendanceLink?> renew(AttendanceLink link) async {
    final state = await _change(link, () async {
      final renewed = await _repository.renewLink(link.shortCode);
      return renewed.link;
    }, LinksStrings.renewFailed);
    if (state == null) return null;

    _emit(
      LinkNotice(
        title: LinksStrings.renewed,
        body: LinksStrings.renewedBody(state.shortCode),
        long: true,
      ),
    );
    return _links.firstWhere(
      (l) => l.shortCode == state.shortCode,
      orElse: () => link.withState(state),
    );
  }

  // ---------------------------------------------------------------- helpers

  /// Runs one change to [link], and puts the server's answer in its place.
  /// The answer is the new truth — not the phone's guess of what the tap did.
  Future<LinkState?> _change(
    AttendanceLink link,
    Future<LinkState> Function() request,
    String failTitle,
  ) async {
    final code = link.shortCode;
    if (!_busy.add(code)) return null;
    _notify();

    try {
      final state = await request();
      if (_disposed) return null;
      _replace(code, state);
      return state;
    } on ScannerException catch (e) {
      if (!_disposed && !_refused(e)) {
        _emit(
          LinkNotice(title: failTitle, body: e.message, tone: LinkTone.error),
        );
      }
      return null;
    } finally {
      _busy.remove(code);
      _notify();
    }
  }

  void _replace(String oldCode, LinkState state) {
    final i = _links.indexWhere((l) => l.shortCode == oldCode);
    if (i < 0) return;
    _links = [..._links]..[i] = _links[i].withState(state);
    _measuredAt
      ..remove(oldCode)
      ..[state.shortCode] = _clock();
    _closedSeen
      ..remove(oldCode)
      ..remove(state.shortCode);
  }

  /// A refusal that is about the account, not the request.
  bool _refused(ScannerException e) {
    switch (e.code) {
      case 'unauthenticated':
        onSignedOut?.call();
        return true;
      case 'forbidden':
        _blocked = e.message;
        _links = const [];
        _loaded = false;
        _error = null;
        return true;
    }
    return false;
  }

  void _emit(LinkNotice notice) {
    if (_disposed) return;
    if (_notices.hasListener) {
      _notices.add(notice);
    } else {
      _unheard.add(notice);
    }
  }

  void _flushUnheard() {
    for (final notice in _unheard) {
      _notices.add(notice);
    }
    _unheard.clear();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_notices.close());
    super.dispose();
  }
}
