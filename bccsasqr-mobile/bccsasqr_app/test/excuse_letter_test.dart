import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/core/theme/app_colors.dart';
import 'package:bccsasqr_app/core/theme/app_theme.dart';
import 'package:bccsasqr_app/models/attendance_history.dart';
import 'package:bccsasqr_app/models/excuse_letter.dart';
import 'package:bccsasqr_app/views/excuse_letter_page.dart';
import 'package:bccsasqr_app/views/widgets/island.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Made-up students only: year 000 never occurs in the school's numbers.

/// Missed twice; taken with section 2A, though the record says 2B — an
/// irregular student, whose letter goes to the class they take it with.
final _oop = SubjectAttendance(
  subject: 'Object Oriented Programming',
  instructor: 'Sample Instructor',
  count: 1,
  days: [
    AttendanceDay(
      date: DateTime(2026, 9, 24),
      rawDate: '2026-09-24',
      timeIn: '08:11:40 AM',
    ),
  ],
  section: '2A',
  enrolled: true,
  classes: 3,
  absentDates: [DateTime(2026, 9, 28), DateTime(2026, 9, 21)],
);

final _history = AttendanceHistory(
  studentNumber: '000-1023',
  fullName: 'DELA CRUZ, JUAN P.',
  course: 'BSIT',
  section: '2B',
  total: 1,
  classes: 3,
  absences: 2,
  subjects: [_oop],
);

final _written = DateTime(2026, 10, 3, 9);

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.build(AppPalette.light),
  builder: (context, child) => IslandHost(child: child!),
  home: home,
);

Widget _page({Future<void> Function(String text, String subject)? share}) =>
    _app(
      ExcuseLetterPage(
        history: _history,
        subject: _oop,
        date: DateTime(2026, 9, 28),
        now: () => _written,
        share: share ?? (text, subject) async {},
      ),
    );

