import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// What an island says it is about — the colour of its icon.
enum IslandTone { info, success, warning, error }

/// One message on the island.
@immutable
class IslandMessage {
  const IslandMessage({
    required this.title,
    this.body,
    this.tone = IslandTone.info,
    this.icon,
    this.hold = const Duration(milliseconds: 2600),
    this.onTap,
  });

  final String title;
  final String? body;
  final IslandTone tone;

  /// The tone's own icon when left out.
  final IconData? icon;

  /// How long it stays open, once open.
  final Duration hold;

  /// Where a tap takes the reader — Notifications, for several at once. A
  /// tap closes the island either way.
  final VoidCallback? onTap;
}

/// The app's way of saying something that needs no answer — a QR saved, a
/// scan the server refused, the lock switched on. A small black capsule
/// drops out of the top of the screen, where a phone's camera sits, widens
/// into the message, holds, and shrinks back into the top: the "Dynamic
/// Island" of a recent phone. Questions still get a dialog.
///
/// Why not a SnackBar: it rises from the bottom, where the scanner's camera
/// and the Menu button are, and in a queue at the door the instructor is
/// looking at the top of the phone.
abstract final class Island {
  /// Shows [message], putting away any island already open — the newest
  /// wins: a message about the previous student is stale the moment the next
  /// one is scanned.
  ///
  /// Under no [IslandHost] (a page tested on its own), a SnackBar instead.
  static void show(BuildContext context, IslandMessage message) {
    final host = context.findAncestorStateOfType<_IslandHostState>();
    if (host != null) {
      host._show(message);
      return;
    }
    final body = message.body;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            body == null ? message.title : '${message.title}\n$body',
          ),
        ),
      );
  }
}

/// Holds the island over everything under it — pages, dialogs and sheets
/// alike. MaterialApp.builder puts one over the navigator.
class IslandHost extends StatefulWidget {
  const IslandHost({super.key, required this.child});

  final Widget child;

  @override
  State<IslandHost> createState() => _IslandHostState();
}

