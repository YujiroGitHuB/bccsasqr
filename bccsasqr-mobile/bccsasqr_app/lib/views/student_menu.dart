import 'package:flutter/material.dart';

import '../controllers/my_qr_controller.dart';
import '../controllers/notifications_controller.dart';
import '../controllers/profile_controller.dart';
import '../controllers/whats_new_controller.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../models/student_profile.dart';
import 'menu_shell.dart';
import 'student_shell.dart';
import 'widgets/profile_avatar.dart';

/// What the Menu button at the foot of the student's screen opens: every
/// part of the side, under what it is for. IN CLASS — the QR code first and
/// widest, and Check in, the two ways to be marked present. MY RECORDS — My
/// QR Code, Attendance and My Profile. GENERAL — Home, Notifications, What's
/// New, Settings and the tour. ACCOUNT — whose phone this is, at the foot. The
/// instructor's Menu, laid out for a student.
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
    this.notificationsBuilder,
    this.notifications,
    this.tourBuilder,
  });

  final MenuHandle<StudentTab> menu;
  final ProfileController profile;
  final MyQrController qr;

  /// Puts the code full screen for the scanner.
  final VoidCallback onShowQr;

  final WidgetBuilder? whatsNewBuilder;
  final WhatsNewController? whatsNew;

  /// Notifications, with a dot while something there is new.
  final WidgetBuilder? notificationsBuilder;
  final NotificationsController? notifications;
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
    final notices = notificationsBuilder;
    final tour = tourBuilder;

    return ListenableBuilder(
      listenable: Listenable.merge([
        profile,
        qr,
        whatsNew ?? const _Silent(),
        notifications ?? const _Silent(),
      ]),
      builder: (context, _) {
        final kept = profile.profile;
        final unread = whatsNew?.unread ?? false;
        final newNotices = notifications?.unread ?? 0;

        MenuTile tab(StudentTab tab, IconData icon, String label) => MenuTile(
          name: tab.name,
          icon: icon,
          label: label,
          selected: tab == menu.current,
          onTap: () => menu.open(tab),
        );

        final number = kept?.record.studentNumber.value;
        final leadBody = switch (qr.status) {
          MyQrStatus.ready => StudentStrings.showQrBody(number ?? ''),
          MyQrStatus.noProfile => StudentStrings.showQrSetUp,
          _ => StudentStrings.showQrMake,
        };

        return MenuPanelCard(
          child: MenuBody(
            shown: menu.shown,
            heading: const MenuHeading(role: StudentStrings.role),
            groups: [
              MenuGroup(
                name: 'inClass',
                label: MenuStrings.inClass,
                lead: MenuLeadCard(
                  name: 'showQr',
                  icon: Icons.qr_code_2_rounded,
                  title: StudentStrings.showQr,
                  subtitle: leadBody,
                  onTap: _lead,
                ),
                tiles: [
                  tab(
                    StudentTab.checkIn,
                    Icons.qr_code_scanner_rounded,
                    StudentStrings.checkIn,
                  ),
                ],
              ),
              MenuGroup(
                name: 'records',
                label: MenuStrings.myRecords,
                tiles: [
                  tab(
                    StudentTab.qr,
                    Icons.qr_code_2_rounded,
                    StudentStrings.myQr,
                  ),
                  tab(
                    StudentTab.tracker,
                    Icons.event_available_rounded,
                    StudentStrings.attendance,
                  ),
                  tab(
                    StudentTab.profile,
                    Icons.account_circle_outlined,
                    StudentStrings.profile,
                  ),
                ],
              ),
              MenuGroup(
                name: 'general',
                label: MenuStrings.general,
                tiles: [
                  tab(StudentTab.home, Icons.home_rounded, NavStrings.home),
                  if (notices != null)
                    MenuTile(
                      name: 'notifications',
                      icon: newNotices == 0
                          ? Icons.notifications_none_rounded
                          : Icons.notifications_active_rounded,
                      label: NoticeStrings.title,
                      tooltip: newNotices == 0
                          ? null
                          : NoticeStrings.openUnread(newNotices),
                      dot: newNotices > 0,
                      onTap: () => _page(context, notices),
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
                ],
              ),
            ],
            account: kept == null
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
                    // The name they are greeted by: the full one, surname
                    // first, is cut off beside the button.
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
