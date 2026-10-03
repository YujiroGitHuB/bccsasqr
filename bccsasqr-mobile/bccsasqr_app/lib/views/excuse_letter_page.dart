import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/date_label.dart';
import '../models/attendance_history.dart';
import '../models/excuse_letter.dart';
import 'widgets/island.dart';
import 'widgets/splash_parts.dart';
import 'widgets/surface_panel.dart';

/// Hands the letter to the phone's share sheet — Messenger, Gmail — with its
/// subject line for an email app to take.
Future<void> deviceShareLetter(String text, String subject) async {
  await SharePlus.instance.share(ShareParams(text: text, subject: subject));
}

/// An excuse letter for days missed in one subject, opened from a day marked
/// Absent in My Attendance. The student picks the days and the reason, and
/// the letter is written from the record — subject, class, instructor and
/// dates — ready to copy or share. A template ([ExcuseLetter]), so it works
/// offline, on any phone, with nothing to download.
///
/// The letter is the student's to change: once they edit it, the choices
/// above stop rewriting it, and Start over brings back the letter the
/// choices make.
class ExcuseLetterPage extends StatefulWidget {
  const ExcuseLetterPage({
    super.key,
    required this.history,
    required this.subject,
    required this.date,
    this.now = DateTime.now,
    this.share = deviceShareLetter,
  });

  final AttendanceHistory history;

  /// The subject the day was missed in. Its other missed days are offered
  /// too: one letter can cover them all.
  final SubjectAttendance subject;

  /// The day tapped, chosen to begin with.
  final DateTime date;

  /// The day the letter is dated; tests fix it.
  final DateTime Function() now;

  final Future<void> Function(String text, String subject) share;

  @override
  State<ExcuseLetterPage> createState() => _ExcuseLetterPageState();
}

