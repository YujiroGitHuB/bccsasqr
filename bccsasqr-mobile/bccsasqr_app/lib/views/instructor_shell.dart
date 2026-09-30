import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../models/whats_new.dart';
import 'widgets/press_scale.dart';

/// The instructor's tabs. Home, Scanner, Attendance and Settings sit on the
/// bar, two either side of the Menu button — see [InstructorDock]. QR Code
/// and Links are opened from the Menu and from Home's shortcuts, with the bar
/// still under them.
enum InstructorTab {
  home,
  scanner,
  qr,
  links,
  tracker,
  settings;

  /// On the bar itself, rather than behind the Menu.
  bool get onBar => this != qr && this != links;

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

/// What the bar hands the Menu's panel: how far open it is, the tabs this
/// account has, and the ways out of it.
@immutable
class MenuHandle {
  const MenuHandle({
    required this.shown,
    required this.tabs,
    required this.open,
    required this.close,
  });

  /// 0 closed → 1 open. The panel's pieces arrive along it, so they are still
  /// the moment the panel is.
  final Animation<double> shown;

  /// The tabs this account has — Links only with the permission.
  final List<InstructorTab> tabs;

  /// Closes the Menu and shows [tab].
  final ValueChanged<InstructorTab> open;

  /// Closes the Menu, for an item that opens a page, a sheet or a question
  /// over the bar.
  final VoidCallback close;
}

/// Builds the Menu's panel.
typedef InstructorMenuBuilder =
    Widget Function(BuildContext context, MenuHandle menu);

/// An instructor's phone: Home, the scanner, Attendance and Settings on a
/// bottom bar, opening on Home, with the Menu in the middle of it — the way
/// GoTyme puts its menu between the tabs. QR Code and Links open from the
/// Menu; Links only for an account allowed to manage them, as on the web.
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
    required this.homeBuilder,
    required this.generatorBuilder,
    required this.scannerBuilder,
    required this.trackerBuilder,
    required this.settingsBuilder,
    this.linksBuilder,
    this.menuBuilder,
    this.account,
    this.canManageLinks,
  });

  final ValueNotifier<InstructorTab> tab;
  final WidgetBuilder homeBuilder;
  final WidgetBuilder generatorBuilder;
  final WidgetBuilder scannerBuilder;
  final WidgetBuilder trackerBuilder;
  final WidgetBuilder settingsBuilder;

  /// The Links tab — there while [canManageLinks] says so, asked again each
  /// time [account] changes: the permission comes back with every refresh of
  /// the scanner's subjects, so unticking it on the web takes the tab away.
  final WidgetBuilder? linksBuilder;
  final Listenable? account;
  final bool Function()? canManageLinks;

  /// What the Menu button opens. No button without it.
  final InstructorMenuBuilder? menuBuilder;

  @override
  State<InstructorShell> createState() => _InstructorShellState();
}

