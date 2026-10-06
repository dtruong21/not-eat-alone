import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/font_license.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';

const _weights = ['Regular', 'Medium', 'Bold', 'ExtraBold'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final b in Brightness.values) {
    test('every text style carries Nunito (${b.name})', () {
      final t = buildTheme(b).textTheme;
      final styles = <String, TextStyle?>{
        'displayLarge': t.displayLarge,
        'displayMedium': t.displayMedium,
        'displaySmall': t.displaySmall,
        'headlineLarge': t.headlineLarge,
        'headlineMedium': t.headlineMedium,
        'headlineSmall': t.headlineSmall,
        'titleLarge': t.titleLarge,
        'titleMedium': t.titleMedium,
        'titleSmall': t.titleSmall,
        'bodyLarge': t.bodyLarge,
        'bodyMedium': t.bodyMedium,
        'bodySmall': t.bodySmall,
        'labelLarge': t.labelLarge,
        'labelMedium': t.labelMedium,
        'labelSmall': t.labelSmall,
      };
      for (final e in styles.entries) {
        if (e.value == null) continue;
        expect(
          e.value!.fontFamily,
          WarmPlayfulFonts.body,
          reason: '${e.key} must use the bundled Nunito',
        );
      }
      expect(buildTheme(b).primaryTextTheme.bodyMedium?.fontFamily, 'Nunito');
    });
  }

  group('bundled font assets', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    test('google_fonts is gone from pubspec and lib/', () {
      expect(pubspec, isNot(contains('google_fonts:')));
      final offenders = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => f.readAsStringSync().contains('package:google_fonts'));
      expect(offenders, isEmpty);
    });

    test('Nunito weights are declared and exist on disk', () {
      expect(pubspec, contains('family: Nunito'));
      for (final w in _weights) {
        final path = 'assets/fonts/Nunito-$w.ttf';
        expect(pubspec, contains('asset: $path'));
        expect(File(path).existsSync(), isTrue, reason: path);
      }
      // Each file is mapped to ITS weight, not just "the numbers appear".
      final entries = RegExp(
        r'asset: assets/fonts/Nunito-(\w+)\.ttf\s+weight: (\d+)',
      ).allMatches(pubspec).map((m) => '${m[1]}=${m[2]}').toList();
      expect(entries, [
        'Regular=400',
        'Medium=500',
        'Bold=700',
        'ExtraBold=800',
      ]);
      expect(File('assets/fonts/OFL.txt').existsSync(), isTrue);
      expect(pubspec, contains('- assets/fonts/OFL.txt'));
    });
  });

  // bootstrap() itself needs Firebase, so it is not run here: the behaviour is
  // covered by the unit test below, and this guards the call site.
  test('bootstrap registers the font licence before anything else', () {
    final src = File('lib/main_common.dart').readAsStringSync();
    final boot = src.substring(src.indexOf('Future<void> bootstrap('));
    expect(boot, contains('registerFontLicense();'));
    expect(
      boot.indexOf('registerFontLicense();'),
      lessThan(boot.indexOf('Firebase.initializeApp')),
    );
  });

  test('registerFontLicense lists Nunito under the OFL', () async {
    registerFontLicense();
    final entries = await LicenseRegistry.licenses.toList();
    final nunito = entries.where((e) => e.packages.contains('Nunito'));
    expect(nunito, isNotEmpty);
    final text = nunito.first.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('SIL Open Font License'));
    // The asset is really loadable through the bundle.
    expect(
      await rootBundle.loadString('assets/fonts/OFL.txt'),
      contains('SIL Open Font License'),
    );
  });
}