class _IslandHostState extends State<IslandHost>
    with SingleTickerProviderStateMixin {
  /// Opening, holding and closing, as one timeline — frame-driven, so a
  /// test's pumpAndSettle waits for it and nothing is left on a timer.
  ///
  /// Preserved under "reduce motion": the hold is for reading, and must not
  /// shrink with the animations. The opening and closing are dropped instead.
  ///
  /// Made in initState, not lazily: most launches never show an island, and
  /// a controller first made in dispose would look for its ticker's
  /// ancestors in a tree already coming down.
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
    )..addStatusListener(_onStatus);
  }

  static const Duration _opening = Duration(milliseconds: 520);
  static const Duration _closing = Duration(milliseconds: 380);

  IslandMessage? _message;
  int _serial = 0;

  /// Where on the timeline the island is fully open, and starts to close.
  double _open = 0.2;
  double _close = 0.85;

  void _show(IslandMessage message) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final opening = still ? Duration.zero : _opening;
    final closing = still ? Duration.zero : _closing;
    final total = opening + message.hold + closing;

    // Already open: the new message takes its place without closing first.
    final wasOpen =
        _message != null &&
        _controller.value >= _open &&
        _controller.value < _close;

    setState(() {
      _message = message;
      _serial++;
      _open = opening.inMicroseconds / total.inMicroseconds;
      _close = 1 - closing.inMicroseconds / total.inMicroseconds;
    });
    _controller
      ..duration = total
      ..forward(from: wasOpen ? _open : 0);
  }

  /// A tap, or a flick up: close now rather than at the end of the hold.
  void _dismiss() {
    if (_controller.value < _close) _controller.forward(from: _close);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _message = null);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;

    return Stack(
      children: [
        widget.child,
        if (message != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => _Island(
                      key: ValueKey(_serial),
                      message: message,
                      t: _controller.value,
                      open: _open,
                      close: _close,
                      onDismiss: _dismiss,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The capsule itself, at [t] of its timeline.
class _Island extends StatelessWidget {
  const _Island({
    super.key,
    required this.message,
    required this.t,
    required this.open,
    required this.close,
    required this.onDismiss,
  });

  final IslandMessage message;
  final double t;
  final double open;
  final double close;
  final VoidCallback onDismiss;

  static const double _closedWidth = 120;
  static const double _maxWidth = 440;

  /// Always dark, whatever the theme — it is the phone's island, not a
  /// panel of the app — so its colours are the dark set's in both.
  static const AppPalette _ink = AppPalette.dark;

  Color get _toneColor => switch (message.tone) {
    IslandTone.info => _ink.accent,
    IslandTone.success => _ink.success,
    IslandTone.warning => _ink.warning,
    IslandTone.error => _ink.danger,
  };

  IconData get _toneIcon =>
      message.icon ??
      switch (message.tone) {
        IslandTone.info => Icons.info_outline_rounded,
        IslandTone.success => Icons.check_circle_rounded,
        IslandTone.warning => Icons.warning_amber_rounded,
        IslandTone.error => Icons.error_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    // 0 → 1 as it opens, 1 while it holds, 1 → 0 as it closes.
    final double grow;
    final double content;
    final double presence;
    if (t < close) {
      final a = open == 0 ? 1.0 : (t / open).clamp(0.0, 1.0);
      grow = Curves.easeOutBack.transform(a);
      content = ((a - 0.45) / 0.55).clamp(0.0, 1.0);
      presence = (a * 3).clamp(0.0, 1.0);
    } else {
      final s = close >= 1 ? 1.0 : ((t - close) / (1 - close)).clamp(0.0, 1.0);
      grow = 1 - Curves.easeInCubic.transform(s);
      content = (1 - s * 2.2).clamp(0.0, 1.0);
      presence = 1 - ((s - 0.6) / 0.4).clamp(0.0, 1.0);
    }
    // How much of the hold is left, for the line along the bottom.
    final left = t <= open
        ? 1.0
        : t >= close
        ? 0.0
        : 1 - (t - open) / (close - open);

    final screen = MediaQuery.sizeOf(context).width;
    final openWidth = math.min(screen - 24, _maxWidth);
    final radius = lerpDouble(18, 26, grow.clamp(0.0, 1.0))!;
    final body = message.body;

    final inner = SizedBox(
      width: openWidth,
      child: Opacity(
        opacity: content,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _toneColor.withValues(alpha: 0.18),
                ),
                child: Icon(_toneIcon, size: 20, color: _toneColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: _ink.textPrimary,
                      ),
                    ),
                    if (body != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        body,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: _ink.textSecondary,
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
    );

    return Opacity(
      opacity: presence,
      child: Transform.translate(
        offset: Offset(0, -10 * (1 - grow.clamp(0.0, 1.0))),
        child: GestureDetector(
          onTap: () {
            message.onTap?.call();
            onDismiss();
          },
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) < -100) onDismiss();
          },
          child: Semantics(
            liveRegion: true,
            container: true,
            button: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _ink.canvas,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: _ink.borderStrong),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35 * presence),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: Material(
                  type: MaterialType.transparency,
                  child: Stack(
                    children: [
                      // Grows out of the middle: the capsule widens and
                      // deepens around the message.
                      Align(
                        widthFactor: lerpDouble(
                          _closedWidth / openWidth,
                          1,
                          grow,
                        )!.clamp(0.0, 1.2),
                        heightFactor: lerpDouble(0.5, 1, grow)!.clamp(0.0, 1.2),
                        child: inner,
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 0,
                        height: 2,
                        child: Opacity(
                          opacity: content,
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: left,
                            child: ColoredBox(
                              color: _toneColor.withValues(alpha: 0.55),
                            ),
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
    );
  }
}
