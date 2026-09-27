import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/scanner_models.dart';
import '../../widgets/app_header_card.dart';
import '../../widgets/surface_panel.dart';

/// The scanner's header: the app mark and title with the account button,
/// then who is standing behind the camera — the web scanner's `.scan-head`
/// and `.instructor-info`.
///
/// Signing out lives behind the avatar, in the account sheet, rather than
/// on a bare icon one slip of the thumb away from the Back arrow.
class ScannerHeader extends StatelessWidget {
  const ScannerHeader({
    super.key,
    required this.user,
    required this.subjectCount,
    required this.onAccount,
    this.onBack,
  });

  final ScannerUser user;
  final int subjectCount;
  final VoidCallback onAccount;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SurfacePanel(
      topAccent: true,
      padding: const EdgeInsets.fromLTRB(10, 12, 12, 14),
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
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _AccountButton(user: user, onTap: onAccount),
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

/// The avatar in the corner, ringed in the accent — the app's way into the
/// account sheet, as in most apps a phone already has.
class _AccountButton extends StatelessWidget {
  const _AccountButton({required this.user, required this.onTap});

  final ScannerUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // The tooltip is for the eye; the label below already says "Account" to
    // a screen reader, which would otherwise hear it twice.
    return Tooltip(
      message: ScannerStrings.account,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: '${ScannerStrings.account}: ${user.name}',
        // Excluding the InkWell's own node drops its tap action with it, so
        // the action is given back here.
        onTap: onTap,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: colors.headerRule,
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surface,
              ),
              child: UserAvatar(user: user, size: 36),
            ),
          ),
        ),
      ),
    );
  }
}

/// Name and role chips — who the records are being filed under.
class _WhoIsScanning extends StatelessWidget {
  const _WhoIsScanning({required this.user, required this.subjectCount});

  final ScannerUser user;
  final int subjectCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          user.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        UserChips(user: user, subjectCount: subjectCount),
      ],
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
