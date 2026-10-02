import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';

/// "Absent" where a day's time would be: a day the student's class met
/// without them. The Late tag's shape (attendance_panel.dart) in red, the
/// colour the records keep for absent.
class AbsentTag extends StatelessWidget {
  const AbsentTag({super.key});

  @override
  Widget build(BuildContext context) {
    final danger = context.colors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: danger.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: danger.withValues(alpha: 0.45)),
      ),
      child: Text(
        TrackerStrings.absentTag,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: danger,
        ),
      ),
    );
  }
}
