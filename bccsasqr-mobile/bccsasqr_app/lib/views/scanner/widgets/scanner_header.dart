import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/scanner_models.dart';
import '../../widgets/app_header_card.dart';
import '../../widgets/surface_panel.dart';

/// The scanner's header: the app mark and title, then who is standing behind
/// the camera — the web scanner's `.scan-head` and `.instructor-info`.
class ScannerHeader extends StatelessWidget {
  const ScannerHeader({
    super.key,
    required this.user,
    required this.subjectCount,
    required this.onSignOut,
    this.onBack,
  });

  final ScannerUser user;
  final int subjectCount;
  final VoidCallback onSignOut;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      topAccent: true,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (onBack != null)
                IconButton(
                  onPressed: onBack,
                  tooltip: AppStrings.homeBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: AppColors.textSecondary,
                )
              else
                const SizedBox(width: 6),
              const BrandMark(size: 40),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ScannerStrings.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      ScannerStrings.subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onSignOut,
                tooltip: ScannerStrings.signOut,
                icon: const Icon(Icons.logout_rounded),
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _WhoIsScanning(user: user, subjectCount: subjectCount),
          ),
        ],
      ),
    );
  }
}

/// Face on the left, name and role chips on the right.
class _WhoIsScanning extends StatelessWidget {
  const _WhoIsScanning({required this.user, required this.subjectCount});

  final ScannerUser user;
  final int subjectCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Avatar(url: user.avatarUrl),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (user.isAdmin) ...const [
                    _Chip(ScannerStrings.roleAdmin, emphasis: true),
                    _Chip(ScannerStrings.roleAllSections, emphasis: true),
                  ] else
                    const _Chip(ScannerStrings.roleInstructor),
                  _Chip(
                    '$subjectCount subject${subjectCount == 1 ? '' : 's'}',
                    quiet: true,
                  ),
                  _Chip('ID ${user.id}', quiet: true),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.url});

  final String? url;

  static const double _size = 42;

  @override
  Widget build(BuildContext context) {
    const fallback = Icon(
      Icons.person_rounded,
      color: AppColors.textSecondary,
      size: 24,
    );

    return Container(
      height: _size,
      width: _size,
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderStrong),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: url == null
          ? fallback
          : Image.network(
              url!,
              width: _size,
              height: _size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {this.emphasis = false, this.quiet = false});

  final String label;

  /// The admin chips, tinted so "All sections" is seen at a glance.
  final bool emphasis;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final color = emphasis
        ? AppColors.accent
        : quiet
        ? AppColors.textSecondary
        : AppColors.textPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: emphasis ? AppColors.accentWash(0.10) : AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: emphasis ? AppColors.accentWash(0.35) : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