class _InstructorShellState extends State<InstructorShell>
    with SingleTickerProviderStateMixin {
  final Set<InstructorTab> _built = {};
  late bool _linksShown = _canLinks;

  /// The Menu's panel, opening and closing. Made in initState, not lazily: a
  /// session that never opens the Menu would first make it in dispose.
  late final AnimationController _menu;

  /// Asked for open — ahead of [_menu], which is still on its way.
  bool _menuOpen = false;

  bool get _canLinks =>
      widget.linksBuilder != null && (widget.canManageLinks?.call() ?? false);

  /// The tabs this account has, in order.
  List<InstructorTab> get _tabs => [
    for (final tab in InstructorTab.values)
      if (tab != InstructorTab.links || _linksShown) tab,
  ];

  /// The selected tab — Home, when the one asked for is not there (What's
  /// New opening Links for an account without it).
  InstructorTab get _current {
    final tab = widget.tab.value;
    return _tabs.contains(tab) ? tab : InstructorTab.home;
  }

  @override
  void initState() {
    super.initState();
    _menu = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 260),
    )..addStatusListener(_onMenuStatus);
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
    _menu.dispose();
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

  void _onTab() {
    // A field left focused on the tab being left would keep the keyboard
    // up over the next one.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {});
  }

  /// Closed all the way: the panel leaves the tree, so nothing on it can be
  /// focused or read out while it is not there.
  void _onMenuStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && mounted) setState(() {});
  }

  void _setMenu(bool open) {
    if (open == _menuOpen) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _menuOpen = open);
    open ? _menu.forward() : _menu.reverse();
  }

  /// A tab picked on the bar or in the Menu: the Menu goes with it.
  void _select(InstructorTab tab) {
    _setMenu(false);
    widget.tab.value = tab;
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
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final current = _current;
    _built.add(current);
    final menu = widget.menuBuilder;
    final menuUp = menu != null && (_menuOpen || !_menu.isDismissed);

    // Back closes the Menu first, then goes Home from any other tab, then out.
    return PopScope(
      canPop: !_menuOpen && current == InstructorTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_menuOpen) {
          _setMenu(false);
        } else {
          widget.tab.value = InstructorTab.home;
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            IndexedStack(
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
            if (menuUp) ...[
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_menuOpen,
                  child: KeyedSubtree(
                    key: const ValueKey('menu.scrim'),
                    child: AnimatedModalBarrier(
                      color: ColorTween(
                        begin: menuScrim(context).withValues(alpha: 0),
                        end: menuScrim(context),
                      ).animate(_menu),
                      dismissible: true,
                      semanticsLabel: NavStrings.menuClose,
                      onDismiss: () => _setMenu(false),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_menuOpen,
                  child: _MenuPanel(
                    shown: _menu,
                    child: Builder(
                      builder: (context) => menu(
                        context,
                        MenuHandle(
                          shown: _menu,
                          tabs: tabs,
                          open: _select,
                          close: () => _setMenu(false),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        bottomNavigationBar: InstructorDock(
          current: current,
          onSelected: _select,
          onMenu: menu == null ? null : () => _setMenu(!_menuOpen),
          menuOpen: _menuOpen,
          menu: _menu,
        ),
      ),
    );
  }
}

/// The dim over the page while the Menu is open. Black, in both themes: a
/// shade reads on a light ground and a dark one only as black.
Color menuScrim(BuildContext context) => const Color(
  0xFF000000,
).withValues(alpha: context.colors.isDark ? 0.62 : 0.40);

/// Where the Menu's panel sits — at the foot of the page, just over the
/// bar, as wide as the bar — and how it arrives: rising a little out of the
/// bar as it fades in, and sinking back into it on the way out.
class _MenuPanel extends StatelessWidget {
  const _MenuPanel({required this.shown, required this.child});

  final Animation<double> shown;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              // The panel scrolls inside itself on a short phone rather than
              // running off the top.
              maxHeight: (box.maxHeight - 22).clamp(0.0, double.infinity),
            ),
            child: AnimatedBuilder(
              animation: shown,
              child: child,
              builder: (context, child) {
                final t = shown.value;
                final lift = Curves.easeOutCubic.transform(t);
                return Opacity(
                  opacity: const Interval(0, 0.6).transform(t),
                  child: Transform.translate(
                    offset: Offset(0, 28 * (1 - lift)),
                    child: Transform.scale(
                      scale: 0.96 + 0.04 * lift,
                      alignment: Alignment.bottomCenter,
                      child: child,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The instructor's bar: Home and Scanner on the left of a rounded dock
/// lifted off the page, Attendance and Settings on its right, and the Menu —
/// everything else — as the round brand button in the middle, standing above
/// the dock. A pill slides to the tab picked; on a tab the Menu opened (QR
/// Code, Links) the Menu's own label lights up instead.
///
/// Picked on 2026-09-30, after the GCash-style bar with Scan in the middle:
/// the phone now opens on Home, and the scanner is a tab beside it. Every
/// movement on it plays once per tap and settles: the pill's spring, the
/// icon's pop, the button's turn, and the give under the finger.
///
/// While the Menu is open the rest of the bar dims with the page, so the
/// dock and its button seem to sit on top of the dim.
class InstructorDock extends StatelessWidget {
  const InstructorDock({
    super.key,
    required this.current,
    required this.onSelected,
    this.onMenu,
    this.menuOpen = false,
    this.menu = kAlwaysDismissedAnimation,
  });

  /// The tab showing. May be one the Menu opened, which has no place on
  /// the bar.
  final InstructorTab current;
  final ValueChanged<InstructorTab> onSelected;

  /// Opens the Menu, or closes it when it is open. No button without it.
  final VoidCallback? onMenu;
  final bool menuOpen;

  /// How far open the Menu is, for the dim.
  final Animation<double> menu;

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
    InstructorTab.home,
    InstructorTab.scanner,
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

    // Where the Menu took the phone, rather than a tab of the bar.
    final behindMenu = !current.onBar;
    final scrim = menuScrim(context);

    return Stack(
      children: [
        // The dim, under the dock: the strip the button stands in and the
        // edges round the dock darken with the page. A tap there closes the
        // Menu, as a tap on the page does.
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !menuOpen,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onMenu,
              child: AnimatedBuilder(
                animation: menu,
                builder: (context, _) => ColoredBox(
                  color: scrim.withValues(alpha: scrim.a * menu.value),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
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
                            final l = _left.indexOf(tab);
                            if (l >= 0) return half / _left.length * (l + 0.5);
                            final r = _right.indexOf(tab);
                            return half +
                                _gap +
                                half / _right.length * (r + 0.5);
                          }

                          final x = behindMenu
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
                                  opacity: behindMenu ? 0 : 1,
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
                                  _side(half, _left, ms),
                                  SizedBox(
                                    width: _gap,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        top: _pillTop + _pillHeight + 3,
                                      ),
                                      child: _Label(
                                        NavStrings.menu,
                                        on: behindMenu || menuOpen,
                                      ),
                                    ),
                                  ),
                                  _side(half, _right, ms),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                if (onMenu case final onMenu?)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _MenuButton(
                        open: menuOpen,
                        lit: behindMenu,
                        onPressed: onMenu,
                        menu: menu,
                        ms: ms,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _side(
    double width,
    List<InstructorTab> side,
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
    required this.onPressed,
    required this.ms,
  });

  final InstructorTab tab;
  final bool on;
  final VoidCallback onPressed;
  final Duration Function(int) ms;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (IconData icon, IconData picked, String label) = switch (tab) {
      InstructorTab.home => (
        Icons.home_outlined,
        Icons.home_rounded,
        NavStrings.home,
      ),
      InstructorTab.scanner => (
        Icons.qr_code_scanner_outlined,
        Icons.qr_code_scanner_rounded,
        NavStrings.scanner,
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
      // Behind the Menu, never on the bar.
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
    };

    return Semantics(
      selected: on,
      child: Tooltip(
        message: label,
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
                        child: Icon(
                          on ? picked : icon,
                          size: 23,
                          color: on ? colors.accent : colors.textSecondary,
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

/// The Menu: a round brand button standing above the dock, ringed in the
/// page's own colour so it seems cut into the dock — dimmed with the page
/// while the Menu is open, so it still does. Its four squares turn into a
/// cross while the Menu is open, and back.
class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.open,
    required this.lit,
    required this.onPressed,
    required this.menu,
    required this.ms,
  });

  final bool open;

  /// On a tab the Menu opened: the button glows as a picked tab would.
  final bool lit;
  final VoidCallback onPressed;
  final Animation<double> menu;
  final Duration Function(int) ms;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scrim = menuScrim(context);
    const size = InstructorDock._orb;
    // The brand fill is the same cyan in both themes, so the ink on it is the
    // dark set's in both.
    final ink = AppPalette.dark.onAccent;

    return Semantics(
      button: true,
      selected: lit,
      child: Tooltip(
        message: open ? NavStrings.menuClose : NavStrings.menu,
        child: PressScale(
          scale: 0.92,
          child: AnimatedBuilder(
            animation: menu,
            builder: (context, child) => DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppPalette.brandMark,
                border: Border.all(
                  color: Color.alphaBlend(
                    scrim.withValues(alpha: scrim.a * menu.value),
                    colors.canvas,
                  ),
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.accentWash(
                      0.28 + 0.2 * menu.value + (lit ? 0.12 : 0),
                    ),
                    blurRadius: 14 + 8 * menu.value,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: child,
            ),
            child: SizedBox.square(
              dimension: size,
              child: Material(
                type: MaterialType.transparency,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const ValueKey('nav.menu'),
                  onTap: onPressed,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedRotation(
                        duration: ms(380),
                        curve: Curves.easeOutBack,
                        turns: open ? 0.25 : 0,
                        child: AnimatedOpacity(
                          duration: ms(200),
                          opacity: open ? 0 : 1,
                          child: Icon(
                            Icons.grid_view_rounded,
                            size: 26,
                            color: ink,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        duration: ms(380),
                        curve: Curves.easeOutBack,
                        turns: open ? 0 : -0.25,
                        child: AnimatedOpacity(
                          duration: ms(200),
                          opacity: open ? 1 : 0,
                          child: Icon(
                            Icons.close_rounded,
                            size: 28,
                            color: ink,
                          ),
                        ),
                      ),
                    ],
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
