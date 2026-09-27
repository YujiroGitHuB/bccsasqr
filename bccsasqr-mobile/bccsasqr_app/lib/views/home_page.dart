import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/whats_new_controller.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import 'student_splash.dart';
import 'widgets/app_footer.dart';
import 'widgets/app_header_card.dart';
import 'widgets/destination_card.dart';
import 'widgets/press_scale.dart';
import 'widgets/splash_parts.dart';
import 'widgets/surface_panel.dart';

/// The student's opening screen: the generator and the attendance tracker,
/// and nothing of the scanner's. An instructor's phone opens the bottom bar
/// instead (instructor_shell.dart).
///
/// My QR Code is the one big cyan card — it is what a student comes for —
/// with My Attendance under it and the three steps of the day below. The
/// pieces rise in one after another the first time the screen shows, not
/// again on the way back from a page.
///
/// The destinations are built by the caller, so this screen knows nothing
/// about repositories or services.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.generatorBuilder,
    required this.trackerBuilder,
    this.settingsBuilder,
    this.whatsNewBuilder,
    this.whatsNew,
    this.now = DateTime.now,
  });

  final WidgetBuilder generatorBuilder;
  final WidgetBuilder trackerBuilder;

  /// The gear in the corner. Students get the theme and the voice switch
  /// too, not only instructors behind a sign-in.
  final WidgetBuilder? settingsBuilder;

  /// The What's New page, beside the gear. While [whatsNew] says this phone
  /// has not opened the newest release, the button carries a dot and a card
  /// sits above the destinations — until the page is opened or the card
  /// closed.
  final WidgetBuilder? whatsNewBuilder;
  final WhatsNewController? whatsNew;

  /// The clock the greeting is picked by. Overridable for tests.
  final DateTime Function() now;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  static const double _maxContentWidth = 560;

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  late final Animation<double> _top = _slice(0.00, 0.40, Curves.easeOut);
  late final Animation<double> _greet = _slice(0.10, 0.50, Curves.easeOut);
  late final Animation<double> _hero = _slice(0.20, 0.62, Curves.easeOutCubic);
  late final Animation<double> _tracker = _slice(0.30, 0.72, Curves.easeOut);
  late final Animation<double> _howTo = _slice(0.42, 0.78, Curves.easeOut);
  late final List<Animation<double>> _steps = [
    _slice(0.48, 0.74, Curves.easeOutCubic),
    _slice(0.56, 0.82, Curves.easeOutCubic),
    _slice(0.64, 0.90, Curves.easeOutCubic),
  ];
  late final Animation<double> _foot = _slice(0.60, 1.00, Curves.easeOut);

  Animation<double> _slice(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _intro,
        curve: Interval(begin, end, curve: curve),
      );

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  void _open(WidgetBuilder builder) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
  }

  bool get _unread => widget.whatsNew?.unread ?? false;

  String get _greeting {
    final hour = widget.now().hour;
    if (hour < 12) return AppStrings.homeMorning;
    if (hour < 18) return AppStrings.homeAfternoon;
    return AppStrings.homeEvening;
  }

  /// Fades [child] in and lifts it into place as [shown] runs 0 → 1.
  Widget _rise(Animation<double> shown, Widget child) => AnimatedBuilder(
    animation: shown,
    child: child,
    builder: (context, child) => splashRise(shown.value, child!),
  );

  @override
  Widget build(BuildContext context) {
    final news = widget.whatsNewBuilder;

    // Only the home screen listens: the mark changing must not rebuild the
    // whole app the way a theme change does.
    return ListenableBuilder(
      listenable: widget.whatsNew ?? const _Silent(),
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              10,
              AppTheme.pagePadding,
              24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _rise(_top, _topBar(context)),
                    const SizedBox(height: 24),
                    _rise(_greet, _Greeting(greeting: _greeting)),
                    const SizedBox(height: 20),
                    // Folds away rather than vanishing, so the cards below
                    // slide up instead of jumping.
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      alignment: Alignment.topCenter,
                      child: _unread && news != null
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _WhatsNewCard(
                                onTap: () => _open(news),
                                onClose: widget.whatsNew!.markSeen,
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                    _rise(
                      _hero,
                      _QrHero(
                        key: const ValueKey('home.generator'),
                        onTap: () => _open(widget.generatorBuilder),
                      ),
                    ),
                    // Room for the bright card's shadow.
                    const SizedBox(height: 18),
                    _rise(
                      _tracker,
                      PressScale(
                        child: DestinationCard(
                          key: const ValueKey('home.tracker'),
                          icon: Icons.event_available_rounded,
                          title: AppStrings.homeTrackerTitle,
                          body: AppStrings.homeTrackerBody,
                          onTap: () => _open(widget.trackerBuilder),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _rise(
                      _howTo,
                      const PanelHeading(
                        icon: Icons.route_outlined,
                        label: AppStrings.homeHowItWorks,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: AnimatedBuilder(
                        animation: _intro,
                        builder: (context, _) => SplashSteps(
                          steps: StudentSplash.steps,
                          shown: [for (final s in _steps) s.value],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _rise(
                      _foot,
                      AppFooter(
                        onOpenDeveloper: () => launchUrl(
                          Uri.parse(AppStrings.developerUrl),
                          mode: LaunchMode.externalApplication,
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
    );
  }

  /// The seal and the wordmark on the left; What's New and the gear on the
  /// right.
  Widget _topBar(BuildContext context) {
    final colors = context.colors;
    final settings = widget.settingsBuilder;
    final news = widget.whatsNewBuilder;

    return Row(
      children: [
        const BrandMark(size: 40),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                AppStrings.homeStudentSection,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (news != null)
          _WhatsNewButton(unread: _unread, onPressed: () => _open(news)),
        if (settings != null)
          IconButton(
            key: const ValueKey('home.settings'),
            onPressed: () => _open(settings),
            tooltip: SettingsStrings.open,
            icon: const Icon(Icons.settings_outlined),
            color: colors.textSecondary,
          ),
      ],
    );
  }
}

/// "Good morning" — by the hour — and the question the cards answer.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.greeting});

  final String greeting;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.accent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppStrings.homeQuestion,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.2,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// My QR Code, on the brand fill: the page's one bright card, with a code on
/// a white plate at its side.
class _QrHero extends StatelessWidget {
  const _QrHero({super.key, required this.onTap});

  final VoidCallback onTap;

  static const double _radius = AppTheme.cardRadius + 4;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // The brand fill is the same cyan in both themes, so the ink on it is the
    // dark set's in both.
    final ink = AppPalette.dark.onAccent;

    return PressScale(
      child: MergeSemantics(
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
              decoration: BoxDecoration(
                gradient: AppPalette.brandMark,
                borderRadius: BorderRadius.circular(_radius),
                boxShadow: [
                  BoxShadow(
                    color: colors.accentWash(0.30),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.homeStudentTitle,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppStrings.homeStudentBody,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: ink.withValues(alpha: 0.78),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: ink.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppStrings.homeOpen,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: ink,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: ink,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  _QrPlate(ink: ink),
                ],
              ),
            ),
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(_radius),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A code on a white plate, tipped a little — the card the student will
/// carry.
class _QrPlate extends StatelessWidget {
  const _QrPlate({required this.ink});

  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.07,
      child: Container(
        width: 86,
        height: 86,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          // A plate that is white in both themes, as a QR's backing must be.
          color: AppPalette.light.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: ink.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ExcludeSemantics(
          child: QrImageView(
            data: AppStrings.appName,
            version: QrVersions.auto,
            padding: EdgeInsets.zero,
            backgroundColor: AppPalette.light.surface,
            eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: ink),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.circle,
              color: ink,
            ),
          ),
        ),
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
