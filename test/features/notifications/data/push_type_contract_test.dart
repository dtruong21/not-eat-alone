import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/notifications/data/push_route_mapper.dart';

/// QA sweep 2026-10-09: cross-language contract. Every push `type` that the
/// Cloud Functions can send (scraped from `payloads.ts`) must resolve to a
/// route in the Dart mapper, so adding a server push without a client route
/// fails CI instead of silently dropping the tap.
void main() {
  final source = File(
    'firebase/functions/src/lib/payloads.ts',
  ).readAsStringSync();
  final types = RegExp(
    r"type:\s*'([a-z_]+)'",
  ).allMatches(source).map((m) => m.group(1)!).toSet();

  test('payloads.ts exposes the known set of push types', () {
    expect(types, {
      'request',
      'request_update',
      'message',
      'rate',
      'meal_reminder',
    });
  });

  for (final type in types) {
    test('"$type" maps to a route when the payload is complete', () {
      final route = mapPushData({
        'type': type,
        'status': 'approved',
        'mealId': 'm1',
        'matchId': 'm1',
        'reminder': '24h',
      });
      expect(route, isNotNull, reason: 'no client route for push "$type"');
      expect(route!.location, startsWith('/'));
    });
  }
}
