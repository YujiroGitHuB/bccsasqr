import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';

/// Consent row — tapping the box or the sentence toggles; only the underlined
/// link opens the terms.
class TermsCheckbox extends StatefulWidget {
  const TermsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onOpenTerms,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenTerms;

  @override
  State<TermsCheckbox> createState() => _TermsCheckboxState();
}

class _TermsCheckboxState extends State<TermsCheckbox> {
  /// Owned by the state so it is disposed with the widget rather than
  /// re-created (and leaked) on every build.
  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()
    ..onTap = () => widget.onOpenTerms();

  @override
  void dispose() {
    _termsTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: widget.value ? AppColors.accentWash(0.45) : AppColors.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: () => widget.onChanged(!widget.value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  height: 22,
                  width: 22,
                  child: Checkbox(
                    value: widget.value,
                    onChanged: (v) => widget.onChanged(v ?? false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.textPrimary,
                      ),
                      children: [
                        const TextSpan(text: AppStrings.agreePrefix),
                        TextSpan(
                          text: AppStrings.termsLink,
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.accent,
                          ),
                          recognizer: _termsTap,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
