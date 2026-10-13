import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// l10n.yaml leaves `use-escaping` off (the gen_l10n default), so `'` is a
/// plain character in EVERY message, plurals and selects included, and `''`
/// is shown twice on screen. (With escaping on it would be the other way
/// round: `''` for a literal apostrophe.) These tests pin that convention.
Map<String, String> _messages(String file) {
  final arb =
      jsonDecode(File('lib/l10n/$file').readAsStringSync())
          as Map<String, dynamic>;
  return {
    for (final e in arb.entries)
      if (!e.key.startsWith('@')) e.key: e.value as String,
  };
}

/// French keys allowed to carry an ASCII apostrophe (none today).
const _frenchAsciiApostropheAllowList = <String>{};

void main() {
  test('l10n.yaml does not turn on use-escaping', () {
    expect(
      File('l10n.yaml').readAsStringSync(),
      isNot(contains('use-escaping')),
    );
  });

  for (final file in ['app_en.arb', 'app_fr.arb']) {
    final messages = _messages(file);

    test('$file: no doubled apostrophe in any message', () {
      final bad = [
        for (final e in messages.entries)
          if (e.value.contains("''")) e.key,
      ];
      expect(bad, isEmpty, reason: "'' is shown twice: use a single ' or ’");
    });

    test('$file: every plural has an other case', () {
      final bad = [
        for (final e in messages.entries)
          if (e.value.contains(', plural,') && !e.value.contains('other{'))
            e.key,
      ];
      expect(bad, isEmpty);
    });
  }

  test('French copy uses the typographic apostrophe, never ASCII', () {
    final bad = [
      for (final e in _messages('app_fr.arb').entries)
        if (e.value.contains("'") &&
            !_frenchAsciiApostropheAllowList.contains(e.key))
          e.key,
    ];
    expect(bad, isEmpty, reason: 'use ’ in French copy');
  });
}
