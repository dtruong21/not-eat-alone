import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:not_eat_alone/core/util/date_format.dart';

/// Independent expectation: shifts the UTC instant by the machine's offset and
/// reads the UTC fields of the shifted value, never calling `toLocal()` on
/// the instant under test.
DateTime _shifted(DateTime utc) => utc.add(utc.toLocal().timeZoneOffset);

String _hhmm(DateTime shifted) =>
    '${shifted.hour.toString().padLeft(2, '0')}:'
    '${shifted.minute.toString().padLeft(2, '0')}';

const fr = Locale('fr');

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('fr');
  });

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
      // Retry once if midnight rolls over between reading the clock and the
      // call under test.
      for (var attempt = 0; attempt < 2; attempt++) {
        final real = DateTime.now();
        final out = formatMealDateTime(
          DateTime(real.year, real.month, real.day, 23, 59),
        );
        final after = DateTime.now();
        if (after.day == real.day) {
          expect(out, 'Today 23:59');
          return;
        }
      }
      fail('the day rolled over twice in a row');
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
      const months = ['Jan', 'Feb', 'Mar'];
      expect(
        formatMonthDay(utc),
        '${shifted.day} ${months[shifted.month - 1]}',
      );
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

  group('formatDayLabel', () {
    test('same calendar day reads Today, whatever the time', () {
      expect(formatDayLabel(DateTime(2026, 10, 9, 0, 1), now: now), 'Today');
      expect(formatDayLabel(DateTime(2026, 10, 9, 23, 59), now: now), 'Today');
    });
    test('the previous calendar day reads Yesterday', () {
      expect(
        formatDayLabel(DateTime(2026, 10, 8, 23, 59), now: now),
        'Yesterday',
      );
      expect(
        formatDayLabel(
          DateTime(2026, 12, 31, 10),
          now: DateTime(2027, 1, 1, 0, 5),
        ),
        'Yesterday',
      );
    });
    test('older days use weekday, day and month, no year in the same year', () {
      expect(formatDayLabel(DateTime(2026, 10, 5, 8), now: now), 'Mon 5 Oct');
      expect(formatDayLabel(DateTime(2026, 1, 1, 8), now: now), 'Thu 1 Jan');
    });
    test('a different year appends the year', () {
      expect(
        formatDayLabel(DateTime(2025, 12, 31, 8), now: now),
        'Wed 31 Dec 2025',
      );
    });
    test('a time ahead of now (clock skew) still reads Today', () {
      expect(
        formatDayLabel(DateTime(2026, 10, 9, 15, 0, 30), now: now),
        'Today',
      );
    });
    test('a UTC instant is placed on its LOCAL calendar day', () {
      final utc = DateTime.utc(2026, 10, 9, 23, 30);
      final shifted = _shifted(utc);
      final sameDay = DateTime(shifted.year, shifted.month, shifted.day, 12);
      final dayAfter = DateTime(
        shifted.year,
        shifted.month,
        shifted.day + 1,
        9,
      );
      expect(formatDayLabel(utc, now: sameDay), 'Today');
      expect(formatDayLabel(utc, now: dayAfter), 'Yesterday');
    });
  });

  // French: same boundaries as the English groups, literal expectations
  // (whatever `intl` gives for fr abbreviations: weekday and month take a dot).
  group('French (fr)', () {
    test('formatMealDateTime: Today, Tomorrow, absolute, year, midnight', () {
      String meal(DateTime v, {DateTime? at}) =>
          formatMealDateTime(v, now: at ?? now, locale: fr);
      expect(meal(DateTime(2026, 10, 9, 20, 30)), 'Aujourd’hui 20:30');
      expect(meal(DateTime(2026, 10, 10, 12, 30)), 'Demain 12:30');
      expect(
        meal(DateTime(2027, 1, 1, 0, 30), at: DateTime(2026, 12, 31, 8)),
        'Demain 00:30',
      );
      expect(meal(DateTime(2026, 10, 10, 20)), 'Demain 20:00');
      expect(meal(DateTime(2026, 10, 11, 20)), 'dim. 11 oct., 20:00');
      expect(meal(DateTime(2026, 10, 8, 19)), 'jeu. 8 oct., 19:00');
      expect(meal(DateTime(2027, 1, 5, 19, 30)), 'mar. 5 janv. 2027, 19:30');
      expect(meal(DateTime(2026, 10, 12, 0, 5)), 'lun. 12 oct., 00:05');
      expect(meal(DateTime(2026, 12, 25, 19, 15)), 'ven. 25 déc., 19:15');
    });
    test('formatMealDateTime: a UTC instant is placed on its local day', () {
      final utc = DateTime.utc(2026, 10, 9, 23, 30);
      final shifted = _shifted(utc);
      final sameDay = DateTime(shifted.year, shifted.month, shifted.day, 12);
      final dayBefore = DateTime(
        shifted.year,
        shifted.month,
        shifted.day - 1,
        12,
      );
      expect(
        formatMealDateTime(utc, now: sameDay, locale: fr),
        'Aujourd’hui ${_hhmm(shifted)}',
      );
      expect(
        formatMealDateTime(utc, now: dayBefore, locale: fr),
        'Demain ${_hhmm(shifted)}',
      );
    });
    test('formatClockTime is 24 h', () {
      expect(
        formatClockTime(DateTime(2027, 1, 5, 19, 30), locale: fr),
        '19:30',
      );
      expect(formatClockTime(DateTime(2027, 1, 5), locale: fr), '00:00');
      expect(formatClockTime(DateTime(2027, 1, 5, 9, 5), locale: fr), '09:05');
      final utc = DateTime.utc(2027, 1, 5, 18, 30);
      expect(formatClockTime(utc, locale: fr), _hhmm(_shifted(utc)));
    });
    test('formatMonthDay', () {
      expect(formatMonthDay(DateTime(2027, 1, 5), locale: fr), '5 janv.');
      expect(formatMonthDay(DateTime(2027, 12, 31), locale: fr), '31 déc.');
      expect(formatMonthDay(DateTime(2027, 8, 2), locale: fr), '2 août');
    });
    test('formatLongDate', () {
      expect(
        formatLongDate(DateTime(2027, 1, 5), locale: fr),
        '5 janvier 2027',
      );
      expect(
        formatLongDate(DateTime(1999, 12, 31), locale: fr),
        '31 décembre 1999',
      );
    });
    test('formatDayLabel: Today, Hier, absolute, year, clock skew', () {
      String label(DateTime v) => formatDayLabel(v, now: now, locale: fr);
      expect(label(DateTime(2026, 10, 9, 0, 1)), 'Aujourd’hui');
      expect(label(DateTime(2026, 10, 9, 15, 0, 30)), 'Aujourd’hui');
      expect(label(DateTime(2026, 10, 8, 23, 59)), 'Hier');
      expect(
        formatDayLabel(
          DateTime(2026, 12, 31, 10),
          now: DateTime(2027, 1, 1, 0, 5),
          locale: fr,
        ),
        'Hier',
      );
      expect(label(DateTime(2026, 10, 5, 8)), 'lun. 5 oct.');
      expect(label(DateTime(2025, 12, 31, 8)), 'mer. 31 déc. 2025');
    });
    test('a language without a table falls back to English', () {
      expect(
        formatMealDateTime(
          DateTime(2026, 10, 9, 20, 30),
          now: now,
          locale: const Locale('de'),
        ),
        'Today 20:30',
      );
    });
  });

  // DST: a "day" is 23 or 25 hours long here, so a Duration-based comparison
  // would be off by one. Run with TZ=America/Los_Angeles.
  group(
    'under TZ=America/Los_Angeles (DST)',
    skip: Platform.environment['TZ'] == 'America/Los_Angeles'
        ? false
        : 'run with TZ=America/Los_Angeles',
    () {
      test('Yesterday across the 25 h fall-back day', () {
        // 1 Nov 2026 has 25 hours: 00:30 on the 1st is 23.75 h before 00:15
        // on the 2nd by the clock, but still "Yesterday" by the calendar.
        expect(
          formatDayLabel(
            DateTime(2026, 11, 1, 0, 30),
            now: DateTime(2026, 11, 2, 0, 15),
          ),
          'Yesterday',
        );
      });
      test('Yesterday across the 23 h spring-forward day', () {
        expect(
          formatDayLabel(
            DateTime(2027, 3, 13, 23, 45),
            now: DateTime(2027, 3, 14, 23, 30),
          ),
          'Yesterday',
        );
        expect(
          formatDayLabel(
            DateTime(2027, 3, 14, 0, 30),
            now: DateTime(2027, 3, 14, 23, 30),
          ),
          'Today',
        );
      });
      test('a UTC instant lands on the Pacific calendar day', () {
        // 03:30Z on 2 Nov is 20:30 PST on 1 Nov.
        final utc = DateTime.utc(2026, 11, 2, 3, 30);
        expect(formatDayLabel(utc, now: DateTime(2026, 11, 1, 22)), 'Today');
        expect(formatDayLabel(utc, now: DateTime(2026, 11, 2, 9)), 'Yesterday');
      });
      test(
        'French: Hier across the DST days, Pacific day for a UTC instant',
        () {
          expect(
            formatDayLabel(
              DateTime(2026, 11, 1, 0, 30),
              now: DateTime(2026, 11, 2, 0, 15),
              locale: fr,
            ),
            'Hier',
          );
          expect(
            formatDayLabel(
              DateTime(2027, 3, 13, 23, 45),
              now: DateTime(2027, 3, 14, 23, 30),
              locale: fr,
            ),
            'Hier',
          );
          final utc = DateTime.utc(2026, 11, 2, 3, 30);
          expect(
            formatMealDateTime(utc, now: DateTime(2026, 11, 1, 22), locale: fr),
            'Aujourd’hui 19:30',
          );
        },
      );
    },
  );

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
      test('formatDayLabel puts 23:30Z on 2 Jan, local', () {
        expect(formatDayLabel(instant, now: DateTime(2026, 1, 2, 9)), 'Today');
        expect(
          formatDayLabel(instant, now: DateTime(2026, 1, 3, 9)),
          'Yesterday',
        );
        expect(
          formatDayLabel(instant, now: DateTime(2026, 1, 9, 9)),
          'Fri 2 Jan',
        );
      });
      test('formatMealDateTime rolls over to Fri 2 Jan', () {
        expect(
          formatMealDateTime(instant, now: DateTime(2026, 1, 4, 9)),
          'Fri 2 Jan, 13:30',
        );
      });
      test('French: local day and clock, not UTC', () {
        expect(formatClockTime(instant, locale: fr), '13:30');
        expect(formatMonthDay(instant, locale: fr), '2 janv.');
        expect(formatLongDate(instant, locale: fr), '2 janvier 2026');
        expect(
          formatMealDateTime(instant, now: DateTime(2026, 1, 1, 9), locale: fr),
          'Demain 13:30',
        );
        expect(
          formatDayLabel(instant, now: DateTime(2026, 1, 3, 9), locale: fr),
          'Hier',
        );
        expect(
          formatMealDateTime(instant, now: DateTime(2026, 1, 4, 9), locale: fr),
          'ven. 2 janv., 13:30',
        );
      });
    },
  );
}
