import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import 'widgets/press_scale.dart';
import 'widgets/splash_parts.dart';

/// What the shell hands the Menu's panel: how far open it is, the tabs this
/// phone has, the one showing, and the ways out of it.
@immutable
class MenuHandle<T> {
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

  /// The tabs this phone has, in order.
  final List<T> tabs;

  /// The tab under the Menu, which it marks: with only the button at the
  /// foot of the screen, the Menu is where the phone says where it is.
  final T current;

  /// Closes the Menu and shows [tab].
  final ValueChanged<T> open;

  /// Closes the Menu, for an item that opens a page, a sheet or a question
  /// over the shell.
  final VoidCallback close;
}

/// Builds the Menu's panel.
typedef MenuBuilder<T> =
    Widget Function(BuildContext context, MenuHandle<T> menu);

/// One part of the app at a time, opening on [home], with the Menu button
/// floating at the foot of the screen — the way GoTyme puts the whole app
/// behind one button. Both sides of the app are one of these: the
/// instructor's (instructor_shell.dart) and the student's
/// (student_shell.dart). Everything opens from the Menu, [home] included.
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
/// The selected tab lives in [tab], so a page pushed over the shell — What's
/// New — can open one.
class MenuShell<T> extends StatefulWidget {
  const MenuShell({
    super.key,
    required this.tab,
    required this.home,
    required this.tabs,
    required this.builder,
    required this.menuBuilder,
  });

  final ValueNotifier<T> tab;

  /// Where the shell opens, where Back goes first, and what shows when the
  /// tab asked for is not one this phone has.
  final T home;

  /// The tabs this phone has, in order. May change from one build to the
  /// next — a permission taken away — and each tab keeps its state while the
  /// others come and go.
  final List<T> tabs;

  /// Builds [tab]'s page.
  final WidgetBuilder Function(T tab) builder;

  /// What the Menu button opens — the way from one tab to another.
  final MenuBuilder<T> menuBuilder;

  @override
  State<MenuShell<T>> createState() => _MenuShellState<T>();
}

