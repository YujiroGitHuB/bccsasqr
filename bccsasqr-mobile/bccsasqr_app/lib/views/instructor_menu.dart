import 'package:flutter/material.dart';

import '../controllers/scanner_controller.dart';
import '../controllers/whats_new_controller.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import 'instructor_shell.dart';
import 'scanner/widgets/attendance_sheet.dart';
import 'scanner/widgets/scanner_header.dart';
import 'scanner/widgets/sign_out_dialog.dart';
import 'widgets/press_scale.dart';
import 'widgets/splash_parts.dart';

/// What the Menu button at the foot of the screen opens: every part of the
/// instructor's side, one tap each — the scanner first and largest, then a
/// tile for everything else, Home first, and who is signed in with the way
/// out at the foot. The part showing under it is marked, as a tab on a bar
/// would be. GoTyme's one-button menu, in the app's own colours.
///
/// Its pieces rise in one after another along [MenuHandle.shown] — the same
/// timeline that opens and closes the panel — so nothing on it moves once
/// the panel is still.
class InstructorMenu extends StatelessWidget {
  const InstructorMenu({
    super.key,
    required this.menu,
    required this.session,
    this.whatsNewBuilder,
    this.whatsNew,
    this.tourBuilder,
  });

  final MenuHandle menu;

  /// Who is signed in, the subject being scanned, the scans not yet sent,
  /// and the sign-out.
  final ScannerController session;

  /// What's New, with a dot on its tile while [whatsNew] says this phone has
  /// not opened the newest release.
  final WidgetBuilder? whatsNewBuilder;
  final WhatsNewController? whatsNew;

  /// The first launch's introduction.
  final WidgetBuilder? tourBuilder;

  /// Closes the Menu, then opens [builder] over the shell.
  void _page(BuildContext context, WidgetBuilder builder) {
    menu.close();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
  }

  /// Today's whole list, every subject.
  void _today(BuildContext context) {
    menu.close();
    session.setAttendanceSubject(null);
    showAttendanceSheet(context, session);
  }

  /// The same question as Settings → Account → Sign out.
  Future<void> _signOut(BuildContext context) async {
    menu.close();
    if (await confirmSignOut(context, pending: session.pendingCount)) {
      await session.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final news = whatsNewBuilder;
    final tour = tourBuilder;

    return ListenableBuilder(
      listenable: Listenable.merge([session, whatsNew ?? const _Silent()]),
      builder: (context, _) {
        final user = session.user;
        final selected = session.selectedSubject;
        final unread = whatsNew?.unread ?? false;

        /// A tile that shows a tab, marked while it is the one showing.
        _Tile tab(InstructorTab tab, IconData icon, String label) => _Tile(
          name: tab.name,
          icon: icon,
          label: label,
          selected: tab == menu.current,
          onTap: () => menu.open(tab),
        );

        final tiles = [
          tab(InstructorTab.home, Icons.home_rounded, NavStrings.home),
          tab(InstructorTab.qr, Icons.qr_code_2_rounded, NavStrings.qr),
          if (menu.tabs.contains(InstructorTab.links))
            tab(InstructorTab.links, Icons.link_rounded, NavStrings.links),
          tab(
            InstructorTab.tracker,
            Icons.event_available_rounded,
            NavStrings.tracker,
          ),
          _Tile(
            name: 'today',
            icon: Icons.format_list_bulleted_rounded,
            label: InstructorHomeStrings.todayList,
            onTap: () => _today(context),
          ),
          if (news != null)
            _Tile(
              name: 'whatsNew',
              icon: Icons.auto_awesome_outlined,
              label: SettingsStrings.whatsNew,
              tooltip: unread ? WhatsNewStrings.openUnread : null,
              dot: unread,
              onTap: () => _page(context, news),
            ),
          tab(
            InstructorTab.settings,
            Icons.settings_outlined,
            NavStrings.settings,
          ),
          if (tour != null)
            _Tile(
              name: 'tour',
              icon: Icons.slideshow_outlined,
              label: SettingsStrings.tour,
              onTap: () => _page(context, tour),
            ),
        ];

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
              child: AnimatedBuilder(
                animation: menu.shown,
                builder: (context, _) {
                  final t = menu.shown.value;
                  Widget rise(double begin, double end, Widget child) =>
                      splashRise(
                        Interval(
                          begin,
                          end,
                          curve: Curves.easeOutCubic,
                        ).transform(t),
                        child,
                      );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      rise(0.20, 0.62, _Heading(admin: user?.isAdmin ?? false)),
                      const SizedBox(height: 16),
                      rise(
                        0.26,
                        0.68,
                        _ScanCard(
                          subject: selected?.label,
                          selected: menu.current == InstructorTab.scanner,
                          onTap: () => menu.open(InstructorTab.scanner),
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (var row = 0; row * 4 < tiles.length; row++) ...[
                        if (row > 0) const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = row * 4; i < row * 4 + 4; i++)
                              Expanded(
                                child: i < tiles.length
                                    ? rise(
                                        0.32 + 0.04 * i,
                                        (0.70 + 0.04 * i).clamp(0.0, 1.0),
                                        tiles[i],
                                      )
                                    : const SizedBox.shrink(),
                              ),
                          ],
                        ),
                      ],
                      if (user != null) ...[
                        const SizedBox(height: 16),
                        rise(
                          0.56,
                          1.00,
                          _Account(
                            name: user.name,
                            avatar: UserAvatar(user: user, size: 36),
                            onSignOut: () => _signOut(context),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "Menu", what it holds, and whose side this is.
class _Heading extends StatelessWidget {
  const _Heading({required this.admin});

  final bool admin;

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
            (admin ? ScannerStrings.roleAdmin : ScannerStrings.roleInstructor)
                .toUpperCase(),
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

/// The scanner, first and widest: what the app is opened for, with the
/// subject the next scan goes to.
class _ScanCard extends StatelessWidget {
  const _ScanCard({
    required this.subject,
    required this.selected,
    required this.onTap,
  });

  /// "Object Oriented Programming (ITE211)", or null before one is picked.
  final String? subject;

  /// The scanner is the tab under the Menu.
  final bool selected;
  final VoidCallback onTap;

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
            key: const ValueKey('menu.scanner'),
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
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 23,
                      color: colors.onAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          MenuStrings.scan,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subject ?? InstructorHomeStrings.pickSubject,
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

/// One part of the instructor's side: an icon on a tile, its name under it.
class _Tile extends StatelessWidget {
  const _Tile({
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

/// Who is signed in on this phone, and the sign-out — which asks first, as
/// the one in Settings does.
class _Account extends StatelessWidget {
  const _Account({
    required this.name,
    required this.avatar,
    required this.onSignOut,
  });

  final String name;
  final Widget avatar;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
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
                  MenuStrings.signedIn,
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            key: const ValueKey('menu.signOut'),
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded, size: 17),
            label: const Text(ScannerStrings.signOut),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              foregroundColor: colors.danger,
              side: BorderSide(color: colors.danger.withValues(alpha: 0.4)),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A [Listenable] that never fires — for a Menu with no What's New.
class _Silent implements Listenable {
  const _Silent();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
