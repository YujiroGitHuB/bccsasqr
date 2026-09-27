import 'package:flutter/material.dart';

import '../../controllers/scanner_controller.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/app_header_card.dart';
import '../widgets/surface_panel.dart';

/// The instructor's email and password — the same account as the web system,
/// checked by the same rules (`crud/login_process.php`).
class ScannerSignInPage extends StatefulWidget {
  const ScannerSignInPage({
    super.key,
    required this.controller,
    this.demo = false,
    this.onBack,
  });

  final ScannerController controller;
  final bool demo;

  /// The arrow above the form: back to the student-or-instructor question.
  /// Without it, the arrow is there only when a page is under this one.
  final VoidCallback? onBack;

  @override
  State<ScannerSignInPage> createState() => _ScannerSignInPageState();
}

class _ScannerSignInPageState extends State<ScannerSignInPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    widget.controller.signIn(email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final VoidCallback? back =
        widget.onBack ??
        (Navigator.of(context).canPop()
            ? () => Navigator.of(context).maybePop()
            : null);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.pagePadding,
            vertical: 12,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              // The form rises into place as the splash fades out. Played
              // once: rebuilding with the same end value does not replay it.
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, 24 * (1 - t)),
                    child: child,
                  ),
                ),
                child: ListenableBuilder(
                  listenable: c,
                  builder: (context, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (back != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            key: const ValueKey('signIn.back'),
                            onPressed: back,
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 18,
                            ),
                            label: Text(
                              widget.onBack != null
                                  ? RoleStrings.signInBack
                                  : AppStrings.homeBack,
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: context.colors.textSecondary,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      SurfacePanel(
                        topAccent: true,
                        padding: const EdgeInsets.all(20),
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const BrandMark(size: 40),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ScannerStrings.title,
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            color: context.colors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          ScannerStrings.subtitle,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: context.colors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              Text(
                                ScannerStrings.signInHeading,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: context.colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                ScannerStrings.signInBody,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: context.colors.textSecondary,
                                ),
                              ),
                              if (c.sessionMessage case final message?) ...[
                                const SizedBox(height: 14),
                                _Callout(
                                  text: message,
                                  color: context.colors.warning,
                                ),
                              ],
                              if (widget.demo) ...[
                                const SizedBox(height: 14),
                                _Callout(
                                  text: ScannerStrings.demoSignInHint,
                                  color: context.colors.warning,
                                ),
                              ],
                              const SizedBox(height: 18),
                              TextField(
                                controller: _email,
                                enabled: !c.isSigningIn,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [
                                  AutofillHints.email,
                                  AutofillHints.username,
                                ],
                                autocorrect: false,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  hintText: ScannerStrings.emailLabel,
                                  prefixIcon: Icon(Icons.mail_outline_rounded),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _password,
                                enabled: !c.isSigningIn,
                                obscureText: _hidePassword,
                                autofillHints: const [AutofillHints.password],
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  hintText: ScannerStrings.passwordLabel,
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                  ),
                                  suffixIcon: IconButton(
                                    tooltip: _hidePassword
                                        ? ScannerStrings.showPassword
                                        : ScannerStrings.hidePassword,
                                    onPressed: () => setState(
                                      () => _hidePassword = !_hidePassword,
                                    ),
                                    icon: Icon(
                                      _hidePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              if (c.signInError case final error?) ...[
                                const SizedBox(height: 12),
                                Text(
                                  error,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: context.colors.danger,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              FilledButton(
                                onPressed: c.isSigningIn ? null : _submit,
                                child: c.isSigningIn
                                    ? const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          Text(ScannerStrings.signingIn),
                                        ],
                                      )
                                    : const Text(ScannerStrings.signIn),
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
          ),
        ),
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12.5, height: 1.4, color: color),
      ),
    );
  }
}
