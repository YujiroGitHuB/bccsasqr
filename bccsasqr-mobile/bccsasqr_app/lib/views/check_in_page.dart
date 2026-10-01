import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/check_in_controller.dart';
import '../controllers/profile_controller.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../models/class_link.dart';
import 'instructor_home.dart' show codeParts, shortTime;
import 'scanner/scanner_page.dart' show QrCameraBuilder;
import 'widgets/island.dart';
import 'widgets/surface_panel.dart';
import 'widgets/viewfinder.dart';

/// Check in — the student's side of an instructor's attendance link, inside
/// the app: read the class QR on the screen or board (or type the six
/// letters under it), see which class it is, and confirm. The student this
/// phone is set up for is sent; there is no number to type.
///
/// Before the phone is set up there is nobody to send, so the page asks for
/// My Profile first.
class CheckInPage extends StatefulWidget {
  const CheckInPage({
    super.key,
    required this.controller,
    required this.profile,
    required this.cameraBuilder,
    required this.onSetUp,
    this.onCheckedIn,
  });

  final CheckInController controller;
  final ProfileController profile;
  final QrCameraBuilder cameraBuilder;

  /// Opens My Profile.
  final VoidCallback onSetUp;

  /// After a check-in the records took — Home's attendance asks again.
  final VoidCallback? onCheckedIn;

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  final TextEditingController _field = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncField);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncField);
    _field.dispose();
    super.dispose();
  }

  /// A code read by the camera shows in the boxes too; a cleared one clears
  /// them.
  void _syncField() {
    final code = widget.controller.code;
    if (_field.text != code) {
      _field.value = TextEditingValue(
        text: code,
        selection: TextSelection.collapsed(offset: code.length),
      );
    }
  }

  Future<void> _confirm() async {
    FocusScope.of(context).unfocus();
    final controller = widget.controller;
    final result = await controller.confirm();
    if (!mounted) return;

    if (result == null) {
      final error = controller.error;
      if (error != null) {
        Island.show(
          context,
          IslandMessage(
            title: CheckInStrings.failedTitle,
            body: error,
            tone: IslandTone.error,
          ),
        );
      }
      return;
    }

    unawaited(HapticFeedback.mediumImpact());
    Island.show(
      context,
      IslandMessage(
        title: result.late
            ? CheckInStrings.doneLateTitle
            : CheckInStrings.doneTitle,
        body: '${result.subject} · ${shortTime(result.timeIn)}',
        tone: result.late ? IslandTone.warning : IslandTone.success,
        icon: Icons.how_to_reg_rounded,
        hold: const Duration(seconds: 4),
      ),
    );
    widget.onCheckedIn?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      key: const ValueKey('checkIn'),
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([widget.controller, widget.profile]),
          builder: (context, _) {
            final controller = widget.controller;
            final profile = widget.profile.profile;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                14,
                AppTheme.pagePadding,
                28 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        CheckInStrings.title,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CheckInStrings.subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!widget.profile.loaded)
                        const SizedBox.shrink()
                      else if (profile == null)
                        _SetUpFirst(onSetUp: widget.onSetUp)
                      else ...[
                        _Camera(
                          controller: controller,
                          cameraBuilder: widget.cameraBuilder,
                        ),
                        const SizedBox(height: 16),
                        _Divider(),
                        const SizedBox(height: 14),
                        _CodeBoxes(
                          field: _field,
                          enabled: !controller.busy,
                          onChanged: controller.onCodeTyped,
                        ),
                        if (controller.error case final error?
                            when controller.stage == CheckInStage.idle) ...[
                          const SizedBox(height: 12),
                          _ErrorLine(text: error),
                        ],
                        const SizedBox(height: 16),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOut,
                          alignment: Alignment.topCenter,
                          child: switch (controller.stage) {
                            CheckInStage.looking => const _Looking(),
                            CheckInStage.found ||
                            CheckInStage.sending => _ClassCard(
                              link: controller.link!,
                              name: profile.givenName,
                              number: profile.record.studentNumber.value,
                              sending: controller.stage == CheckInStage.sending,
                              onConfirm: _confirm,
                              onAnother: controller.reset,
                            ),
                            CheckInStage.idle => const SizedBox(
                              width: double.infinity,
                            ),
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The camera, framed — live while there is nothing else on screen, a green
/// tick once a code is read. Off whenever this tab is out of sight: the
/// shell stops its tickers, as it does for the scanner's camera.
class _Camera extends StatelessWidget {
  const _Camera({required this.controller, required this.cameraBuilder});

  final CheckInController controller;
  final QrCameraBuilder cameraBuilder;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final live = controller.cameraOn;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 228,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Always black behind the picture, in both themes — it is a
            // camera viewport.
            const ColoredBox(color: Color(0xFF000000)),
            if (live)
              Builder(
                builder: (context) => TickerMode.of(context)
                    ? cameraBuilder(context, controller.onScanned)
                    : const SizedBox.shrink(),
              )
            else
              Center(
                child: Container(
                  height: 54,
                  width: 54,
                  decoration: BoxDecoration(
                    color: colors.success,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 30,
                    color: AppPalette.dark.onAccent,
                  ),
                ),
              ),
            IgnorePointer(
              child: Center(
                child: SizedBox.square(
                  dimension: 164,
                  child: CustomPaint(
                    painter: ViewfinderPainter(color: colors.accent),
                  ),
                ),
              ),
            ),
            if (live)
              const Positioned(
                left: 12,
                right: 12,
                bottom: 14,
                child: Text(
                  CheckInStrings.cameraHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    // Over the camera's picture, in both themes.
                    color: Color(0xFFFFFFFF),
                    shadows: [Shadow(blurRadius: 6)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        Expanded(child: Divider(color: colors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            CheckInStrings.orType,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: colors.textSecondary,
            ),
          ),
        ),
        Expanded(child: Divider(color: colors.border)),
      ],
    );
  }
}

/// Six boxes over one field: the keyboard types into the field, the boxes
/// show its letters — so pasting a code, or deleting one, works as anywhere.
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({
    required this.field,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController field;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      label: CheckInStrings.orType,
      child: Stack(
        children: [
          ListenableBuilder(
            listenable: field,
            builder: (context, _) {
              final text = field.text;
              return Row(
                children: [
                  for (var i = 0; i < classCodeLength; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: i < text.length
                                ? colors.accentWash(0.55)
                                : colors.borderStrong,
                          ),
                        ),
                        child: Text(
                          i < text.length ? text[i] : '',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          // The field itself, invisible over the boxes: a tap anywhere on
          // them brings up the keyboard.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                key: const ValueKey('checkIn.code'),
                controller: field,
                enabled: enabled,
                onChanged: onChanged,
                autocorrect: false,
                enableSuggestions: false,
                showCursor: false,
                textCapitalization: TextCapitalization.characters,
                maxLength: classCodeLength,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                ],
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline_rounded, size: 18, color: colors.danger),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            key: const ValueKey('checkIn.error'),
            style: TextStyle(fontSize: 13, height: 1.4, color: colors.danger),
          ),
        ),
      ],
    );
  }
}

class _Looking extends StatelessWidget {
  const _Looking();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: colors.accent,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            CheckInStrings.looking,
            style: TextStyle(fontSize: 13.5, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// The class the code is for, and the one button that checks in.
class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.link,
    required this.name,
    required this.number,
    required this.sending,
    required this.onConfirm,
    required this.onAnother,
  });

  final ClassLink link;
  final String name;
  final String number;
  final bool sending;
  final VoidCallback onConfirm;
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (head, tail) = codeParts(link.subjectCode, link.subjectName);
    final lateLabel = link.lateLabel;
    final closes = link.closesLabel;

    return Column(
      key: const ValueKey('checkIn.class'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SurfacePanel(
          borderColor: colors.accentWash(0.35),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: colors.surfaceSunken,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          head,
                          style: TextStyle(
                            fontSize: tail == null ? 12 : 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: colors.accent,
                          ),
                        ),
                        if (tail != null)
                          Text(
                            tail,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          link.subjectName,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CheckInStrings.section(link.section, link.instructor),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if ((link.lateOn && lateLabel != null) || closes != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (link.lateOn && lateLabel != null)
                      _Pill(
                        icon: Icons.schedule_rounded,
                        label: link.lateNow
                            ? CheckInStrings.lateNow
                            : CheckInStrings.onTimeUntil(lateLabel),
                        tint: link.lateNow ? colors.warning : colors.success,
                      ),
                    if (closes != null)
                      _Pill(label: CheckInStrings.closes(closes)),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const ValueKey('checkIn.confirm'),
                onPressed: sending ? null : onConfirm,
                icon: sending
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: colors.onAccent,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  sending
                      ? CheckInStrings.checkingIn
                      : CheckInStrings.confirm(name),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          CheckInStrings.sends(number),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
        TextButton.icon(
          key: const ValueKey('checkIn.another'),
          onPressed: sending ? null : onAnother,
          icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
          label: const Text(CheckInStrings.another),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.icon, this.tint});

  final String label;
  final IconData? icon;

  /// A state's colour — on time or late — or none, for a plain fact.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = this.tint;
    final icon = this.icon;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint?.withValues(alpha: 0.12) ?? colors.surfaceSunken,
        borderRadius: BorderRadius.circular(999),
        border: tint == null ? Border.all(color: colors.border) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: tint ?? colors.textSecondary),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: tint ?? colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Nobody to check in yet: My Profile first.
class _SetUpFirst extends StatelessWidget {
  const _SetUpFirst({required this.onSetUp});

  final VoidCallback onSetUp;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SurfacePanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.badge_outlined, size: 30, color: colors.accent),
          const SizedBox(height: 10),
          Text(
            CheckInStrings.setUpTitle,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            CheckInStrings.setUpBody,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const ValueKey('checkIn.setUp'),
            onPressed: onSetUp,
            icon: const Icon(Icons.account_circle_outlined),
            label: const Text(CheckInStrings.setUpAction),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
