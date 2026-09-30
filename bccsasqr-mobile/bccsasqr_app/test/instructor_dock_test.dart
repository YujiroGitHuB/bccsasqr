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

  /// The four tabs on the bar, left to right.
  const onBar = [
    InstructorTab.home,
    InstructorTab.scanner,
    InstructorTab.tracker,
    InstructorTab.settings,
  ];

  Widget dock({
    InstructorTab current = InstructorTab.home,
    ValueChanged<InstructorTab>? onSelected,
    VoidCallback? onMenu,
    bool menuOpen = false,
    AppPalette palette = AppPalette.dark,
  }) => MaterialApp(
    theme: AppTheme.build(palette),
    home: Scaffold(
      body: const SizedBox.expand(),
      bottomNavigationBar: InstructorDock(
        current: current,
        onSelected: onSelected ?? (_) {},
        onMenu: onMenu ?? () {},
        menuOpen: menuOpen,
        menu: menuOpen ? kAlwaysCompleteAnimation : kAlwaysDismissedAnimation,
      ),
    ),
  );

  Offset centre(WidgetTester tester, String name) =>
      tester.getCenter(find.byKey(ValueKey('nav.$name')));

  testWidgets('the Menu sits in the middle, two tabs either side', (
    tester,
  ) async {
    phone(const Size(390, 844));
    await tester.pumpWidget(dock());
    await tester.pumpAndSettle();

    expect(centre(tester, 'menu').dx, closeTo(195, 1));
    expect(centre(tester, 'home').dx, lessThan(centre(tester, 'scanner').dx));
    expect(centre(tester, 'scanner').dx, lessThan(centre(tester, 'menu').dx));
    expect(centre(tester, 'menu').dx, lessThan(centre(tester, 'tracker').dx));
    expect(
      centre(tester, 'tracker').dx,
      lessThan(centre(tester, 'settings').dx),
    );
    // Standing above the dock, not in line with the tabs.
    expect(centre(tester, 'menu').dy, lessThan(centre(tester, 'home').dy));
    // QR Code and Links are behind the Menu, not on the bar.
    expect(find.byKey(const ValueKey('nav.qr')), findsNothing);
    expect(find.byKey(const ValueKey('nav.links')), findsNothing);
    for (final label in [
      NavStrings.home,
      NavStrings.scanner,
      NavStrings.menu,
      NavStrings.tracker,
      NavStrings.settings,
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('every tab answers a tap, and the button opens the Menu', (
    tester,
  ) async {
    phone(const Size(390, 844));
    final tapped = <InstructorTab>[];
    var menus = 0;
    await tester.pumpWidget(
      dock(
        current: InstructorTab.tracker,
        onSelected: tapped.add,
        onMenu: () => menus++,
      ),
    );
    await tester.pumpAndSettle();

    for (final tab in onBar) {
      await tester.tap(find.byKey(ValueKey('nav.${tab.name}')));
      await tester.pumpAndSettle();
    }
    expect(tapped, onBar);

    await tester.tap(find.byKey(const ValueKey('nav.menu')));
    await tester.pumpAndSettle();
    expect(menus, 1);
  });

  testWidgets('the picked tab reads as selected, in words too', (tester) async {
    phone(const Size(390, 844));
    await tester.pumpWidget(dock(current: InstructorTab.scanner));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byKey(const ValueKey('nav.scanner'))),
      containsSemantics(isSelected: true),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('nav.home'))),
      isNot(containsSemantics(isSelected: true)),
    );
    expect(find.byTooltip(NavStrings.scanner), findsOneWidget);
    expect(find.byTooltip(NavStrings.menu), findsOneWidget);
  });

  testWidgets('on a tab the Menu opened, the Menu is the one lit', (
    tester,
  ) async {
    phone(const Size(390, 844));
    await tester.pumpWidget(dock(current: InstructorTab.qr));
    await tester.pumpAndSettle();

    for (final tab in onBar) {
      expect(
        tester.getSemantics(find.byKey(ValueKey('nav.${tab.name}'))),
        isNot(containsSemantics(isSelected: true)),
        reason: tab.name,
      );
    }
    final label = tester.widget<Text>(find.text(NavStrings.menu));
    expect(label.style?.fontWeight, FontWeight.w800);
  });

  testWidgets('open, the button says it closes the Menu', (tester) async {
    phone(const Size(390, 844));
    await tester.pumpWidget(dock(menuOpen: true));
    await tester.pumpAndSettle();

    expect(find.byTooltip(NavStrings.menuClose), findsOneWidget);
    expect(find.byTooltip(NavStrings.menu), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('fits a small phone, every tab picked in turn, both themes', (
    tester,
  ) async {
    phone(const Size(320, 640));
    for (final palette in [AppPalette.dark, AppPalette.light]) {
      for (final tab in InstructorTab.values) {
        for (final open in [false, true]) {
          await tester.pumpWidget(
            dock(current: tab, menuOpen: open, palette: palette),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '${tab.name} $open');
        }
      }
    }
  });
}
