import 'package:flutter/material.dart';

import '../controllers/whats_new_controller.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../models/whats_new.dart';
import 'widgets/press_scale.dart';

/// The instructor's tabs. On the bar the scanner sits in the middle, with the
/// others either side of it — see [InstructorDock].
enum InstructorTab {
  qr,
  scanner,
  links,
  tracker,
  settings;

  /// Where a What's New item about [area] opens.
  static InstructorTab of(WhatsNewArea area) => switch (area) {
    WhatsNewArea.qr => qr,
    WhatsNewArea.scanner => scanner,
    WhatsNewArea.links => links,
    WhatsNewArea.tracker => tracker,
    // My Profile is the student's, and left out of the instructor's What's
    // New; were it asked for, the nearest tab is the QR code it is about.
    WhatsNewArea.profile => qr,
  };
}

/// An instructor's phone: My QR Code, the scanner, the attendance links, My
/// Attendance and Settings on a bottom bar, opening on the scanner. Links is
/// there only for an account allowed to manage them, as on the web.
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
    this.linksBuilder,
    this.account,
    this.canManageLinks,
    this.whatsNew,
  });

  final ValueNotifier<InstructorTab> tab;
  final WidgetBuilder generatorBuilder;
  final WidgetBuilder scannerBuilder;
  final WidgetBuilder trackerBuilder;
  final WidgetBuilder settingsBuilder;

  /// The Links tab — shown while [canManageLinks] says so, asked again each
  /// time [account] changes: the permission comes back with every refresh of
  /// the scanner's subjects, so unticking it on the web takes the tab away.
  final WidgetBuilder? linksBuilder;
  final Listenable? account;
  final bool Function()? canManageLinks;

  /// Puts a dot on Settings while this phone has not opened the newest
  /// What's New — the student's home screen card, in the bar.
  final WhatsNewController? whatsNew;

  @override
  State<InstructorShell> createState() => _InstructorShellState();
}

class _InstructorShellState extends State<InstructorShell> {
  final Set<InstructorTab> _built = {};
  late bool _linksShown = _canLinks;

  bool get _canLinks =>
      widget.linksBuilder != null && (widget.canManageLinks?.call() ?? false);

  /// The tabs on the bar, left to right.
  List<InstructorTab> get _tabs => [
    for (final tab in InstructorTab.values)
      if (tab != InstructorTab.links || _linksShown) tab,
  ];

  /// The selected tab — the scanner, when the one asked for is not on the
  /// bar (What's New opening Links for an account without it).
  InstructorTab get _current {
    final tab = widget.tab.value;
    return _tabs.contains(tab) ? tab : InstructorTab.scanner;
  }

  @override
  void initState() {
    super.initState();
    widget.tab.addListener(_onTab);
    widget.account?.addListener(_onAccount);
  }

  @override
  void didUpdateWidget(InstructorShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab != widget.tab) {
      oldWidget.tab.removeListener(_onTab);
      widget.tab.addListener(_onTab);
    }
    if (oldWidget.account != widget.account) {
      oldWidget.account?.removeListener(_onAccount);
      widget.account?.addListener(_onAccount);
    }
    _linksShown = _canLinks;
  }

  @override
  void dispose() {
    widget.tab.removeListener(_onTab);
    widget.account?.removeListener(_onAccount);
    super.dispose();
  }

  /// Rebuilds only when the answer changes — the account notifies on every
  /// scan, and the tabs need not hear about those.
  void _onAccount() {
    final show = _canLinks;
    if (show == _linksShown) return;
    setState(() => _linksShown = show);
    // Taken away while picked (only What's New can pick it unseen): the
    // scanner, rather than Links reappearing on its own later.
    if (!show && widget.tab.value == InstructorTab.links) {
      widget.tab.value = InstructorTab.scanner;
    }
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
    InstructorTab.links => widget.linksBuilder!,
    InstructorTab.tracker => widget.trackerBuilder,
    InstructorTab.settings => widget.settingsBuilder,
  };

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
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
          index: tabs.indexOf(current),
          children: [
            // Keyed, so a tab keeps its state when Links comes or goes
            // beside it.
            for (final tab in tabs)
              TickerMode(
                key: ValueKey(tab),
                enabled: tab == current,
                child: _built.contains(tab)
                    ? Builder(builder: _builder(tab))
                    : const SizedBox.shrink(),
              ),
          ],
        ),
        bottomNavigationBar: ListenableBuilder(
          listenable: widget.whatsNew ?? const _Silent(),
          builder: (context, _) => InstructorDock(
            tabs: tabs,
            current: current,
            onSelected: (tab) => widget.tab.value = tab,
            unread: widget.whatsNew?.unread ?? false,
          ),
        ),
      ),
    );
  }
}

