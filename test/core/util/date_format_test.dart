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

  test('a UTC instant is rendered in local time, not UTC', () {
    final utc = DateTime.utc(2027, 1, 5, 18, 30);
    final local = utc.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final period = local.hour < 12 ? 'AM' : 'PM';
    final minute = local.minute.toString().padLeft(2, '0');
    final formatted = formatMealDateTime(utc);
    expect(formatted, contains('${local.day}, ${local.year} at '));
    expect(formatted, endsWith('$hour12:$minute $period'));
    // And identical to formatting the already-local value.
    expect(formatted, formatMealDateTime(local));
  });
}
