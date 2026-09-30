import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../generator_splash.dart' show BuildingQrPainter;
import '../tracker_splash.dart' show CalendarPainter;
import 'splash_parts.dart';
import 'viewfinder.dart';

/// The pictures of the introduction (views/onboarding_page.dart), one per
/// slide. Each is drawn from a single [t] running 0 → 1 once, the first time
/// its slide is shown: the parts arrive one after another, then everything
/// holds still. Nothing loops.
///
/// They reuse the splashes' own pieces — the generator's QR being built, the
/// tracker's calendar, the viewfinder and scan line — so the introduction
/// shows the app as it will look.

/// [t] eased over its own slice [begin]–[end] of the timeline.
double _at(double t, double begin, double end, [Curve curve = Curves.linear]) =>
    curve.transform(((t - begin) / (end - begin)).clamp(0.0, 1.0));

/// "BCC SASQR" as a real QR, so the dots land where a code's would. Never a
/// student's number.
final QrImage _brandCode = QrImage(
  QrCode.fromData(
    data: AppStrings.appName,
    errorCorrectLevel: QrErrorCorrectLevel.M,
  ),
);

/// The school seal "scanned" in the viewfinder, as on the opening splash —
/// then the three parts of the app pop out around it.
class WelcomeArt extends StatelessWidget {
  const WelcomeArt({super.key, required this.t});

  final double t;

  static const double _width = 290;
  static const double _height = 250;
  static const double _viewfinder = 172;
  static const double _seal = 118;
  static const double _trail = 30;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final frame = _at(t, 0.00, 0.38, Curves.easeOutBack);
    final seal = _at(t, 0.10, 0.45, Curves.easeOutBack);
    final scan = _at(t, 0.35, 0.78, Curves.easeInOut);
    final beam = math.sin(math.pi * scan);

    // Each part lands in turn just outside the viewfinder — above it, beside
    // it, below it — clear of its corners.
    final parts = [
      (
        icon: Icons.qr_code_2_rounded,
        label: OnboardingStrings.welcomeQr,
        at: const Alignment(-1, -1),
        shown: _at(t, 0.62, 0.84, Curves.easeOutBack),
      ),
      (
        icon: Icons.qr_code_scanner_rounded,
        label: OnboardingStrings.welcomeScan,
        at: const Alignment(1, 0),
        shown: _at(t, 0.70, 0.92, Curves.easeOutBack),
      ),
      (
        icon: Icons.event_available_rounded,
        label: OnboardingStrings.welcomeDays,
        at: const Alignment(-0.9, 1),
        shown: _at(t, 0.78, 1.00, Curves.easeOutBack),
      ),
    ];

