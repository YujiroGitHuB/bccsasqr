import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import 'surface_panel.dart';

/// Branded header: app mark, title, tagline and the two reassurance chips.
class AppHeaderCard extends StatelessWidget {
  const AppHeaderCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      topAccent: true,
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Chips move under the title once the header gets narrow.
          final stacked = constraints.maxWidth < 560;

          if (stacked) {
            return const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_Identity(), SizedBox(height: 16), _HeaderChips()],
            );
          }

          return const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Identity()),
              SizedBox(width: 16),
              _HeaderChips(),
            ],
          );
        },
      ),
    );
  }
}

/// App mark plus the title block, kept together so both layouts reuse it.
class _Identity extends StatelessWidget {
  const _Identity();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BrandMark(),
        SizedBox(width: 14),
        Expanded(child: _TitleBlock()),
      ],
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          AppStrings.appTitle,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppStrings.appTagline,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      width: 46,
      decoration: BoxDecoration(
        gradient: AppColors.brandMark,
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentWash(0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.diamond_outlined, size: 24, color: Colors.white),
    );
  }
}

class _HeaderChips extends StatelessWidget {
  const _HeaderChips();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _HeaderChip(
          icon: Icons.verified_user_outlined,
          label: AppStrings.chipVerified,
        ),
        _HeaderChip(
          icon: Icons.download_outlined,
          label: AppStrings.chipFreeDownload,
        ),
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
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