/// A [Listenable] that never fires — for a bar with no What's New.
class _Silent implements Listenable {
  const _Silent();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// The instructor's bar: the tabs on a rounded dock lifted off the page, and
/// the scanner — what the app is opened for — as the round brand button in
/// the middle, standing above the dock, the way GCash puts Scan QR. A pill
/// slides to the tab picked, and slides out of the button when the scanner
/// is left.
///
/// Picked on 2026-09-30 over the stock Material bar. Every movement on it
/// plays once per tap and settles: the pill's spring, the icon's pop, the
/// button's glow, and the give under the finger.
class InstructorDock extends StatelessWidget {
  const InstructorDock({
    super.key,
    required this.tabs,
    required this.current,
    required this.onSelected,
    this.unread = false,
  });

  /// The tabs this account has. Links, when present, sits beside QR Code.
  final List<InstructorTab> tabs;
  final InstructorTab current;
  final ValueChanged<InstructorTab> onSelected;

  /// What's New not opened yet: a dot on Settings.
  final bool unread;

  static const double _height = 66;
  static const double _orb = 62;

  /// How far the button stands above the dock.
  static const double _rise = 26;

  /// The middle of the dock, under the button.
  static const double _gap = 80;

  /// Where the icons' pill sits, from the top of the dock; the labels all
  /// share the line under it.
  static const double _pillTop = 9;
  static const double _pillHeight = 30;

