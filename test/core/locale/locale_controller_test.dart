import 'dart:ui';

import 'package:flutter/widgets.dart' show basicLocaleListResolution;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/locale/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to null (follow the device)', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(localeControllerProvider), isNull);
  });

  test('setLocale updates state and persists; a seeded container starts in '
      'French', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c
        .read(localeControllerProvider.notifier)
        .setLocale(const Locale('fr'));
    expect(c.read(localeControllerProvider), const Locale('fr'));

    final saved = await readSavedLocale();
    expect(saved, const Locale('fr'));
    final fresh = ProviderContainer(
      overrides: [localeSeedProvider.overrideWithValue(saved)],
    );
    addTearDown(fresh.dispose);
    expect(fresh.read(localeControllerProvider), const Locale('fr'));
  });

  test('reads a pre-stored code; unknown codes are ignored', () async {
    SharedPreferences.setMockInitialValues({'app_locale': 'fr'});
    expect(await readSavedLocale(), const Locale('fr'));
    SharedPreferences.setMockInitialValues({'app_locale': 'xx'});
    expect(await readSavedLocale(), isNull);
  });

  test(
    'setLocale(null) follows the device again and removes the key',
    () async {
      SharedPreferences.setMockInitialValues({'app_locale': 'fr'});
      final c = ProviderContainer(
        overrides: [localeSeedProvider.overrideWithValue(const Locale('fr'))],
      );
      addTearDown(c.dispose);
      await c.read(localeControllerProvider.notifier).setLocale(null);
      expect(c.read(localeControllerProvider), isNull);
      expect(
        (await SharedPreferences.getInstance()).containsKey('app_locale'),
        isFalse,
      );
    },
  );

  group('resolveAppLanguage', () {
    const devices = <List<Locale>>[
      [Locale('fr', 'FR')],
      [Locale('fr', 'CA')],
      [Locale('es'), Locale('fr')],
      [Locale('de')],
      [],
      [Locale('en', 'US'), Locale('fr')],
    ];

    test('follows the device exactly like the UI default resolution', () {
      for (final d in devices) {
        expect(
          resolveAppLanguage(null, d),
          basicLocaleListResolution(d, supportedAppLocales).languageCode,
          reason: '$d',
        );
      }
    });

    test('an explicit choice wins over the device', () {
      expect(
        resolveAppLanguage(const Locale('fr'), const [Locale('en')]),
        'fr',
      );
      expect(
        resolveAppLanguage(const Locale('en'), const [Locale('fr')]),
        'en',
      );
    });

    test('an unsupported explicit choice is ignored', () {
      expect(
        resolveAppLanguage(const Locale('de'), const [Locale('fr')]),
        'fr',
      );
    });
  });
}