    return SizedBox(
      width: _width,
      height: _height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _Glow(shown: frame, size: 230),
          Opacity(
            opacity: frame.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 1.3 - 0.3 * frame,
              child: CustomPaint(
                size: const Size.square(_viewfinder),
                painter: ViewfinderPainter(color: colors.accent),
              ),
            ),
          ),
          Opacity(
            opacity: seal.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.8 + 0.2 * seal,
              child: SizedBox.square(
                dimension: _seal,
                child: ClipOval(
                  child: Stack(
                    children: [
                      Image.asset(
                        AppAssets.bccLogo,
                        width: _seal,
                        height: _seal,
                        fit: BoxFit.contain,
                      ),
                      if (beam > 0)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: _seal * scan - _trail,
                          height: _trail + 2,
                          child: Opacity(
                            opacity: beam.clamp(0.0, 1.0),
                            child: ScanBeam(trail: _trail, palette: colors),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          for (final part in parts)
            Align(
              alignment: part.at,
              child: _Pop(
                shown: part.shown,
                child: ArtChip(icon: part.icon, label: part.label),
              ),
            ),
        ],
      ),
    );
  }
}

/// A QR building itself on a tile — the generator's splash — and a chip
/// saying it is kept on the phone.
class QrArt extends StatelessWidget {
  const QrArt({super.key, required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      width: 250,
      height: 250,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          SplashTile(
            shown: _at(t, 0.00, 0.30, Curves.easeOutBack),
            child: CustomPaint(
              painter: BuildingQrPainter(
                code: _brandCode,
                eyes: _at(t, 0.08, 0.32, Curves.easeOutBack),
                wave: _at(t, 0.15, 0.62),
                shine: _at(t, 0.62, 0.84, Curves.easeInOut),
                module: colors.textPrimary,
                eye: colors.accent,
                glint: colors.accentSoft.withValues(alpha: 0.45),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _Pop(
              shown: _at(t, 0.68, 0.95, Curves.easeOutBack),
              child: ArtChip(
                icon: Icons.offline_pin_rounded,
                label: OnboardingStrings.qrChip,
                color: colors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A code in the scanner's viewfinder: the scan line passes over it once, a
/// tick lands on its corner, and "Marked present" comes up underneath with
/// the sound the scanner makes.
class ScanArt extends StatelessWidget {
  const ScanArt({super.key, required this.t});

  final double t;

  static const double _viewfinder = 170;
  static const double _tile = 120;
  static const double _trail = 30;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final frame = _at(t, 0.00, 0.35, Curves.easeOutBack);
    final code = _at(t, 0.10, 0.42, Curves.easeOutBack);
    final scan = _at(t, 0.38, 0.72, Curves.easeInOut);
    final beam = math.sin(math.pi * scan);
    final tick = _at(t, 0.70, 0.86, Curves.easeOutBack);

    return SizedBox(
      width: 250,
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            child: SizedBox.square(
              dimension: 210,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _Glow(shown: frame, size: 210),
                  Opacity(
                    opacity: frame.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 1.3 - 0.3 * frame,
                      child: CustomPaint(
                        size: const Size.square(_viewfinder),
                        painter: ViewfinderPainter(color: colors.accent),
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: code.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.86 + 0.14 * code,
                      child: _CodeTile(
                        size: _tile,
                        scan: scan,
                        beam: beam,
                        trail: _trail,
                      ),
                    ),
                  ),
                  // The tick, on the tile's top-right corner.
                  Transform.translate(
                    offset: const Offset(_tile / 2 - 4, -_tile / 2 + 4),
                    child: Transform.scale(
                      scale: tick,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.success,
                          border: Border.all(color: colors.surface, width: 3),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: colors.canvas,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _Pop(
              shown: _at(t, 0.76, 1.00, Curves.easeOutBack),
              child: ArtChip(
                icon: Icons.volume_up_rounded,
                label: OnboardingStrings.scanChip,
                color: colors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A QR on a tile, with the scan line at [scan] down it.
class _CodeTile extends StatelessWidget {
  const _CodeTile({
    required this.size,
    required this.scan,
    required this.beam,
    required this.trail,
  });

  final double size;
  final double scan;
  final double beam;
  final double trail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.accentWash(0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          children: [
            Center(
              child: QrImageView(
                data: AppStrings.appName,
                version: QrVersions.auto,
                size: size - 28,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.transparent,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: colors.accent,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.circle,
                  color: colors.textPrimary,
                ),
              ),
            ),
            if (beam > 0)
              Positioned(
                left: 0,
                right: 0,
                top: size * scan - trail,
                height: trail + 2,
                child: Opacity(
                  opacity: beam.clamp(0.0, 1.0),
                  child: ScanBeam(trail: trail, palette: colors),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The tracker's calendar checking itself off, and a count of the days that
/// climbs with the ticks.
class DaysArt extends StatelessWidget {
  const DaysArt({super.key, required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ticks = _at(t, 0.36, 0.84);

    return SizedBox(
      width: 250,
      height: 250,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          SplashTile(
            shown: _at(t, 0.00, 0.28, Curves.easeOutBack),
            child: CustomPaint(
              painter: CalendarPainter(
                bar: _at(t, 0.08, 0.30, Curves.easeOutBack),
                days: _at(t, 0.15, 0.48),
                ticks: ticks,
                shine: _at(t, 0.80, 0.98, Curves.easeInOut),
                accent: colors.accent,
                late: colors.warning,
                day: colors.textPrimary.withValues(alpha: 0.10),
                ring: colors.textPrimary,
                check: colors.onAccent,
                glint: colors.accentSoft.withValues(alpha: 0.45),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _Pop(
              shown: _at(t, 0.34, 0.56, Curves.easeOutBack),
              child: ArtChip(
                icon: Icons.event_available_rounded,
                label: OnboardingStrings.daysChip(
                  CalendarPainter.checkedAt(ticks),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The accent glow behind a picture.
class _Glow extends StatelessWidget {
  const _Glow({required this.shown, required this.size});

  final double shown;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Opacity(
      opacity: shown.clamp(0.0, 1.0),
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [colors.accentWash(0.22), colors.accentWash(0)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pops [child] in — scaled up from small with an overshoot, fading in — as
/// [shown] runs 0 → 1.
class _Pop extends StatelessWidget {
  const _Pop({required this.shown, required this.child});

  final double shown;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (shown <= 0) return const SizedBox.shrink();
    return Opacity(
      opacity: shown.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, 10 * (1 - shown)),
        child: Transform.scale(scale: 0.6 + 0.4 * shown, child: child),
      ),
    );
  }
}

/// A small floating pill in a picture: an icon and a few words.
class ArtChip extends StatelessWidget {
  const ArtChip({
    super.key,
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;

  /// The icon's colour; the accent when left out.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = color ?? colors.accent;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 13, 7),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.35 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: tint),
          const SizedBox(width: 6),
          // Never wider than the picture, whatever the text size.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