class _ExcuseLetterPageState extends State<ExcuseLetterPage>
    with SingleTickerProviderStateMixin {
  static const double _maxContentWidth = 640;

  /// Made in initState, not lazily, like every controller a screen owns.
  late final AnimationController _intro;
  late final List<Animation<double>> _pieces;
  late final TextEditingController _note;
  late final TextEditingController _letter;

  late final Set<DateTime> _days;
  ExcuseReason _reason = ExcuseReason.sick;

  /// The letter the choices make as they stand — what the field holds until
  /// the student edits it.
  late String _template;

  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _pieces = [
      for (var i = 0; i < 6; i++)
        CurvedAnimation(
          parent: _intro,
          curve: Interval(
            0.08 * i,
            (0.08 * i + 0.5).clamp(0.0, 1.0),
            curve: Curves.easeOutCubic,
          ),
        ),
    ];
    _days = {widget.date};
    _note = TextEditingController();
    _template = _draft().text;
    _letter = TextEditingController(text: _template);
  }

  @override
  void dispose() {
    _intro.dispose();
    _note.dispose();
    _letter.dispose();
    super.dispose();
  }

  ExcuseLetter _draft() => ExcuseLetter.forSubject(
    history: widget.history,
    subject: widget.subject,
    dates: _days,
    reason: _reason,
    written: widget.now(),
    note: _note.text,
  );

  /// Applies [change] to the choices. A letter the student has not touched
  /// follows them; an edited one is theirs, and stays as it is.
  void _choose(VoidCallback change) {
    final untouched = _letter.text == _template;
    setState(() {
      change();
      _template = _draft().text;
    });
    if (untouched) _letter.text = _template;
  }

  void _toggle(DateTime day) {
    if (!_days.contains(day)) {
      _choose(() => _days.add(day));
    } else if (_days.length > 1) {
      // One day at least: a letter about no day is no letter.
      _choose(() => _days.remove(day));
    }
  }

  void _copy() {
    unawaited(Clipboard.setData(ClipboardData(text: _letter.text)));
    Island.show(
      context,
      const IslandMessage(
        title: ExcuseLetterStrings.copied,
        body: ExcuseLetterStrings.copiedBody,
        tone: IslandTone.success,
        icon: Icons.content_copy_rounded,
      ),
    );
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      await widget.share(_letter.text, _draft().subjectLine);
    } catch (_) {
      if (mounted) {
        Island.show(
          context,
          const IslandMessage(
            title: ExcuseLetterStrings.shareFailed,
            tone: IslandTone.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// Fades [child] in and lifts it into place as piece [i] arrives.
  Widget _rise(int i, Widget child) => AnimatedBuilder(
    animation: _pieces[i],
    child: child,
    builder: (context, child) => splashRise(_pieces[i].value, child!),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final missed = widget.subject.absentDates;
    // Newest first, as My Attendance lists them — and the day tapped even
    // if a scan sent late has filled it since.
    final offered = [if (!missed.contains(widget.date)) widget.date, ...missed];

    return Scaffold(
      key: const ValueKey('excuseLetter'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.pagePadding,
            vertical: 12,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _rise(0, _Header(subject: widget.subject.subject)),
                  const SizedBox(height: 18),
                  _rise(
                    1,
                    _Section(
                      icon: Icons.event_busy_rounded,
                      label: ExcuseLetterStrings.daysHeading,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final day in offered)
                            _Choice(
                              name: 'day.${_ymd(day)}',
                              label: DateLabel.short(day),
                              selected: _days.contains(day),
                              onTap: () => _toggle(day),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _rise(
                    2,
                    _Section(
                      icon: Icons.help_outline_rounded,
                      label: ExcuseLetterStrings.reasonHeading,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final reason in ExcuseReason.values)
                            _Choice(
                              name: 'reason.${reason.name}',
                              label: reason.label,
                              selected: _reason == reason,
                              onTap: () => _choose(() => _reason = reason),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _rise(
                    3,
                    _Section(
                      icon: Icons.notes_rounded,
                      label: ExcuseLetterStrings.noteHeading,
                      child: TextField(
                        key: const ValueKey('excuseLetter.note'),
                        controller: _note,
                        minLines: 2,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: ExcuseLetterStrings.noteHint,
                          hintMaxLines: 2,
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: colors.textMuted,
                          ),
                          contentPadding: const EdgeInsets.all(14),
                        ),
                        onChanged: (_) => _choose(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _rise(
                    4,
                    _Section(
                      icon: Icons.mail_outline_rounded,
                      label: ExcuseLetterStrings.letterHeading,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            key: const ValueKey('excuseLetter.letter'),
                            controller: _letter,
                            minLines: 12,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            textCapitalization: TextCapitalization.sentences,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: colors.textPrimary,
                            ),
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.all(14),
                            ),
                          ),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _letter,
                            builder: (context, value, _) =>
                                value.text == _template
                                ? const SizedBox.shrink()
                                : Align(
                                    alignment: Alignment.centerLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: TextButton.icon(
                                        key: const ValueKey(
                                          'excuseLetter.startOver',
                                        ),
                                        onPressed: () =>
                                            _letter.text = _template,
                                        icon: const Icon(
                                          Icons.restart_alt_rounded,
                                          size: 19,
                                        ),
                                        label: const Text(
                                          ExcuseLetterStrings.startOver,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _rise(
                    5,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Reminder(),
                        const SizedBox(height: 14),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _letter,
                          builder: (context, value, _) {
                            final empty = value.text.trim().isEmpty;
                            return Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    key: const ValueKey('excuseLetter.share'),
                                    onPressed: empty || _sharing
                                        ? null
                                        : _share,
                                    icon: const Icon(
                                      Icons.ios_share_rounded,
                                      size: 20,
                                    ),
                                    label: const Text(
                                      ExcuseLetterStrings.share,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    key: const ValueKey('excuseLetter.copy'),
                                    onPressed: empty ? null : _copy,
                                    icon: const Icon(
                                      Icons.content_copy_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(ExcuseLetterStrings.copy),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `2026-09-28` — a day chip's key.
String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Back to My Attendance, the page's name and the subject, and what to do.
class _Header extends StatelessWidget {
  const _Header({required this.subject});

  final String subject;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('excuseLetter.back'),
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: MyAttendanceStrings.title,
              icon: const Icon(Icons.arrow_back_rounded),
              color: colors.textSecondary,
            ),
            const SizedBox(width: 4),
            // Wraps rather than runs off a small phone at a large text size.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ExcuseLetterStrings.title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    subject,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            ExcuseLetterStrings.intro,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// One part of the letter, in the panel every block on the screen sits in.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => SurfacePanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeading(icon: icon, label: label),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

/// A day or a reason: My Attendance's filter chips, with a tick on the ones
/// chosen.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.name,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// `excuseLetter.<name>`, for tests.
  final String name;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? colors.accentWash(0.12) : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? colors.accentWash(0.45) : colors.borderStrong,
          ),
        ),
        child: InkWell(
          key: ValueKey('excuseLetter.$name'),
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: colors.accent,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    color: selected ? colors.accent : colors.textSecondary,
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

/// What sending the letter does — and does not — do, above the buttons that
/// send it.
class _Reminder extends StatelessWidget {
  const _Reminder();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ExcuseLetterStrings.reminder,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
