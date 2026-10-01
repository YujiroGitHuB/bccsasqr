import 'package:flutter/material.dart';

import '../controllers/scanner_controller.dart';
import '../controllers/whats_new_controller.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import 'instructor_shell.dart';
import 'menu_shell.dart';
import 'scanner/widgets/attendance_sheet.dart';
import 'scanner/widgets/scanner_header.dart';
import 'scanner/widgets/sign_out_dialog.dart';
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

  final MenuHandle<InstructorTab> menu;

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
    final news = whatsNewBuilder;
    final tour = tourBuilder;

    return ListenableBuilder(
      listenable: Listenable.merge([session, whatsNew ?? const _Silent()]),
      builder: (context, _) {
        final user = session.user;
        final selected = session.selectedSubject;
        final unread = whatsNew?.unread ?? false;

        /// A tile that shows a tab, marked while it is the one showing.
        MenuTile tab(InstructorTab tab, IconData icon, String label) =>
            MenuTile(
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
          MenuTile(
            name: 'today',
            icon: Icons.format_list_bulleted_rounded,
            label: InstructorHomeStrings.todayList,
            onTap: () => _today(context),
          ),
          if (news != null)
            MenuTile(
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
            MenuTile(
              name: 'tour',
              icon: Icons.slideshow_outlined,
              label: SettingsStrings.tour,
              onTap: () => _page(context, tour),
            ),
        ];

        return MenuPanelCard(
          child: AnimatedBuilder(
            animation: menu.shown,
            builder: (context, _) {
              final t = menu.shown.value;
              Widget rise(double begin, double end, Widget child) => splashRise(
                Interval(begin, end, curve: Curves.easeOutCubic).transform(t),
                child,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  rise(
                    0.20,
                    0.62,
                    MenuHeading(
                      role: (user?.isAdmin ?? false)
                          ? ScannerStrings.roleAdmin
                          : ScannerStrings.roleInstructor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  rise(
                    0.26,
                    0.68,
                    MenuLeadCard(
                      name: 'scanner',
                      icon: Icons.qr_code_scanner_rounded,
                      title: MenuStrings.scan,
                      subtitle:
                          selected?.label ?? InstructorHomeStrings.pickSubject,
                      selected: menu.current == InstructorTab.scanner,
                      onTap: () => menu.open(InstructorTab.scanner),
                    ),
                  ),
                  const SizedBox(height: 18),
                  MenuTileGrid(
                    tiles: tiles,
                    rise: (i, tile) => rise(
                      0.32 + 0.04 * i,
                      (0.70 + 0.04 * i).clamp(0.0, 1.0),
                      tile,
                    ),
                  ),
                  if (user != null) ...[
                    const SizedBox(height: 16),
                    rise(
                      0.56,
                      1.00,
                      MenuAccountRow(
                        avatar: UserAvatar(user: user, size: 36),
                        name: user.name,
                        subtitle: MenuStrings.signedIn,
                        action: _SignOutButton(
                          onPressed: () => _signOut(context),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// The way out, which asks first — as Settings → Account → Sign out does.
class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return OutlinedButton.icon(
      key: const ValueKey('menu.signOut'),
      onPressed: onPressed,
      icon: const Icon(Icons.logout_rounded, size: 17),
      label: const Text(ScannerStrings.signOut),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        foregroundColor: colors.danger,
        side: BorderSide(color: colors.danger.withValues(alpha: 0.4)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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