String _letter(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const ValueKey('excuseLetter.letter')))
    .controller!
    .text;

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.devicePixelRatio = 1.0;
    // Tall enough for the whole page: every chip and button in reach.
    view.physicalSize = const Size(420, 2200);
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  group('the letter', () {
    test('is signed given name first, out of the export\'s capitals', () {
      expect(
        ExcuseLetter.signatureName('DELA CRUZ, JUAN P.'),
        'Juan P. Dela Cruz',
      );
      // A lone V is her middle initial, not "the Fifth".
      expect(ExcuseLetter.signatureName('SANTOS, MARIA V.'), 'Maria V. Santos');
      expect(ExcuseLetter.signatureName('REYES, JOSE III'), 'Jose Reyes III');
      expect(
        ExcuseLetter.signatureName('GARCIA JR., PEDRO'),
        'Pedro Garcia Jr.',
      );
      expect(
        ExcuseLetter.signatureName('LOPEZ,  MA. ANA JR.'),
        'Ma. Ana Lopez Jr.',
      );
      expect(
        ExcuseLetter.signatureName("O'NEIL-SANTOS, ANA"),
        "Ana O'Neil-Santos",
      );
      // Typed by a person: the order and the case are kept.
      expect(ExcuseLetter.signatureName('Ana McArthur'), 'Ana McArthur');
    });

    test('writes the days as a letter does, oldest first', () {
      expect(
        ExcuseLetter.datesPhrase([DateTime(2026, 9, 28)]),
        'Monday, September 28, 2026',
      );
      expect(
        ExcuseLetter.datesPhrase([
          DateTime(2026, 9, 28),
          DateTime(2026, 9, 21),
        ]),
        'September 21 and 28, 2026',
      );
      expect(
        ExcuseLetter.datesPhrase([
          DateTime(2026, 9, 28),
          DateTime(2026, 9, 14),
          DateTime(2026, 9, 21),
        ]),
        'September 14, 21 and 28, 2026',
      );
      expect(
        ExcuseLetter.datesPhrase([
          DateTime(2026, 10, 1),
          DateTime(2026, 9, 28),
        ]),
        'September 28 and October 1, 2026',
      );
      expect(
        ExcuseLetter.datesPhrase([
          DateTime(2026, 1, 5),
          DateTime(2025, 12, 15),
        ]),
        'December 15, 2025 and January 5, 2026',
      );
    });

    test('names the class once', () {
      // A no-break space: the class is never split at the end of a line.
      expect(ExcuseLetter.classOf('BSIT', '2A'), 'BSIT 2A');
      expect(ExcuseLetter.classOf('BSIT', 'BSIT-2A'), 'BSIT-2A');
      expect(ExcuseLetter.classOf('', '2A'), '2A');
      expect(ExcuseLetter.classOf('BSIT', ' '), 'BSIT');
      expect(ExcuseLetter.classOf('', ''), '');
    });

    test('is written from the record, to the class the subject is taken '
        'with', () {
      final letter = ExcuseLetter.forSubject(
        history: _history,
        subject: _oop,
        dates: [DateTime(2026, 9, 28)],
        reason: ExcuseReason.sick,
        written: _written,
        note: '   ',
      );

      expect(
        letter.text,
        'October 3, 2026\n'
        '\n'
        'Sample Instructor\n'
        'Instructor, Object Oriented Programming\n'
        'Binalatongan Community College\n'
        '\n'
        'Dear Sir/Ma\'am,\n'
        '\n'
        'Good day! I am Juan P. Dela Cruz of BSIT 2A, a student in your '
        'Object Oriented Programming class.\n'
        '\n'
        'I would like to ask you to excuse my absence on Monday, September '
        '28, 2026, because I was sick.\n'
        '\n'
        'I will catch up on the lessons I missed and complete any activities '
        'or requirements I need to submit. Thank you for your understanding.\n'
        '\n'
        'Respectfully yours,\n'
        '\n'
        'Juan P. Dela Cruz\n'
        'BSIT 2A\n'
        '000-1023',
      );
      expect(letter.subjectLine, 'Excuse letter — Object Oriented Programming');
    });

    test('a note is a paragraph of its own; a class nobody has scanned yet '
        'goes to its instructor unnamed', () {
      final paragraphs = ExcuseLetter(
        studentName: 'DELA CRUZ, JUAN P.',
        studentNumber: '000-1023',
        course: 'BSIT',
        section: '2A',
        subject: 'Data Structures and Algorithms',
        instructor: 'N/A',
        dates: [DateTime(2026, 9, 29), DateTime(2026, 9, 22)],
        reason: ExcuseReason.weather,
        written: _written,
        note: '  I have attached a photo of the flooded road.  ',
      ).text.split('\n\n');

      expect(
        paragraphs[1],
        'Instructor, Data Structures and Algorithms\n'
        'Binalatongan Community College',
      );
      expect(
        paragraphs[4],
        'I would like to ask you to excuse my absences on September 22 and '
        '29, 2026, because of the heavy rain and flooding in our area.',
      );
      expect(paragraphs[5], 'I have attached a photo of the flooded road.');
      expect(paragraphs[6], ExcuseLetterStrings.closing);
    });
  });

  group('the page', () {
    testWidgets('opens on the day tapped, and the letter follows the '
        'choices', (tester) async {
      await tester.pumpWidget(_page());
      await tester.pumpAndSettle();

      expect(
        _letter(tester),
        contains(
          'my absence on Monday, September 28, 2026, because I was '
          'sick.',
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('excuseLetter.reason.family')),
      );
      await tester.pump();
      expect(_letter(tester), contains('because of a family emergency.'));

      // The subject's other missed day is offered: one letter for both.
      await tester.tap(
        find.byKey(const ValueKey('excuseLetter.day.2026-09-21')),
      );
      await tester.pump();
      expect(
        _letter(tester),
        contains(
          'my absences on September 21 and 28, 2026, because of a '
          'family emergency.',
        ),
      );

      // Down to one day, and that one stays: a letter about no day is no
      // letter.
      await tester.tap(
        find.byKey(const ValueKey('excuseLetter.day.2026-09-21')),
      );
      await tester.tap(
        find.byKey(const ValueKey('excuseLetter.day.2026-09-28')),
      );
      await tester.pump();
      expect(
        _letter(tester),
        contains('my absence on Monday, September 28, 2026,'),
      );

      await tester.enterText(
        find.byKey(const ValueKey('excuseLetter.note')),
        'I have attached my medical certificate.',
      );
      await tester.pump();
      expect(
        _letter(tester),
        contains('\n\nI have attached my medical certificate.\n\n'),
      );
    });

    testWidgets('an edited letter is the student\'s: the choices leave it, '
        'and Start over brings theirs back', (tester) async {
      await tester.pumpWidget(_page());
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('excuseLetter.startOver')),
        findsNothing,
      );

      await tester.enterText(
        find.byKey(const ValueKey('excuseLetter.letter')),
        'Good day, Sir. I was absent on Monday.',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('excuseLetter.reason.weather')),
      );
      await tester.pump();
      expect(_letter(tester), 'Good day, Sir. I was absent on Monday.');

      await tester.tap(find.byKey(const ValueKey('excuseLetter.startOver')));
      await tester.pump();
      expect(
        _letter(tester),
        contains('because of the heavy rain and flooding in our area.'),
      );
      expect(
        find.byKey(const ValueKey('excuseLetter.startOver')),
        findsNothing,
      );
    });

    testWidgets('shares the letter with its subject line, and copies it', (
      tester,
    ) async {
      String? copied;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      final shared = <(String, String)>[];
      await tester.pumpWidget(
        _page(share: (text, subject) async => shared.add((text, subject))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('excuseLetter.share')));
      await tester.pumpAndSettle();
      expect(shared.single.$1, _letter(tester));
      expect(shared.single.$2, 'Excuse letter — Object Oriented Programming');

      await tester.tap(find.byKey(const ValueKey('excuseLetter.copy')));
      await tester.pump();
      expect(copied, _letter(tester));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(ExcuseLetterStrings.copied), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('an emptied letter cannot be sent', (tester) async {
      await tester.pumpWidget(_page());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('excuseLetter.letter')),
        '  ',
      );
      await tester.pump();

      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('excuseLetter.share')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('excuseLetter.copy')),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('a share sheet that will not open says so', (tester) async {
      await tester.pumpWidget(
        _page(share: (text, subject) async => throw Exception('no sheet')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('excuseLetter.share')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(ExcuseLetterStrings.shareFailed), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('lays out on a small phone without overflowing', (
      tester,
    ) async {
      TestWidgetsFlutterBinding
          .instance
          .platformDispatcher
          .views
          .first
          .physicalSize = const Size(
        320,
        640,
      );
      await tester.pumpWidget(_page());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The page's own scroll: the letter's field has one of its own.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('excuseLetter.share')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
