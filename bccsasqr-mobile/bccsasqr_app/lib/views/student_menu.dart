import 'package:flutter/material.dart';

import '../controllers/my_qr_controller.dart';
import '../controllers/profile_controller.dart';
import '../controllers/whats_new_controller.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../models/student_profile.dart';
import 'menu_shell.dart';
import 'student_shell.dart';
import 'widgets/profile_avatar.dart';
import 'widgets/splash_parts.dart';

/// What the Menu button at the foot of the student's screen opens: the QR
/// code first and widest, then a tile for every part of the side, Home
/// first, and whose phone this is at the foot. The instructor's Menu, laid
/// out for a student.
///
/// Its pieces rise in one after another along [MenuHandle.shown] — the same
/// timeline that opens and closes the panel — so nothing on it moves once
/// the panel is still.
class StudentMenu extends StatelessWidget {
  const StudentMenu({
    super.key,
    required this.menu,
    required this.profile,
    required this.qr,
    required this.onShowQr,
    this.whatsNewBuilder,
    this.whatsNew,
    this.tourBuilder,
  });

  final MenuHandle<StudentTab> menu;
  final ProfileController profile;
  final MyQrController qr;

  /// Puts the code full screen for the scanner.
  final VoidCallback onShowQr;

  final WidgetBuilder? whatsNewBuilder;
  final WhatsNewController? whatsNew;
  final WidgetBuilder? tourBuilder;

  /// Closes the Menu, then opens [builder] over the shell.
  void _page(BuildContext context, WidgetBuilder builder) {
    menu.close();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
  }

  /// The big card: the code full screen when there is one, otherwise the
  /// step that gets the student one.
  void _lead() {
    switch (qr.status) {
      case MyQrStatus.ready:
        menu.close();
        onShowQr();
      case MyQrStatus.noProfile:
        menu.open(StudentTab.profile);
      case MyQrStatus.loading ||
          MyQrStatus.needsTerms ||
          MyQrStatus.unavailable:
        menu.open(StudentTab.qr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final news = whatsNewBuilder;
    final tour = tourBuilder;

    return ListenableBuilder(
      listenable: Listenable.merge([profile, qr, whatsNew ?? const _Silent()]),
      builder: (context, _) {
        final kept = profile.profile;
        final unread = whatsNew?.unread ?? false;

        MenuTile tab(StudentTab tab, IconData icon, String label) => MenuTile(
          name: tab.name,
          icon: icon,
          label: label,
          selected: tab == menu.current,
          onTap: () => menu.open(tab),
        );

        final tiles = [
          tab(StudentTab.home, Icons.home_rounded, NavStrings.home),
          tab(StudentTab.qr, Icons.qr_code_2_rounded, StudentStrings.myQr),
          tab(
            StudentTab.tracker,
            Icons.event_available_rounded,
            StudentStrings.attendance,
          ),
          tab(
            StudentTab.checkIn,
            Icons.qr_code_scanner_rounded,
            StudentStrings.checkIn,
          ),
          tab(
            StudentTab.profile,
            Icons.account_circle_outlined,
            StudentStrings.profile,
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
            StudentTab.settings,
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

        final number = kept?.record.studentNumber.value;
        final leadBody = switch (qr.status) {
          MyQrStatus.ready => StudentStrings.showQrBody(number ?? ''),
          MyQrStatus.noProfile => StudentStrings.showQrSetUp,
          _ => StudentStrings.showQrMake,
        };

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
                    const MenuHeading(role: StudentStrings.role),
                  ),
                  const SizedBox(height: 16),
                  rise(
                    0.26,
                    0.68,
                    MenuLeadCard(
                      name: 'showQr',
                      icon: Icons.qr_code_2_rounded,
                      title: StudentStrings.showQr,
                      subtitle: leadBody,
                      onTap: _lead,
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
                  const SizedBox(height: 16),
                  rise(
                    0.56,
                    1.00,
                    kept == null
                        ? MenuAccountRow(
                            avatar: const ProfileAvatar(size: 36),
                            name: StudentStrings.notSetUpName,
                            subtitle: StudentStrings.notSetUpBody,
                            action: _AccountButton(
                              name: 'setUp',
                              icon: Icons.person_add_alt_1_rounded,
                              label: StudentStrings.setUp,
                              onPressed: () => menu.open(StudentTab.profile),
                            ),
                          )
                        : MenuAccountRow(
                            avatar: ProfileAvatar(
                              size: 36,
                              name: kept.record.fullName,
                              photo: kept.photo,
                              photoUrl: kept.photoUrl,
                            ),
                            // The name they are greeted by: the full one,
                            // surname first, is cut off beside the button.
                            name: kept.givenName,
                            subtitle: StudentStrings.onThisPhone(number!),
                            action: _AccountButton(
                              name: 'notYou',
                              icon: Icons.person_remove_alt_1_outlined,
                              label: StudentStrings.notYou,
                              onPressed: () => _forget(context, kept),
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// "Not you?" — asks first, as My Profile's does; the phone forgets the
  /// student, and nothing changes on the school record.
  Future<void> _forget(BuildContext context, StudentProfile kept) async {
    menu.close();
    if (await confirmForget(context, kept)) await profile.forget();
  }
}

/// The question before the phone forgets [kept].
Future<bool> confirmForget(BuildContext context, StudentProfile kept) async {
  final sure = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(StudentStrings.forgetTitle),
      content: Text(StudentStrings.forgetBody(kept.givenName)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(StudentStrings.forgetCancel),
        ),
        TextButton(
          key: const ValueKey('menu.notYou.confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: context.colors.danger),
          child: const Text(StudentStrings.forgetConfirm),
        ),
      ],
    ),
  );
  return sure == true;
}

class _AccountButton extends StatelessWidget {
  const _AccountButton({
    required this.name,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  /// `menu.<name>`, for tests.
  final String name;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return OutlinedButton.icon(
      key: ValueKey('menu.$name'),
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        foregroundColor: colors.textPrimary,
        side: BorderSide(color: colors.borderStrong),
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
