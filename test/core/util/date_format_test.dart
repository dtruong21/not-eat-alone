import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/util/date_format.dart';

void main() {
  test('evening time uses PM', () {
    expect(
      formatMealDateTime(DateTime(2027, 1, 5, 19, 30)),
      'January 5, 2027 at 7:30 PM',
    );
  });
  test('midnight is 12:00 AM', () {
    expect(
      formatMealDateTime(DateTime(2027, 12, 31, 0, 5)),
      'December 31, 2027 at 12:05 AM',
    );
  });
  test('noon is 12:00 PM', () {
    expect(
      formatMealDateTime(DateTime(2027, 6, 1, 12)),
      'June 1, 2027 at 12:00 PM',
    );
  });
}
