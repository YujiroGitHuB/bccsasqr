import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/attendance_link.dart';

/// "Close the link in…": the web card's expiry panel as a sheet. Presets from
/// now, a date and time of your own, and — when one is set — no expiry.
///
/// Answers the time picked, or null when the sheet was put away.
Future<LinkTime?> showExpirySheet(
  BuildContext context, {
  required bool isSet,
  DateTime Function() clock = DateTime.now,
}) => _show(
  context,
  title: LinksStrings.expirySheetTitle,
  icon: Icons.hourglass_top_rounded,
  presetsHint: LinksStrings.expiryIn,
  presets: [
    for (final h in const [1, 2, 4])
      (label: LinksStrings.hours(h), time: LinkTime.minutes(h * 60)),
    (label: LinksStrings.endOfDay, time: const LinkTime.endOfDay()),
  ],
  customHint: LinksStrings.expiryAt,
  customLabel: LinksStrings.pickDateTime,
  customIcon: Icons.event_rounded,
  pickCustom: (context) => _pickDateTime(context, clock()),
  clearLabel: isSet ? LinksStrings.removeExpiry : null,
);

/// "Students are on time for the next…": the late cutoff. Counted from now,
/// because the common case is setting it the moment class starts.
Future<LinkTime?> showLateSheet(BuildContext context, {required bool isSet}) =>
    _show(
      context,
      title: LinksStrings.lateSheetTitle,
      icon: Icons.alarm_rounded,
      presetsHint: LinksStrings.lateIn,
      presets: [
        for (final m in const [10, 15, 30])
          (label: LinksStrings.minutes(m), time: LinkTime.minutes(m)),
      ],
      customHint: LinksStrings.lateAt,
      customLabel: LinksStrings.pickTime,
      customIcon: Icons.schedule_rounded,
      pickCustom: _pickTime,
      clearLabel: isSet ? LinksStrings.removeLate : null,
    );

typedef _Preset = ({String label, LinkTime time});

Future<LinkTime?> _show(
  BuildContext context, {
  required String title,
  required IconData icon,
  required String presetsHint,
  required List<_Preset> presets,
  required String customHint,
  required String customLabel,
  required IconData customIcon,
  required Future<LinkTime?> Function(BuildContext context) pickCustom,
  String? clearLabel,
}) {
  return showModalBottomSheet<LinkTime>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    builder: (context) {
      final colors = context.colors;
      final hint = TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: colors.textSecondary,
      );

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: colors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(presetsHint, style: hint),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = 0; i < presets.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        key: ValueKey('linkTime.preset.$i'),
                        onPressed: () =>
                            Navigator.pop(context, presets[i].time),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 46),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        child: Text(
                          presets[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              Text(customHint, style: hint),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                key: const ValueKey('linkTime.custom'),
                onPressed: () async {
                  final time = await pickCustom(context);
                  if (time != null && context.mounted) {
                    Navigator.pop(context, time);
                  }
                },
                icon: Icon(customIcon, size: 20),
                label: Text(customLabel),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  backgroundColor: colors.accentWash(0.14),
                  foregroundColor: colors.accent,
                ),
              ),
              if (clearLabel != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  key: const ValueKey('linkTime.clear'),
                  onPressed: () =>
                      Navigator.pop(context, const LinkTime.clear()),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text(clearLabel),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.danger,
                    minimumSize: const Size(0, 44),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// A day, then a time on it. Up to a year ahead — the server refuses a time
/// already past, so the picker starts at today and says nothing about it.
Future<LinkTime?> _pickDateTime(BuildContext context, DateTime now) async {
  final day = await showDatePicker(
    context: context,
    initialDate: now,
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: now.add(const Duration(days: 365)),
  );
  if (day == null || !context.mounted) return null;

  final soon = now.add(const Duration(hours: 1));
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: soon.hour, minute: 0),
  );
  if (time == null) return null;

  return LinkTime.closesAt(
    DateTime(day.year, day.month, day.day, time.hour, time.minute),
  );
}

Future<LinkTime?> _pickTime(BuildContext context) async {
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.now(),
  );
  return time == null ? null : LinkTime.onTimeUntil(time.hour, time.minute);
}
