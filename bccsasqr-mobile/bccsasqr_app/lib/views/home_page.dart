import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import 'widgets/app_footer.dart';
import 'widgets/app_header_card.dart';
import 'widgets/surface_panel.dart';

/// The opening screen: one app, two people. Students open the generator;
/// instructors open the scanner, which asks them to sign in.
///
/// The destinations are built by the caller, so this screen knows nothing
/// about repositories or services.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.generatorBuilder,
    required this.scannerBuilder,
    this.settingsBuilder,
  });

  final WidgetBuilder generatorBuilder;
  final WidgetBuilder scannerBuilder;

  /// The gear in the corner. Students get the theme and the voice switch
  /// too, not only instructors behind a sign-in.
  final WidgetBuilder? settingsBuilder;

  static const double _maxContentWidth = 560;

  void _open(BuildContext context, WidgetBuilder builder) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
  }

  @override
  Widget build(BuildContext context) {
    final settings = settingsBuilder;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            _content(context),
            if (settings != null)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  key: const ValueKey('home.settings'),
                  onPressed: () => _open(context, settings),
                  tooltip: SettingsStrings.open,
                  icon: const Icon(Icons.settings_outlined),
                  color: context.colors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.pagePadding,
        vertical: 28,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Center(child: BrandMark(size: 72)),
              const SizedBox(height: 18),
              Text.rich(
                TextSpan(
                  text: AppStrings.splashBrand,
                  children: [
                    TextSpan(
                      text: AppStrings.splashBrandAccent,
                      style: TextStyle(color: context.colors.accent),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppStrings.splashFooter,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              const PanelHeading(
                icon: Icons.school_outlined,
                label: AppStrings.homeStudentSection,
              ),
              const SizedBox(height: 12),
              _Destination(
                key: const ValueKey('home.generator'),
                icon: Icons.qr_code_2_rounded,
                title: AppStrings.homeStudentTitle,
                body: AppStrings.homeStudentBody,
                onTap: () => _open(context, generatorBuilder),
              ),
              const SizedBox(height: 28),
              const PanelHeading(
                icon: Icons.badge_outlined,
                label: AppStrings.homeInstructorSection,
              ),
              const SizedBox(height: 12),
              _Destination(
                key: const ValueKey('home.scanner'),
                icon: Icons.qr_code_scanner_rounded,
                title: AppStrings.homeScannerTitle,
                body: AppStrings.homeScannerBody,
                onTap: () => _open(context, scannerBuilder),
              ),
              const SizedBox(height: 36),
              AppFooter(
                onOpenDeveloper: () => launchUrl(
                  Uri.parse(AppStrings.developerUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The ink sits on top of the panel: under it, the panel's own fill would
    // hide the ripple. Merged, so a screen reader reads the card as one
    // button with its title, not an unnamed button beside some text.
    return MergeSemantics(
      child: Stack(
        children: [
          SurfacePanel(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: context.colors.accentWash(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.colors.accentWash(0.30)),
                  ),
                  child: Icon(icon, color: context.colors.accent, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.colors.textMuted,
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
