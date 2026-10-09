import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/util/phone.dart';

void main() {
  group('isPlausiblePhone', () {
    test('accepts + and 8-15 digits, spaces ignored', () {
      expect(isPlausiblePhone('+33 6 12 34 56 78'), isTrue);
      expect(isPlausiblePhone('+33612345678'), isTrue);
      expect(isPlausiblePhone('+12345678'), isTrue); // 8 digits
      expect(isPlausiblePhone('+123456789012345'), isTrue); // 15 digits
      expect(isPlausiblePhone('  +33612345678  '), isTrue);
    });

    test('rejects the bare prefix, short, long, missing +, junk', () {
      expect(isPlausiblePhone('+33'), isFalse);
      expect(isPlausiblePhone(''), isFalse);
      expect(isPlausiblePhone('+1234567'), isFalse); // 7 digits
      expect(isPlausiblePhone('+1234567890123456'), isFalse); // 16 digits
      expect(isPlausiblePhone('0612345678'), isFalse);
      expect(isPlausiblePhone('+33 6 12 ab 56 78'), isFalse);
      expect(isPlausiblePhone('+33+612345678'), isFalse);
    });
  });

  group('formatPhoneDisplay', () {
    test('groups French numbers', () {
      expect(formatPhoneDisplay('+33612345678'), '+33 6 12 34 56 78');
    });

    test('leaves other countries and malformed input as is', () {
      expect(formatPhoneDisplay('+14155550123'), '+14155550123');
      expect(formatPhoneDisplay('+3361234'), '+3361234');
      // Near miss: a trunk 0 after +33 (10 national digits) is not mangled;
      // the sign-in screen normalises it away before this is ever shown.
      expect(formatPhoneDisplay('+330612345678'), '+330612345678');
      expect(formatPhoneDisplay(''), '');
    });
  });
}
