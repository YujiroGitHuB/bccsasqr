import 'package:bccsasqr_app/core/utils/student_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StudentNumber.tryParse', () {
    test('accepts three- and four-digit registration numbers', () {
      expect(StudentNumber.tryParse('019-464')?.value, '019-464');
      expect(StudentNumber.tryParse('025-1023')?.value, '025-1023');
    });

    test('trims surrounding whitespace', () {
      expect(StudentNumber.tryParse('  019-464 ')?.value, '019-464');
    });

    test('rejects malformed input', () {
      for (final raw in [
        '',
        '019',
        '19-464',
        '019-46',
        '019-10234',
        'ab-cde',
      ]) {
        expect(StudentNumber.tryParse(raw), isNull, reason: raw);
      }
    });

    test('equality is by value', () {
      expect(
        StudentNumber.tryParse('019-464'),
        equals(StudentNumber.tryParse('019-464')),
      );
    });
  });

  group('StudentNumberInputFormatter', () {
    const formatter = StudentNumberInputFormatter();

    TextEditingValue format(String input) => formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: input),
    );

    test('inserts the dash after three digits', () {
      expect(format('019464').text, '019-464');
    });

    test('strips non-digits', () {
      expect(format('01a9/464').text, '019-464');
    });

    test('caps the registration number at four digits', () {
      expect(format('025102399').text, '025-1023');
    });

    test('leaves a short prefix unpunctuated', () {
      expect(format('01').text, '01');
    });
  });
}
