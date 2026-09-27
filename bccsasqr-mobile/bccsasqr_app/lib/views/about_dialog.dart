import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_strings.dart';
import '../core/constants/whats_new_log.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/date_label.dart';
import '../models/app_role.dart';
import '../services/app_info.dart';
import 'widgets/app_header_card.dart';
import 'widgets/splash_parts.dart';

/// Opens the About card over whatever is showing — Settings → Version.
Future<void> showAboutCard(
  BuildContext context, {
  required AppInfo info,
  AppRole? role,
  String? serverHost,
}) => showDialog<void>(
  context: context,
  builder: (context) =>
      AboutCard(info: info, role: role, serverHost: serverHost),
);

/// What this install is: the seal, the version and build, when the bundled
/// What's New was last added to, the server, and whose phone it is set up
/// for — with a button that copies it all, for a message to whoever looks
/// after the system.
///
/// The seal pops in and a glint passes over it as the card opens: the
/// splashes' touch, once.
class AboutCard extends StatefulWidget {
  const AboutCard({super.key, required this.info, this.role, this.serverHost});

  final AppInfo info;
  final AppRole? role;

  /// The server this build talks to; null is demo mode.
  final String? serverHost;

  @override
  State<AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<AboutCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  late final Animation<double> _seal = CurvedAnimation(
    parent: _open,
    curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
  );
  late final Animation<double> _shine = CurvedAnimation(
    parent: _open,
    curve: const Interval(0.45, 0.95, curve: Curves.easeInOut),
  );

  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    _open.dispose();
    super.dispose();
  }

  String? get _roleLabel => switch (widget.role) {
    AppRole.student => RoleStrings.currentStudent,
    AppRole.instructor => RoleStrings.currentInstructor,
    null => null,
  };

  String get _updated => DateLabel.date(WhatsNewLog.releases.first.date);

  String get _server => widget.serverHost ?? AboutStrings.demo;

  Future<void> _copy() async {
    final role = _roleLabel;
    await Clipboard.setData(
      ClipboardData(
        text: [
          '${AppStrings.appName} ${widget.info.label}',
          '${AboutStrings.updated}: $_updated',
          '${AboutStrings.server}: $_server',
          if (role != null) '${AboutStrings.role}: $role',
        ].join('\n'),
      ),
    );
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final info = widget.info;
    final role = _roleLabel;

    return Dialog(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Semantics(
          label: AboutStrings.semantics,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: AnimatedBuilder(
                    animation: _open,
                    builder: (context, _) =>
                        _Seal(shown: _seal.value, shine: _shine.value),
                  ),
                ),
                const SizedBox(height: 16),
                Text.rich(
                  TextSpan(
                    text: AppStrings.splashBrand,
                    children: [
                      TextSpan(
                        text: AppStrings.splashBrandAccent,
                        style: TextStyle(color: colors.accent),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.splashFooter,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                ),
                const SizedBox(height: 16),
                Center(child: _VersionPill(info: info)),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceSunken,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    children: [
                      _Fact(
                        icon: Icons.auto_awesome_outlined,
                        label: AboutStrings.updated,
                        value: _updated,
                      ),
                      _Fact(
                        icon: Icons.dns_outlined,
                        label: AboutStrings.server,
                        value: _server,
                        divided: role != null,
                      ),
                      if (role != null)
                        _Fact(
                          icon: widget.role == AppRole.student
                              ? Icons.school_outlined
                              : Icons.badge_outlined,
                          label: AboutStrings.role,
                          value: role,
                          divided: false,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('about.copy'),
                        onPressed: _copy,
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            _copied ? Icons.check_rounded : Icons.copy_rounded,
                            key: ValueKey(_copied),
                            size: 18,
                            color: _copied ? colors.success : null,
                          ),
                        ),
                        label: Text(
                          _copied ? AboutStrings.copied : AboutStrings.copy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('about.done'),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(AboutStrings.done),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  AppStrings.footerRights,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The app's mark, popping in, with a glint passing over it.
class _Seal extends StatelessWidget {
  const _Seal({required this.shown, required this.shine});

  final double shown;
  final double shine;

  static const double _size = 76;

  @override
  Widget build(BuildContext context) {
    final glint = context.colors.onAccent.withValues(alpha: 0.35);

    return Opacity(
      opacity: shown.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.7 + 0.3 * shown,
        child: SizedBox.square(
          dimension: _size,
          child: Stack(
            children: [
              const BrandMark(size: _size),
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_size * 0.28),
                  child: CustomPaint(painter: _ShinePainter(shine, glint)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShinePainter extends CustomPainter {
  const _ShinePainter(this.shine, this.glint);

  final double shine;
  final Color glint;

  @override
  void paint(Canvas canvas, Size size) =>
      paintSplashShine(canvas, size, shine, glint);

  @override
  bool shouldRepaint(_ShinePainter old) =>
      old.shine != shine || old.glint != glint;
}

/// "Version 1.6.0 · build 10", on a wash of the accent.
class _VersionPill extends StatelessWidget {
  const _VersionPill({required this.info});

  final AppInfo info;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: colors.accentWash(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.accentWash(0.30)),
      ),
      child: Text.rich(
        TextSpan(
          text: AboutStrings.version(info.version),
          children: [
            if (info.buildNumber.isNotEmpty)
              TextSpan(
                text: '  ·  ${AboutStrings.build(info.buildNumber)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
          ],
        ),
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: colors.accent,
        ),
      ),
    );
  }
}

/// A label on the left and its value on the right, a hairline under it.
class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    this.divided = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool divided;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: divided
            ? Border(bottom: BorderSide(color: colors.border))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: MergeSemantics(
          child: Row(
            children: [
              Icon(icon, size: 17, color: colors.textMuted),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
