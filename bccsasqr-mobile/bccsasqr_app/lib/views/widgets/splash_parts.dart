import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import 'fade_scale_switcher.dart';

/// The pieces the students' two splashes share — the generator's and the
/// tracker's — so they read as one family: a tile with a glow, the wordmark
/// with a tagline, three steps, and the college's name at the foot.

/// A page behind its splash: the splash plays once, then cross-fades into the
/// page. The page is not built until then, so nothing on it starts talking
/// under the animation.
class SplashThen extends StatefulWidget {
  const SplashThen({super.key, required this.splash, required this.page});

  /// Builds the splash; it calls the callback once it has played.
  final Widget Function(VoidCallback onFinished) splash;
  final WidgetBuilder page;

  @override
  State<SplashThen> createState() => _SplashThenState();
}

class _SplashThenState extends State<SplashThen> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return FadeScaleSwitcher(
      child: _done
          ? Builder(key: const ValueKey('page'), builder: widget.page)
          : KeyedSubtree(
              key: const ValueKey('splash'),
              child: widget.splash(() {
                if (mounted) setState(() => _done = true);
              }),
            ),
    );
  }
}

/// Fades [child] in while lifting it the last 12 px into place.
Widget splashRise(double t, Widget child) => Opacity(
  opacity: t.clamp(0.0, 1.0),
  child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
);

/// The tile the picture is drawn on, and the glow behind it. [shown] runs
/// 0 → 1 (and a little past, with an overshooting curve) as it pops in.
class SplashTile extends StatelessWidget {
  const SplashTile({super.key, required this.shown, required this.child});

  final double shown;
  final Widget child;

  static const double _box = 210;
  static const double _tileSize = 150;
  static const double _inset = 16;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final opacity = shown.clamp(0.0, 1.0);

    return SizedBox.square(
      dimension: _box,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: opacity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [colors.accentWash(0.22), colors.accentWash(0)],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: 0.8 + 0.2 * shown,
              child: Container(
                width: _tileSize,
                height: _tileSize,
                padding: const EdgeInsets.all(_inset),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: colors.accentWash(0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A light passing corner to corner over a finished picture. [shine] runs
/// 0 → 1; nothing is drawn outside that.
void paintSplashShine(Canvas canvas, Size size, double shine, Color glint) {
  if (shine <= 0 || shine >= 1) return;
  final s = -0.25 + 1.5 * shine;
  final rect = Offset.zero & size;
  final clear = glint.withValues(alpha: 0);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [clear, glint, clear],
        stops: [
          (s - 0.15).clamp(0.0, 1.0),
          s.clamp(0.0, 1.0),
          (s + 0.15).clamp(0.0, 1.0),
        ],
      ).createShader(rect),
  );
}

/// "BCC SASQR" and what this part of the app does.
class SplashWordmark extends StatelessWidget {
  const SplashWordmark({super.key, required this.tagline});

  final String tagline;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
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
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tagline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.4,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// One of the three steps under the wordmark.
typedef SplashStep = ({IconData icon, String label});

/// The three steps a student is about to take, each arriving in turn, joined
/// by a line that draws itself across.
class SplashSteps extends StatelessWidget {
  const SplashSteps({super.key, required this.steps, required this.shown})
    : assert(steps.length == shown.length);

  final List<SplashStep> steps;

  /// One 0 → 1 value per step.
  final List<double> shown;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, step) in steps.indexed) ...[
          if (i > 0) _Connector(shown: shown[i]),
          _Step(icon: step.icon, label: step.label, shown: shown[i]),
        ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.label, required this.shown});

  final IconData icon;
  final String label;
  final double shown;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      width: 76,
      child: splashRise(
        shown,
        Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accentWash(0.12),
                border: Border.all(color: colors.accentWash(0.30)),
              ),
              child: Icon(icon, size: 18, color: colors.accent),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.shown});

  final double shown;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Level with the middle of the 38 px circles.
      padding: const EdgeInsets.only(top: 18),
      child: SizedBox(
        width: 20,
        height: 2,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: shown.clamp(0.0, 1.0),
            heightFactor: 1,
            child: ColoredBox(color: context.colors.accentWash(0.45)),
          ),
        ),
      ),
    );
  }
}

/// The college's name at the foot of the screen, arriving with the last step.
class SplashFooter extends StatelessWidget {
  const SplashFooter({super.key, required this.shown});

  final double shown;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Opacity(
          opacity: shown.clamp(0.0, 1.0),
          child: Text(
            AppStrings.splashFooter,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.4,
              color: context.colors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// A splash's timeline: [play] for the animation, then [hold] on the finished
/// scene so it can be looked at before the page takes over.
///
/// The hold is part of the same controller rather than a timer after it, so
/// the splash stays frame-driven — "reduce motion" shortens it along with the
/// rest, and a test's pumpAndSettle waits for it.
class SplashTimeline {
  const SplashTimeline({required this.play, required this.hold});

  final Duration play;
  final Duration hold;

  Duration get total => play + hold;

  /// An interval written against [play] alone (0 → 1 over the animation),
  /// placed on the whole timeline.
  Interval interval(double begin, double end, Curve curve) {
    final f = play.inMicroseconds / total.inMicroseconds;
    return Interval(begin * f, end * f, curve: curve);
  }
}
