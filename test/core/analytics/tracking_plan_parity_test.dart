import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// QA sweep 2026-10-09: docs/TRACKING-PLAN.md, the typed registry in
/// `lib/core/analytics/events.dart` and the call sites must agree. The plan
/// says "if an event is not in this doc, it does not get fired" and the north
/// star / retention metrics depend on `signup_completed` and `app_opened`.
void main() {
  final registrySource = File(
    'lib/core/analytics/events.dart',
  ).readAsStringSync();
  // class <Name> extends AppEvent ... String get name => '<event>';
  final registry = <String, String>{}; // event name -> class name
  for (final m in RegExp(
    r"^final class (\w+) extends AppEvent[\s\S]*?String get name => '([a-z_]+)';",
    multiLine: true,
  ).allMatches(registrySource)) {
    registry[m.group(2)!] = m.group(1)!;
  }

  final plan = File('docs/TRACKING-PLAN.md').readAsStringSync();
  final planEvents = RegExp(r'^\| `([a-z_]+)` \|', multiLine: true)
      .allMatches(
        plan
            .split('## Event registry')
            .last
            .split('## User property registry')
            .first,
      )
      .map((m) => m.group(1)!)
      .toSet();

  test('the registry parses to a plausible number of events', () {
    expect(registry.length, greaterThan(20));
  });

  test('every registry event is documented in TRACKING-PLAN.md', () {
    expect(
      registry.keys.toSet().difference(planEvents),
      isEmpty,
      reason: 'fired in code but missing from the plan',
    );
  });

  test('every documented event exists in the registry', () {
    expect(
      planEvents.difference(registry.keys.toSet()),
      isEmpty,
      reason: 'documented but cannot be fired',
    );
  });

  test(
    'every registry event is fired from somewhere in lib/',
    () {
      final libSources = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.endsWith('events.dart'))
          .where((f) => !f.path.endsWith('.g.dart'))
          .map((f) => f.readAsStringSync())
          .join('\n');
      final neverFired = [
        for (final e in registry.entries)
          if (!libSources.contains('${e.value}(')) e.key,
      ];
      expect(neverFired, isEmpty, reason: 'declared but never fired');
    },
  );
}
