import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import 'surface_panel.dart';

/// One reassurance chip in the header.
typedef HeaderChip = ({IconData icon, String label});

/// Branded header: app mark, title, tagline and the reassurance chips. The
/// generator's words unless a page brings its own — the tracker does.
class AppHeaderCard extends StatelessWidget {
  const AppHeaderCard({
    super.key,
    this.title = AppStrings.appTitle,
    this.tagline = AppStrings.appTagline,
    this.chips = generatorChips,
  });

  final String title;
  final String tagline;
  final List<HeaderChip> chips;

  static const List<HeaderChip> generatorChips = [
    (icon: Icons.verified_user_outlined, label: AppStrings.chipVerified),
    (icon: Icons.download_outlined, label: AppStrings.chipFreeDownload),
  ];

  @override
  Widget build(BuildContext context) {
    final identity = _Identity(title: title, tagline: tagline);
    final chipRow = _HeaderChips(chips: chips);

    return SurfacePanel(
      topAccent: true,
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Chips move under the title once the header gets narrow.
          final stacked = constraints.maxWidth < 560;

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [identity, const SizedBox(height: 16), chipRow],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: identity),
              const SizedBox(width: 16),
              chipRow,
            ],
          );
        },
      ),
    );
  }
}

/// App mark plus the title block, kept together so both layouts reuse it.
class _Identity extends StatelessWidget {
  const _Identity({required this.title, required this.tagline});

  final String title;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BrandMark(),
        const SizedBox(width: 14),
        Expanded(
          child: _TitleBlock(title: title, tagline: tagline),
        ),
      ],
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.title, required this.tagline});

  final String title;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tagline,
          style: TextStyle(
            fontSize: 13,
            color: context.colors.textSecondary,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

/// The school seal on the cyan tile — the app's mark, on the generator's
/// header, the opening screen and the scanner.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 46});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        gradient: AppPalette.brandMark,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: context.colors.accentWash(0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // The school seal, as on the web hero (.qr-hero-icon: 34px in 52px).
      alignment: Alignment.center,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.15),
        child: Image.asset(
          AppAssets.bccLogo,
          width: size * 0.65,
          height: size * 0.65,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _HeaderChips extends StatelessWidget {
  const _HeaderChips({required this.chips});

  final List<HeaderChip> chips;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final chip in chips)
          _HeaderChip(icon: chip.icon, label: chip.label),
      ],
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.surfaceRaised,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: context.colors.borderStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.colors.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
