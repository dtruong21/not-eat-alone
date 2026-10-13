import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _load(String name) =>
    jsonDecode(File('lib/l10n/$name').readAsStringSync())
        as Map<String, dynamic>;

Set<String> _keys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

Map<String, String> _placeholders(Map<String, dynamic> arb, String key) {
  final meta = arb['@$key'] as Map<String, dynamic>?;
  final ph = (meta?['placeholders'] as Map<String, dynamic>?) ?? {};
  return {
    for (final e in ph.entries)
      e.key: ((e.value as Map<String, dynamic>)['type'] as String?) ?? '',
  };
}

void main() {
  final en = _load('app_en.arb');
  final fr = _load('app_fr.arb');

  test('en and fr have identical keys', () {
    expect(_keys(fr), _keys(en));
  });

  test('placeholders match by name and type', () {
    for (final key in _keys(en)) {
      expect(_placeholders(fr, key), _placeholders(en, key), reason: key);
    }
  });

  test('no empty values', () {
    for (final arb in [en, fr]) {
      for (final key in _keys(arb)) {
        expect((arb[key] as String).trim(), isNotEmpty, reason: key);
      }
    }
  });

  test('every key has an @key description', () {
    for (final arb in [en, fr]) {
      for (final key in _keys(arb)) {
        final meta = arb['@$key'] as Map<String, dynamic>?;
        expect(meta?['description'], isA<String>(), reason: key);
        expect((meta!['description'] as String).trim(), isNotEmpty);
      }
    }
  });
}
