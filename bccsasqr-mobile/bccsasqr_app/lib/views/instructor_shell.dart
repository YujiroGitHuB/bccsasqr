import 'package:flutter/material.dart';

import '../models/whats_new.dart';
import 'menu_shell.dart';

export 'menu_shell.dart' show MenuHandle, MenuDock, menuScrim;

/// The instructor's bar — the one Menu button, shared with the student's
/// side since 2026-10-01 (see [MenuDock]). The name stays for the tests and
/// screens that ask whether the instructor's side is showing.
typedef InstructorDock = MenuDock;

/// The parts of the instructor's side. Every one of them opens from the Menu
/// — the one button at the foot of the screen, see [MenuDock] — and Home's
/// shortcuts open some of them too.
enum InstructorTab {
  home,
  scanner,
  qr,
  links,
  tracker,
  settings;

  /// Where a What's New item about [area] opens.
  static InstructorTab of(WhatsNewArea area) => switch (area) {
    WhatsNewArea.qr => qr,
    WhatsNewArea.scanner => scanner,
    WhatsNewArea.links => links,
    WhatsNewArea.tracker => tracker,
    // My Profile and Check in are the student's, and left out of the
    // instructor's What's New; were one asked for, the nearest tab is the
    // QR code it is about.
    WhatsNewArea.profile || WhatsNewArea.checkIn => qr,
  };
}

/// Builds the Menu's panel.
typedef InstructorMenuBuilder =
    Widget Function(BuildContext context, MenuHandle<InstructorTab> menu);

/// An instructor's phone: a [MenuShell] opening on Home. Everything opens
/// from the Menu: Home, the scanner, QR Code, Links (only for an account
/// allowed to manage them, as on the web), Attendance and Settings.
class InstructorShell extends StatefulWidget {
  const InstructorShell({
    super.key,
    required this.tab,
    required this.homeBuilder,
    required this.generatorBuilder,
    required this.scannerBuilder,
    required this.trackerBuilder,
    required this.settingsBuilder,
    required this.menuBuilder,
    this.linksBuilder,
    this.account,
    this.canManageLinks,
  });

  final ValueNotifier<InstructorTab> tab;
  final WidgetBuilder homeBuilder;
  final WidgetBuilder generatorBuilder;
  final WidgetBuilder scannerBuilder;
  final WidgetBuilder trackerBuilder;
  final WidgetBuilder settingsBuilder;

  /// What the Menu button opens — the way from one tab to another.
  final InstructorMenuBuilder menuBuilder;

  /// The Links tab — there while [canManageLinks] says so, asked again each
  /// time [account] changes: the permission comes back with every refresh of
  /// the scanner's subjects, so unticking it on the web takes the tab away.
  final WidgetBuilder? linksBuilder;
  final Listenable? account;
  final bool Function()? canManageLinks;

  @override
  State<InstructorShell> createState() => _InstructorShellState();
}

class _InstructorShellState extends State<InstructorShell> {
  late bool _linksShown = _canLinks;

  bool get _canLinks =>
      widget.linksBuilder != null && (widget.canManageLinks?.call() ?? false);

  /// The tabs this account has, in order.
  List<InstructorTab> get _tabs => [
    for (final tab in InstructorTab.values)
      if (tab != InstructorTab.links || _linksShown) tab,
  ];

  @override
  void initState() {
    super.initState();
    widget.account?.addListener(_onAccount);
  }

  @override
  void didUpdateWidget(InstructorShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account != widget.account) {
      oldWidget.account?.removeListener(_onAccount);
      widget.account?.addListener(_onAccount);
    }
    _linksShown = _canLinks;
  }

  @override
  void dispose() {
    widget.account?.removeListener(_onAccount);
    super.dispose();
  }

  /// Rebuilds only when the answer changes — the account notifies on every
  /// scan, and the tabs need not hear about those.
  void _onAccount() {
    final show = _canLinks;
    if (show == _linksShown) return;
    setState(() => _linksShown = show);
    // Taken away while open: back Home, rather than Links reappearing on its
    // own later.
    if (!show && widget.tab.value == InstructorTab.links) {
      widget.tab.value = InstructorTab.home;
    }
  }

  WidgetBuilder _builder(InstructorTab tab) => switch (tab) {
    InstructorTab.home => widget.homeBuilder,
    InstructorTab.qr => widget.generatorBuilder,
    InstructorTab.scanner => widget.scannerBuilder,
    InstructorTab.links => widget.linksBuilder!,
    InstructorTab.tracker => widget.trackerBuilder,
    InstructorTab.settings => widget.settingsBuilder,
  };

  @override
  Widget build(BuildContext context) => MenuShell<InstructorTab>(
    tab: widget.tab,
    home: InstructorTab.home,
    tabs: _tabs,
    builder: _builder,
    menuBuilder: widget.menuBuilder,
  );
}
