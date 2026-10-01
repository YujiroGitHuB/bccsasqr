import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/phone_lock_controller.dart';
import '../controllers/settings_controller.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../models/app_role.dart';
import '../models/scanner_models.dart';
import '../services/app_info.dart';
import 'about_dialog.dart';
import 'scanner/widgets/scanner_header.dart';
import 'scanner/widgets/sign_out_dialog.dart';
import 'widgets/island.dart';
import 'widgets/surface_panel.dart';

/// The instructor's account, theme, the scanner's beep / buzz / voice, the
/// role, and what version this is. A pushed page on a student's phone; on an
/// instructor's, a tab the Menu opens.
///
/// Every switch applies the moment it is flipped — there is no Save.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    this.appInfo = AppInfo.load,
    this.whatsNewBuilder,
    this.role,
    this.onSwitchRole,
    this.account,
    this.subjectCount,
    this.lock,
    this.onSignOut,
    this.pendingScans,
    this.tourBuilder,
  });

  /// The instructor signed in on this phone. The Account panel shows only
  /// with one — the only place the app shows who is signed in, since the
  /// scanner's header gave it up for the camera (2026-09-30).
  final ScannerUser? account;

  /// How many subjects the account scans for, on its chips.
  final int Function()? subjectCount;

  /// The phone's fingerprint, face or screen lock in front of the scanner —
  /// in the Account panel — or the student's side, under Privacy. Its
  /// switch shows only on a phone that has one.
  final PhoneLockController? lock;

  /// Signs the scanner out, after asking. The instructor's side goes with
  /// it, back to the sign-in.
  final Future<void> Function()? onSignOut;

  /// How many scans are still kept on the phone, unsent — the sign-out
  /// question says so.
  final int Function()? pendingScans;

  final SettingsController controller;

  /// Who this phone is for. A student's has no scanner, so its beep and
  /// buzz are left out. Null shows everything.
  final AppRole? role;

  /// Asks the first launch's question again. No Role row without it.
  final VoidCallback? onSwitchRole;

  /// The What's New page, under About — the same one as on the home screen.
  final WidgetBuilder? whatsNewBuilder;

  /// The first launch's introduction, under About. No row without it.
  final WidgetBuilder? tourBuilder;

  /// Overridable for tests: the real one asks the installed package.
  final Future<AppInfo> Function() appInfo;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const double _maxContentWidth = 560;

  late final Future<AppInfo> _info = widget.appInfo();

  Future<void> _signOut() async {
    final signOut = widget.onSignOut;
    if (signOut == null) return;
    final pending = widget.pendingScans?.call() ?? 0;
    if (await confirmSignOut(context, pending: pending)) await signOut();
  }

  Future<void> _open(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      Island.show(
        context,
        IslandMessage(title: 'Could not open $url', tone: IslandTone.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final colors = context.colors;
    final download = AppInfo.downloadPageUrl;
    final whatsNew = widget.whatsNewBuilder;
    final tour = widget.tourBuilder;
    final role = widget.role;
    final switchRole = widget.onSwitchRole;
    final scanner = role != AppRole.student;

    return Scaffold(
      // The foot is left to the padding, so the page runs on under the
      // instructor's Menu button, or the phone's own bar, and still ends
      // clear of it.
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            12,
            AppTheme.pagePadding,
            12 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: ListenableBuilder(
                listenable: c,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        // A tab of the instructor's shell has nowhere to go
                        // back to.
                        if (Navigator.of(context).canPop())
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            tooltip: AppStrings.homeBack,
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: colors.textSecondary,
                          )
                        else
                          const SizedBox(height: 48),
                        const SizedBox(width: 4),
                        Text(
                          SettingsStrings.title,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Account ────────────────────────────────────────
                    // First: on an instructor's phone, whose sign-in this
                    // is comes before how it looks.
                    if (widget.account case final account?) ...[
                      _AccountPanel(
                        account: account,
                        subjectCount: widget.subjectCount?.call(),
                        lock: widget.lock,
                        onSignOut: widget.onSignOut == null ? null : _signOut,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Privacy ────────────────────────────────────────
                    // The student's lock, first, where the instructor's
                    // Account panel has theirs. Only on a phone with a
                    // screen lock to ask for.
                    if (role == AppRole.student)
                      if (widget.lock case final lock? when lock.available) ...[
                        SurfacePanel(
                          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const PanelHeading(
                                icon: Icons.lock_outline_rounded,
                                label: StudentLockStrings.section,
                              ),
                              const SizedBox(height: 6),
                              _LockSwitch(
                                lock: lock,
                                body: StudentLockStrings.tileBody,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                    // ── Appearance ─────────────────────────────────────
                    SurfacePanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const PanelHeading(
                            icon: Icons.palette_outlined,
                            label: SettingsStrings.appearance,
                          ),
                          const SizedBox(height: 14),
                          SegmentedButton<ThemeMode>(
                            segments: const [
                              ButtonSegment(
                                value: ThemeMode.system,
                                icon: Icon(Icons.brightness_auto_outlined),
                                label: Text(SettingsStrings.themeSystem),
                              ),
                              ButtonSegment(
                                value: ThemeMode.light,
                                icon: Icon(Icons.light_mode_outlined),
                                label: Text(SettingsStrings.themeLight),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                icon: Icon(Icons.dark_mode_outlined),
                                label: Text(SettingsStrings.themeDark),
                              ),
                            ],
                            selected: {c.themeMode},
                            showSelectedIcon: false,
                            onSelectionChanged: (picked) =>
                                c.setThemeMode(picked.first),
                            style: SegmentedButton.styleFrom(
                              backgroundColor: colors.surfaceSunken,
                              foregroundColor: colors.textSecondary,
                              selectedBackgroundColor: colors.accentWash(0.14),
                              selectedForegroundColor: colors.accent,
                              side: BorderSide(color: colors.border),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            SettingsStrings.themeHint,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Scanner feedback ───────────────────────────────
                    SurfacePanel(
                      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PanelHeading(
                            icon: Icons.tune_rounded,
                            label: scanner
                                ? SettingsStrings.feedback
                                : SettingsStrings.feedbackStudent,
                          ),
                          const SizedBox(height: 6),
                          if (scanner) ...[
                            _SwitchRow(
                              icon: Icons.volume_up_outlined,
                              title: SettingsStrings.sound,
                              body: SettingsStrings.soundBody,
                              value: c.sound,
                              onChanged: c.setSound,
                            ),
                            _SwitchRow(
                              icon: Icons.vibration_rounded,
                              title: SettingsStrings.vibration,
                              body: SettingsStrings.vibrationBody,
                              value: c.vibration,
                              onChanged: c.setVibration,
                            ),
                          ],
                          _SwitchRow(
                            icon: Icons.record_voice_over_outlined,
                            title: SettingsStrings.voice,
                            body: scanner
                                ? SettingsStrings.voiceBody
                                : SettingsStrings.voiceBodyStudent,
                            value: c.voice,
                            onChanged: c.setVoice,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Role ───────────────────────────────────────────
                    if (role != null && switchRole != null) ...[
                      SurfacePanel(
                        padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const PanelHeading(
                              icon: Icons.switch_account_outlined,
                              label: SettingsStrings.role,
                            ),
                            const SizedBox(height: 6),
                            _LinkRow(
                              key: const ValueKey('settings.switchRole'),
                              icon: switch (role) {
                                AppRole.student => Icons.school_outlined,
                                AppRole.instructor => Icons.badge_outlined,
                              },
                              title: switch (role) {
                                AppRole.student => RoleStrings.currentStudent,
                                AppRole.instructor =>
                                  RoleStrings.currentInstructor,
                              },
                              body: RoleStrings.switchBody,
                              external: false,
                              onTap: switchRole,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── About ──────────────────────────────────────────
                    SurfacePanel(
                      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const PanelHeading(
                            icon: Icons.info_outline_rounded,
                            label: SettingsStrings.about,
                          ),
                          const SizedBox(height: 6),
                          FutureBuilder<AppInfo>(
                            future: _info,
                            builder: (context, snapshot) => _InfoRow(
                              key: const ValueKey('settings.version'),
                              icon: Icons.verified_outlined,
                              title: SettingsStrings.version,
                              value: snapshot.data?.label ?? '…',
                              onTap: switch (snapshot.data) {
                                final info? => () => showAboutCard(
                                  context,
                                  info: info,
                                  role: widget.role,
                                  serverHost: AppInfo.serverHost,
                                ),
                                null => null,
                              },
                            ),
                          ),
                          if (whatsNew != null)
                            _LinkRow(
                              key: const ValueKey('settings.whatsNew'),
                              icon: Icons.auto_awesome_outlined,
                              title: SettingsStrings.whatsNew,
                              body: WhatsNewStrings.settingsBody,
                              external: false,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(builder: whatsNew),
                              ),
                            ),
                          if (tour != null)
                            _LinkRow(
                              key: const ValueKey('settings.tour'),
                              icon: Icons.slideshow_outlined,
                              title: SettingsStrings.tour,
                              body: SettingsStrings.tourBody,
                              external: false,
                              onTap: () => Navigator.of(
                                context,
                              ).push(MaterialPageRoute<void>(builder: tour)),
                            ),
                          _InfoRow(
                            icon: Icons.dns_outlined,
                            title: SettingsStrings.server,
                            value:
                                AppInfo.serverHost ??
                                SettingsStrings.serverDemo,
                          ),
                          if (download != null)
                            _LinkRow(
                              icon: Icons.system_update_outlined,
                              title: SettingsStrings.update,
                              body: SettingsStrings.updateBody,
                              onTap: () => _open(download),
                            ),
                          _LinkRow(
                            icon: Icons.code_rounded,
                            title: SettingsStrings.developer,
                            body: AppStrings.footerDeveloperName,
                            onTap: () => _open(AppStrings.developerUrl),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      AppStrings.footerRights,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.5,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon, title and a line of explanation — the shape every row here shares.
class _RowBody extends StatelessWidget {
  const _RowBody({required this.icon, required this.title, this.body});

  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: colors.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              if (body != null) ...[
                const SizedBox(height: 2),
                Text(
                  body!,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _RowBody(icon: icon, title: title, body: body),
              ),
              const SizedBox(width: 8),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;

  /// Opens more about it — the version's About card. With it, the row gets
  /// the ripple and the chevron the link rows have.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 8, 10),
      child: MergeSemantics(
        // spaceBetween, so a short value ("1.1.0") sits against the right
        // edge like a long one does, instead of wherever its half ends.
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _RowBody(icon: icon, title: title),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: context.colors.textMuted,
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: row,
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.external = true,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  /// Leaves the app (the browser) rather than opening a page inside it.
  final bool external;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: _RowBody(icon: icon, title: title, body: body),
              ),
              Icon(
                external
                    ? Icons.open_in_new_rounded
                    : Icons.chevron_right_rounded,
                size: external ? 18 : 22,
                color: context.colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The lock's switch — the scanner's in the Account panel, the student's
/// under Privacy.
class _LockSwitch extends StatelessWidget {
  const _LockSwitch({required this.lock, required this.body});

  final PhoneLockController lock;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: lock,
      builder: (context, _) => _SwitchRow(
        key: const ValueKey('settings.lock'),
        icon: Icons.fingerprint_rounded,
        title: LockStrings.tile,
        body: body,
        value: lock.enabled,
        // Turning it on asks for the phone's lock first, so the finger that
        // opens the app later is the owner's.
        onChanged: (on) {
          if (lock.unlocking) return;
          on ? lock.enable() : lock.disable();
        },
      ),
    );
  }
}

/// Who is signed in on this instructor's phone — name, email, role, subjects
/// and ID — the lock in front of the scanner, and the sign-out.
class _AccountPanel extends StatelessWidget {
  const _AccountPanel({
    required this.account,
    required this.subjectCount,
    required this.lock,
    required this.onSignOut,
  });

  final ScannerUser account;
  final int? subjectCount;
  final PhoneLockController? lock;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final signOut = onSignOut;

    return SurfacePanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHeading(
            icon: Icons.account_circle_outlined,
            label: SettingsStrings.account,
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                UserAvatar(user: account, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      if (account.email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          account.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: UserChips(user: account, subjectCount: subjectCount),
          ),
          const SizedBox(height: 6),
          // Only on a phone with a screen lock to ask for.
          if (lock case final lock? when lock.available)
            _LockSwitch(lock: lock, body: ScannerStrings.lockTileBody),
          if (signOut != null) ...[
            const SizedBox(height: 8),
            MergeSemantics(
              child: InkWell(
                key: const ValueKey('settings.signOut'),
                onTap: signOut,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                  child: Row(
                    children: [
                      Container(
                        height: 36,
                        width: 36,
                        decoration: BoxDecoration(
                          color: colors.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.logout_rounded,
                          size: 19,
                          color: colors.danger,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ScannerStrings.signOut,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: colors.danger,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              SettingsStrings.signOutBody,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
