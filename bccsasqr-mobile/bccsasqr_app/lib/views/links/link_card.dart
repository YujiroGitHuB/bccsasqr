import 'package:flutter/material.dart';

import '../../controllers/links_controller.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/attendance_link.dart';
import '../widgets/press_scale.dart';

/// "1h 05m 09s" — the web page's humanLeft(). Seconds are padded, and with
/// tabular figures the countdown stands still instead of jittering.
String linkTimeLeft(int seconds) {
  if (seconds <= 0) return 'closed';

  final d = seconds ~/ 86400;
  final h = (seconds % 86400) ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String pad(int n) => n.toString().padLeft(2, '0');

  // At a day or more, seconds are noise.
  if (d > 0) return '${d}d ${h}h ${pad(m)}m';
  if (h > 0) return '${h}h ${pad(m)}m ${pad(s)}s';
  if (m > 0) return '${m}m ${pad(s)}s';
  return '${s}s';
}

/// What a card's buttons do; the page decides how.
class LinkCardActions {
  const LinkCardActions({
    required this.onQr,
    required this.onCopy,
    required this.onShare,
    required this.onOpen,
    required this.onExpiry,
    required this.onExtend,
    required this.onLate,
    required this.onRenew,
  });

  final VoidCallback onQr;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onOpen;
  final VoidCallback onExpiry;
  final VoidCallback onExtend;
  final VoidCallback onLate;
  final VoidCallback onRenew;
}

/// One class's link: the web page's card, top to bottom — section and code,
/// the subject, the address, when it closes and when late starts, and the
/// buttons. Tapping the card opens its QR code, the thing a class needs.
class LinkCard extends StatelessWidget {
  const LinkCard({
    super.key,
    required this.link,
    required this.controller,
    required this.actions,
  });

  final AttendanceLink link;
  final LinksController controller;
  final LinkCardActions actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final expired = controller.isExpired(link);
    final busy = controller.isBusy(link);
    // An admin's own classes stand out among everyone's, as on the web.
    final highlight = controller.admin && link.mine;

