import 'dart:convert';

import 'package:bccsasqr_app/controllers/links_controller.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/models/attendance_link.dart';
import 'package:bccsasqr_app/services/http_scanner_repository.dart';
import 'package:bccsasqr_app/services/link_repository.dart';
import 'package:bccsasqr_app/services/qr_export_service.dart';
import 'package:bccsasqr_app/services/scanner_repository.dart';
import 'package:bccsasqr_app/services/token_store.dart';
import 'package:bccsasqr_app/views/links/link_card.dart';
import 'package:bccsasqr_app/views/links/link_qr_page.dart';
import 'package:bccsasqr_app/views/links/links_page.dart';
import 'package:bccsasqr_app/views/links/links_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _base = 'https://example.test/bccsasqr/api/v1';
const _token =
    '7ce955c81566e179254a6e2ad1243503a148bfa2636ea779b95c25b1a070a742';
const _url = 'https://example.test/bccsasqr/pages/daily_attendance.php?c=';

String ok(Map<String, dynamic> data) =>
    jsonEncode({'success': true, 'data': data});

String fail(String code, [String message = 'nope']) => jsonEncode({
  'success': false,
  'error': {'code': code, 'message': message},
});

http.Response json(String body, [int status = 200]) =>
    http.Response(body, status, headers: {'content-type': 'application/json'});

Map<String, dynamic> linkJson(
  String code, {
  String subject = 'IT101',
  String section = 'BSIT-2A',
  bool mine = true,
  Map<String, dynamic>? expiry,
  Map<String, dynamic>? late,
}) => {
  'short_code': code,
  'url': '$_url$code',
  'expiry':
      expiry ??
      {'at': null, 'label': null, 'short': null, 'in': null, 'expired': false},
  'late': late ?? {'on': false, 'in': null, 'label': null},
  'subject_code': subject,
  'subject_name': 'Sample Subject $subject',
  'section': section,
  'instructor': 'Test Instructor',
  'mine': mine,
};

AttendanceLink link(
  String code, {
  String subject = 'IT101',
  String section = 'BSIT-2A',
  bool mine = true,
  LinkExpiry expiry = const LinkExpiry(),
  LinkLate late = const LinkLate(),
}) => AttendanceLink(
  shortCode: code,
  url: '$_url$code',
  expiry: expiry,
  late: late,
  subjectCode: subject,
  subjectName: 'Sample Subject $subject',
  section: section,
  instructor: 'Test Instructor',
  mine: mine,
);

/// A server kept in the test: what it answers, and what it was asked.
class _Links implements LinkRepository {
  _Links(this.list, {this.admin = false});

  List<AttendanceLink> list;
  bool admin;
  List<RotatedLink> rotated = const [];
  ScannerException? refuse;
  int loads = 0;
  final List<(String, String, Map<String, Object>)> calls = [];

  /// What the next change answers; the link unchanged when left out.
  LinkState Function(String code, LinkTime? time)? answer;

  @override
  Future<LinkList> loadLinks() async {
    loads++;
    if (refuse case final e?) throw e;
    return (links: list, rotated: rotated, admin: admin);
  }

  LinkState _answer(String what, String code, LinkTime? time) {
    calls.add((what, code, time?.json ?? const {}));
    if (refuse case final e?) throw e;
    return answer?.call(code, time) ??
        list.firstWhere((l) => l.shortCode == code);
  }

  @override
  Future<LinkState> setExpiry(String shortCode, LinkTime time) async =>
      _answer('expiry', shortCode, time);

  @override
  Future<LinkState> setLate(String shortCode, LinkTime time) async =>
      _answer('late', shortCode, time);

  @override
  Future<RenewedLink> renewLink(String shortCode) async =>
      (oldCode: shortCode, link: _answer('renew', shortCode, null));
}

class _NoExport implements QrExportService {
  @override
  Future<String> export({
    required GlobalKey boundaryKey,
    required String fileName,
    String? shareText,
  }) async => fileName;
}

