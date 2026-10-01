import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../controllers/phone_lock_controller.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import 'splash_parts.dart';

/// The way past the lock without the phone's own — under the Unlock button:
/// the scanner's password, the student's "Not you?". `lock.<name>`, for
/// tests.
typedef LockAlternative = ({
  String name,
  IconData icon,
  String label,
  VoidCallback onPressed,
});

/// In front of whatever the lock guards — the scanner's saved sign-in, the
/// student's side — when it is on: whose it is, and the phone's own prompt,
/// asked for straight away. Nothing behind it is started until it opens.
///
/// The fingerprint is the picture: while the phone's prompt is up, a light
/// runs down and up its ridges and rings go out from it, as if it were being
/// read. A prompt closed without a finger shakes it and turns it red for a
/// moment. Nothing loops once the prompt is down — a locked phone left on a
/// desk sits still.
class PhoneLockScreen extends StatefulWidget {
  const PhoneLockScreen({
    super.key,
    required this.lock,
    required this.title,
    required this.body,
    this.owner,
    this.alternative,
  });

  final PhoneLockController lock;
  final String title;
  final String body;

  /// Whose it is, over the fingerprint — see [LockOwnerChip].
  final Widget? owner;
  final LockAlternative? alternative;

  /// How long the screen is up before the system prompt covers it, so the
  /// owner sees whose it is and what is being asked.
  static const Duration promptDelay = Duration(milliseconds: 700);

  @override
  State<PhoneLockScreen> createState() => _PhoneLockScreenState();
}