  static const List<InstructorTab> _left = [
    InstructorTab.qr,
    InstructorTab.links,
  ];
  static const List<InstructorTab> _right = [
    InstructorTab.tracker,
    InstructorTab.settings,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Duration ms(int n) => still ? Duration.zero : Duration(milliseconds: n);

    final left = [
      for (final t in _left)
        if (tabs.contains(t)) t,
    ];
    final right = [
      for (final t in _right)
        if (tabs.contains(t)) t,
    ];
    final onScanner = current == InstructorTab.scanner;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: _rise + _height + 10,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              height: _height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      // A shadow reads on both grounds only as black.
                      color: const Color(
                        0xFF000000,
                      ).withValues(alpha: colors.isDark ? 0.45 : 0.10),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: colors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final half = (box.maxWidth - _gap) / 2;
                      double centreOf(InstructorTab tab) {
                        final l = left.indexOf(tab);
                        if (l >= 0) return half / left.length * (l + 0.5);
                        final r = right.indexOf(tab);
                        return half + _gap + half / right.length * (r + 0.5);
                      }

                      final x = onScanner
                          ? box.maxWidth / 2
                          : centreOf(current);
                      return Stack(
                        children: [
                          AnimatedPositioned(
                            duration: ms(420),
                            curve: Curves.easeOutBack,
                            left: x - 28,
                            top: _pillTop,
                            width: 56,
                            height: _pillHeight,
                            child: AnimatedOpacity(
                              duration: ms(200),
                              opacity: onScanner ? 0 : 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: colors.accentWash(0.16),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              _side(context, left, half, ms),
                              SizedBox(
                                width: _gap,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    top: _pillTop + _pillHeight + 3,
                                  ),
                                  child: _Label(
                                    NavStrings.scanner,
                                    on: onScanner,
                                  ),
                                ),
                              ),
                              _side(context, right, half, ms),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: _ScanButton(
                  on: onScanner,
                  onPressed: () => onSelected(InstructorTab.scanner),
                  ms: ms,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _side(
    BuildContext context,
    List<InstructorTab> side,
    double width,
    Duration Function(int) ms,
  ) => SizedBox(
    width: width,
    child: Row(
      children: [
        for (final tab in side)
          Expanded(
            child: _DockTab(
              tab: tab,
              on: tab == current,
              dot: tab == InstructorTab.settings && unread,
              onPressed: () => onSelected(tab),
              ms: ms,
            ),
          ),
      ],
    ),
  );
}

/// One tab beside the button: its icon over its label, filled and in the
/// accent once picked.
class _DockTab extends StatelessWidget {
  const _DockTab({
    required this.tab,
    required this.on,
    required this.dot,
    required this.onPressed,
    required this.ms,
  });

  final InstructorTab tab;
  final bool on;
  final bool dot;
  final VoidCallback onPressed;
  final Duration Function(int) ms;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (IconData icon, IconData picked, String label) = switch (tab) {
      InstructorTab.qr => (
        Icons.qr_code_2_outlined,
        Icons.qr_code_2_rounded,
        NavStrings.qr,
      ),
      InstructorTab.links => (
        Icons.link_outlined,
        Icons.link_rounded,
        NavStrings.links,
      ),
      InstructorTab.tracker => (
        Icons.event_available_outlined,
        Icons.event_available_rounded,
        NavStrings.tracker,
      ),
      InstructorTab.settings => (
        Icons.settings_outlined,
        Icons.settings_rounded,
        NavStrings.settings,
      ),
      // The button in the middle, never a tab beside it.
      InstructorTab.scanner => (
        Icons.qr_code_scanner_outlined,
        Icons.qr_code_scanner_rounded,
        NavStrings.scanner,
      ),
    };

    return Semantics(
      selected: on,
      child: Tooltip(
        message: dot ? NavStrings.settingsUnread : label,
        child: PressScale(
          scale: 0.92,
          child: InkWell(
            key: ValueKey('nav.${tab.name}'),
            onTap: onPressed,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.only(top: InstructorDock._pillTop),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: InstructorDock._pillHeight,
                    child: Center(
                      child: AnimatedScale(
                        duration: ms(300),
                        curve: Curves.easeOutBack,
                        scale: on ? 1.08 : 1,
                        child: Badge(
                          isLabelVisible: dot,
                          smallSize: 8,
                          backgroundColor: colors.accent,
                          child: Icon(
                            on ? picked : icon,
                            size: 23,
                            color: on ? colors.accent : colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  _Label(label, on: on),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tab's name under its icon — the same line for every tab and the button.
class _Label extends StatelessWidget {
  const _Label(this.text, {required this.on});

  final String text;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
      style: Theme.of(context).textTheme.labelSmall!.copyWith(
        fontSize: 11,
        fontWeight: on ? FontWeight.w800 : FontWeight.w600,
        color: on ? colors.accent : colors.textSecondary,
      ),
    );
  }
}

/// The scanner: a round brand button standing above the dock, ringed in the
/// page's own colour so it seems cut into the dock. Full size and glowing
/// while the scanner is open, a little smaller from any other tab.
class _ScanButton extends StatelessWidget {
  const _ScanButton({
    required this.on,
    required this.onPressed,
    required this.ms,
  });

  final bool on;
  final VoidCallback onPressed;
  final Duration Function(int) ms;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const size = InstructorDock._orb;

    return Semantics(
      selected: on,
      child: Tooltip(
        message: NavStrings.scanner,
        child: PressScale(
          scale: 0.92,
          child: AnimatedScale(
            duration: ms(320),
            curve: Curves.easeOutBack,
            scale: on ? 1 : 0.9,
            child: AnimatedContainer(
              duration: ms(320),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppPalette.brandMark,
                border: Border.all(color: colors.canvas, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: colors.accentWash(on ? 0.45 : 0.22),
                    blurRadius: on ? 20 : 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const ValueKey('nav.scanner'),
                  onTap: onPressed,
                  child: Center(
                    // The brand fill is the same cyan in both themes, so the
                    // ink on it is the dark set's in both.
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 27,
                      color: AppPalette.dark.onAccent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