void main() {
  group('HttpScannerRepository — links', () {
    test(
      'reads the list, the renewed codes and whether it is an admin\'s',
      () async {
        final seen = <http.Request>[];
        final r = HttpScannerRepository(
          tokens: MemoryTokenStore(_token),
          baseUrl: _base,
          client: MockClient((req) async {
            seen.add(req);
            if (req.url.path.endsWith('auth/me')) {
              return json(
                ok({
                  'user': {
                    'id': 2,
                    'name': 'Test Instructor',
                    'role': 'instructor',
                    'can_manage_links': true,
                  },
                }),
              );
            }
            return json(
              ok({
                'admin': false,
                'links': [
                  linkJson(
                    'K7M2QP',
                    expiry: {
                      'at': '2026-09-30 17:00:00',
                      'label': 'Sep 30, 2026 5:00 PM',
                      'short': '5:00 PM',
                      'in': 3600,
                      'expired': false,
                    },
                    late: {'on': true, 'in': 600, 'label': '8:15 AM'},
                  ),
                  {'no_code': true},
                ],
                'rotated': [
                  {'old': 'AAAAAA', 'new': 'K7M2QP'},
                ],
              }),
            );
          }),
        );

        final user = await r.restoreSession();
        expect(user?.canManageLinks, isTrue);

        final list = await r.loadLinks();
        expect(seen.last.url.path, endsWith('/links'));
        expect(seen.last.headers['X-Auth-Token'], _token);
        expect(list.admin, isFalse);
        expect(list.links, hasLength(1));
        expect(list.rotated.single, (oldCode: 'AAAAAA', newCode: 'K7M2QP'));

        final l = list.links.single;
        expect(l.url, '${_url}K7M2QP');
        expect(l.section, 'BSIT-2A');
        expect(l.expiry.secondsLeft, 3600);
        expect(l.expiry.short, '5:00 PM');
        expect(l.late.on, isTrue);
        expect(l.late.label, '8:15 AM');
      },
    );

    test('sends each change the way the web form does', () async {
      final bodies = <String, Map<String, dynamic>>{};
      final r = HttpScannerRepository(
        tokens: MemoryTokenStore(),
        baseUrl: _base,
        client: MockClient((req) async {
          final path = req.url.path.split('/api/v1/').last;
          bodies[path] = jsonDecode(req.body) as Map<String, dynamic>;
          return json(
            ok({
              if (path == 'links/renew') 'old_code': 'K7M2QP',
              'link': linkJson(path == 'links/renew' ? 'H4TW9C' : 'K7M2QP'),
            }),
          );
        }),
      );

      await r.setExpiry('K7M2QP', LinkTime.minutes(60));
      await r.setLate('K7M2QP', LinkTime.onTimeUntil(8, 5));
      final renewed = await r.renewLink('K7M2QP');

      expect(bodies['links/expiry'], {'short_code': 'K7M2QP', 'minutes': 60});
      expect(bodies['links/late'], {'short_code': 'K7M2QP', 'at': '08:05'});
      expect(bodies['links/renew'], {'short_code': 'K7M2QP'});
      expect(renewed.oldCode, 'K7M2QP');
      expect(renewed.link.shortCode, 'H4TW9C');
    });

    test('the time fields match the web page\'s', () {
      expect(const LinkTime.endOfDay().json, {'preset': 'eod'});
      expect(const LinkTime.clear().json, {'clear': true});
      expect(LinkTime.closesAt(DateTime(2026, 10, 1, 7, 5)).json, {
        'at': '2026-10-01T07:05',
      });
    });

    test('a refusal keeps its code; a dead token is dropped', () async {
      final tokens = MemoryTokenStore(_token);
      var status = 403;
      final r = HttpScannerRepository(
        tokens: tokens,
        baseUrl: _base,
        client: MockClient(
          (_) async => json(
            fail(status == 403 ? 'forbidden' : 'unauthenticated'),
            status,
          ),
        ),
      );

      await expectLater(
        r.loadLinks(),
        throwsA(
          isA<ScannerException>().having((e) => e.code, 'code', 'forbidden'),
        ),
      );
      expect(await tokens.read(), _token);

      status = 401;
      await expectLater(
        r.setExpiry('K7M2QP', const LinkTime.clear()),
        throwsA(
          isA<ScannerException>().having((e) => e.isSignedOut, 'out', true),
        ),
      );
      expect(await tokens.read(), isNull);
    });
  });

  group('LinksController', () {
    late DateTime now;
    DateTime clock() => now;

    setUp(() => now = DateTime(2026, 9, 30, 8));

    test(
      'filters by section, by search, and — for an admin — by owner',
      () async {
        final repo = _Links([
          link('AAAAAA', subject: 'IT101', section: 'BSIT-2A'),
          link('BBBBBB', subject: 'IT202', section: 'BSIT-2A', mine: false),
          link('CCCCCC', subject: 'IT303', section: 'BSCS-3B', mine: false),
        ], admin: true);
        final c = LinksController(repository: repo, clock: clock);
        await c.load();

        expect(c.sections, ['BSIT-2A', 'BSCS-3B']);
        expect(c.visible, hasLength(3));

        c.setSection('BSIT-2A');
        expect(c.visible.map((l) => l.shortCode), ['AAAAAA', 'BBBBBB']);

        c.setOwner(LinkOwner.others);
        expect(c.visible.map((l) => l.shortCode), ['BBBBBB']);

        c
          ..setSection(null)
          ..setSearch('it303');
        expect(c.visible.map((l) => l.shortCode), ['CCCCCC']);
      },
    );

    test(
      'counts down from the server\'s figure and asks again at zero',
      () async {
        final repo = _Links([
          link(
            'AAAAAA',
            expiry: const LinkExpiry(
              at: '2026-09-30 08:01:00',
              short: '8:01 AM',
              secondsLeft: 60,
            ),
            late: const LinkLate(on: true, secondsLeft: 30, label: '7:59 AM'),
          ),
        ]);
        final c = LinksController(repository: repo, clock: clock);
        await c.load();
        final l = c.links.single;

        expect(c.counting, isTrue);
        expect(c.isLate(l), isFalse);

        now = now.add(const Duration(seconds: 31));
        c.tick();
        expect(c.lateIn(l), -1);
        expect(c.isLate(l), isTrue);
        expect(repo.loads, 1);

        now = now.add(const Duration(seconds: 30));
        expect(c.isExpired(l), isTrue);
        expect(c.counting, isFalse);
        c.tick();
        await pumpEventQueue();
        expect(repo.loads, 2);

        // Once, however many seconds go by before the server answers.
        c.tick();
        await pumpEventQueue();
        expect(repo.loads, 2);
      },
    );

    test(
      'a change puts the server\'s answer on the card and says so',
      () async {
        final repo = _Links([link('AAAAAA')])
          ..answer = (code, _) => const LinkState(
            shortCode: 'AAAAAA',
            url: '${_url}AAAAAA',
            expiry: LinkExpiry(
              at: '2026-09-30 09:00:00',
              label: 'Sep 30, 2026 9:00 AM',
              secondsLeft: 3600,
            ),
          );
        final c = LinksController(repository: repo, clock: clock);
        final notices = <LinkNotice>[];
        c.notices.listen(notices.add);
        await c.load();

        expect(await c.setExpiry(c.links.single, LinkTime.minutes(60)), isTrue);
        await pumpEventQueue();

        expect(repo.calls.single.$1, 'expiry');
        expect(repo.calls.single.$2, 'AAAAAA');
        expect(repo.calls.single.$3, {'minutes': 60});
        expect(c.links.single.expiry.secondsLeft, 3600);
        expect(c.expiresIn(c.links.single), 3600);
        expect(notices.single.title, LinksStrings.expirySet);
        expect(notices.single.body, 'Closes Sep 30, 2026 9:00 AM');
      },
    );

    test('a late time already past is a warning that stays', () async {
      final repo = _Links([link('AAAAAA')])
        ..answer = (code, _) => const LinkState(
          shortCode: 'AAAAAA',
          url: '${_url}AAAAAA',
          late: LinkLate(on: true, secondsLeft: -3600, label: '7:00 AM'),
        );
      final c = LinksController(repository: repo, clock: clock);
      final notices = <LinkNotice>[];
      c.notices.listen(notices.add);
      await c.load();

      await c.setLate(c.links.single, LinkTime.onTimeUntil(7, 0));
      await pumpEventQueue();

      expect(notices.single.tone, LinkTone.warning);
      expect(notices.single.long, isTrue);
      expect(notices.single.title, LinksStrings.latePassed('7:00 AM'));
    });

    test('a new link replaces the old one in place', () async {
      final repo = _Links([link('AAAAAA'), link('BBBBBB')])
        ..answer = (code, _) =>
            const LinkState(shortCode: 'ZZZZZZ', url: '${_url}ZZZZZZ');
      final c = LinksController(repository: repo, clock: clock);
      await c.load();

      final renewed = await c.renew(c.links.first);
      expect(renewed?.shortCode, 'ZZZZZZ');
      expect(renewed?.subjectCode, 'IT101');
      expect(c.links.map((l) => l.shortCode), ['ZZZZZZ', 'BBBBBB']);
    });

    test('links renewed on the server are announced', () async {
      final repo = _Links([link('AAAAAA')])
        ..rotated = [(oldCode: 'OLDOLD', newCode: 'AAAAAA')];
      final c = LinksController(repository: repo, clock: clock);
      final notices = <LinkNotice>[];
      c.notices.listen(notices.add);

      await c.load();
      await pumpEventQueue();
      expect(notices.single.title, LinksStrings.rotatedTitle(1));
    });

    test('a dead token signs out; no permission says so', () async {
      var signedOut = 0;
      final repo = _Links([])
        ..refuse = const ScannerException('gone', code: 'unauthenticated');
      final c = LinksController(
        repository: repo,
        onSignedOut: () => signedOut++,
      );

      await c.load();
      expect(signedOut, 1);
      expect(c.error, isNull);

      repo.refuse = const ScannerException('No access.', code: 'forbidden');
      await c.load();
      expect(c.blocked, 'No access.');
      expect(c.hasList, isFalse);
    });

    test(
      'a notice from before anyone listened is kept until they do',
      () async {
        final repo = _Links([link('AAAAAA')])
          ..rotated = [(oldCode: 'OLDOLD', newCode: 'AAAAAA')];
        final c = LinksController(repository: repo, clock: clock);

        await c.load();
        final notices = <LinkNotice>[];
        c.notices.listen(notices.add);
        await pumpEventQueue();

        expect(notices.single.title, LinksStrings.rotatedTitle(1));
      },
    );

    test(
      'a first load that fails shows why; a later one keeps the list',
      () async {
        final repo = _Links([link('AAAAAA')])
          ..refuse = const ScannerException('No internet.', code: 'network');
        final c = LinksController(repository: repo);
        final notices = <LinkNotice>[];
        c.notices.listen(notices.add);

        await c.load();
        expect(c.error, 'No internet.');

        repo.refuse = null;
        await c.load();
        expect(c.links, hasLength(1));

        repo.refuse = const ScannerException('No internet.', code: 'network');
        await c.load();
        await pumpEventQueue();
        expect(c.links, hasLength(1));
        expect(c.error, isNull);
        expect(notices.single.tone, LinkTone.error);
      },
    );
  });

  test('the countdown reads like the web page\'s', () {
    expect(linkTimeLeft(0), 'closed');
    expect(linkTimeLeft(9), '9s');
    expect(linkTimeLeft(65), '1m 05s');
    expect(linkTimeLeft(3909), '1h 05m 09s');
    expect(linkTimeLeft(90061), '1d 1h 01m');
  });

  group('LinksPage', () {
    late List<bool> awake;
    late List<String> shared;

    setUp(() {
      awake = [];
      shared = [];
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.devicePixelRatio = 1.0;
      view.physicalSize = const Size(400, 1800);
    });

    tearDown(() {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    Widget page(
      LinkRepository repo, {
      VoidCallback? onSignedOut,
      DateTime Function()? clock,
    }) => MaterialApp(
      home: LinksPage(
        repository: repo,
        exportService: _NoExport(),
        keepAwake: (on) async => awake.add(on),
        shareText: (text) async => shared.add(text),
        openUrl: (_) async {},
        onSignedOut: onSignedOut,
        clock: clock,
      ),
    );

    testWidgets('shows each class\'s link, and sets when it closes', (
      tester,
    ) async {
      final repo =
          _Links([
              link('AAAAAA'),
              link('BBBBBB', subject: 'IT202', section: 'BSCS-3B'),
            ])
            ..answer = (code, time) => LinkState(
              shortCode: code,
              url: '$_url$code',
              expiry: const LinkExpiry(
                at: '2026-09-30 09:00:00',
                label: 'Sep 30, 2026 9:00 AM',
                short: '9:00 AM',
                secondsLeft: 3600,
              ),
            );
      await tester.pumpWidget(page(repo, clock: tester.binding.clock.now));
      await tester.pumpAndSettle();

      expect(find.text(LinksStrings.title), findsOneWidget);
      expect(find.text('AAAAAA'), findsOneWidget);
      expect(find.text('BBBBBB'), findsOneWidget);
      expect(
        find.text(LinksStrings.noExpiry, findRichText: true),
        findsNWidgets(2),
      );

      await tester.tap(find.byKey(const ValueKey('link.expiry.AAAAAA')));
      await tester.pumpAndSettle();
      expect(find.text(LinksStrings.expiryIn), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('linkTime.preset.0')));
      await tester.pumpAndSettle();

      expect(repo.calls.single.$1, 'expiry');
      expect(repo.calls.single.$2, 'AAAAAA');
      expect(repo.calls.single.$3, {'minutes': 60});
      expect(find.textContaining(LinksStrings.expirySet), findsOneWidget);
      expect(
        find.textContaining('1h 00m 00s', findRichText: true),
        findsOneWidget,
      );

      // The countdown runs while the page is up — and stops with it.
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.textContaining('59m 58s', findRichText: true),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the QR code opens full screen and keeps the screen on', (
      tester,
    ) async {
      await tester.pumpWidget(page(_Links([link('AAAAAA')])));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('link.qr.AAAAAA')));
      await tester.pumpAndSettle();

      expect(find.byType(LinkQrPage), findsOneWidget);
      expect(find.byKey(const ValueKey('linkQr.code')), findsOneWidget);
      expect(awake, [true]);

      await tester.tap(find.byKey(const ValueKey('linkQr.close')));
      await tester.pumpAndSettle();
      expect(find.byType(LinkQrPage), findsNothing);
      expect(awake, [true, false]);
    });

    testWidgets('share hands over the address with the class', (tester) async {
      await tester.pumpWidget(page(_Links([link('AAAAAA')])));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('link.share.AAAAAA')));
      await tester.pump();
      expect(shared.single, contains('${_url}AAAAAA'));
      expect(shared.single, contains('BSIT-2A'));
    });

    testWidgets('a new link is asked about, then offers to set its expiry', (
      tester,
    ) async {
      final repo =
          _Links([
              link(
                'AAAAAA',
                expiry: const LinkExpiry(
                  at: '2026-09-30 07:00:00',
                  short: '7:00 AM',
                  secondsLeft: -60,
                  expired: true,
                ),
              ),
            ])
            ..answer = (code, _) =>
                const LinkState(shortCode: 'ZZZZZZ', url: '${_url}ZZZZZZ');
      await tester.pumpWidget(page(repo));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(LinksStrings.expired, findRichText: true),
        findsOneWidget,
      );
      // A closed link takes no submissions: no late row.
      expect(
        find.textContaining(LinksStrings.lateLabel.toUpperCase()),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('link.renew.AAAAAA')));
      await tester.pumpAndSettle();
      expect(find.text(LinksStrings.renewConfirmTitle), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('links.confirm')));
      await tester.pumpAndSettle();

      expect(repo.calls.single.$1, 'renew');
      expect(find.text('ZZZZZZ'), findsOneWidget);
      expect(find.text(LinksStrings.expiryIn), findsOneWidget);
    });

    testWidgets('the splash plays while the list loads, then the cards rise', (
      tester,
    ) async {
      final repo = _Links([link('AAAAAA')])
        ..rotated = [(oldCode: 'OLDOLD', newCode: 'AAAAAA')];
      await tester.pumpWidget(
        MaterialApp(
          home: LinksIntro(
            repository: repo,
            page: (context, controller) => LinksPage(
              repository: repo,
              controller: controller,
              exportService: _NoExport(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Asked for under the splash, not after it.
      expect(find.byType(LinksSplash), findsOneWidget);
      expect(find.text(LinksStrings.splashTagline), findsOneWidget);
      expect(repo.loads, 1);

      await tester.pumpAndSettle();
      expect(find.byType(LinksSplash), findsNothing);
      expect(find.text('AAAAAA'), findsOneWidget);
      // No second trip for the page, and the news from the first is told.
      expect(repo.loads, 1);
      expect(find.textContaining(LinksStrings.rotatedTitle(1)), findsOneWidget);
    });

    testWidgets('no access says so instead of an empty list', (tester) async {
      final repo = _Links([])
        ..refuse = const ScannerException(
          'Your account does not have access to attendance links.',
          code: 'forbidden',
        );
      await tester.pumpWidget(page(repo));
      await tester.pumpAndSettle();

      expect(
        find.text('Your account does not have access to attendance links.'),
        findsOneWidget,
      );
    });

    testWidgets('lays out on a small phone without overflowing', (
      tester,
    ) async {
      final view = tester.view;
      view.physicalSize = const Size(320, 640);
      await tester.pumpWidget(
        page(
          _Links([
            link(
              'AAAAAA',
              expiry: const LinkExpiry(
                at: '2026-10-01 17:00:00',
                short: 'Oct 1, 5:00 PM',
                secondsLeft: 90000,
              ),
              late: const LinkLate(
                on: true,
                secondsLeft: 600,
                label: '8:15 AM',
              ),
            ),
            link(
              'BBBBBB',
              expiry: const LinkExpiry(
                at: '2026-09-30 07:00:00',
                short: '7:00 AM',
                secondsLeft: -60,
                expired: true,
              ),
            ),
          ], admin: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final qr = find.byKey(const ValueKey('link.qr.AAAAAA'));
      await tester.ensureVisible(qr);
      await tester.pumpAndSettle();
      await tester.tap(qr);
      await tester.pumpAndSettle();
      expect(find.byType(LinkQrPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  test('demo links answer like the server', () async {
    var now = DateTime(2026, 9, 30, 8);
    final demo = InMemoryLinkRepository(
      latency: Duration.zero,
      clock: () => now,
    );
    final list = await demo.loadLinks();
    final code = list.links.first.shortCode;

    final closes = await demo.setExpiry(code, LinkTime.minutes(90));
    expect(closes.expiry.secondsLeft, 5400);
    expect(closes.expiry.short, '9:30 AM');

    await expectLater(
      demo.setExpiry(code, LinkTime.closesAt(DateTime(2026, 9, 29))),
      throwsA(isA<ScannerException>()),
    );

    final late = await demo.setLate(code, LinkTime.onTimeUntil(8, 15));
    expect(late.late.on, isTrue);
    expect(late.late.label, '8:15 AM');
    expect(late.late.secondsLeft, 16 * 60);

    final renewed = await demo.renewLink(code);
    expect(renewed.link.shortCode, isNot(code));
    expect(renewed.link.expiry.isSet, isFalse);
    expect(renewed.link.late.on, isFalse);
    now = now.add(const Duration(days: 1));
  });
}