class _PhoneLockScreenState extends State<PhoneLockScreen>
    with TickerProviderStateMixin {
  /// The chip, the fingerprint, the words and the buttons, arriving in turn.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..forward();

  /// Rings going out from the fingerprint while the prompt is up.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  /// The light running down and up the ridges while the prompt is up.
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  /// The fingerprint shaking off a prompt closed without a finger.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );

  late final Animation<double> _chip = _slice(0.00, 0.45, Curves.easeOut);
  late final Animation<double> _print = _slice(0.05, 0.60, Curves.easeOutBack);
  late final Animation<double> _words = _slice(0.30, 0.75, Curves.easeOut);
  late final Animation<double> _actions = _slice(0.45, 1.00, Curves.easeOut);

  Timer? _prompt;
  String? _lastMessage;

  Animation<double> _slice(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _intro,
        curve: Interval(begin, end, curve: curve),
      );

  @override
  void initState() {
    super.initState();
    _lastMessage = widget.lock.message;
    widget.lock.addListener(_onLock);
    // Ask straight away — the app was opened to be used — but not before
    // this screen has faded in.
    _prompt = Timer(PhoneLockScreen.promptDelay, () {
      if (mounted) widget.lock.unlock();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _onLock();
  }

  void _onLock() {
    if (!mounted) return;
    final reading =
        widget.lock.unlocking && !MediaQuery.of(context).disableAnimations;
    if (reading && !_pulse.isAnimating) {
      _pulse.repeat();
      _scan.repeat(reverse: true);
    } else if (!reading && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
      _scan
        ..stop()
        ..value = 0;
    }

    final message = widget.lock.message;
    if (message != null && message != _lastMessage) _shake.forward(from: 0);
    _lastMessage = message;
  }

  @override
  void dispose() {
    _prompt?.cancel();
    widget.lock.removeListener(_onLock);
    _intro.dispose();
    _pulse.dispose();
    _scan.dispose();
    _shake.dispose();
    super.dispose();
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
    final owner = widget.owner;
    final alternative = widget.alternative;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ListenableBuilder(
                listenable: widget.lock,
                builder: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (owner != null) ...[
                      _rise(_chip, Center(child: owner)),
                      const SizedBox(height: 18),
                    ],
                    Center(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _print,
                          _pulse,
                          _scan,
                          _shake,
                        ]),
                        builder: (context, _) {
                          final s = _shake.value;
                          final shaking = _shake.isAnimating;
                          return Transform.translate(
                            offset: Offset(
                              shaking
                                  ? math.sin(s * math.pi * 5) * 10 * (1 - s)
                                  : 0,
                              0,
                            ),
                            child: _Fingerprint(
                              shown: _print.value,
                              pulse: _pulse.isAnimating ? _pulse.value : null,
                              scan: _scan.isAnimating ? _scan.value : null,
                              alarm: shaking ? math.sin(math.pi * s) : 0,
                              onTap: widget.lock.unlocking
                                  ? null
                                  : widget.lock.unlock,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    _rise(
                      _words,
                      Column(
                        children: [
                          Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.body,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.5,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Opens rather than appears, so the buttons slide down.
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      alignment: Alignment.topCenter,
                      child: switch (widget.lock.message) {
                        final message? => Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: _Callout(text: message),
                        ),
                        null => const SizedBox(width: double.infinity),
                      },
                    ),
                    const SizedBox(height: 24),
                    _rise(
                      _actions,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.icon(
                            key: const ValueKey('lock.unlock'),
                            onPressed: widget.lock.unlocking
                                ? null
                                : widget.lock.unlock,
                            icon: const Icon(Icons.fingerprint_rounded),
                            label: const Text(LockStrings.unlock),
                          ),
                          if (alternative != null) ...[
                            const SizedBox(height: 6),
                            TextButton.icon(
                              key: ValueKey('lock.${alternative.name}'),
                              onPressed: alternative.onPressed,
                              icon: Icon(alternative.icon, size: 18),
                              label: Text(alternative.label),
                              style: TextButton.styleFrom(
                                foregroundColor: colors.textSecondary,
                              ),
                            ),
                          ],
                        ],
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
}

/// Whose it is: their picture, their name and a padlock, in a pill.
class LockOwnerChip extends StatelessWidget {
  const LockOwnerChip({super.key, required this.avatar, required this.name});

  /// A 30 px picture — the instructor's, the student's.
  final Widget avatar;
  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatar,
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.lock_rounded, size: 15, color: colors.accent),
        ],
      ),
    );
  }
}

/// The big fingerprint to tap: a glowing disc, rings going out from it and a
/// light running over its ridges while the phone reads a finger.
class _Fingerprint extends StatelessWidget {
  const _Fingerprint({
    required this.shown,
    required this.pulse,
    required this.scan,
    required this.alarm,
    required this.onTap,
  });

  /// 0 → 1 (a little past, overshooting): the disc arriving.
  final double shown;

  /// 0 → 1, over and over: the rings. Null: none.
  final double? pulse;

  /// 0 → 1 → 0, over and over: where the light is on the ridges. Null: none.
  final double? scan;

  /// 0 → 1 → 0: red, for a prompt closed without a finger.
  final double alarm;

  /// Null while the prompt is up.
  final VoidCallback? onTap;

  static const double _box = 220;
  static const double _disc = 128;
  static const double _print = 78;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = Color.lerp(colors.accent, colors.danger, alarm)!;
    // The light on the ridges: near white on the dark ground, the soft
    // accent on the light one, where white would not show.
    final light = colors.isDark ? colors.textPrimary : colors.accentSoft;
    final opacity = shown.clamp(0.0, 1.0);
    final p = pulse;
    final t = scan;

    return Semantics(
      button: true,
      label: LockStrings.unlock,
      child: SizedBox.square(
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
                    colors: [
                      tint.withValues(alpha: 0.20),
                      tint.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: const SizedBox.expand(),
              ),
            ),
            // Two rings, half a beat apart.
            if (p != null)
              for (final lag in const [0.0, 0.5])
                _Ring(t: (p + lag) % 1, disc: _disc, box: _box, color: tint),
            Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: 0.8 + 0.2 * shown,
                child: Material(
                  color: colors.surface,
                  shape: CircleBorder(
                    side: BorderSide(
                      color: tint.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                  ),
                  elevation: 0,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onTap,
                    child: SizedBox.square(
                      dimension: _disc,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: tint.withValues(alpha: 0.10),
                          boxShadow: [
                            BoxShadow(
                              color: tint.withValues(alpha: 0.28),
                              blurRadius: 26,
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: t == null
                                  ? Icon(
                                      Icons.fingerprint_rounded,
                                      size: _print,
                                      color: tint,
                                    )
                                  // The ridges lit where the light is.
                                  : ShaderMask(
                                      blendMode: BlendMode.srcIn,
                                      shaderCallback: (rect) => LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [tint, light, tint],
                                        stops: [
                                          (t - 0.22).clamp(0.0, 1.0),
                                          t.clamp(0.0, 1.0),
                                          (t + 0.22).clamp(0.0, 1.0),
                                        ],
                                      ).createShader(rect),
                                      child: const Icon(
                                        Icons.fingerprint_rounded,
                                        size: _print,
                                      ),
                                    ),
                            ),
                            // The reading line itself, across the ridges.
                            if (t != null)
                              Positioned(
                                left: 20,
                                right: 20,
                                top: (_disc - _print) / 2 + _print * t - 1,
                                height: 2,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        light.withValues(alpha: 0),
                                        light,
                                        light.withValues(alpha: 0),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: tint.withValues(alpha: 0.6),
                                        blurRadius: 8,
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One ring on its way out from the disc to the edge of the glow.
class _Ring extends StatelessWidget {
  const _Ring({
    required this.t,
    required this.disc,
    required this.box,
    required this.color,
  });

  final double t;
  final double disc;
  final double box;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final size = disc + (box - disc) * Curves.easeOut.transform(t);

    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: 0.45 * (1 - t)),
            width: 2,
          ),
        ),
      ),
    );
  }
}

/// Why the lock is still shut, with a fingerprint crossed out.
class _Callout extends StatelessWidget {
  const _Callout({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.warning;

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
          Icon(Icons.do_not_touch_outlined, size: 17, color: color),
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

/// Offered once, on a phone that has a screen lock: right after an
/// instructor's sign-in with the password, or a student's set-up in My
/// Profile. True when they said yes.
Future<bool> showLockOffer(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.fingerprint_rounded, color: context.colors.accent),
      title: Text(title),
      content: Text(
        body,
        style: TextStyle(
          fontSize: 14,
          height: 1.45,
          color: context.colors.textSecondary,
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('lock.offer.later'),
          onPressed: () => Navigator.pop(context, false),
          child: const Text(LockStrings.later),
        ),
        FilledButton(
          key: const ValueKey('lock.offer.on'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text(LockStrings.turnOn),
        ),
      ],
    ),
  );
  return yes ?? false;
}
