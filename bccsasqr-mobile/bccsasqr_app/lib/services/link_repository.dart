import 'dart:math';

import '../models/attendance_link.dart';
import 'scanner_repository.dart';

/// The contract the Links tab depends on — `api/v1/handlers/links.php`,
/// behind the scanner's sign-in.
///
/// Every refusal is a [ScannerException]: the same transport and the same
/// sign-in as the scanner, so the same `unauthenticated` sends the
/// instructor back to the sign-in form.
abstract interface class LinkRepository {
  /// The signed-in account's links. Opening the list is also what keeps them
  /// in order on the server — new classes get a link, a link that expired on
  /// an earlier day gets a new code ([LinkList.rotated]).
  Future<LinkList> loadLinks();

  /// When the link closes. [LinkTime.minutes], [LinkTime.endOfDay],
  /// [LinkTime.closesAt] or [LinkTime.clear].
  Future<LinkState> setExpiry(String shortCode, LinkTime time);

  /// When submissions start counting as late. [LinkTime.minutes],
  /// [LinkTime.onTimeUntil] or [LinkTime.clear].
  Future<LinkState> setLate(String shortCode, LinkTime time);

  /// A new code — a new address and QR — for the same class. The old one
  /// stops working at once.
  Future<RenewedLink> renewLink(String shortCode);
}

/// What runs when no `API_BASE_URL` was supplied at build time: the demo
/// scanner's two subjects, with times worked out on this phone. Nothing
/// leaves it, and the addresses point at example.com.
class InMemoryLinkRepository implements LinkRepository {
  InMemoryLinkRepository({
    this.latency = const Duration(milliseconds: 350),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration latency;
  final DateTime Function() _clock;
  final Random _random = Random();

  late final List<_DemoLink> _links = [
    _DemoLink('CC121', 'Introduction to Computing', 'K7M2QP'),
    _DemoLink('ITE211', 'Object Oriented Programming', 'H4TW9C'),
  ];

  static const String _base =
      'https://example.com/bccsasqr/pages/daily_attendance.php?c=';

  _DemoLink _find(String code) => _links.firstWhere(
    (l) => l.code == code,
    orElse: () => throw const ScannerException(
      'Link not found, or it is not yours to change.',
      code: 'link_not_found',
    ),
  );

  @override
  Future<LinkList> loadLinks() async {
    await Future<void>.delayed(latency);
    return (
      links: [
        for (final l in _links)
          AttendanceLink(
            shortCode: l.code,
            url: '$_base${l.code}',
            expiry: _expiry(l),
            late: _late(l),
            subjectCode: l.subjectCode,
            subjectName: l.subjectName,
            section: 'BSIT-4A',
            instructor: 'Demo Instructor',
          ),
      ],
      rotated: const <RotatedLink>[],
      admin: false,
    );
  }

  @override
  Future<LinkState> setExpiry(String shortCode, LinkTime time) async {
    await Future<void>.delayed(latency);
    final link = _find(shortCode);
    final now = _clock();
    final json = time.json;

    if (json['clear'] == true) {
      link.expires = null;
    } else if (json['minutes'] case final int minutes) {
      link.expires = now.add(Duration(minutes: minutes));
    } else if (json['preset'] == 'eod') {
      link.expires = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (json['at'] case final String at) {
      final when = DateTime.parse(at);
      if (!when.isAfter(now)) {
        throw const ScannerException(
          'That time has already passed.',
          code: 'not_changed',
        );
      }
      link.expires = when;
    }
    return _state(link);
  }

  @override
  Future<LinkState> setLate(String shortCode, LinkTime time) async {
    await Future<void>.delayed(latency);
    final link = _find(shortCode);
    final now = _clock();
    final json = time.json;

    if (json['clear'] == true) {
      link.lateAfter = null;
    } else if (json['minutes'] case final int minutes) {
      final t = now.add(Duration(minutes: minutes));
      link.lateAfter = DateTime(t.year, t.month, t.day, t.hour, t.minute);
    } else if (json['at'] case final String at) {
      final [h, m] = at.split(':').map(int.parse).toList();
      link.lateAfter = DateTime(now.year, now.month, now.day, h, m);
    }
    return _state(link);
  }

  @override
  Future<RenewedLink> renewLink(String shortCode) async {
    await Future<void>.delayed(latency);
    final link = _find(shortCode);
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    link
      ..code = String.fromCharCodes([
        for (var i = 0; i < 6; i++)
          chars.codeUnitAt(_random.nextInt(chars.length)),
      ])
      ..expires = null
      ..lateAfter = null;
    return (oldCode: shortCode, link: _state(link));
  }

  LinkState _state(_DemoLink l) => LinkState(
    shortCode: l.code,
    url: '$_base${l.code}',
    expiry: _expiry(l),
    late: _late(l),
  );

  LinkExpiry _expiry(_DemoLink l) {
    final at = l.expires;
    if (at == null) return const LinkExpiry();
    final left = at.difference(_clock()).inSeconds;
    return LinkExpiry(
      at: at.toIso8601String(),
      label: _clockLabel(at),
      short: _clockLabel(at),
      secondsLeft: left,
      expired: left <= 0,
    );
  }

  LinkLate _late(_DemoLink l) {
    final after = l.lateAfter;
    final now = _clock();
    if (after == null ||
        after.year != now.year ||
        after.month != now.month ||
        after.day != now.day) {
      return const LinkLate();
    }
    return LinkLate(
      on: true,
      secondsLeft: after
          .add(const Duration(minutes: 1))
          .difference(now)
          .inSeconds,
      label: _clockLabel(after),
    );
  }

  static String _clockLabel(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${t.hour < 12 ? 'AM' : 'PM'}';
  }
}

class _DemoLink {
  _DemoLink(this.subjectCode, this.subjectName, this.code);

  final String subjectCode;
  final String subjectName;
  String code;
  DateTime? expires;
  DateTime? lateAfter;
}
