import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/util/date_format.dart';

/// Independent expectation: shifts the UTC instant by the machine's offset and
/// reads the UTC fields of the shifted value, never calling `toLocal()` on
/// the instant under test.
DateTime _shifted(DateTime utc) => utc.add(utc.toLocal().timeZoneOffset);

String _hhmm(DateTime shifted) =>
    '${shifted.hour.toString().padLeft(2, '0')}:'
    '${shifted.minute.toString().padLeft(2, '0')}';

void main() {
  // A fixed local "now": Fri 9 Oct 2026, 15:00. Local DateTimes are
  // zone-independent, so the literals below hold on any machine.
  final now = DateTime(2026, 10, 9, 15);

  group('formatMealDateTime', () {
    test('same calendar day reads Today with a 24 h time', () {
      expect(
        formatMealDateTime(DateTime(2026, 10, 9, 20, 30), now: now),
        'Today 20:30',
      );
    });
    test('next calendar day reads Tomorrow', () {
      expect(
        formatMealDateTime(DateTime(2026, 10, 10, 12, 30), now: now),
        'Tomorrow 12:30',
      );
    });
    test('Tomorrow crosses month and year ends', () {
      expect(
        formatMealDateTime(
          DateTime(2026, 11, 1, 9),
          now: DateTime(2026, 10, 31, 23),
        ),
        'Tomorrow 09:00',
      );
      expect(
        formatMealDateTime(
          DateTime(2027, 1, 1, 0, 30),
          now: DateTime(2026, 12, 31, 8),
        ),
        'Tomorrow 00:30',
      );
    });
    test('later days use weekday, day, month and no year in the same year', () {
      expect(
        formatMealDateTime(DateTime(2026, 10, 11, 20), now: now),
        'Sun 11 Oct, 20:00',
      );
      expect(
        formatMealDateTime(DateTime(2026, 12, 25, 19, 15), now: now),
        'Fri 25 Dec, 19:15',
      );
    });
    test('a different year appends the year', () {
      expect(
        formatMealDateTime(DateTime(2027, 1, 5, 19, 30), now: now),
        'Tue 5 Jan 2027, 19:30',
      );
    });
    test('past dates use the absolute form', () {
      expect(
        formatMealDateTime(DateTime(2026, 10, 8, 19), now: now),
        'Thu 8 Oct, 19:00',
      );
      expect(
        formatMealDateTime(DateTime(2020, 1, 5, 19, 30), now: now),
        'Sun 5 Jan 2020, 19:30',
      );
    });
    test('midnight, 00:05 and noon use a zero-padded 24 h clock', () {
      expect(
        formatMealDateTime(DateTime(2026, 10, 12), now: now),
        'Mon 12 Oct, 00:00',
      );
      expect(
        formatMealDateTime(DateTime(2026, 10, 12, 0, 5), now: now),
        'Mon 12 Oct, 00:05',
      );
      expect(
        formatMealDateTime(DateTime(2026, 10, 9, 12), now: now),
        'Today 12:00',
      );
    });
    test('without now it compares against the real clock', () {
      final real = DateTime.now();
      expect(
        formatMealDateTime(DateTime(real.year, real.month, real.day, 23, 59)),
        'Today 23:59',
      );
    });

    test('a UTC instant is placed on its LOCAL calendar day', () {
      // 23:30Z is already the next day anywhere ahead of UTC (CI re-runs this
      // file under TZ=Pacific/Kiritimati so it cannot pass vacuously).
      final utc = DateTime.utc(2026, 10, 9, 23, 30);
      final shifted = _shifted(utc);
      final sameDay = DateTime(shifted.year, shifted.month, shifted.day, 12);
      final dayBefore = DateTime(
        shifted.year,
        shifted.month,
        shifted.day - 1,
        12,
      );
      expect(formatMealDateTime(utc, now: sameDay), 'Today ${_hhmm(shifted)}');
      expect(
        formatMealDateTime(utc, now: dayBefore),
        'Tomorrow ${_hhmm(shifted)}',
      );
    });
    test('now is also read in local time', () {
      final utc = DateTime.utc(2026, 10, 9, 23, 30);
      final shifted = _shifted(utc);
      // The same instant as value and as (UTC) now: always "Today".
      expect(formatMealDateTime(utc, now: utc), 'Today ${_hhmm(shifted)}');
    });
  });

  group('formatClockTime', () {
    test('evening is 24 h', () {
      expect(formatClockTime(DateTime(2027, 1, 5, 19, 30)), '19:30');
    });
    test('midnight is 00:00', () {
      expect(formatClockTime(DateTime(2027, 1, 5)), '00:00');
    });
    test('00:05 and noon are zero padded', () {
      expect(formatClockTime(DateTime(2027, 1, 5, 0, 5)), '00:05');
      expect(formatClockTime(DateTime(2027, 1, 5, 12)), '12:00');
    });
    test('minutes are zero-padded', () {
      expect(formatClockTime(DateTime(2027, 1, 5, 9, 5)), '09:05');
    });
    test('a UTC instant is rendered in local time, not UTC', () {
      final utc = DateTime.utc(2027, 1, 5, 18, 30);
      expect(formatClockTime(utc), _hhmm(_shifted(utc)));
      expect(formatClockTime(utc), formatClockTime(utc.toLocal()));
    });
    test('UTC midnight and noon follow the local clock', () {
      for (final utc in [
        DateTime.utc(2027, 1, 5),
        DateTime.utc(2027, 1, 5, 12),
      ]) {
        expect(formatClockTime(utc), _hhmm(_shifted(utc)));
      }
    });
  });

  group('formatMonthDay', () {
    test('renders day then month abbreviation without padding', () {
      expect(formatMonthDay(DateTime(2027, 1, 5)), '5 Jan');
      expect(formatMonthDay(DateTime(2027, 12, 31)), '31 Dec');
    });
    test('a UTC instant is rendered in local date, not UTC', () {
      // 23:30Z: the local calendar day differs from the UTC one in any zone
      // ahead of UTC.
      final utc = DateTime.utc(2027, 1, 5, 23, 30);
      final shifted = _shifted(utc);
      expect(formatMonthDay(utc), '${shifted.day} Jan');
      expect(formatMonthDay(utc), formatMonthDay(utc.toLocal()));
    });
    test('an early-UTC instant follows the local date too', () {
      // 00:30Z: the local day differs in any zone behind UTC.
      final utc = DateTime.utc(2027, 3, 1, 0, 30);
      final shifted = _shifted(utc);
      expect(formatMonthDay(utc), '${shifted.day} Mar');
    });
  });

  group('formatLongDate', () {
    test('renders day, full month name and year', () {
      expect(formatLongDate(DateTime(2027, 1, 5)), '5 January 2027');
      expect(formatLongDate(DateTime(2000, 9, 30)), '30 September 2000');
      expect(formatLongDate(DateTime(1999, 12, 31)), '31 December 1999');
    });
    test('a UTC instant is rendered in local date, not UTC', () {
      final utc = DateTime.utc(2027, 1, 5, 23, 30);
      expect(formatLongDate(utc), '${_shifted(utc).day} January 2027');
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
      test('formatClockTime shows 13:30', () {
        expect(formatClockTime(instant), '13:30');
      });
      test('formatMonthDay rolls over to 2 Jan', () {
        expect(formatMonthDay(instant), '2 Jan');
      });
      test('formatLongDate rolls over to 2 January 2026', () {
        expect(formatLongDate(instant), '2 January 2026');
      });
      test('formatMealDateTime is Today on the local day', () {
        expect(
          formatMealDateTime(instant, now: DateTime(2026, 1, 2, 9)),
          'Today 13:30',
        );
      });
      test('formatMealDateTime is Tomorrow the local day before', () {
        // In UTC this instant is still 1 Jan, i.e. the same day as this now.
        expect(
          formatMealDateTime(instant, now: DateTime(2026, 1, 1, 9)),
          'Tomorrow 13:30',
        );
      });
      test('formatMealDateTime rolls over to Fri 2 Jan', () {
        expect(
          formatMealDateTime(instant, now: DateTime(2026, 1, 4, 9)),
          'Fri 2 Jan, 13:30',
        );
      });
    },
  );
}
