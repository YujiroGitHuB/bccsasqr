import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants/app_assets.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';

/// The opening screen: the school seal is "scanned", the name settles in
/// under it, and the app fades through to the generator.
///
/// It takes over from the NATIVE launch screen (`flutter_native_splash` in
/// `pubspec.yaml`), and its first frame is that screen exactly — the same
/// colour, the same logo at the same size, dead centre of the whole window. So
/// the student never sees a hand-over: the still picture simply starts to move.
///
/// The native screen is kept up until the logo is decoded (see [initState]),
/// otherwise the first Flutter frame would show the background alone and the
/// logo would blink.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.onFinished});

  /// Called once, when the splash is done. The caller swaps in the next page.
  final VoidCallback onFinished;

  /// The native splash draws the 526 px logo as 4x: 131.5 logical pixels.
  /// Change one, change the other, or the logo jumps at hand-over.
  static const double logoSize = 131.5;

  /// The whole animation. The splash has nothing to load, so this is kept
  /// short: long enough to read, not long enough to wait on.
  static const Duration duration = Duration(milliseconds: 1700);

  /// Longest the native screen is held for the logo. A slow decode costs a
  /// blink, never a hang.
  static const Duration logoWaitLimit = Duration(milliseconds: 700);

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SplashPage.duration,
  )..addStatusListener(_onStatus);

  // Each part of the scene has its own slice of the timeline.
  late final Animation<double> _lift = _slice(0.00, 0.40, Curves.easeOutCubic);
  late final Animation<double> _frame = _slice(0.10, 0.45, Curves.easeOutBack);
  late final Animation<double> _scan = _slice(0.22, 0.85, Curves.easeInOut);
  late final Animation<double> _title = _slice(0.35, 0.70, Curves.easeOutCubic);
  late final Animation<double> _tagline = _slice(
    0.45,
    0.80,
    Curves.easeOutCubic,
  );
  late final Animation<double> _footer = _slice(0.55, 0.90, Curves.easeOut);

  bool _started = false;
  bool _animating = false;
  bool _holdingFirstFrame = false;
  bool _finished = false;
  Timer? _logoWait;
  Timer? _timer;

  Animation<double> _slice(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _controller,
        curve: Interval(begin, end, curve: curve),
      );

  @override
  void initState() {
    super.initState();
    // Keep the native launch screen up until the logo can be drawn. Paired
    // with allowFirstFrame() in _start(), which always runs.
    WidgetsBinding.instance.deferFirstFrame();
    _holdingFirstFrame = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    // Whichever comes first: the logo is ready, or we stop waiting for it.
    _logoWait = Timer(SplashPage.logoWaitLimit, _start);
    precacheImage(
      const AssetImage(AppAssets.bccLogo),
      context,
    ).then((_) => _start(), onError: (_) => _start());
  }

  void _start() {
    _logoWait?.cancel();
    if (!mounted || _animating) return;
    _animating = true;
    _releaseFirstFrame();

    // "Reduce motion" on: show the finished scene, pause, move on. The timer
    // is set first so the jump to the end does not also start the short
    // hold in _onStatus.
    if (MediaQuery.disableAnimationsOf(context)) {
      _timer = Timer(const Duration(milliseconds: 600), _finish);
      _controller.value = 1;
      return;
    }
    _controller.forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _timer == null) {
      _timer = Timer(const Duration(milliseconds: 150), _finish);
    }
  }

  void _releaseFirstFrame() {
    if (!_holdingFirstFrame) return;
    _holdingFirstFrame = false;
    WidgetsBinding.instance.allowFirstFrame();
  }

  void _finish() {
    if (!mounted || _finished) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _releaseFirstFrame();
    _logoWait?.cancel();
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Semantics(
        label: AppStrings.splashSemantics,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final lift = _lift.value;

            return Stack(
              children: [
                // Not inside a SafeArea: the native screen centres on the
                // whole window, so this must too.
                Center(
                  child: Transform.translate(
                    offset: Offset(0, -64 * lift),
                    child: Transform.scale(
                      scale: 1 - 0.12 * lift,
                      child: _ScannedSeal(
                        frame: _frame.value,
                        scan: _scan.value,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Transform.translate(
                    offset: Offset(0, 80 + 14 * (1 - _title.value)),
                    child: _Wordmark(
                      title: _title.value,
                      tagline: _tagline.value,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    minimum: const EdgeInsets.only(bottom: 28),
                    child: Opacity(
                      opacity: _footer.value,
                      child: const Text(
                        AppStrings.splashFooter,
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 0.4,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The seal inside a scanner's viewfinder, with the scan line passing over
/// it — what the app is for, in one picture.
class _ScannedSeal extends StatelessWidget {
  const _ScannedSeal({required this.frame, required this.scan});

  /// 0 → 1: the glow and the viewfinder corners arriving.
  final double frame;

  /// 0 → 1: the scan line's trip from the top of the seal to the bottom.
  final double scan;

  static const double _box = 220;
  static const double _viewfinder = 176;
  static const double _trail = 34;

  @override
  Widget build(BuildContext context) {
    const size = SplashPage.logoSize;
    final shown = frame.clamp(0.0, 1.0);
    // Fades in at the top and out at the bottom instead of popping.
    final scanOpacity = math.sin(math.pi * scan).clamp(0.0, 1.0);

    return SizedBox(
      width: _box,
      height: _box,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: shown,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.accentWash(0.26), AppColors.accentWash(0)],
                ),
              ),
            ),
          ),
          Opacity(
            opacity: shown,
            child: Transform.scale(
              scale: 1.3 - 0.3 * frame,
              child: const CustomPaint(
                size: Size.square(_viewfinder),
                painter: _ViewfinderPainter(color: AppColors.accent),
              ),
            ),
          ),
          SizedBox.square(
            dimension: size,
            child: ClipOval(
              child: Stack(
                children: [
                  Image.asset(
                    AppAssets.bccLogo,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                  if (scanOpacity > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: size * scan - _trail,
                      height: _trail + 2,
                      child: Opacity(
                        opacity: scanOpacity,
                        child: const _ScanLine(trail: _trail),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A bright line with a soft wash trailing above it.
class _ScanLine extends StatelessWidget {
  const _ScanLine({required this.trail});

  final double trail;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: trail,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.accentWash(0), AppColors.accentWash(0.28)],
            ),
          ),
        ),
        Container(
          height: 2,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0x002DD4F5),
                AppColors.accentSoft,
                Color(0x002DD4F5),
              ],
            ),
            boxShadow: [
              BoxShadow(color: AppColors.accentWash(0.7), blurRadius: 8),
            ],
          ),
        ),
      ],
    );
  }
}

/// Four rounded corner brackets — a camera viewfinder.
class _ViewfinderPainter extends CustomPainter {
  const _ViewfinderPainter({required this.color});

  final Color color;

  static const double _arm = 26;
  static const double _radius = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const a = _arm;
    const r = _radius;

    final path = Path()
      // top left
      ..moveTo(0, a)
      ..lineTo(0, r)
      ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
      ..lineTo(a, 0)
      // top right
      ..moveTo(w - a, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
      ..lineTo(w, a)
      // bottom right
      ..moveTo(w, h - a)
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: const Radius.circular(r))
      ..lineTo(w - a, h)
      // bottom left
      ..moveTo(a, h)
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: const Radius.circular(r))
      ..lineTo(0, h - a);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = color;

    // A blurred pass under the crisp one reads as a glow.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_ViewfinderPainter old) => old.color != color;
}

/// "BCC SASQR" and what it is.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.title, required this.tagline});

  final double title;
  final double tagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: title.clamp(0.0, 1.0),
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: AppStrings.splashBrand),
                TextSpan(
                  text: AppStrings.splashBrandAccent,
                  style: TextStyle(
                    foreground: Paint()
                      ..shader = const LinearGradient(
                        colors: [AppColors.accentSoft, AppColors.accentDeep],
                      ).createShader(const Rect.fromLTWH(0, 0, 110, 36)),
                  ),
                ),
              ],
            ),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Opacity(
          opacity: tagline.clamp(0.0, 1.0),
          child: const Text(
            AppStrings.splashTagline,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.4,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
