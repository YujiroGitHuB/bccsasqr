import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/scanner_models.dart';
import '../../widgets/app_header_card.dart';
import '../../widgets/surface_panel.dart';

/// The scanner's header: the app mark and the title — the web scanner's
/// `.scan-head`.
///
/// Who is signed in, the lock and the sign-out are in Settings → Account
/// (since 2026-09-30): the scanner keeps the room for the camera and the
/// class.
class ScannerHeader extends StatelessWidget {
  const ScannerHeader({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SurfacePanel(
      topAccent: true,
      padding: const EdgeInsets.fromLTRB(10, 12, 12, 12),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              tooltip: AppStrings.homeBack,
              icon: const Icon(Icons.arrow_back_rounded),
              color: colors.textSecondary,
            )
          else
            const SizedBox(width: 6),
          const BrandMark(size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ScannerStrings.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ScannerStrings.subtitle,
                  style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Admin / All sections, or Instructor, then the subject count and the ID.
class UserChips extends StatelessWidget {
  const UserChips({super.key, required this.user, this.subjectCount});

  final ScannerUser user;
  final int? subjectCount;

  @override
  Widget build(BuildContext context) {
    final count = subjectCount;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (user.isAdmin) ...const [
          _Chip(ScannerStrings.roleAdmin, emphasis: true),
          _Chip(ScannerStrings.roleAllSections, emphasis: true),
        ] else
          const _Chip(ScannerStrings.roleInstructor),
        if (count != null)
          _Chip('$count subject${count == 1 ? '' : 's'}', quiet: true),
        _Chip('ID ${user.id}', quiet: true),
      ],
    );
  }
}

/// The account's photo, or its initials on the accent wash when there is
/// none (or it fails to load).
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.size = 42});

  final ScannerUser user;
  final double size;

  String get _initials {
    final words = user.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);
    final initials = words.take(2).map((w) => w[0].toUpperCase()).join();
    return initials.isEmpty ? '?' : initials;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final initials = Center(
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
          color: colors.accent,
        ),
      ),
    );
    final url = user.avatarUrl;

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: colors.accentWash(0.14),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? initials
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => initials,
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
    final colors = context.colors;
    final color = emphasis
        ? colors.accent
        : quiet
        ? colors.textSecondary
        : colors.textPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: emphasis ? colors.accentWash(0.10) : colors.surfaceRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: emphasis ? colors.accentWash(0.35) : colors.border,
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
