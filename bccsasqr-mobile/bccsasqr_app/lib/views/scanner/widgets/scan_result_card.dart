import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/scanner_models.dart';
import '../../widgets/surface_panel.dart';
import 'attendance_panel.dart';

/// Who was just recorded: face, name, course and section, the subject, and
/// the time the server stored — the web scanner's `#studentCard`.
///
/// The face is the point. It is the instructor's only way to see that the
/// person holding the QR is the person it belongs to, so a record with no
/// photo says so in amber instead of letting initials pass for one.
class ScanResultCard extends StatelessWidget {
  const ScanResultCard({super.key, required this.record});

  final ScanRecord record;

  @override
  Widget build(BuildContext context) {
    final warn = record.photoMissing;

    return SurfacePanel(
      // Amber for anything the instructor should notice — late, or no face
      // to check — the same colour the status line uses for it.
      borderColor: (warn || record.late ? AppColors.warning : AppColors.success)
          .withValues(alpha: 0.45),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          StudentAvatar(
            name: record.name,
            photoUrl: record.photoUrl,
            badge: warn ? AppColors.warning : AppColors.success,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.name,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (record.courseAndSection.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    record.courseAndSection,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                _SubjectBadge(
                  text: warn ? ScannerStrings.noPhoto : '✓ ${record.subject}',
                  warn: warn,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                record.timeIn,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              if (record.late)
                const LateTag()
              else
                Text(
                  record.date,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.accent,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubjectBadge extends StatelessWidget {
  const _SubjectBadge({required this.text, required this.warn});

  final String text;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final color = warn ? AppColors.warning : AppColors.accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// The student's photo, or their initials when there is none (or it fails to
/// load), with a small badge in the outcome's colour.
class StudentAvatar extends StatelessWidget {
  const StudentAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.badge,
    this.size = 60,
  });

  final String name;
  final String? photoUrl;
  final Color? badge;
  final double size;

  /// "GARCIA, MICAELLA JANE V." → "GM", as the web card does it.
  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final initials = words.take(2).map((w) => w[0].toUpperCase()).join();
    return initials.isEmpty ? '?' : initials;
  }

  @override
  Widget build(BuildContext context) {
    final initials = Center(
      child: Text(
        initialsOf(name),
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
          color: AppColors.accent,
        ),
      ),
    );

    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: size,
            width: size,
            decoration: BoxDecoration(
              color: AppColors.accentWash(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accentWash(0.35), width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: photoUrl == null
                ? initials
                : Image.network(
                    photoUrl!,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                    errorBuilder: (_, _, _) => initials,
                  ),
          ),
          if (badge != null)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                height: size * 0.36,
                width: size * 0.36,
                decoration: BoxDecoration(
                  color: badge,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: Icon(
                  badge == AppColors.success
                      ? Icons.check_rounded
                      : Icons.priority_high_rounded,
                  size: size * 0.22,
                  color: AppColors.canvas,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
