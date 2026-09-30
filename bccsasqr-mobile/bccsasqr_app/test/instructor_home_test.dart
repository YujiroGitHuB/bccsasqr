import 'package:bccsasqr_app/app.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/core/constants/whats_new_log.dart';
import 'package:bccsasqr_app/models/app_role.dart';
import 'package:bccsasqr_app/models/app_settings.dart';
import 'package:bccsasqr_app/models/scanner_models.dart';
import 'package:bccsasqr_app/models/today_summary.dart';
import 'package:bccsasqr_app/services/app_info.dart';
import 'package:bccsasqr_app/services/device_lock.dart';
import 'package:bccsasqr_app/services/link_repository.dart';
import 'package:bccsasqr_app/services/qr_export_service.dart';
import 'package:bccsasqr_app/services/role_store.dart';
import 'package:bccsasqr_app/services/scan_feedback.dart';
import 'package:bccsasqr_app/services/scanner_repository.dart';
import 'package:bccsasqr_app/services/settings_store.dart';
import 'package:bccsasqr_app/services/speech_service.dart';
import 'package:bccsasqr_app/services/student_repository.dart';
import 'package:bccsasqr_app/services/tracker_repository.dart';
import 'package:bccsasqr_app/services/whats_new_store.dart';
import 'package:bccsasqr_app/views/instructor_home.dart';
import 'package:bccsasqr_app/views/instructor_menu.dart';
import 'package:bccsasqr_app/views/instructor_shell.dart';
import 'package:bccsasqr_app/views/onboarding_page.dart';
import 'package:bccsasqr_app/views/tracker_splash.dart';
import 'package:bccsasqr_app/views/whats_new_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoExport implements QrExportService {
  @override
  Future<String> export({
    required GlobalKey boundaryKey,
    required String fileName,
    String? shareText,
  }) async => fileName;
}

/// The morning these tests happen on — the demo server's clock, so its date
/// is the one the scans are filed under.
final DateTime _morning = DateTime(2026, 9, 30, 8, 30);

AttendanceEntry _scan(
  String number,
  String name,
  String subject,
  String time, {
  bool late = false,
}) => AttendanceEntry(
  studentNumber: number,
  name: name,
  course: 'BSIT',
  section: '2G',
  subject: subject,
  date: '2026-09-30',
  timeIn: time,
  late: late,
);

/// Made-up students: year 000 never occurs, so no number here is anyone's.
final List<AttendanceEntry> _earlier = [
  _scan(
    '000-2041',
    'Andrea Villanueva',
    'Object Oriented Programming',
    '08:12:40 AM',
    late: true,
  ),
  _scan(
    '000-2187',
    'Miguel Santos',
    'Object Oriented Programming',
    '08:05:02 AM',
  ),
  _scan('000-2310', 'Paolo Reyes', 'Introduction to Computing', '07:44:19 AM'),
];

/// The demo scanner, with a morning's scans already on the server and a
/// "Manage attendance links" that can be ticked and unticked.
class _Scanner extends InMemoryScannerRepository {
  _Scanner() : super(latency: Duration.zero, clock: () => _morning);

  bool links = true;
  List<AttendanceEntry> earlier = _earlier;

  ScannerUser _as(ScannerUser u) => ScannerUser(
    id: u.id,
    name: u.name,
    email: u.email,
    role: u.role,
    canManageLinks: links,
  );

  @override
  Future<ScannerUser> signIn({
    required String email,
    required String password,
  }) async => _as(await super.signIn(email: email, password: password));

  @override
  Future<SubjectList> loadSubjects() async {
    final list = await super.loadSubjects();
    return (user: _as(list.user), subjects: list.subjects, date: list.date);
  }

  /// Newest first: what was scanned here, then the morning's.
  @override
  Future<List<AttendanceEntry>> loadToday() async => [
    ...await super.loadToday(),
    ...earlier,
  ];
}

/// Stands in for the camera: a button that "scans" a made-up student's code.
Widget _camera(BuildContext context, ValueChanged<String> onCode) => ColoredBox(
  color: Colors.black,
  child: Center(
    child: TextButton(
      key: const ValueKey('scan:000-1023'),
      onPressed: () => onCode('000-1023'),
      child: const Text('scan 000-1023'),
    ),
  ),
);