    return PressScale(
      scale: 0.985,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          side: BorderSide(
            color: highlight
                ? colors.success.withValues(alpha: 0.45)
                : colors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('link.${link.shortCode}'),
          onTap: actions.onQr,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Wraps rather than squeezing the code pill: a long
                    // section name goes to a second line.
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _Badge(text: link.section),
                          Text(
                            link.subjectCode,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                            ),
                          ),
                          if (highlight)
                            _Badge(
                              text: LinksStrings.mine,
                              color: colors.success,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CodePill(code: link.shortCode, dim: expired),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  link.subjectName,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: colors.textPrimary,
                  ),
                ),
                if (controller.admin) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.person_rounded,
                        size: 14,
                        color: colors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          link.instructor,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                _Address(url: link.url, dim: expired),
                const SizedBox(height: 12),
                _TimeGroup(
                  children: [
                    _expiryRow(context, expired, busy),
                    // A closed link takes no submissions: nothing to mark.
                    if (!expired) _lateRow(context, busy),
                  ],
                ),
                const SizedBox(height: 10),
                _buttons(context, busy),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _expiryRow(BuildContext context, bool expired, bool busy) {
    final at = link.expiry.short ?? link.expiry.label;

    if (expired) {
      // Two answers, and they differ: Extend is the same class running
      // over, and keeps the address the students in front of you have. New
      // link is a new class, and kills the one in the group chat. New link
      // comes first — the next class is the more common case.
      return _TimeRow(
        tone: _Tone.bad,
        icon: Icons.block_rounded,
        label: LinksStrings.closedLabel,
        value: const TextSpan(text: LinksStrings.expired),
        meta: at,
        actions: [
          _SmallButton(
            key: ValueKey('link.renew.${link.shortCode}'),
            label: LinksStrings.newLink,
            icon: Icons.autorenew_rounded,
            filled: true,
            onPressed: busy ? null : actions.onRenew,
          ),
          _SmallButton(
            key: ValueKey('link.extend.${link.shortCode}'),
            label: LinksStrings.extend,
            icon: Icons.more_time_rounded,
            onPressed: busy ? null : actions.onExtend,
          ),
        ],
      );
    }

    final left = controller.expiresIn(link);
    if (left == null) {
      return _TimeRow(
        tone: _Tone.none,
        icon: Icons.all_inclusive_rounded,
        label: LinksStrings.closesLabel,
        value: const TextSpan(text: LinksStrings.noExpiry),
        actions: [
          _edit(LinksStrings.set, false, busy, actions.onExpiry, 'expiry'),
        ],
      );
    }

    return _TimeRow(
      tone: left <= 900 ? _Tone.warn : _Tone.ok,
      icon: Icons.hourglass_top_rounded,
      label: LinksStrings.closesLabel,
      value: TextSpan(
        children: [
          const TextSpan(text: LinksStrings.closesInPrefix),
          TextSpan(
            text: linkTimeLeft(left),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
      meta: at,
      semanticsValue: '${LinksStrings.closesIn(linkTimeLeft(left))}, $at',
      actions: [
        _edit(LinksStrings.edit, true, busy, actions.onExpiry, 'expiry'),
      ],
    );
  }

  Widget _lateRow(BuildContext context, bool busy) {
    final label = link.late.label ?? '';

    if (!link.late.on) {
      return _TimeRow(
        tone: _Tone.none,
        icon: Icons.alarm_rounded,
        label: LinksStrings.lateLabel,
        value: const TextSpan(text: LinksStrings.lateOff),
        meta: LinksStrings.lateOffMeta,
        actions: [_edit(LinksStrings.set, false, busy, actions.onLate, 'late')],
      );
    }

    final late = controller.isLate(link);
    return _TimeRow(
      tone: late ? _Tone.warn : _Tone.ok,
      icon: late ? Icons.alarm_on_rounded : Icons.alarm_rounded,
      label: LinksStrings.lateLabel,
      value: TextSpan(
        children: [
          TextSpan(
            text: late
                ? LinksStrings.lateAfterPrefix
                : LinksStrings.onTimeUntilPrefix,
          ),
          TextSpan(
            text: label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
      semanticsValue: late
          ? LinksStrings.lateAfter(label)
          : LinksStrings.onTimeUntil(label),
      actions: [_edit(LinksStrings.edit, true, busy, actions.onLate, 'late')],
    );
  }

  /// "+ Set" when nothing is set, "Edit" once something is.
  Widget _edit(
    String label,
    bool isSet,
    bool busy,
    VoidCallback onPressed,
    String what,
  ) => _SmallButton(
    key: ValueKey('link.$what.${link.shortCode}'),
    label: label,
    icon: isSet ? Icons.edit_rounded : Icons.add_rounded,
    onPressed: busy ? null : onPressed,
  );

  Widget _buttons(BuildContext context, bool busy) {
    final colors = context.colors;

    // One labelled button — the QR code, what a class needs — and the rest
    // as icons: two labelled buttons side by side wrap their words on a
    // 360-wide phone.
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: ValueKey('link.qr.${link.shortCode}'),
            onPressed: actions.onQr,
            icon: const Icon(Icons.qr_code_2_rounded, size: 20),
            label: const Text(LinksStrings.qr),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          key: ValueKey('link.copy.${link.shortCode}'),
          onPressed: actions.onCopy,
          tooltip: LinksStrings.copyLink,
          icon: const Icon(Icons.content_copy_rounded, size: 20),
          color: colors.textSecondary,
        ),
        IconButton(
          key: ValueKey('link.share.${link.shortCode}'),
          onPressed: actions.onShare,
          tooltip: LinksStrings.share,
          icon: const Icon(Icons.share_rounded, size: 20),
          color: colors.textSecondary,
        ),
        if (busy)
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.accent,
              ),
            ),
          )
        else
          PopupMenuButton<VoidCallback>(
            key: ValueKey('link.more.${link.shortCode}'),
            tooltip: LinksStrings.more,
            icon: Icon(Icons.more_vert_rounded, color: colors.textSecondary),
            color: colors.surfaceRaised,
            onSelected: (run) => run(),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: actions.onOpen,
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.open_in_new_rounded),
                  title: Text(LinksStrings.openInBrowser),
                ),
              ),
              PopupMenuItem(
                key: ValueKey('link.menu.renew.${link.shortCode}'),
                value: actions.onRenew,
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.autorenew_rounded),
                  title: Text(LinksStrings.newLink),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// How a time row reads: nothing set, fine, soon, closed.
enum _Tone { none, ok, warn, bad }

/// The expiry and the late cutoff, as one small settings list — the web's
/// `.lnk-time` group.
class _TimeGroup extends StatelessWidget {
  const _TimeGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: colors.border),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.tone,
    required this.icon,
    required this.label,
    required this.value,
    required this.actions,
    this.meta,
    this.semanticsValue,
  });

  final _Tone tone;
  final IconData icon;

  /// What the row is — always the same words.
  final String label;

  /// Its current setting: the part that changes.
  final InlineSpan value;

  /// The exact time, muted, after the value.
  final String? meta;
  final String? semanticsValue;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = switch (tone) {
      _Tone.none => colors.textMuted,
      _Tone.ok => colors.success,
      _Tone.warn => colors.warning,
      _Tone.bad => colors.danger,
    };

    // One button sits at the end of the row; two — New link and Extend —
    // go under the words, where they have the width to themselves.
    final trailing = actions.length == 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tone == _Tone.none
                  ? colors.surfaceRaised
                  : color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: label,
                  value: semanticsValue,
                  excludeSemantics: semanticsValue != null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: colors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            value,
                            if (meta case final meta? when meta.isNotEmpty)
                              TextSpan(
                                // A no-break space after the dot: when the
                                // line wraps, the dot goes down with the
                                // time instead of trailing.
                                text: '  · $meta',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: colors.textMuted,
                                ),
                              ),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: 13.5,
                          color: tone == _Tone.none
                              ? colors.textSecondary
                              : color,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!trailing)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(spacing: 8, runSpacing: 6, children: actions),
                  ),
              ],
            ),
          ),
          if (trailing) ...[const SizedBox(width: 6), actions.single],
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const padding = EdgeInsets.symmetric(horizontal: 10);
    const size = Size(0, 34);
    const text = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700);

    if (filled) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: FilledButton.styleFrom(
          padding: padding,
          minimumSize: size,
          textStyle: text,
          visualDensity: VisualDensity.compact,
        ),
      );
    }
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        padding: padding,
        minimumSize: size,
        textStyle: text,
        foregroundColor: colors.accent,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint?.withValues(alpha: 0.14) ?? colors.surfaceRaised,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: tint?.withValues(alpha: 0.45) ?? colors.borderStrong,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: tint ?? colors.textSecondary,
        ),
      ),
    );
  }
}

/// The six-character code — what students type if they cannot scan.
class _CodePill extends StatelessWidget {
  const _CodePill({required this.code, required this.dim});

  final String code;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ink = dim ? colors.textMuted : colors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: dim ? colors.surfaceRaised : colors.accentWash(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ink.withValues(alpha: 0.4)),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
          color: ink,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _Address extends StatelessWidget {
  const _Address({required this.url, required this.dim});

  final String url;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.link_rounded, size: 16, color: colors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                fontFamily: 'monospace',
                decoration: dim ? TextDecoration.lineThrough : null,
                color: dim ? colors.textMuted : colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
