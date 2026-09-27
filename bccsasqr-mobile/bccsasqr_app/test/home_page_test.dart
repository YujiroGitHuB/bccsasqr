import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/core/theme/app_colors.dart';
import 'package:bccsasqr_app/core/theme/app_theme.dart';
import 'package:bccsasqr_app/views/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.devicePixelRatio = 1.0;
    view.physicalSize = const Size(420, 1400);
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Widget home(int hour) => MaterialApp(
    theme: AppTheme.build(AppPalette.light),
    home: HomePage(
      generatorBuilder: (context) => const Text('generator'),
      trackerBuilder: (context) => const Text('tracker'),
      now: () => DateTime(2026, 9, 27, hour),
    ),
  );

  for (final (hour, greeting) in [
    (8, AppStrings.homeMorning),
    (14, AppStrings.homeAfternoon),
    (20, AppStrings.homeEvening),
  ]) {
    testWidgets('greets by the hour: $greeting at $hour:00', (tester) async {
      await tester.pumpWidget(home(hour));
      await tester.pumpAndSettle();

      expect(find.text(greeting), findsOneWidget);
      expect(find.text(AppStrings.homeQuestion), findsOneWidget);
    });
  }

  testWidgets('My QR Code leads, with My Attendance and the steps under it', (
    tester,
  ) async {
    await tester.pumpWidget(home(9));
    await tester.pumpAndSettle();

    final qr = tester.getTopLeft(find.byKey(const ValueKey('home.generator')));
    final tracker = tester.getTopLeft(
      find.byKey(const ValueKey('home.tracker')),
    );
    expect(qr.dy, lessThan(tracker.dy));
    expect(find.text(AppStrings.homeHowItWorks), findsOneWidget);
    expect(find.text(AppStrings.studentStepSave), findsOneWidget);
    expect(find.text(AppStrings.studentStepCheck), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home.generator')));
    await tester.pumpAndSettle();
    expect(find.text('generator'), findsOneWidget);
  });

  testWidgets('lays out on a small phone without overflowing', (tester) async {
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .views
        .first
        .physicalSize = const Size(
      320,
      640,
    );
    await tester.pumpWidget(home(9));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
