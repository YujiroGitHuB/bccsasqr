import 'package:flutter/material.dart';

import '../controllers/whats_new_controller.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../models/whats_new.dart';

/// The instructor's bottom bar, left to right.
enum InstructorTab {
  qr,
  scanner,
  tracker,
  settings;

  /// Where a What's New item about [area] opens.
  static InstructorTab of(WhatsNewArea area) => switch (area) {
    WhatsNewArea.qr => qr,
    WhatsNewArea.scanner => scanner,
    WhatsNewArea.tracker => tracker,
  };
}

/// An instructor's phone: My QR Code, the scanner, My Attendance and
/// Settings on a bottom bar, opening on the scanner.
///
/// Each tab is built the first time it is opened — its opening splash plays
/// then, once — and kept after that, so a subject picked in the scanner is
/// still picked after a look at the tracker. A tab out of sight has its
/// tickers stopped, which is also what switches the scanner's camera off
/// (see CameraPanel).
///
/// The selected tab lives in [tab], so What's New can open one from a page
/// pushed over the bar.
class InstructorShell extends StatefulWidget {
  const InstructorShell({
    super.key,
    required this.tab,
    required this.generatorBuilder,
    required this.scannerBuilder,
    required this.trackerBuilder,
    required this.settingsBuilder,
    this.whatsNew,
  });

  final ValueNotifier<InstructorTab> tab;
  final WidgetBuilder generatorBuilder;
  final WidgetBuilder scannerBuilder;
  final WidgetBuilder trackerBuilder;
  final WidgetBuilder settingsBuilder;

  /// Puts a dot on Settings while this phone has not opened the newest
  /// What's New — the student's home screen card, in the bar.
  final WhatsNewController? whatsNew;

  @override
  State<InstructorShell> createState() => _InstructorShellState();
}

class _InstructorShellState extends State<InstructorShell> {
  final Set<InstructorTab> _built = {};

  InstructorTab get _current => widget.tab.value;

  @override
  void initState() {
    super.initState();
    widget.tab.addListener(_onTab);
  }

  @override
  void didUpdateWidget(InstructorShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab != widget.tab) {
      oldWidget.tab.removeListener(_onTab);
      widget.tab.addListener(_onTab);
    }
  }

  @override
  void dispose() {
    widget.tab.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() {
    // A field left focused on the tab being left would keep the keyboard
    // up over the next one.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {});
  }

  WidgetBuilder _builder(InstructorTab tab) => switch (tab) {
    InstructorTab.qr => widget.generatorBuilder,
    InstructorTab.scanner => widget.scannerBuilder,
    InstructorTab.tracker => widget.trackerBuilder,
    InstructorTab.settings => widget.settingsBuilder,
  };

  @override
  Widget build(BuildContext context) {
    final current = _current;
    _built.add(current);

    // Back from any other tab goes to the scanner first, then out.
    return PopScope(
      canPop: current == InstructorTab.scanner,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.tab.value = InstructorTab.scanner;
      },
      child: Scaffold(
        body: IndexedStack(
          index: current.index,
          children: [
            for (final tab in InstructorTab.values)
              TickerMode(
                enabled: tab == current,
                child: _built.contains(tab)
                    ? Builder(builder: _builder(tab))
                    : const SizedBox.shrink(),
              ),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: context.colors.border)),
          ),
          child: ListenableBuilder(
            listenable: widget.whatsNew ?? const _Silent(),
            builder: (context, _) => _bar(context, current),
          ),
        ),
      ),
    );
  }

  Widget _bar(BuildContext context, InstructorTab current) {
    final unread = widget.whatsNew?.unread ?? false;

    return NavigationBar(
      selectedIndex: current.index,
      onDestinationSelected: (i) => widget.tab.value = InstructorTab.values[i],
      destinations: [
        const NavigationDestination(
          key: ValueKey('nav.qr'),
          icon: Icon(Icons.qr_code_2_outlined),
          selectedIcon: Icon(Icons.qr_code_2_rounded),
          label: NavStrings.qr,
        ),
        const NavigationDestination(
          key: ValueKey('nav.scanner'),
          icon: Icon(Icons.qr_code_scanner_outlined),
          selectedIcon: Icon(Icons.qr_code_scanner_rounded),
          label: NavStrings.scanner,
        ),
        const NavigationDestination(
          key: ValueKey('nav.tracker'),
          icon: Icon(Icons.event_available_outlined),
          selectedIcon: Icon(Icons.event_available_rounded),
          label: NavStrings.tracker,
        ),
        NavigationDestination(
          key: const ValueKey('nav.settings'),
          icon: _dot(unread, const Icon(Icons.settings_outlined)),
          selectedIcon: _dot(unread, const Icon(Icons.settings_rounded)),
          label: NavStrings.settings,
          tooltip: unread ? NavStrings.settingsUnread : NavStrings.settings,
        ),
      ],
    );
  }

  Widget _dot(bool unread, Widget icon) => Badge(
    isLabelVisible: unread,
    smallSize: 9,
    backgroundColor: context.colors.accent,
    child: icon,
  );
}

/// A [Listenable] that never fires — for a bar with no What's New.
class _Silent implements Listenable {
  const _Silent();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
