import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/chat/domain/entities/chat_message.dart';
import 'package:not_eat_alone/features/chat/presentation/group_messages.dart';

ChatMessage _m(String id, String sender, DateTime? at) => ChatMessage(
  id: id,
  matchId: 'm',
  senderId: sender,
  text: id,
  createdAt: at,
);

/// Compact readable form: `D:<label>` for a separator, `<id>` for a message
/// that ends a run (shows its time), `<id>~` for one that does not.
List<String> _shape(List<ChatListEntry> entries) => [
  for (final e in entries)
    switch (e) {
      DaySeparatorEntry(:final label) => 'D:$label',
      MessageEntry(:final message, :final endsRun) =>
        endsRun ? message.id : '${message.id}~',
    },
];

void main() {
  // Fri 9 Oct 2026, 15:00 local.
  final now = DateTime(2026, 10, 9, 15);

  test('no messages -> no entries', () {
    expect(groupMessages(const [], now: now), isEmpty);
  });

  test('the first message of a day is preceded by that day separator', () {
    final out = groupMessages([
      _m('a', 'x', DateTime(2026, 10, 9, 9)),
    ], now: now);
    expect(_shape(out), ['D:Today', 'a']);
  });

  test('a separator appears between messages of different local days', () {
    final out = groupMessages([
      _m('a', 'x', DateTime(2026, 10, 5, 22)),
      _m('b', 'x', DateTime(2026, 10, 8, 8)),
      _m('c', 'y', DateTime(2026, 10, 9, 8)),
    ], now: now);
    expect(_shape(out), [
      'D:Mon 5 Oct',
      'a',
      'D:Yesterday',
      'b',
      'D:Today',
      'c',
    ]);
  });

  test('same sender within 5 minutes: only the last bubble ends the run', () {
    final out = groupMessages([
      _m('a', 'x', DateTime(2026, 10, 9, 9, 0)),
      _m('b', 'x', DateTime(2026, 10, 9, 9, 3)),
      _m('c', 'x', DateTime(2026, 10, 9, 9, 7)), // 4 min after b: same run
    ], now: now);
    expect(_shape(out), ['D:Today', 'a~', 'b~', 'c']);
  });

  test('a gap of more than 5 minutes ends the run', () {
    final out = groupMessages([
      _m('a', 'x', DateTime(2026, 10, 9, 9, 0)),
      _m('b', 'x', DateTime(2026, 10, 9, 9, 5)), // exactly 5 min: same run
      _m('c', 'x', DateTime(2026, 10, 9, 9, 10, 1)), // 5 min 1 s: new run
    ], now: now);
    expect(_shape(out), ['D:Today', 'a~', 'b', 'c']);
  });

  test('a different sender ends the run', () {
    final out = groupMessages([
      _m('a', 'x', DateTime(2026, 10, 9, 9, 0)),
      _m('b', 'y', DateTime(2026, 10, 9, 9, 1)),
      _m('c', 'x', DateTime(2026, 10, 9, 9, 2)),
    ], now: now);
    expect(_shape(out), ['D:Today', 'a', 'b', 'c']);
  });

  test('a day change ends the run even within 5 minutes', () {
    final out = groupMessages([
      _m('a', 'x', DateTime(2026, 10, 8, 23, 59)),
      _m('b', 'x', DateTime(2026, 10, 9, 0, 1)),
    ], now: now);
    expect(_shape(out), ['D:Yesterday', 'a', 'D:Today', 'b']);
  });

  test('a pending message (no server time yet) counts as now', () {
    final out = groupMessages([
      _m('a', 'x', DateTime(2026, 10, 9, 14, 58)),
      _m('b', 'x', null),
    ], now: now);
    // b is 2 min after a: the same run, so only b ends it.
    expect(_shape(out), ['D:Today', 'a~', 'b']);
  });

  test('a pending message after an old one starts a new run and day', () {
    final out = groupMessages([
      _m('a', 'x', DateTime(2026, 10, 7, 14)),
      _m('b', 'x', null),
    ], now: now);
    expect(_shape(out), ['D:Wed 7 Oct', 'a', 'D:Today', 'b']);
  });

  test('a UTC createdAt is grouped by its LOCAL day', () {
    final utc = DateTime.utc(2026, 10, 9, 23, 30);
    final shifted = utc.add(utc.toLocal().timeZoneOffset);
    final localNoon = DateTime(shifted.year, shifted.month, shifted.day, 12);
    final out = groupMessages([_m('a', 'x', utc)], now: localNoon);
    expect(_shape(out), ['D:Today', 'a']);
  });

  group(
    'under TZ=Pacific/Kiritimati (UTC+14)',
    skip: Platform.environment['TZ'] == 'Pacific/Kiritimati'
        ? false
        : 'run with TZ=Pacific/Kiritimati (CI does this in a dedicated step)',
    () {
      test('23:30Z and 00:30Z the next UTC day are the same local day', () {
        // 13:30 and 14:30 on 2 Jan locally.
        final out = groupMessages([
          _m('a', 'x', DateTime.utc(2026, 1, 1, 23, 30)),
          _m('b', 'y', DateTime.utc(2026, 1, 2, 0, 30)),
        ], now: DateTime(2026, 1, 2, 18));
        expect(_shape(out), ['D:Today', 'a', 'b']);
      });
      test('09:00Z and 11:00Z straddle local midnight', () {
        // 23:00 on 1 Jan and 01:00 on 2 Jan locally.
        final out = groupMessages([
          _m('a', 'x', DateTime.utc(2026, 1, 1, 9)),
          _m('b', 'x', DateTime.utc(2026, 1, 1, 11)),
        ], now: DateTime(2026, 1, 2, 18));
        expect(_shape(out), ['D:Yesterday', 'a', 'D:Today', 'b']);
      });
    },
  );

  group(
    'under TZ=America/Los_Angeles (DST)',
    skip: Platform.environment['TZ'] == 'America/Los_Angeles'
        ? false
        : 'run with TZ=America/Los_Angeles',
    () {
      test('the 25 h fall-back day is one day, the next is Today', () {
        final out = groupMessages([
          _m('a', 'x', DateTime(2026, 11, 1, 0, 30)),
          _m('b', 'x', DateTime(2026, 11, 1, 23, 30)),
          _m('c', 'x', DateTime(2026, 11, 2, 0, 15)),
        ], now: DateTime(2026, 11, 2, 9));
        expect(_shape(out), ['D:Yesterday', 'a', 'b', 'D:Today', 'c']);
      });
      test('the 23 h spring-forward day is one day', () {
        final out = groupMessages([
          _m('a', 'x', DateTime(2027, 3, 14, 0, 30)),
          _m('b', 'y', DateTime(2027, 3, 14, 23, 30)),
        ], now: DateTime(2027, 3, 15, 9));
        expect(_shape(out), ['D:Yesterday', 'a', 'b']);
      });
    },
  );
}
