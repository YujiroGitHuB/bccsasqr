import 'package:flutter/material.dart';

/// Hands one screen over to the next with a cross-fade and a slight zoom:
/// the app's splash to Home, and each of the scanner's and generator's
/// splashes to the screen it opens.
class FadeScaleSwitcher extends StatelessWidget {
  const FadeScaleSwitcher({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
  });

  /// Give each screen its own key, or the switcher sees no change.
  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
