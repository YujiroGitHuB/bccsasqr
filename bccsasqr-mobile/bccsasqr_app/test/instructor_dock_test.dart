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

  /// The foot padding the page under the bar is given.
  late double pagePadding;

  /// The bar as the shell has it: over the foot of a page that runs on under
  /// it, with a button in the page's own bottom corner.
  Widget dock({
    VoidCallback? onMenu,
    VoidCallback? onPage,
    bool menuOpen = false,
    AppPalette palette = AppPalette.dark,
  }) => MaterialApp(
    theme: AppTheme.build(palette),
    home: Scaffold(
      extendBody: true,
      body: Builder(
        builder: (context) {
          pagePadding = MediaQuery.paddingOf(context).bottom;
          return Align(
            alignment: Alignment.bottomLeft,
            child: TextButton(
              key: const ValueKey('page.corner'),
              onPressed: onPage ?? () {},
              child: const Text('corner'),
            ),
          );
        },
      ),
      bottomNavigationBar: InstructorDock(
        onMenu: onMenu ?? () {},
        menuOpen: menuOpen,
        menu: menuOpen ? kAlwaysCompleteAnimation : kAlwaysDismissedAnimation,
      ),
    ),
  );

  final button = find.byKey(const ValueKey('nav.menu'));

  testWidgets('the Menu button is all there is, in the middle of the foot', (
    tester,
  ) async {
    phone(const Size(390, 844));
    await tester.pumpWidget(dock());
    await tester.pumpAndSettle();

    final rect = tester.getRect(button);
    expect(rect.center.dx, closeTo(195, 1));
    expect(rect.bottom, inInclusiveRange(844 - 30, 844 - 8));
    // The page's foot padding covers the button: a last card scrolled to
    // the end stops above it.
    expect(844 - pagePadding, lessThanOrEqualTo(rect.top));
    // No tabs beside it: every one of them is in the Menu.
    for (final tab in InstructorTab.values) {
      expect(
        find.byKey(ValueKey('nav.${tab.name}')),
        findsNothing,
        reason: tab.name,
      );
    }
    expect(
      find.descendant(
        of: find.byType(InstructorDock),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
    expect(find.byTooltip(NavStrings.menu), findsOneWidget);
  });

  testWidgets('the button opens the Menu, and beside it the page still '
      'answers', (tester) async {
    phone(const Size(390, 844));
    var menus = 0;
    var page = 0;
    await tester.pumpWidget(dock(onMenu: () => menus++, onPage: () => page++));
    await tester.pumpAndSettle();

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(menus, 1);

    // In the strip the bar stands in, but not on the button.
    expect(
      tester.getRect(find.byKey(const ValueKey('page.corner'))).bottom,
      greaterThan(tester.getRect(button).top),
    );
    await tester.tap(find.byKey(const ValueKey('page.corner')));
    await tester.pumpAndSettle();
    expect(page, 1);
    expect(menus, 1);
  });

  testWidgets('open, the button says it closes the Menu', (tester) async {
    phone(const Size(390, 844));
    await tester.pumpWidget(dock(menuOpen: true));
    await tester.pumpAndSettle();

    expect(find.byTooltip(NavStrings.menuClose), findsOneWidget);
    expect(find.byTooltip(NavStrings.menu), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('fits a small phone, open and closed, both themes', (
    tester,
  ) async {
    phone(const Size(320, 640));
    for (final palette in [AppPalette.dark, AppPalette.light]) {
      for (final open in [false, true]) {
        await tester.pumpWidget(dock(menuOpen: open, palette: palette));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$palette $open');
      }
    }
  });
}
