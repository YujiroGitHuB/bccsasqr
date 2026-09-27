import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../controllers/scanner_controller.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/app_header_card.dart';
import '../widgets/splash_parts.dart';
import '../widgets/surface_panel.dart';
import '../widgets/viewfinder.dart';

/// The instructor's email and password — the same account as the web system,
/// checked by the same rules (`crud/login_process.php`).
///
/// It carries on from the scanner's splash: the same viewfinder, now round
/// the school seal, arrives first and the form rises in under it piece by
/// piece. The scan line passes over the seal twice and rests, and sweeps
/// again for as long as the password is being checked. A refused sign-in
/// shakes the form and turns the corners red for a moment.
///
/// Nothing here loops for good: a screen left open does not keep animating,
/// and a test's pumpAndSettle can settle on it.
class ScannerSignInPage extends StatefulWidget {
  const ScannerSignInPage({
    super.key,
    required this.controller,
    this.demo = false,
    this.onBack,
  });

  final ScannerController controller;
  final bool demo;

  /// The arrow above the form: back to the student-or-instructor question.
  /// Without it, the arrow is there only when a page is under this one.
  final VoidCallback? onBack;

  @override
  State<ScannerSignInPage> createState() => _ScannerSignInPageState();
}

class _ScannerSignInPageState extends State<ScannerSignInPage>
    with TickerProviderStateMixin {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _hidePassword = true;

  /// The seal, the heading, the form and the note, arriving in turn.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..addStatusListener(_onIntro);

  /// One trip of the scan line down the seal.
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  /// The form shaking off a refused sign-in.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );

  late final Animation<double> _hero = _slice(0.00, 0.55, Curves.easeOutBack);
  late final Animation<double> _heading = _slice(0.18, 0.62, Curves.easeOut);
  late final Animation<double> _form = _slice(0.32, 0.84, Curves.easeOutCubic);
  late final Animation<double> _note = _slice(0.55, 1.00, Curves.easeOut);

  bool _wasSigningIn = false;

  ScannerController get _c => widget.controller;

  /// "Reduce motion": the scan line stays put. The entrance still runs, at
  /// the twentieth of its length the framework gives it.
  bool get _still => MediaQuery.disableAnimationsOf(context);

  Animation<double> _slice(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _intro,
        curve: Interval(begin, end, curve: curve),
      );

  @override
  void initState() {
    super.initState();
    _c.addListener(_onController);
    _intro.forward();
  }

  @override
  void dispose() {
    _c.removeListener(_onController);
    _intro.dispose();
    _sweep.dispose();
    _shake.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Twice over the seal once the page is in, then rest.
  void _onIntro(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted || _still) return;
    _sweep.repeat(count: 2);
  }

  /// The line sweeps for as long as the password is being checked.
  void _onController() {
    final signingIn = _c.isSigningIn;
    if (signingIn == _wasSigningIn) return;
    _wasSigningIn = signingIn;
    if (!mounted) return;
    if (signingIn && !_still) {
      _sweep.repeat();
    } else if (!signingIn && _sweep.isAnimating) {
      _sweep.stop();
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    await _c.signIn(email: _email.text, password: _password.text);
    // Refused — a wrong password, or a field left empty — every time, even
    // when the message is the same as the last one.
    if (mounted && _c.signInError != null) _shake.forward(from: 0);
  }

  /// Fades [child] in and lifts it into place as [shown] runs 0 → 1.
  Widget _rise(Animation<double> shown, Widget child) => AnimatedBuilder(
    animation: shown,
    child: child,
    builder: (context, child) => splashRise(shown.value, child!),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final VoidCallback? back =
        widget.onBack ??
        (Navigator.of(context).canPop()
            ? () => Navigator.of(context).maybePop()
            : null);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.pagePadding,
            vertical: 12,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // There from the first frame: whoever tapped the wrong card
                  // can leave without waiting for the rest.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: back == null
                        ? const SizedBox(height: 40)
                        : TextButton.icon(
                            key: const ValueKey('signIn.back'),
                            onPressed: back,
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 18,
                            ),
                            label: Text(
                              widget.onBack != null
                                  ? RoleStrings.signInBack
                                  : AppStrings.homeBack,
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: colors.textSecondary,
                            ),
                          ),
                  ),
                  Center(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_hero, _sweep, _shake]),
                      builder: (context, _) => _SignInHero(
                        shown: _hero.value,
                        sweep: _sweep.isAnimating ? _sweep.value : null,
                        alarm: _shake.isAnimating
                            ? math.sin(math.pi * _shake.value)
                            : 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _rise(_heading, const _Heading()),
                  const SizedBox(height: 22),
                  _rise(
                    _form,
                    AnimatedBuilder(
                      animation: _shake,
                      child: _formCard(context),
                      // Side to side, dying away — the "no" of a head.
                      builder: (context, child) {
                        final t = _shake.value;
                        final dx = _shake.isAnimating
                            ? math.sin(t * math.pi * 5) * 10 * (1 - t)
                            : 0.0;
                        return Transform.translate(
                          offset: Offset(dx, 0),
                          child: child,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  _rise(_note, const _Note()),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formCard(BuildContext context) {
    return SurfacePanel(
      topAccent: true,
      padding: const EdgeInsets.all(20),
      child: ListenableBuilder(
        listenable: _c,
        builder: (context, _) {
          final colors = context.colors;
          final busy = _c.isSigningIn;

          return AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_c.sessionMessage case final message?) ...[
                  _Callout(
                    icon: Icons.info_outline_rounded,
                    text: message,
                    color: colors.warning,
                  ),
                  const SizedBox(height: 14),
                ],
                if (widget.demo) ...[
                  _Callout(
                    icon: Icons.science_outlined,
                    text: ScannerStrings.demoSignInHint,
                    color: colors.warning,
                  ),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: _email,
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [
                    AutofillHints.email,
                    AutofillHints.username,
                  ],
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: ScannerStrings.emailLabel,
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  enabled: !busy,
                  obscureText: _hidePassword,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: ScannerStrings.passwordLabel,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: _hidePassword
                          ? ScannerStrings.showPassword
                          : ScannerStrings.hidePassword,
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                // Opens rather than appears, so the button below slides
                // down instead of jumping.
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: switch (_c.signInError) {
                    final error? => Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _Callout(
                        icon: Icons.error_outline_rounded,
                        text: error,
                        color: colors.danger,
                      ),
                    ),
                    null => const SizedBox(width: double.infinity),
                  },
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: busy ? null : _submit,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: busy
                        ? const Row(
                            key: ValueKey('busy'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(ScannerStrings.signingIn),
                            ],
                          )
                        : const Row(
                            key: ValueKey('idle'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(ScannerStrings.signIn),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The school seal in the scanner's viewfinder, with the glow behind it —
/// the splash's picture, with the seal where the QR was.
class _SignInHero extends StatelessWidget {
  const _SignInHero({
    required this.shown,
    required this.sweep,
    required this.alarm,
  });

  /// 0 → 1 (a little past, overshooting): the whole picture arriving.
  final double shown;

  /// 0 → 1: the scan line's trip down the seal. Null: no line.
  final double? sweep;

  /// 0 → 1 → 0: the corners going red for a refused sign-in.
  final double alarm;

  static const double _box = 176;
  static const double _viewfinder = 128;
  static const double _seal = 88;
  static const double _trail = 24;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final opacity = shown.clamp(0.0, 1.0);
    final t = sweep;
    // Fades in at the top and out at the bottom instead of popping.
    final beam = t == null ? 0.0 : math.sin(math.pi * t);

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
              scale: 1.25 - 0.25 * shown,
              child: CustomPaint(
                size: const Size.square(_viewfinder),
                painter: ViewfinderPainter(
                  color: Color.lerp(colors.accent, colors.danger, alarm)!,
                ),
              ),
            ),
          ),
          Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: 0.86 + 0.14 * shown,
              child: SizedBox.square(
                dimension: _seal,
                child: Stack(
                  children: [
                    const BrandMark(size: _seal),
                    if (t != null && beam > 0)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(_seal * 0.28),
                          child: Stack(
                            children: [
                              Positioned(
                                left: 0,
                                right: 0,
                                top: _seal * t - _trail,
                                height: _trail + 2,
                                child: Opacity(
                                  opacity: beam.clamp(0.0, 1.0),
                                  child: ScanBeam(
                                    trail: _trail,
                                    palette: colors,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "BCC SASQR SCANNER", then what this screen is for.
class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      children: [
        Text(
          ScannerStrings.title.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
            color: colors.accent,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          ScannerStrings.signInHeading,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          ScannerStrings.signInBody,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.5,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Under the form, for the student who came to see what was behind it.
class _Note extends StatelessWidget {
  const _Note();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.verified_user_outlined, size: 15, color: colors.textMuted),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            ScannerStrings.signInOnlyInstructors,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: colors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, height: 1.4, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
