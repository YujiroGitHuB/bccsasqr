import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../services/student_repository.dart';

/// Says out loud that the app is running on bundled demo records.
///
/// Without this the fallback lies. A build with no `API_BASE_URL` answers a
/// real student number with "No verified record matches that student number"
/// — the same message a genuinely unknown number gets — so the obvious
/// conclusion is that the API is broken, when in fact the app never called it.
///
/// Renders nothing at all when the app is talking to a real backend.
///
/// [active] is decided by which repository is actually in use, not by whether
/// `API_BASE_URL` was defined — a test that injects its own repository is
/// connected to something real as far as the screen is concerned, and must not
/// be told otherwise.
class DemoModeBanner extends StatelessWidget {
  const DemoModeBanner({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    if (!active) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.science_outlined,
            size: 18,
            color: AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppStrings.demoModeTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  AppStrings.demoModeBody,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                // The numbers that actually work here, so whoever is testing
                // is not left guessing which ones are seeded.
                Text(
                  '${AppStrings.demoModeNumbers} '
                  '${InMemoryStudentRepository.sampleNumbers.join(' · ')}',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
