import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/scanner_lock_controller.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/scanner_models.dart';
import 'widgets/scanner_header.dart';

/// In front of a saved sign-in when the lock is on: whose scanner it is, and
/// the phone's own prompt, asked for straight away. The camera is not started
/// until it opens.
class ScannerLockScreen extends StatefulWidget {
  const ScannerLockScreen({
    super.key,
    required this.lock,
    required this.user,
    required this.onUsePassword,
  });

  final ScannerLockController lock;
  final ScannerUser? user;

  /// Signs out, for the password instead — a finger that will not read, or
  /// someone else's phone lock.
  final VoidCallback onUsePassword;

  /// How long the screen is up before the system prompt covers it, so the
  /// instructor sees whose scanner it is and what is being asked.
  static const Duration promptDelay = Duration(milliseconds: 700);

  @override
  State<ScannerLockScreen> createState() => _ScannerLockScreenState();
}

class _ScannerLockScreenState extends State<ScannerLockScreen>
    with SingleTickerProviderStateMixin {
  /// A slow breath on the fingerprint while the prompt is up.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  Timer? _prompt;

  @override
  void initState() {
    super.initState();
    widget.lock.addListener(_onLock);
    // Ask straight away — the instructor opened the scanner to use it — but
    // not before this screen has faded in.
    _prompt = Timer(ScannerLockScreen.promptDelay, () {
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
    final breathe =
        widget.lock.unlocking && !MediaQuery.of(context).disableAnimations;
    if (breathe && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!breathe && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _prompt?.cancel();
    widget.lock.removeListener(_onLock);
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = widget.user;

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
                  children: [
                    if (user != null) ...[
                      _LockedAvatar(user: user),
                      const SizedBox(height: 12),
                      Text(
                        user.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],
                    Text(
                      ScannerStrings.lockTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ScannerStrings.lockBody,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _FingerprintButton(
                      pulse: _pulse,
                      busy: widget.lock.unlocking,
                      onPressed: widget.lock.unlock,
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('lock.unlock'),
                        onPressed: widget.lock.unlocking
                            ? null
                            : widget.lock.unlock,
                        icon: const Icon(Icons.lock_open_rounded),
                        label: const Text(ScannerStrings.lockUnlock),
                      ),
                    ),
                    if (widget.lock.message case final message?) ...[
                      const SizedBox(height: 10),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: colors.warning),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton(
                      key: const ValueKey('lock.password'),
                      onPressed: widget.onUsePassword,
                      child: const Text(ScannerStrings.lockUsePassword),
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

/// The instructor's picture with a small padlock on it.
class _LockedAvatar extends StatelessWidget {
  const _LockedAvatar({required this.user});

  final ScannerUser user;

  @override
  Widget build(BuildContext context) {
    const size = 72.0;
    final colors = context.colors;

    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          UserAvatar(user: user, size: size),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              height: 28,
              width: 28,
              decoration: BoxDecoration(
                color: colors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: colors.canvas, width: 2.5),
              ),
              child: Icon(Icons.lock_rounded, size: 14, color: colors.onAccent),
            ),
          ),
        ],
      ),
    );
  }
}

/// A big fingerprint to tap, breathing while the system prompt is up.
class _FingerprintButton extends StatelessWidget {
  const _FingerprintButton({
    required this.pulse,
    required this.busy,
    required this.onPressed,
  });

  final Animation<double> pulse;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const size = 96.0;

    return Semantics(
      button: true,
      label: ScannerStrings.lockUnlock,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(pulse.value);
          return SizedBox.square(
            dimension: size * 1.5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The ring that breathes out from the button.
                Container(
                  height: size * (1.1 + 0.35 * t),
                  width: size * (1.1 + 0.35 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.accentWash(0.35 * (1 - t) + 0.08),
                      width: 2,
                    ),
                  ),
                ),
                child!,
              ],
            ),
          );
        },
        child: Material(
          color: colors.accentWash(0.12),
          shape: CircleBorder(side: BorderSide(color: colors.accentWash(0.35))),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: busy ? null : onPressed,
            child: SizedBox.square(
              dimension: size,
              child: Icon(
                Icons.fingerprint_rounded,
                size: 56,
                color: colors.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Offered once, right after a sign-in with the password, on a phone that has
/// a screen lock. True when the instructor said yes.
Future<bool> showLockOffer(BuildContext context) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.fingerprint_rounded, color: context.colors.accent),
      title: const Text(ScannerStrings.lockOfferTitle),
      content: Text(
        ScannerStrings.lockOfferBody,
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
          child: const Text(ScannerStrings.lockOfferLater),
        ),
        FilledButton(
          key: const ValueKey('lock.offer.on'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text(ScannerStrings.lockOfferOn),
        ),
      ],
    ),
  );
  return yes ?? false;
}
