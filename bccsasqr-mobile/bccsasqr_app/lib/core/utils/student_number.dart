import 'package:flutter/services.dart';

/// Value object for a student number of the form `YEAR-Registration No.`
/// (three digits, a dash, then three or four digits) — e.g. `019-464`.
///
/// Parsing and validation live here rather than in the controller so both the
/// form and the repository agree on what a well-formed number is.
class StudentNumber {
  const StudentNumber._(this.year, this.registration);

  final String year;
  final String registration;

  static final RegExp _pattern = RegExp(r'^(\d{3})-(\d{3,4})$');

  /// Returns a [StudentNumber] when [raw] is well formed, otherwise `null`.
  static StudentNumber? tryParse(String raw) {
    final match = _pattern.firstMatch(raw.trim());
    if (match == null) return null;
    return StudentNumber._(match.group(1)!, match.group(2)!);
  }

  static bool isValid(String raw) => tryParse(raw) != null;

  String get value => '$year-$registration';

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      other is StudentNumber && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Keeps the field to digits only and inserts the dash after three digits,
/// so the user never has to type the separator.
class StudentNumberInputFormatter extends TextInputFormatter {
  const StudentNumberInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');

    final capped = digits.length > 7 ? digits.substring(0, 7) : digits;
    final buffer = StringBuffer(capped.substring(0, capped.length.clamp(0, 3)));
    if (capped.length > 3) {
      buffer.write('-');
      buffer.write(capped.substring(3));
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
