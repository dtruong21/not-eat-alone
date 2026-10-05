import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/util/date_format.dart';

/// Independent expectation: shifts the UTC instant by the machine's offset and
/// reads the UTC fields of the shifted value, never calling `toLocal()` on
/// the instant under test.
DateTime _shifted(DateTime utc) => utc.add(utc.toLocal().timeZoneOffset);

String _clock(DateTime shifted) {
  final hour12 = shifted.hour % 12 == 0 ? 12 : shifted.hour % 12;
  final minute = shifted.minute.toString().padLeft(2, '0');
  return '$hour12:$minute ${shifted.hour < 12 ? 'AM' : 'PM'}';
}

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
      expect(formatClockTime(utc), _clock(_shifted(utc)));
      expect(formatClockTime(utc), formatClockTime(utc.toLocal()));
    });
    test('UTC midnight and noon follow the local clock', () {
      // On a UTC machine these degenerate to 12:00 AM / 12:00 PM; CI also
      // runs this file under TZ=Pacific/Kiritimati (see ci.yml) so the
      // assertion cannot pass vacuously.
      for (final utc in [
        DateTime.utc(2027, 1, 5),
        DateTime.utc(2027, 1, 5, 12),
      ]) {
        expect(formatClockTime(utc), _clock(_shifted(utc)));
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
      final shifted = _shifted(utc);
      expect(formatMonthDay(utc), '${shifted.month}/${shifted.day}');
      expect(formatMonthDay(utc), formatMonthDay(local));
    });
    test('an early-UTC instant follows the local date too', () {
      // 00:30 UTC: local day differs in any timezone behind UTC (e.g. NYC).
      final utc = DateTime.utc(2027, 3, 1, 0, 30);
      final shifted = _shifted(utc);
      expect(formatMonthDay(utc), '${shifted.month}/${shifted.day}');
    });
  });

  // Hard literals, only meaningful under a known zone. CI's non-UTC step sets
  // TZ=Pacific/Kiritimati (UTC+14, no DST), so 23:30Z lands on the next day.
  group(
    'under TZ=Pacific/Kiritimati (UTC+14)',
    skip: Platform.environment['TZ'] == 'Pacific/Kiritimati'
        ? false
        : 'run with TZ=Pacific/Kiritimati (CI does this in a dedicated step)',
    () {
      final instant = DateTime.utc(2026, 1, 1, 23, 30);
      test('formatClockTime shows 1:30 PM', () {
        expect(formatClockTime(instant), '1:30 PM');
      });
      test('formatMonthDay rolls over to 1/2', () {
        expect(formatMonthDay(instant), '1/2');
      });
      test('formatMealDateTime rolls over to January 2', () {
        expect(formatMealDateTime(instant), 'January 2, 2026 at 1:30 PM');
      });
    },
  );
}
