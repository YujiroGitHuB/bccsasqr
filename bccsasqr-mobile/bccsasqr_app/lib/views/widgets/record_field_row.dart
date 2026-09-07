import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';

/// One locked read-only row inside the record box (NAME / COURSE / SECTION).
///
/// The padlock communicates that the value comes from the verified enrolment
/// list and cannot be typed over.
class RecordFieldRow extends StatelessWidget {
  const RecordFieldRow({
    super.key,
    required this.label,
    required this.value,
    this.loading = false,
  });

  final String label;
  final String? value;
  final bool loading;

  bool get _filled => value != null && value!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            _filled ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
            size: 13,
            color: _filled ? AppColors.accent : AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: loading
                ? const _ValueShimmer()
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    // Default switcher layout centres children; these values
                    // must stay flush with the left edge of the column.
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.centerLeft,
                      children: [...previous, ?current],
                    ),
                    child: Text(
                      _filled ? value! : AppStrings.emptyValue,
                      key: ValueKey(value ?? '_'),
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.3,
                        fontWeight: _filled ? FontWeight.w600 : FontWeight.w400,
                        color: _filled
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Pulsing placeholder bar shown while a lookup is in flight.
class _ValueShimmer extends StatefulWidget {
  const _ValueShimmer();

  @override
  State<_ValueShimmer> createState() => _ValueShimmerState();
}

class _ValueShimmerState extends State<_ValueShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.25, end: 0.6).animate(_controller),
      child: Container(
        height: 11,
        margin: const EdgeInsets.only(top: 3, right: 40),
        decoration: BoxDecoration(
          color: AppColors.borderStrong,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
