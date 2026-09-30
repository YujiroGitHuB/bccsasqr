import 'package:bccsasqr_app/core/constants/app_strings.dart';
import 'package:bccsasqr_app/core/theme/app_colors.dart';
import 'package:bccsasqr_app/core/theme/app_theme.dart';
import 'package:bccsasqr_app/views/instructor_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void phone(Size size) {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.devicePixelRatio = 1.0;
    view.physicalSize = size;
  }

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  const all = InstructorTab.values;

  Widget dock({
    List<InstructorTab> tabs = all,
    InstructorTab current = InstructorTab.scanner,
    ValueChanged<InstructorTab>? onSelected,
    bool unread = false,
  }) => MaterialApp(
    theme: AppTheme.build(AppPalette.dark),
    home: Scaffold(
      body: const SizedBox.expand(),
      bottomNavigationBar: InstructorDock(
        tabs: tabs,
        current: current,
        onSelected: onSelected ?? (_) {},
        unread: unread,
      ),
    ),
  );

  double x(WidgetTester tester, String tab) =>
      tester.getCenter(find.byKey(ValueKey('nav.$tab'))).dx;

  testWidgets('Scan sits in the middle, two tabs either side', (tester) async {
    phone(const Size(390, 844));
    await tester.pumpWidget(dock());
    await tester.pumpAndSettle();

    expect(x(tester, 'scanner'), closeTo(195, 1));
    expect(x(tester, 'qr'), lessThan(x(tester, 'links')));
    expect(x(tester, 'links'), lessThan(x(tester, 'scanner')));
    expect(x(tester, 'scanner'), lessThan(x(tester, 'tracker')));
    expect(x(tester, 'tracker'), lessThan(x(tester, 'settings')));
    // Standing above the dock, not in line with the tabs.
    expect(
      tester.getCenter(find.byKey(const ValueKey('nav.scanner'))).dy,
      lessThan(tester.getCenter(find.byKey(const ValueKey('nav.qr'))).dy),
    );
  });

  testWidgets('without Links, Scan stays in the middle', (tester) async {
    phone(const Size(390, 844));
    await tester.pumpWidget(
      dock(
        tabs: [
          for (final t in all)
            if (t != InstructorTab.links) t,
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('nav.links')), findsNothing);
    expect(x(tester, 'scanner'), closeTo(195, 1));
    expect(x(tester, 'qr'), lessThan(x(tester, 'scanner')));
  });

  testWidgets('every tab and the button answer a tap', (tester) async {
    phone(const Size(390, 844));
    final tapped = <InstructorTab>[];
    await tester.pumpWidget(
      dock(current: InstructorTab.tracker, onSelected: tapped.add),
    );
    await tester.pumpAndSettle();

    for (final tab in all) {
      await tester.tap(find.byKey(ValueKey('nav.${tab.name}')));
      await tester.pumpAndSettle();
    }
    expect(tapped, all);
  });

  testWidgets('the picked tab reads as selected, in words too', (tester) async {
    phone(const Size(390, 844));
    await tester.pumpWidget(dock(current: InstructorTab.links));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byKey(const ValueKey('nav.links'))),
      containsSemantics(isSelected: true),
    );
    expect(find.byTooltip(NavStrings.links), findsOneWidget);
  });

  testWidgets('a new What\'s New puts the dot on Settings', (tester) async {
    phone(const Size(390, 844));
    await tester.pumpWidget(dock(unread: true));
    await tester.pumpAndSettle();

    expect(find.byTooltip(NavStrings.settingsUnread), findsOneWidget);
    final badge = tester.widget<Badge>(
      find.descendant(
        of: find.byKey(const ValueKey('nav.settings')),
        matching: find.byType(Badge),
      ),
    );
    expect(badge.isLabelVisible, isTrue);
  });

  testWidgets('fits a small phone, every tab picked in turn', (tester) async {
    phone(const Size(320, 640));
    for (final tab in all) {
      await tester.pumpWidget(dock(current: tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab.name);
    }
  });
}