class _MenuShellState<T> extends State<MenuShell<T>>
    with SingleTickerProviderStateMixin {
  final Set<T> _built = {};

  /// The Menu's panel, opening and closing. Made in initState, not lazily: a
  /// session that never opens the Menu would first make it in dispose.
  late final AnimationController _menu;

  /// Asked for open — ahead of [_menu], which is still on its way.
  bool _menuOpen = false;

  /// The selected tab — [MenuShell.home], when the one asked for is not
  /// there (What's New opening Links for an account without it).
  T get _current {
    final tab = widget.tab.value;
    return widget.tabs.contains(tab) ? tab : widget.home;
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
  }

  @override
  void didUpdateWidget(MenuShell<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab != widget.tab) {
      oldWidget.tab.removeListener(_onTab);
      widget.tab.addListener(_onTab);
    }
  }

  @override
  void dispose() {
    widget.tab.removeListener(_onTab);
    _menu.dispose();
    super.dispose();
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
  void _select(T tab) {
    _setMenu(false);
    widget.tab.value = tab;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.tabs;
    final current = _current;
    _built.add(current);
    final menuUp = _menuOpen || !_menu.isDismissed;

    // Back closes the Menu first, then goes Home from any other tab, then out.
    return PopScope(
      canPop: !_menuOpen && current == widget.home,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_menuOpen) {
          _setMenu(false);
        } else {
          widget.tab.value = widget.home;
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
                // Keyed, so a tab keeps its state when another comes or goes
                // beside it.
                for (final tab in tabs)
                  TickerMode(
                    key: ValueKey(tab),
                    enabled: tab == current,
                    child: _built.contains(tab)
                        ? Builder(builder: widget.builder(tab))
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
                        MenuHandle<T>(
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
        bottomNavigationBar: MenuDock(
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

/// The bar, which is only the Menu button: round, in the brand gradient,
/// floating in the middle of the foot of the screen over the page — the way
/// GoTyme's sits. Everything is behind it, Home included.
///
/// Picked on 2026-10-01, after the instructor's dock with Home and Scanner on
/// the left of this button and Attendance and Settings on its right: three of
/// those four were in the Menu as well, so the bar said the same things
/// twice. Every movement on it plays once per tap and settles: the turn of
/// its four squares into a cross, and the give under the finger.
///
/// Only the button takes a tap. Beside it, the page underneath answers as
/// if the bar were not there.
class MenuDock extends StatelessWidget {
  const MenuDock({
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
    const size = MenuDock._orb;
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

/// One part of the app in the Menu: an icon on a tile, its name under it —
/// the instructor's Menu and the student's both lay theirs out in rows of
/// four.
class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.name,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tooltip,
    this.dot = false,
    this.selected = false,
  });

  /// `menu.<name>`, for tests.
  final String name;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Said instead of [label] when there is more to say — What's New unread.
  final String? tooltip;

  /// Something new behind it.
  final bool dot;

  /// The tab under the Menu: washed in the accent, its name too.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      selected: selected,
      child: Tooltip(
        message: tooltip ?? label,
        child: PressScale(
          scale: 0.92,
          child: InkWell(
            key: ValueKey('menu.$name'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 54,
                    width: 54,
                    decoration: BoxDecoration(
                      color: selected
                          ? colors.accentWash(0.16)
                          : colors.surfaceSunken,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: selected
                            ? colors.accentWash(0.55)
                            : colors.border,
                      ),
                    ),
                    child: Center(
                      child: Badge(
                        isLabelVisible: dot,
                        smallSize: 9,
                        backgroundColor: colors.accent,
                        child: Icon(icon, size: 24, color: colors.accent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      height: 1.25,
                      color: selected ? colors.accent : colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One group of the Menu: its name, and the parts under it — the widest
/// first, when it has one.
@immutable
class MenuGroup {
  const MenuGroup({
    required this.name,
    required this.label,
    this.lead,
    this.tiles = const [],
  });

  /// `menu.group.<name>`, for tests.
  final String name;

  /// What the parts under it are for, in capitals: `IN CLASS`, `GENERAL`.
  final String label;

  final Widget? lead;
  final List<Widget> tiles;
}

/// The inside of the Menu, top to bottom: [heading], each of [groups] under
/// its name, then [account] under [MenuStrings.account].
///
/// Grouped since 2026-10-01: until then every part sat in one grid — the
/// day's scans beside the tour beside Settings — with nothing to say which
/// belonged with which. The web's sidebar names its groups the same way
/// (ATTENDANCE, QR TOOLS, ACCOUNT).
///
/// Each piece rises in a little after the one above it, along [shown] — the
/// timeline that opens and closes the panel — so nothing on it moves once
/// the panel is still.
class MenuBody extends StatelessWidget {
  const MenuBody({
    super.key,
    required this.shown,
    required this.heading,
    required this.groups,
    this.account,
  });

  final Animation<double> shown;
  final Widget heading;
  final List<MenuGroup> groups;

  /// Whose phone this is, and the way out of it.
  final Widget? account;

  /// Where the first piece starts on the panel's timeline, how far behind
  /// the one above it each next one starts, and how long each takes to land.
  static const double _first = 0.20;
  static const double _step = 0.03;
  static const double _span = 0.42;

  /// [child] rising in as piece number [order] from the top, at [t] of the
  /// panel's timeline.
  static Widget _rise(double t, int order, Widget child) {
    final begin = math.min(_first + _step * order, 0.9);
    return splashRise(
      Interval(
        begin,
        math.min(begin + _span, 1),
        curve: Curves.easeOutCubic,
      ).transform(t),
      child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shown,
      builder: (context, _) {
        final t = shown.value;
        // Counted as the pieces are laid out, top to bottom. A grid's tiles
        // are counted here too, before the grid builds them.
        var order = 0;
        Widget rise(Widget child) => _rise(t, order++, child);

        final children = <Widget>[rise(heading)];
        for (final group in groups) {
          final parts = <Widget>[
            rise(MenuSectionLabel(label: group.label)),
            const SizedBox(height: 10),
          ];
          if (group.lead case final lead?) {
            parts.add(rise(lead));
            if (group.tiles.isNotEmpty) parts.add(const SizedBox(height: 12));
          }
          if (group.tiles.isNotEmpty) {
            final first = order;
            order += group.tiles.length;
            parts.add(
              MenuTileGrid(
                tiles: group.tiles,
                rise: (i, tile) => _rise(t, first + i, tile),
              ),
            );
          }
          children.addAll([
            const SizedBox(height: 18),
            KeyedSubtree(
              key: ValueKey('menu.group.${group.name}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: parts,
              ),
            ),
          ]);
        }
        if (account case final account?) {
          children.addAll([
            const SizedBox(height: 18),
            rise(const MenuSectionLabel(label: MenuStrings.account)),
            const SizedBox(height: 10),
            rise(account),
          ]);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }
}

/// A group's name in the Menu, with a hairline running on to the edge.
class MenuSectionLabel extends StatelessWidget {
  const MenuSectionLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      header: true,
      child: LayoutBuilder(
        // However large the text, the name is cut short before it can push
        // the line off the edge.
        builder: (context, box) => Row(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth * 0.75),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Container(height: 1, color: colors.border)),
          ],
        ),
      ),
    );
  }
}

/// [tiles] in rows of four, each rising along [rise] a little after the one
/// before it.
class MenuTileGrid extends StatelessWidget {
  const MenuTileGrid({super.key, required this.tiles, required this.rise});

  final List<Widget> tiles;

  /// Wraps tile `i` in its entrance, timed by the caller's panel.
  final Widget Function(int i, Widget tile) rise;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var row = 0; row * 4 < tiles.length; row++) ...[
          if (row > 0) const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = row * 4; i < row * 4 + 4; i++)
                Expanded(
                  child: i < tiles.length
                      ? rise(i, tiles[i])
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The Menu's frame: a raised panel with a soft shadow, its own scroll on a
/// short phone.
class MenuPanelCard extends StatelessWidget {
  const MenuPanelCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            // A shadow reads on both grounds only as black.
            color: const Color(
              0xFF000000,
            ).withValues(alpha: colors.isDark ? 0.55 : 0.16),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
          child: child,
        ),
      ),
    );
  }
}

/// "Menu", what it holds, and whose side this is — the pill at the right.
class MenuHeading extends StatelessWidget {
  const MenuHeading({super.key, required this.role});

  /// `INSTRUCTOR`, `ADMIN`, `STUDENT`.
  final String role;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                MenuStrings.title,
                key: const ValueKey('menu.title'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                MenuStrings.subtitle,
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: colors.accentWash(0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.accentWash(0.30)),
          ),
          child: Text(
            role.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: colors.accent,
            ),
          ),
        ),
      ],
    );
  }
}

/// The widest thing in the Menu, first, at the head of IN CLASS: what the app
/// is opened for — the instructor's scanner, the student's QR code.
class MenuLeadCard extends StatelessWidget {
  const MenuLeadCard({
    super.key,
    required this.name,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.selected = false,
  });

  /// `menu.<name>`, for tests.
  final String name;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// It is the tab under the Menu.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(18);

    return Semantics(
      selected: selected,
      child: PressScale(
        child: Material(
          color: colors.surfaceSunken,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: selected ? colors.accentWash(0.55) : colors.border,
            ),
          ),
          child: InkWell(
            key: ValueKey('menu.$name'),
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
              child: Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, size: 23, color: colors.onAccent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded, color: colors.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Whose phone this is, at the foot of the Menu under its ACCOUNT label, and
/// the way out of it — [action] asks first, as the same button elsewhere
/// does.
class MenuAccountRow extends StatelessWidget {
  const MenuAccountRow({
    super.key,
    required this.avatar,
    required this.name,
    required this.subtitle,
    required this.action,
  });

  final Widget avatar;
  final String name;
  final String subtitle;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        avatar,
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        action,
      ],
    );
  }
}
