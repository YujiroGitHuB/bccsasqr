/// The web tracker's date wording — PHP's `M d, Y` and `l` — without pulling
/// in `intl` for two formats.
abstract final class DateLabel {
  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// `Aug 04, 2026` — zero-padded, as the web page prints it.
  static String date(DateTime d) =>
      '${_months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';

  /// `Monday`.
  static String weekday(DateTime d) => _weekdays[d.weekday - 1];
}
