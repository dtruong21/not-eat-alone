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

  group('formatClockTime', () {
    test('evening time uses PM', () {
      expect(formatClockTime(DateTime(2027, 1, 5, 19, 30)), '7:30 PM');
    });
    test('midnight is 12:00 AM', () {
      expect(formatClockTime(DateTime(2027, 1, 5)), '12:00 AM');
    });
    test('noon is 12:00 PM', () {
      expect(formatClockTime(DateTime(2027, 1, 5, 12)), '12:00 PM');
    });
    test('minutes are zero-padded', () {
      expect(formatClockTime(DateTime(2027, 1, 5, 9, 5)), '9:05 AM');
    });
    test('a UTC instant is rendered in local time, not UTC', () {
      final utc = DateTime.utc(2027, 1, 5, 18, 30);
      final local = utc.toLocal();
      final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final period = local.hour < 12 ? 'AM' : 'PM';
      final minute = local.minute.toString().padLeft(2, '0');
      expect(formatClockTime(utc), '$hour12:$minute $period');
      expect(formatClockTime(utc), formatClockTime(local));
    });
    test('UTC midnight and noon follow the local clock', () {
      // On a UTC machine these degenerate to 12:00 AM / 12:00 PM.
      for (final utc in [
        DateTime.utc(2027, 1, 5),
        DateTime.utc(2027, 1, 5, 12),
      ]) {
        final local = utc.toLocal();
        final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
        final period = local.hour < 12 ? 'AM' : 'PM';
        final minute = local.minute.toString().padLeft(2, '0');
        expect(formatClockTime(utc), '$hour12:$minute $period');
      }
    });
  });

  group('formatMonthDay', () {
    test('renders M/D without padding', () {
      expect(formatMonthDay(DateTime(2027, 1, 5)), '1/5');
      expect(formatMonthDay(DateTime(2027, 12, 31)), '12/31');
    });
    test('a UTC instant is rendered in local date, not UTC', () {
      // 23:30 UTC: the local calendar day differs from the UTC one in any
      // timezone ahead of UTC (e.g. Paris). On a UTC machine this degenerates
      // to comparing UTC with itself.
      final utc = DateTime.utc(2027, 1, 5, 23, 30);
      final local = utc.toLocal();
      expect(formatMonthDay(utc), '${local.month}/${local.day}');
      expect(formatMonthDay(utc), formatMonthDay(local));
    });
    test('an early-UTC instant follows the local date too', () {
      // 00:30 UTC: local day differs in any timezone behind UTC (e.g. NYC).
      final utc = DateTime.utc(2027, 3, 1, 0, 30);
      final local = utc.toLocal();
      expect(formatMonthDay(utc), '${local.month}/${local.day}');
    });
  });
}
