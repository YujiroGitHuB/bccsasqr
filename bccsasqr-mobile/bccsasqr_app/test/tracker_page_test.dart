import 'package:bccsasqr_app/app.dart';
import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/core/utils/student_number.dart';
import 'package:bccsasqr_app/models/attendance_history.dart';
import 'package:bccsasqr_app/services/speech_service.dart';
import 'package:bccsasqr_app/services/student_repository.dart';
import 'package:bccsasqr_app/services/tracker_repository.dart';
import 'package:bccsasqr_app/views/tracker_page.dart';
import 'package:bccsasqr_app/views/tracker_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AttendanceDay _day(int day, {bool late = false}) => AttendanceDay(
  date: DateTime(2026, 9, day),
  rawDate: '2026-09-${day.toString().padLeft(2, '0')}',
  timeIn: '08:0$day:00 AM',
  late: late,
);

/// One student with a long subject (to fold), one with none, one offline.
class _StubTracker implements TrackerRepository {
  @override
  Future<AttendanceHistory?> fetchAttendance(StudentNumber number) async {
    switch (number.value) {
      case '025-1023':
        return AttendanceHistory(
          studentNumber: '025-1023',
          fullName: 'Maria Isabel Santos',
          course: 'BSCS',
          section: '2-B',
          total: 8,
          lastAttended: DateTime(2026, 9, 7),
          subjects: [
            SubjectAttendance(
              subject: 'Object Oriented Programming',
              instructor: 'Charles Nixon Cayading',
              count: 7,
              days: [for (var d = 7; d >= 1; d--) _day(d, late: d == 6)],
            ),
            SubjectAttendance(
              subject: 'Discrete Structures',
              instructor: 'Ana Villanueva',
              count: 1,
              days: [_day(2)],
            ),
          ],
        );
      case '023-770':
        return const AttendanceHistory(
          studentNumber: '023-770',
          fullName: 'Angelica Mae Reyes',
          course: 'BSED',
          section: '1-A',
          total: 0,
        );
      case '021-318':
        throw const StudentLookupException(
          'The attendance tracker is temporarily closed.',
          code: 'tracker_locked',
        );
    }
    return null;
  }
}

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.devicePixelRatio = 1.0;
    view.physicalSize = const Size(400, 2400);
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<void> openTracker(WidgetTester tester) async {
    await tester.pumpWidget(
      BccSasqrApp(
        trackerRepository: _StubTracker(),
        speech: const SilentSpeechService(),
        showSplash: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home.tracker')));
    await tester.pumpAndSettle();
  }

  /// Types a number and waits out the debounce and the reply.
  Future<void> search(WidgetTester tester, String number) async {
    await tester.enterText(find.byKey(const ValueKey('tracker.field')), number);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  testWidgets('the home screen offers the tracker to students', (tester) async {
    await tester.pumpWidget(
      BccSasqrApp(
        trackerRepository: _StubTracker(),
        speech: const SilentSpeechService(),
        showSplash: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.homeTrackerTitle), findsOneWidget);
    expect(find.text(AppStrings.homeTrackerBody), findsOneWidget);
  });

  testWidgets('plays its own splash before the page', (tester) async {
    await tester.pumpWidget(
      BccSasqrApp(
        trackerRepository: _StubTracker(),
        speech: const SilentSpeechService(),
        showSplash: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home.tracker')));
    // The new route's first frame is laid out offstage, for heroes.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));

    expect(find.byType(TrackerSplash), findsOneWidget);
    expect(find.text(TrackerStrings.splashTagline), findsOneWidget);
    expect(find.text(TrackerStrings.stepDays), findsOneWidget);
    expect(find.byType(TrackerPage), findsNothing);

    await tester.pumpAndSettle();
    expect(find.byType(TrackerSplash), findsNothing);
    expect(find.byType(TrackerPage), findsOneWidget);
  });

  testWidgets('opens on the placeholder', (tester) async {
    await openTracker(tester);

    expect(find.byType(TrackerPage), findsOneWidget);
    expect(find.text(TrackerStrings.title), findsOneWidget);
    expect(find.text(TrackerStrings.placeholderTitle), findsOneWidget);
    // A stub was injected, so no demo notice.
    expect(find.text(AppStrings.demoModeTitle), findsNothing);
  });

  testWidgets('a found student shows the numbers and each subject', (
    tester,
  ) async {
    await openTracker(tester);
    await search(tester, '0251023');

    expect(find.text('Maria Isabel Santos'), findsOneWidget);
    expect(find.text(TrackerStrings.loaded), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tracker.stat.present')),
        matching: find.text('8'),
      ),
      findsOneWidget,
    );
    expect(find.text('Sep 07, 2026'), findsWidgets);
    expect(find.text('Object Oriented Programming'), findsOneWidget);
    expect(find.text('Discrete Structures'), findsOneWidget);
    expect(find.text(TrackerStrings.days(7)), findsOneWidget);
    expect(find.text(TrackerStrings.days(1)), findsOneWidget);
    // The late mark on Sep 6.
    expect(find.text(ScannerStrings.lateTag), findsOneWidget);
    expect(find.text(TrackerStrings.placeholderTitle), findsNothing);
  });

  testWidgets('a long subject folds after five days', (tester) async {
    await openTracker(tester);
    await search(tester, '0251023');

    // Sep 1 and 2 of OOP are folded away; Sep 2 of Discrete shows.
    expect(find.text('Sep 01, 2026'), findsNothing);
    expect(find.text(TrackerStrings.showAll(7)), findsOneWidget);

    await tester.tap(find.text(TrackerStrings.showAll(7)));
    await tester.pumpAndSettle();

    expect(find.text('Sep 01, 2026'), findsOneWidget);
    expect(find.text(TrackerStrings.showLess), findsOneWidget);
  });

  testWidgets('a record with no scans says so', (tester) async {
    await openTracker(tester);
    await search(tester, '023770');

    expect(find.text('Angelica Mae Reyes'), findsOneWidget);
    expect(find.text(TrackerStrings.noAttendance), findsOneWidget);
    expect(find.text(TrackerStrings.emptyTitle), findsOneWidget);
    expect(find.text(TrackerStrings.statPresent), findsNothing);
  });

  testWidgets('an unknown number says "not found"', (tester) async {
    await openTracker(tester);
    await search(tester, '019999');

    expect(find.text(TrackerStrings.notFound), findsOneWidget);
    expect(find.text(TrackerStrings.notFoundTitle), findsOneWidget);
    expect(find.text(AppStrings.actionRetry), findsNothing);
  });

  testWidgets('a server refusal shows its message and a retry', (tester) async {
    await openTracker(tester);
    await search(tester, '021318');

    expect(
      find.text('The attendance tracker is temporarily closed.'),
      findsOneWidget,
    );
    expect(find.text(AppStrings.actionRetry), findsOneWidget);
  });

  testWidgets('lays out on a small phone without overflowing', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(320, 3000);

    await openTracker(tester);
    await search(tester, '0251023');

    expect(tester.takeException(), isNull);
    expect(find.text('Maria Isabel Santos'), findsOneWidget);
  });

  testWidgets('clearing the field brings the placeholder back', (tester) async {
    await openTracker(tester);
    await search(tester, '0251023');
    await search(tester, '');

    expect(find.text('Maria Isabel Santos'), findsNothing);
    expect(find.text(TrackerStrings.placeholderTitle), findsOneWidget);
  });
}