final _home = find.byKey(const ValueKey('instructorHome'));

/// The panel's heading — not the bar's label, which says Menu too.
final _menuTitle = find.byKey(const ValueKey('menu.title'));

void main() {
  group('TodaySummary', () {
    const oop = ScanSubject(
      code: 'ITE211',
      name: 'Object Oriented Programming',
      lateMarking: true,
    );
    const cc = ScanSubject(code: 'CC121', name: 'Introduction to Computing');

    test('counts today only, late apart, each subject newest first', () {
      final summary = TodaySummary.of(
        entries: [
          ..._earlier,
          // Kept offline yesterday and not sent yet: in the list, not today.
          const AttendanceEntry(
            studentNumber: '000-2455',
            name: 'Bea Mendoza',
            course: 'BSIT',
            section: '2G',
            subject: 'Introduction to Computing',
            date: '2026-09-29',
            timeIn: '03:10:00 PM',
            pending: true,
          ),
        ],
        today: '2026-09-30',
        subjects: const [oop, cc],
      );

      expect(summary.total, 3);
      expect(summary.late, 1);
      expect(summary.onTime, 2);
      expect(summary.subjectsScanned, 2);
      expect(
        [for (final s in summary.subjects) s.name],
        ['Object Oriented Programming', 'Introduction to Computing'],
      );
      final first = summary.subjects.first;
      expect(first.scanned, 2);
      expect(first.late, 1);
      expect(first.lastTimeIn, '08:12:40 AM');
      expect(first.subject?.code, 'ITE211');
      expect(summary.subjects.last.scanned, 1);
    });

    test(
      'the subject being scanned is listed first, before its first scan',
      () {
        const pe = ScanSubject(code: 'PE3', name: 'Physical Education');
        final summary = TodaySummary.of(
          entries: _earlier,
          today: '2026-09-30',
          subjects: const [oop, cc, pe],
          selected: pe,
        );

        expect(summary.subjects.first.name, 'Physical Education');
        expect(summary.subjects.first.scanned, 0);
        expect(summary.subjects.first.lastTimeIn, isNull);
        expect(summary.subjectsScanned, 2);

        final picked = TodaySummary.of(
          entries: _earlier,
          today: '2026-09-30',
          subjects: const [oop, cc],
          selected: cc,
        );
        // Already scanned: where its scans put it, not listed twice.
        expect(
          [for (final s in picked.subjects) s.name],
          ['Object Oriented Programming', 'Introduction to Computing'],
        );
      },
    );

    test('nothing today is nothing, whatever is in the list', () {
      final summary = TodaySummary.of(entries: _earlier, today: '2026-10-01');
      expect(summary.total, 0);
      expect(summary.subjects, isEmpty);
    });

    test('a code splits for its tile, and a time loses its seconds', () {
      expect(codeParts('ITE211', 'x'), ('ITE', '211'));
      expect(codeParts('cc 121', 'x'), ('CC', '121'));
      expect(codeParts('NSTP-1', 'x'), ('NSTP', '1'));
      expect(codeParts('ELECTIVE', 'x'), ('ELECT', null));
      expect(codeParts(null, 'Object Oriented Programming'), ('OOP', null));
      expect(shortTime('08:14:03 AM'), '8:14 AM');
      expect(shortTime('12:05:00 PM'), '12:05 PM');
      expect(shortTime('8:14 am'), '8:14 AM');
      expect(shortTime('soon'), 'soon');
    });
  });

  group('the app', () {
    late _Scanner scanner;
    late MemoryWhatsNewStore news;
    late MemoryRoleStore roles;

    setUp(() {
      scanner = _Scanner();
      news = MemoryWhatsNewStore(WhatsNewLog.version);
      roles = MemoryRoleStore(AppRole.instructor);
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.devicePixelRatio = 1.0;
      view.physicalSize = const Size(420, 1600);
    });

    tearDown(() {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    Widget app({AppSettings settings = const AppSettings()}) => BccSasqrApp(
      roleStore: roles,
      repository: InMemoryStudentRepository(latency: Duration.zero),
      trackerRepository: InMemoryTrackerRepository(latency: Duration.zero),
      exportService: _NoExport(),
      speech: const SilentSpeechService(),
      scannerRepository: scanner,
      linkRepository: InMemoryLinkRepository(latency: Duration.zero),
      scanFeedback: const SilentScanFeedback(),
      settingsStore: MemorySettingsStore(settings),
      whatsNewStore: news,
      deviceLock: const NoDeviceLock(),
      scannerLockStore: MemoryScannerLockStore(),
      appInfo: () async => const AppInfo(version: '1.14.0', buildNumber: '18'),
      cameraBuilder: _camera,
      keepAwake: (on) async {},
      showSplash: false,
    );

    /// Signed in with the password: the bar opens on Home.
    Future<void> signIn(
      WidgetTester tester, {
      AppSettings settings = const AppSettings(),
    }) async {
      // The scan line sweeps forever; held still, pumpAndSettle can settle.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await tester.pumpWidget(app(settings: settings));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'demo@bcc.test');
      await tester.enterText(find.byType(TextField).at(1), 'secret');
      await tester.tap(
        find.widgetWithText(FilledButton, ScannerStrings.signIn),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tap(WidgetTester tester, String key) async {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
    }

    Finder inSheet(Finder finder) => find.descendant(
      of: find.byType(DraggableScrollableSheet),
      matching: finder,
    );

    Finder subjectRow(String name) =>
        find.byKey(ValueKey('instructorHome.subject.$name'));

    testWidgets('the bar opens on Home: today at a glance, the scanner a tap '
        'away', (tester) async {
      await signIn(tester);

      expect(_home, findsOneWidget);
      expect(find.text(ScannerStrings.title), findsNothing);
      expect(find.text('Demo Instructor'), findsOneWidget);

      // Three scans this morning, in two subjects, one of them late.
      expect(find.text(InstructorHomeStrings.scannedToday), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('instructorHome.count')))
            .data,
        '3',
      );
      expect(find.text(InstructorHomeStrings.scannedIn(2)), findsOneWidget);
      expect(find.text(InstructorHomeStrings.onTime(2)), findsOneWidget);
      expect(find.text(InstructorHomeStrings.late(1)), findsOneWidget);
      expect(find.text('Wed, Sep 30'), findsOneWidget);

      // Each subject, the latest first, with its last scan.
      expect(
        find.descendant(
          of: subjectRow('Object Oriented Programming'),
          matching: find.text(InstructorHomeStrings.scanned(2, 1)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: subjectRow('Object Oriented Programming'),
          matching: find.text('8:12 AM'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: subjectRow('Introduction to Computing'),
          matching: find.text(InstructorHomeStrings.scanned(1, 0)),
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(subjectRow('Object Oriented Programming')).dy,
        lessThan(tester.getTopLeft(subjectRow('Introduction to Computing')).dy),
      );

      // The newest scans, with the Late tag where it applies.
      expect(find.text(InstructorHomeStrings.recent), findsOneWidget);
      expect(find.text('Andrea Villanueva'), findsOneWidget);
      expect(find.text('Paolo Reyes'), findsOneWidget);
      expect(find.text(ScannerStrings.lateTag), findsOneWidget);

      // No subject yet: the button opens the scanner to pick one.
      expect(find.text(InstructorHomeStrings.pickSubject), findsOneWidget);
      await tap(tester, 'instructorHome.scan');
      expect(find.text(ScannerStrings.title), findsOneWidget);
      expect(find.text(ScannerStrings.subjectPlaceholder), findsOneWidget);
    });

    testWidgets('a scan on the Scanner counts on Home at once', (tester) async {
      await signIn(tester);
      await tap(tester, 'nav.scanner');
      await tester.tap(find.text(ScannerStrings.subjectPlaceholder));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Object Oriented Programming').last);
      await tester.pumpAndSettle();
      // Late marking on, then one more student.
      await tester.tap(find.text(ScannerStrings.lateTitle));
      await tester.pumpAndSettle();
      await tap(tester, 'scan:000-1023');

      await tap(tester, 'nav.home');
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('instructorHome.count')))
            .data,
        '4',
      );
      expect(find.text(InstructorHomeStrings.onTime(2)), findsOneWidget);
      expect(find.text(InstructorHomeStrings.late(2)), findsOneWidget);
      expect(
        find.descendant(
          of: subjectRow('Object Oriented Programming'),
          matching: find.text(InstructorHomeStrings.scanned(3, 2)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: subjectRow('Object Oriented Programming'),
          matching: find.text(InstructorHomeStrings.lateOn),
        ),
        findsOneWidget,
      );
      expect(find.text('Maria Isabel Santos'), findsOneWidget);

      // The card now names the subject, and scans straight into it.
      expect(find.text(InstructorHomeStrings.scanningFor), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('instructorHome.scanFor')),
          matching: find.text('Object Oriented Programming'),
        ),
        findsOneWidget,
      );
      expect(find.text(InstructorHomeStrings.scanNow), findsOneWidget);

      // Let the scan card's hold run out, or its timer outlives the test.
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('the shortcuts open QR Code, Links and Attendance over the '
        'bar, and back goes Home', (tester) async {
      await signIn(tester);

      await tap(tester, 'instructorHome.qr');
      expect(find.text(AppStrings.studentNumberLabel), findsOneWidget);
      expect(find.byType(InstructorDock), findsOneWidget);
      // A tab the Menu opens: the Menu's label is the lit one.
      expect(
        tester.widget<Text>(find.text(NavStrings.menu)).style?.fontWeight,
        FontWeight.w800,
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_home, findsOneWidget);
      expect(find.text(AppStrings.studentNumberLabel), findsNothing);

      await tap(tester, 'instructorHome.links');
      expect(find.text(LinksStrings.title), findsOneWidget);

      await tap(tester, 'nav.home');
      await tap(tester, 'instructorHome.tracker');
      expect(find.byType(TrackerIntro), findsOneWidget);
      // Attendance is on the bar too: it is the tab picked.
      expect(
        tester.getSemantics(find.byKey(const ValueKey('nav.tracker'))),
        containsSemantics(isSelected: true),
      );
    });

    testWidgets('Today\'s scans, and a subject, open the whole list', (
      tester,
    ) async {
      await signIn(tester);

      await tap(tester, 'instructorHome.today');
      expect(
        inSheet(find.text(ScannerStrings.attendanceSheetTitle)),
        findsOneWidget,
      );
      expect(
        inSheet(find.text('${ScannerStrings.attendanceAll} · 3')),
        findsOneWidget,
      );
      expect(inSheet(find.text('Andrea Villanueva')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.tap(subjectRow('Introduction to Computing'));
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Paolo Reyes')), findsOneWidget);
      expect(inSheet(find.text('Andrea Villanueva')), findsNothing);
    });

    testWidgets('the Menu opens over Home with every part, and closes three '
        'ways', (tester) async {
      await signIn(tester);

      await tap(tester, 'nav.menu');
      expect(_menuTitle, findsOneWidget);
      for (final item in [
        'scanner',
        'qr',
        'links',
        'tracker',
        'today',
        'whatsNew',
        'settings',
        'tour',
        'signOut',
      ]) {
        expect(
          find.byKey(ValueKey('menu.$item')),
          findsOneWidget,
          reason: item,
        );
      }
      expect(find.text('Demo Instructor'), findsNWidgets(2));
      expect(find.byTooltip(NavStrings.menuClose), findsOneWidget);

      // The button again.
      await tap(tester, 'nav.menu');
      expect(_menuTitle, findsNothing);
      expect(find.byKey(const ValueKey('menu.qr')), findsNothing);

      // The phone's back button: the Menu goes, Home stays.
      await tap(tester, 'nav.menu');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_menuTitle, findsNothing);
      expect(_home, findsOneWidget);

      // A tap on the page behind it.
      await tap(tester, 'nav.menu');
      await tester.tapAt(const Offset(210, 40));
      await tester.pumpAndSettle();
      expect(_menuTitle, findsNothing);
      expect(_home, findsOneWidget);
    });

    testWidgets('each Menu item opens its part, and the Menu goes', (
      tester,
    ) async {
      await signIn(tester);

      await tap(tester, 'nav.menu');
      await tap(tester, 'menu.scanner');
      expect(_menuTitle, findsNothing);
      expect(find.text(ScannerStrings.title), findsOneWidget);

      await tap(tester, 'nav.menu');
      await tap(tester, 'menu.qr');
      expect(find.text(AppStrings.studentNumberLabel), findsOneWidget);

      await tap(tester, 'nav.menu');
      await tap(tester, 'menu.settings');
      expect(find.text(SettingsStrings.appearance), findsOneWidget);

      await tap(tester, 'nav.menu');
      await tap(tester, 'menu.today');
      expect(
        inSheet(find.text(ScannerStrings.attendanceSheetTitle)),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tap(tester, 'nav.menu');
      await tap(tester, 'menu.whatsNew');
      expect(find.byType(WhatsNewPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tap(tester, 'nav.menu');
      await tap(tester, 'menu.tour');
      expect(find.byType(OnboardingPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_menuTitle, findsNothing);
      expect(find.byType(InstructorDock), findsOneWidget);
    });

    testWidgets('without the permission, Links is on neither Home nor the '
        'Menu', (tester) async {
      scanner.links = false;
      await signIn(tester);

      expect(find.byKey(const ValueKey('instructorHome.qr')), findsOneWidget);
      expect(find.byKey(const ValueKey('instructorHome.links')), findsNothing);

      await tap(tester, 'nav.menu');
      expect(find.byKey(const ValueKey('menu.qr')), findsOneWidget);
      expect(find.byKey(const ValueKey('menu.links')), findsNothing);
    });

    testWidgets('signing out from the Menu asks first', (tester) async {
      await signIn(tester);

      await tap(tester, 'nav.menu');
      await tap(tester, 'menu.signOut');
      expect(find.text(ScannerStrings.signOutConfirmTitle), findsOneWidget);
      expect(_menuTitle, findsNothing);

      await tester.tap(find.text(ScannerStrings.signOut).last);
      await tester.pumpAndSettle();
      expect(find.text(ScannerStrings.signInHeading), findsOneWidget);
      expect(find.byType(InstructorShell, skipOffstage: false), findsNothing);
      expect(roles.saved, AppRole.instructor);
    });

    testWidgets('a new What\'s New puts a dot on Home\'s button, and opening '
        'it there clears it', (tester) async {
      news = MemoryWhatsNewStore();
      await signIn(tester);

      expect(find.byTooltip(WhatsNewStrings.openUnread), findsOneWidget);
      await tap(tester, 'instructorHome.whatsNew');
      expect(find.byType(WhatsNewPage), findsOneWidget);
      expect(news.seen, WhatsNewLog.version);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byTooltip(WhatsNewStrings.openUnread), findsNothing);
      expect(find.byTooltip(WhatsNewStrings.open), findsOneWidget);
    });

    testWidgets('lays out on a small phone, Menu open too, in both themes', (
      tester,
    ) async {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;

      for (final mode in [ThemeMode.dark, ThemeMode.light]) {
        // A fresh app each round, so the theme is read again; signed in on
        // the tall screen, where the form's button is in view.
        view.physicalSize = const Size(420, 1600);
        await tester.pumpWidget(const SizedBox.shrink());
        await signIn(tester, settings: AppSettings(themeMode: mode));

        view.physicalSize = const Size(320, 640);
        await tester.pumpAndSettle();
        expect(_home, findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$mode home');

        await tap(tester, 'nav.menu');
        expect(_menuTitle, findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$mode menu');
        // Taller than the room left: it scrolls inside itself, down to the
        // sign-out.
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('menu.signOut')),
          100,
          scrollable: find
              .descendant(
                of: find.byType(InstructorMenu),
                matching: find.byType(Scrollable),
              )
              .first,
        );

        // Signed out for the next round.
        await tap(tester, 'menu.signOut');
        await tester.tap(find.text(ScannerStrings.signOut).last);
        await tester.pumpAndSettle();
      }
    });
  });
}
