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

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
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

  /// `September` — written out, as a letter's dates are.
  static String month(DateTime d) => _monthNames[d.month - 1];

  /// `Wed, Sep 30` — the instructor's Home, where the year goes without
  /// saying.
  static String short(DateTime d) =>
      '${_weekdays[d.weekday - 1].substring(0, 3)}, '
      '${_months[d.month - 1]} ${d.day}';

  /// `8:04 AM`.
  static String time(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  /// `8:04 AM` on [now]'s day, `Wed, Sep 30, 8:04 AM` before it — when a
  /// copy kept on the phone is from.
  static String since(DateTime d, DateTime now) =>
      d.year == now.year && d.month == now.month && d.day == now.day
      ? time(d)
      : '${short(d)}, ${time(d)}';
}
