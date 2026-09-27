import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../models/app_role.dart';
import 'widgets/app_header_card.dart';
import 'widgets/destination_card.dart';

/// The first launch's one question: student or instructor. The answer is
/// kept, so it is asked once — and again only from Settings → Role.
class RolePickerPage extends StatelessWidget {
  const RolePickerPage({super.key, required this.onChosen});

  final ValueChanged<AppRole> onChosen;

  static const double _maxContentWidth = 560;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      body: SafeArea(
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
                  const BrandHeading(),
                  const SizedBox(height: 36),
                  Text(
                    RoleStrings.question,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DestinationCard(
                    key: const ValueKey('role.student'),
                    icon: Icons.school_outlined,
                    title: RoleStrings.studentTitle,
                    body: RoleStrings.studentBody,
                    onTap: () => onChosen(AppRole.student),
                  ),
                  const SizedBox(height: 12),
                  DestinationCard(
                    key: const ValueKey('role.instructor'),
                    icon: Icons.badge_outlined,
                    title: RoleStrings.instructorTitle,
                    body: RoleStrings.instructorBody,
                    onTap: () => onChosen(AppRole.instructor),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    RoleStrings.hint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
