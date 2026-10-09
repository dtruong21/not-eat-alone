import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'features never use colorScheme.outline (border colour) as text/icon',
    () {
      final re = RegExp(r'\.outline\b(?!Variant)');
      final hits = <String>[];
      for (final f in Directory('lib/features').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (re.hasMatch(lines[i])) hits.add('${f.path}:${i + 1}');
        }
      }
      expect(hits, isEmpty, reason: 'use context.wp.muted/subtle instead');
    },
  );
}
