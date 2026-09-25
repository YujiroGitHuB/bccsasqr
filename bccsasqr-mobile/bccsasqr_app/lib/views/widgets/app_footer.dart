import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key, required this.onOpenDeveloper});

  final VoidCallback onOpenDeveloper;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 16),
        const Text(
          AppStrings.footerRights,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              AppStrings.footerDeveloper,
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
            GestureDetector(
              onTap: onOpenDeveloper,
              child: const Text(
                AppStrings.footerDeveloperName,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
