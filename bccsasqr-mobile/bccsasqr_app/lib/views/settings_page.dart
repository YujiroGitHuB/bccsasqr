import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/settings_controller.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../services/app_info.dart';
import 'widgets/surface_panel.dart';

/// Theme, the scanner's beep / buzz / voice, and what version this is.
///
/// Every switch applies the moment it is flipped — there is no Save.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    this.appInfo = AppInfo.load,
    this.whatsNewBuilder,
  });

  final SettingsController controller;

  /// The What's New page, under About — the same one as on the home screen.
  final WidgetBuilder? whatsNewBuilder;

  /// Overridable for tests: the real one asks the installed package.
  final Future<AppInfo> Function() appInfo;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const double _maxContentWidth = 560;

  late final Future<AppInfo> _info = widget.appInfo();

  Future<void> _open(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final colors = context.colors;
    final download = AppInfo.downloadPageUrl;
    final whatsNew = widget.whatsNewBuilder;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.pagePadding,
            vertical: 12,
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
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          tooltip: AppStrings.homeBack,
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: colors.textSecondary,
                        ),
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
                          const PanelHeading(
                            icon: Icons.tune_rounded,
                            label: SettingsStrings.feedback,
                          ),
                          const SizedBox(height: 6),
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
                          _SwitchRow(
                            icon: Icons.record_voice_over_outlined,
                            title: SettingsStrings.voice,
                            body: SettingsStrings.voiceBody,
                            value: c.voice,
                            onChanged: c.setVoice,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

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
                              icon: Icons.verified_outlined,
                              title: SettingsStrings.version,
                              value: snapshot.data?.label ?? '…',
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
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          ],
        ),
      ),
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
