import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/whats_new_controller.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import 'widgets/app_footer.dart';
import 'widgets/app_header_card.dart';
import 'widgets/surface_panel.dart';

/// The opening screen: one app, two people. Students open the generator or
/// the attendance tracker; instructors open the scanner, which asks them to
/// sign in.
///
/// The destinations are built by the caller, so this screen knows nothing
/// about repositories or services.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.generatorBuilder,
    required this.trackerBuilder,
    required this.scannerBuilder,
    this.settingsBuilder,
    this.whatsNewBuilder,
    this.whatsNew,
  });

  final WidgetBuilder generatorBuilder;
  final WidgetBuilder trackerBuilder;
  final WidgetBuilder scannerBuilder;

  /// The gear in the corner. Students get the theme and the voice switch
  /// too, not only instructors behind a sign-in.
  final WidgetBuilder? settingsBuilder;

  /// The What's New page, beside the gear. While [whatsNew] says this phone
  /// has not opened the newest release, the button carries a dot and a card
  /// sits above the destinations — until the page is opened or the card
  /// closed.
  final WidgetBuilder? whatsNewBuilder;
  final WhatsNewController? whatsNew;

  static const double _maxContentWidth = 560;

  void _open(BuildContext context, WidgetBuilder builder) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
  }

  bool get _unread => whatsNew?.unread ?? false;

  @override
  Widget build(BuildContext context) {
    final settings = settingsBuilder;
    final news = whatsNewBuilder;

    // Only the home screen listens: the mark changing must not rebuild the
    // whole app the way a theme change does.
    return ListenableBuilder(
      listenable: whatsNew ?? const _Silent(),
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              _content(context),
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (news != null)
                      _WhatsNewButton(
                        unread: _unread,
                        onPressed: () => _open(context, news),
                      ),
                    if (settings != null)
                      IconButton(
                        key: const ValueKey('home.settings'),
                        onPressed: () => _open(context, settings),
                        tooltip: SettingsStrings.open,
                        icon: const Icon(Icons.settings_outlined),
                        color: context.colors.textSecondary,
                      ),
                  ],
                ),
              ),
            ],
          ),
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
              // Folds away rather than vanishing, so the cards below slide
              // up instead of jumping.
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _unread && whatsNewBuilder != null
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: _WhatsNewCard(
                          onTap: () => _open(context, whatsNewBuilder!),
                          onClose: whatsNew!.markSeen,
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
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
              const SizedBox(height: 12),
              _Destination(
                key: const ValueKey('home.tracker'),
                icon: Icons.event_available_rounded,
                title: AppStrings.homeTrackerTitle,
                body: AppStrings.homeTrackerBody,
                onTap: () => _open(context, trackerBuilder),
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

/// A [Listenable] that never fires — for a home screen with no What's New.
class _Silent implements Listenable {
  const _Silent();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// The web topbar's stars button, dot and all.
class _WhatsNewButton extends StatelessWidget {
  const _WhatsNewButton({required this.unread, required this.onPressed});

  final bool unread;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return IconButton(
      key: const ValueKey('home.whatsNew'),
      onPressed: onPressed,
      tooltip: unread ? WhatsNewStrings.openUnread : WhatsNewStrings.open,
      color: unread ? colors.accent : colors.textSecondary,
      icon: Badge(
        isLabelVisible: unread,
        smallSize: 9,
        backgroundColor: colors.accent,
        child: const Icon(Icons.auto_awesome_outlined),
      ),
    );
  }
}

/// "New in this update" — above the destinations until the page is opened
/// once or the card is closed.
class _WhatsNewCard extends StatelessWidget {
  const _WhatsNewCard({required this.onTap, required this.onClose});

  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Laid out like a destination, with the ink on top of the panel; the
    // close button sits above the ink so a tap on it only closes.
    return Stack(
      key: const ValueKey('home.whatsNewCard'),
      children: [
        MergeSemantics(
          child: Stack(
            children: [
              SurfacePanel(
                borderColor: colors.accentWash(0.35),
                padding: const EdgeInsets.fromLTRB(16, 14, 44, 14),
                child: Row(
                  children: [
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        gradient: AppPalette.brandMark,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      // The brand fill is the same cyan in both themes, so
                      // the ink on it is the dark set's in both.
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 21,
                        color: AppPalette.dark.onAccent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            WhatsNewStrings.cardTitle,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            WhatsNewStrings.cardBody,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
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
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            key: const ValueKey('home.whatsNewClose'),
            onPressed: onClose,
            tooltip: WhatsNewStrings.cardClose,
            iconSize: 18,
            icon: const Icon(Icons.close_rounded),
            color: colors.textMuted,
          ),
        ),
      ],
    );
  }
}
