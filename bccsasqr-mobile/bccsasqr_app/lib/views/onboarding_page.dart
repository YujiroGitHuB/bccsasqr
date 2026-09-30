import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import 'widgets/onboarding_art.dart';
import 'widgets/press_scale.dart';
import 'widgets/splash_parts.dart';

/// The introduction on the first launch: four slides, one per part of the
/// app — a welcome, the QR code, being scanned, the attendance tracker —
/// before the student-or-instructor question. Settings → App tour shows it
/// again.
///
/// Swiped, or stepped through with **Next**. Each slide's picture builds
/// itself the first time the slide comes into view, with the words rising in
/// under it; after that it holds still. While a slide is being swiped, its
/// picture trails behind the words and dims, and the dots stretch to follow
/// the finger — all driven by the swipe, so nothing moves once it settles.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.onDone,
    this.finishLabel = OnboardingStrings.start,
  });

  /// **Skip**, or the last slide's button.
  final VoidCallback onDone;

  /// The last slide's button: "Get started" on the first launch, "Done"
  /// from Settings.
  final String finishLabel;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

typedef _SlideContent = ({
  String title,
  String body,
  Widget Function(double t) art,
});

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  static const double _maxContentWidth = 560;

  static final List<_SlideContent> _slides = [
    (
      title: OnboardingStrings.welcomeTitle,
      body: OnboardingStrings.welcomeBody,
      art: (t) => WelcomeArt(t: t),
    ),
    (
      title: OnboardingStrings.qrTitle,
      body: OnboardingStrings.qrBody,
      art: (t) => QrArt(t: t),
    ),
    (
      title: OnboardingStrings.scanTitle,
      body: OnboardingStrings.scanBody,
      art: (t) => ScanArt(t: t),
    ),
    (
      title: OnboardingStrings.daysTitle,
      body: OnboardingStrings.daysBody,
      art: (t) => DaysArt(t: t),
    ),
  ];

  final PageController _pages = PageController();

  /// One timeline per slide, played once when the slide first comes into
  /// view. Made here, not lazily: a slide never reached must still be
  /// disposable.
  late final List<AnimationController> _plays = [
    for (final _ in _slides)
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1700),
      ),
  ];

  int _page = 0;
  bool _finished = false;

  bool get _last => _page == _slides.length - 1;

  @override
  void initState() {
    super.initState();
    _plays.first.forward();
    _pages.addListener(_onScroll);
  }

  @override
  void dispose() {
    _pages.dispose();
    for (final play in _plays) {
      play.dispose();
    }
    super.dispose();
  }

  /// Where the pages are, in slides — mid-swipe, between two.
  double get _position {
    if (!_pages.hasClients) return _page.toDouble();
    return _pages.page ?? _page.toDouble();
  }

  /// A slide starts building as soon as it is well into view, not only once
  /// the swipe has settled on it — otherwise it would slide in empty.
  void _onScroll() {
    final at = _position;
    for (final (i, play) in _plays.indexed) {
      if ((i - at).abs() < 0.6 && play.status == AnimationStatus.dismissed) {
        play.forward();
      }
    }
  }

  void _go(int page) => _pages.animateToPage(
    page,
    duration: const Duration(milliseconds: 450),
    curve: Curves.easeOutCubic,
  );

  void _next() => _last ? _finish() : _go(_page + 1);

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return PopScope(
      // Back steps to the slide before; from the first, it leaves as usual.
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_page - 1);
      },
      child: Scaffold(
        body: Stack(
          children: [
            // A wash of the accent across the top, drifting with the pages.
            Positioned(
              top: -160,
              left: -80,
              right: -80,
              height: 460,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pages,
                  builder: (context, _) => DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(
                          -0.5 + _position / (_slides.length - 1),
                          0,
                        ),
                        colors: [colors.accentWash(0.16), colors.accentWash(0)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                  child: Column(
                    children: [
                      _TopBar(skipShown: !_last, onSkip: _finish),
                      Expanded(
                        child: PageView.builder(
                          controller: _pages,
                          itemCount: _slides.length,
                          onPageChanged: (page) => setState(() => _page = page),
                          itemBuilder: (context, i) => _Slide(
                            index: i,
                            count: _slides.length,
                            content: _slides[i],
                            play: _plays[i],
                            pages: _pages,
                            position: () => _position,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedBuilder(
                        animation: _pages,
                        builder: (context, _) => _Dots(
                          count: _slides.length,
                          position: _position,
                          onTap: _go,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _PrimaryButton(
                          label: _last
                              ? widget.finishLabel
                              : OnboardingStrings.next,
                          icon: _last
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                          onTap: _next,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The name on the left, **Skip** on the right — gone on the last slide,
/// where the big button says the same.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.skipShown, required this.onSkip});

  final bool skipShown;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 12, 0),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: AppStrings.splashBrand),
                  TextSpan(
                    text: AppStrings.splashBrandAccent,
                    style: TextStyle(color: colors.accent),
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: colors.textPrimary,
              ),
            ),
            const Spacer(),
            AnimatedOpacity(
              opacity: skipShown ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !skipShown,
                child: TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textSecondary,
                  ),
                  child: const Text(OnboardingStrings.skip),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One slide: its picture, then the title and the words under it.
class _Slide extends StatelessWidget {
  const _Slide({
    required this.index,
    required this.count,
    required this.content,
    required this.play,
    required this.pages,
    required this.position,
  });

  final int index;
  final int count;
  final _SlideContent content;
  final AnimationController play;
  final PageController pages;
  final double Function() position;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final width = MediaQuery.sizeOf(context).width;

    return Semantics(
      container: true,
      label: OnboardingStrings.semantics(index + 1, count),
      child: AnimatedBuilder(
        animation: Listenable.merge([play, pages]),
        builder: (context, _) {
          // How far this slide is from the middle: 0 settled, ±1 a whole
          // slide away.
          final d = (index - position()).clamp(-1.0, 1.0);
          final away = d.abs();
          final t = play.value;
          double slice(double begin, double end) => Curves.easeOutCubic
              .transform(((t - begin) / (end - begin)).clamp(0.0, 1.0));

          // The picture takes about half the height it is given; a small
          // phone with large text scrolls the words rather than cut them.
          return LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: (box.maxHeight * 0.55).clamp(140.0, 300.0),
                      child: Center(
                        // The picture trails the swipe, and dims going out.
                        child: Transform.translate(
                          offset: Offset(-d * width * 0.35, 0),
                          child: Opacity(
                            opacity: 1 - 0.6 * away,
                            child: Transform.scale(
                              scale: 1 - 0.08 * away,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: content.art(t),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // The words run a little ahead of it.
                    Transform.translate(
                      offset: Offset(d * 40, 0),
                      child: splashRise(
                        slice(0.28, 0.68),
                        Text(
                          content.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Transform.translate(
                      offset: Offset(d * 70, 0),
                      child: splashRise(
                        slice(0.38, 0.80),
                        Text(
                          content.body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One dot per slide. The current one stretches into a bar in the accent,
/// and mid-swipe the stretch moves across with the finger.
class _Dots extends StatelessWidget {
  const _Dots({
    required this.count,
    required this.position,
    required this.onTap,
  });

  final int count;
  final double position;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          GestureDetector(
            key: ValueKey('onboarding.dot.$i'),
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Builder(
                builder: (context) {
                  final near = (1 - (i - position).abs()).clamp(0.0, 1.0);
                  return Container(
                    width: 8 + 18 * near,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        colors.borderStrong,
                        colors.accent,
                        near,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// The one bright element on the screen: the brand fill, with **Next** — or,
/// on the last slide, the way out — sliding in as the label changes.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // The brand fill is the same cyan in both themes, so the ink on it is
    // the dark set's in both.
    final ink = AppPalette.dark.onAccent;

    return PressScale(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppPalette.brandMark,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors.accentWash(0.30),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 54,
              width: double.infinity,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.35),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Row(
                    key: ValueKey(label),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: ink,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(icon, size: 20, color: ink),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
