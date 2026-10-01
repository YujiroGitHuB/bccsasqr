import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../models/whats_new.dart';
import 'widgets/press_scale.dart';

/// The parts of the instructor's side. Every one of them opens from the Menu
/// — the one button at the foot of the screen, see [InstructorDock] — and
/// Home's shortcuts open some of them too.
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
    // My Profile is the student's, and left out of the instructor's What's
    // New; were it asked for, the nearest tab is the QR code it is about.
    WhatsNewArea.profile => qr,
  };
}

/// What the shell hands the Menu's panel: how far open it is, the tabs this
/// account has, the one showing, and the ways out of it.
@immutable
class MenuHandle {
  const MenuHandle({
    required this.shown,
    required this.tabs,
    required this.current,
    required this.open,
    required this.close,
  });

  /// 0 closed → 1 open. The panel's pieces arrive along it, so they are still
  /// the moment the panel is.
  final Animation<double> shown;

  /// The tabs this account has — Links only with the permission.
  final List<InstructorTab> tabs;

  /// The tab under the Menu, which it marks: with only the button at the
  /// foot of the screen, the Menu is where the phone says where it is.
  final InstructorTab current;

  /// Closes the Menu and shows [tab].
  final ValueChanged<InstructorTab> open;

  /// Closes the Menu, for an item that opens a page, a sheet or a question
  /// over the shell.
  final VoidCallback close;
}

/// Builds the Menu's panel.
typedef InstructorMenuBuilder =
    Widget Function(BuildContext context, MenuHandle menu);

/// An instructor's phone: one part of the side at a time, opening on Home,
/// with the Menu button floating at the foot of the screen — the way GoTyme
/// puts the whole app behind one button. Everything opens from the Menu:
/// Home, the scanner, QR Code, Links (only for an account allowed to manage
/// them, as on the web), Attendance and Settings.
///
/// The page runs on under the button (`extendBody`): each tab's list
/// scrolls to the foot of the screen and ends just clear of the button,
/// rather than stopping at a strip of empty bar.
///
/// Each tab is built the first time it is opened — its opening splash plays
/// then, once — and kept after that, so a subject picked in the scanner is
/// still picked after a look at the tracker. A tab out of sight has its
/// tickers stopped, which is also what switches the scanner's camera off
/// (see CameraPanel).
///
/// The selected tab lives in [tab], so What's New can open one from a page
/// pushed over the shell.
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

  /// A tab picked in the Menu: the Menu goes with it.
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
    final menuUp = _menuOpen || !_menu.isDismissed;

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
        // Under the button, too: the tabs leave their foot to the padding
        // this gives them, so their lists run on under it.
        extendBody: true,
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
              // The whole screen, the strip round the button included: the
              // page runs under it, so the dim does as well.
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
                      builder: (context) => widget.menuBuilder(
                        context,
                        MenuHandle(
                          shown: _menu,
                          tabs: tabs,
                          current: current,
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
          onMenu: () => _setMenu(!_menuOpen),
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

/// Where the Menu's panel sits — at the foot of the screen, just over the
/// button, no wider than a phone — and how it arrives: rising a little out
/// of the button as it fades in, and sinking back into it on the way out.
class _MenuPanel extends StatelessWidget {
  const _MenuPanel({required this.shown, required this.child});

  final Animation<double> shown;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The page runs on under the button, so the foot of its padding is the
    // button's room, and the top is the status bar's. Held between the two,
    // the panel scrolls inside itself on a short phone rather than running
    // under either.
    final room = MediaQuery.paddingOf(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, room.top + 12, 12, room.bottom + 4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
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
    );
  }
}

/// The instructor's bar, which is only the Menu button: round, in the brand
/// gradient, floating in the middle of the foot of the screen over the page
/// — the way GoTyme's sits. Everything is behind it, Home included.
///
/// Picked on 2026-10-01, after the dock with Home and Scanner on the left of
/// this button and Attendance and Settings on its right: three of those four
/// were in the Menu as well, so the bar said the same things twice. Every
/// movement on it plays once per tap and settles: the turn of its four
/// squares into a cross, and the give under the finger.
///
/// Only the button takes a tap. Beside it, the page underneath answers as
/// if the bar were not there.
class InstructorDock extends StatelessWidget {
  const InstructorDock({
    super.key,
    required this.onMenu,
    this.menuOpen = false,
    this.menu = kAlwaysDismissedAnimation,
  });

  /// Opens the Menu, or closes it when it is open.
  final VoidCallback onMenu;
  final bool menuOpen;

  /// How far open the Menu is, for the button's glow.
  final Animation<double> menu;

  static const double _orb = 62;

  /// The room over the button and under it. All of it, with the button,
  /// is the foot padding the shell gives each tab: a page's last card
  /// scrolls up to just over the button, never under it.
  static const EdgeInsets _room = EdgeInsets.only(top: 8, bottom: 14);

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Duration ms(int n) => still ? Duration.zero : Duration(milliseconds: n);

    return SafeArea(
      top: false,
      child: Padding(
        padding: _room,
        child: Center(
          heightFactor: 1,
          child: _MenuButton(
            open: menuOpen,
            onPressed: onMenu,
            menu: menu,
            ms: ms,
          ),
        ),
      ),
    );
  }
}

/// The Menu: a round brand button, lifted off the page by a shadow under
/// its glow so it reads over whatever card scrolls by. Its four squares
/// turn into a cross while the Menu is open, and back.
class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.open,
    required this.onPressed,
    required this.menu,
    required this.ms,
  });

  final bool open;
  final VoidCallback onPressed;
  final Animation<double> menu;
  final Duration Function(int) ms;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const size = InstructorDock._orb;
    // The brand fill is the same cyan in both themes, so the ink on it is the
    // dark set's in both.
    final ink = AppPalette.dark.onAccent;

    return Semantics(
      button: true,
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
                boxShadow: [
                  BoxShadow(
                    // A shadow reads on both grounds only as black.
                    color: const Color(
                      0xFF000000,
                    ).withValues(alpha: colors.isDark ? 0.40 : 0.14),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: colors.accentWash(0.30 + 0.2 * menu.value),
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
