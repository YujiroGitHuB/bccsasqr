import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../models/app_role.dart';
import 'widgets/app_header_card.dart';
import 'widgets/press_scale.dart';
import 'widgets/splash_parts.dart';

/// The first launch's one question: student or instructor. The answer is
/// kept, so it is asked once — and again only from Settings → Role.
///
/// The seal pops in and the rest rises in under it, one piece after another.
/// A tapped card sinks, lights up and takes a tick before the app moves on —
/// long enough to see which one was picked.
class RolePickerPage extends StatefulWidget {
  const RolePickerPage({super.key, required this.onChosen});

  final ValueChanged<AppRole> onChosen;

  @override
  State<RolePickerPage> createState() => _RolePickerPageState();
}

class _RolePickerPageState extends State<RolePickerPage>
    with TickerProviderStateMixin {
  static const double _maxContentWidth = 560;

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  /// The picked card lighting up, before [RolePickerPage.onChosen].
  late final AnimationController _pick = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  late final Animation<double> _seal = _slice(0.00, 0.40, Curves.easeOutBack);
  late final Animation<double> _heading = _slice(0.15, 0.55, Curves.easeOut);
  late final Animation<double> _student = _slice(0.30, 0.72, Curves.easeOut);
  late final Animation<double> _instructor = _slice(0.40, 0.82, Curves.easeOut);
  late final Animation<double> _hint = _slice(0.60, 1.00, Curves.easeOut);

  AppRole? _picked;

  Animation<double> _slice(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _intro,
        curve: Interval(begin, end, curve: curve),
      );

  @override
  void dispose() {
    _intro.dispose();
    _pick.dispose();
    super.dispose();
  }

  Future<void> _choose(AppRole role) async {
    if (_picked != null) return;
    setState(() => _picked = role);
    await _pick.forward();
    if (mounted) widget.onChosen(role);
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

    return Scaffold(
      body: Stack(
        children: [
          // A wash of the accent behind the seal, fading down the screen.
          Positioned(
            top: -140,
            left: 0,
            right: 0,
            height: 420,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [colors.accentWash(0.16), colors.accentWash(0)],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
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
                      AnimatedBuilder(
                        animation: _seal,
                        child: const BrandHeading(),
                        builder: (context, child) => Opacity(
                          opacity: _seal.value.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 0.85 + 0.15 * _seal.value,
                            child: child,
                          ),
                        ),
                      ),
                      const SizedBox(height: 34),
                      _rise(_heading, const _Question()),
                      const SizedBox(height: 20),
                      _rise(
                        _student,
                        _Choice(
                          key: const ValueKey('role.student'),
                          icon: Icons.school_rounded,
                          title: RoleStrings.studentTitle,
                          body: RoleStrings.studentBody,
                          chips: const [
                            (
                              Icons.qr_code_2_rounded,
                              AppStrings.homeStudentTitle,
                            ),
                            (
                              Icons.event_available_rounded,
                              AppStrings.homeTrackerTitle,
                            ),
                          ],
                          picked: _picked == AppRole.student,
                          pick: _pick,
                          onTap: () => _choose(AppRole.student),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _rise(
                        _instructor,
                        _Choice(
                          key: const ValueKey('role.instructor'),
                          icon: Icons.badge_rounded,
                          title: RoleStrings.instructorTitle,
                          body: RoleStrings.instructorBody,
                          chips: const [
                            (Icons.qr_code_scanner_rounded, NavStrings.scanner),
                            (Icons.qr_code_2_rounded, NavStrings.qr),
                            (Icons.event_available_rounded, NavStrings.tracker),
                            (
                              Icons.lock_outline_rounded,
                              RoleStrings.signInChip,
                            ),
                          ],
                          picked: _picked == AppRole.instructor,
                          pick: _pick,
                          onTap: () => _choose(AppRole.instructor),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _rise(
                        _hint,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.settings_outlined,
                              size: 14,
                              color: colors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                RoleStrings.hint,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.45,
                                  color: colors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The question, and what answering it does.
class _Question extends StatelessWidget {
  const _Question();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      children: [
        Text(
          RoleStrings.question,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          RoleStrings.lead,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
      ],
    );
  }
}

/// One answer: an icon, what it is, and chips for what is behind it. Picked,
/// its border and icon light up in the accent and a tick fills the circle on
/// its right.
class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.chips,
    required this.picked,
    required this.pick,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<(IconData, String)> chips;
  final bool picked;
  final Animation<double> pick;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return PressScale(
      child: AnimatedBuilder(
        animation: pick,
        builder: (context, _) {
          final t = picked ? Curves.easeOut.transform(pick.value) : 0.0;

          return MergeSemantics(
            child: Stack(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      colors.surface,
                      // A tint laid on the surface, so the card stays solid.
                      Color.alphaBlend(colors.accentWash(0.08), colors.surface),
                      t,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                    border: Border.all(
                      color: Color.lerp(colors.border, colors.accent, t)!,
                      width: 1 + t,
                    ),
                    boxShadow: [
                      if (t > 0)
                        BoxShadow(
                          color: colors.accentWash(0.25 * t),
                          blurRadius: 22,
                          offset: const Offset(0, 6),
                        ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Tile(icon: icon, lit: t),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                body,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: colors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final (icon, label) in chips)
                                    _MiniChip(icon: icon, label: label),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _Tick(shown: t),
                        ),
                      ],
                    ),
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
        },
      ),
    );
  }
}

/// The card's icon, on a wash of the accent — on the brand fill once picked.
class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.lit});

  final IconData icon;
  final double lit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox.square(
      dimension: 50,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.accentWash(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.accentWash(0.30)),
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: lit,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppPalette.brandMark,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          Center(
            // The brand fill is the same cyan in both themes, so the ink on
            // it is the dark set's in both.
            child: Icon(
              icon,
              size: 26,
              color: Color.lerp(colors.accent, AppPalette.dark.onAccent, lit),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small pill naming one thing behind the card.
class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: colors.textSecondary),
          const SizedBox(width: 4),
          // Never wider than the card, whatever the text size.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// An empty circle, filled with a tick as the card is picked.
class _Tick extends StatelessWidget {
  const _Tick({required this.shown});

  final double shown;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox.square(
      dimension: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.borderStrong, width: 2),
            ),
            child: const SizedBox.expand(),
          ),
          Transform.scale(
            scale: shown,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent,
              ),
              child: SizedBox.expand(
                child: Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: colors.onAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
