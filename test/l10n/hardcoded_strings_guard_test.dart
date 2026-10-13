import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fails when user-facing English creeps back into `lib/features` or
/// `lib/core`: a `Text('…')` or a `label:`/`hintText:`/`labelText:`/
/// `tooltip:`/`semanticLabel:`/`semanticsLabel:` string literal that has a
/// letter and a space (or starts uppercase). Extract it to the ARB files, or
/// allow-list it in `hardcoded_strings_allowlist.txt` with a reason.
///
/// A regex scan, not a parser. It cannot see: `title:`, `message:`, `hint:`,
/// `helperText:`, `errorText:` literals, `TextSpan(text:)`, `SelectableText`,
/// `Tooltip(message:)`, literals inside ternaries, and lowercase single words.
/// Review those by hand.
void main() {
  final literal = RegExp(
    r'''(?:\bText\(\s*|\b(?:label|hintText|labelText|tooltip|semanticLabel|semanticsLabel)\s*:\s*(?:const\s+)?)(?:r?)(["'])((?:\\.|(?!\1)[^\\\n])*)\1''',
  );

  // Interpolations (`$name`, `${…}`) are code, not words.
  bool userFacing(String s) {
    final words = s.replaceAll(RegExp(r'\$\{[^}]*\}|\$\w+'), '');
    return RegExp('[A-Za-z]').hasMatch(words) &&
        (words.contains(' ') || RegExp('^[A-Z]').hasMatch(words));
  }

  // Allow-list lines: `path | literal | reason`.
  final allowed = <String>{};
  for (final raw in File(
    'test/l10n/hardcoded_strings_allowlist.txt',
  ).readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final parts = line.split(' | ');
    expect(parts.length, 3, reason: 'allow-list line needs 3 parts: $raw');
    expect(parts[2].trim(), isNotEmpty, reason: 'reason missing: $raw');
    allowed.add('${parts[0].trim()} | ${parts[1]}');
  }

  test('no hard-coded user-facing literals outside the allow-list', () {
    final hits = <String>[];
    final used = <String>{};
    for (final root in ['lib/features', 'lib/core']) {
      for (final f in Directory(root).listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (f.path.endsWith('.g.dart') || f.path.endsWith('.freezed.dart')) {
          continue;
        }
        final src = f.readAsStringSync();
        for (final m in literal.allMatches(src)) {
          final text = m.group(2)!;
          if (!userFacing(text)) continue;
          final lineStart = src.lastIndexOf('\n', m.start) + 1;
          if (src.substring(lineStart, m.start).trimLeft().startsWith('//')) {
            continue;
          }
          final key = '${f.path} | $text';
          if (allowed.contains(key)) {
            used.add(key);
            continue;
          }
          final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
          hits.add("${f.path}:$line  '$text'");
        }
      }
    }
    expect(
      hits,
      isEmpty,
      reason:
          'Hard-coded user-facing strings (move to lib/l10n/*.arb or '
          'allow-list with a reason):\n${hits.join('\n')}',
    );
    expect(
      allowed.difference(used),
      isEmpty,
      reason: 'Stale allow-list entries (remove them)',
    );
  });
}
