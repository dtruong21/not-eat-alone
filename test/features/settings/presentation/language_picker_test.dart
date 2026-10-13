import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/locale/locale_controller.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/notifications/application/push_providers.dart';
import 'package:not_eat_alone/features/notifications/domain/repositories/push_repository.dart';
import 'package:not_eat_alone/features/safety/application/account_providers.dart';
import 'package:not_eat_alone/features/safety/domain/repositories/account_repository.dart';
import 'package:not_eat_alone/features/settings/presentation/settings_screen.dart';
import 'package:not_eat_alone/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/load_app_fonts.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockAccount extends Mock implements AccountRepository {}

class _MockPush extends Mock implements PushRepository {}

/// The Language row: live switch through a MaterialApp wired like
/// `main_common`, persistence, device-following and 320 px / 2.0x layout.
void main() {
  setUpAll(loadAppFonts);

  late ProviderContainer container;

  setUp(() {
    FlavorConfig.current = FlavorConfig(flavor: Flavor.prod);
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pump(
    WidgetTester tester, {
    Locale? seed,
    bool narrow = false,
    double textScale = 1,
  }) async {
    tester.view
      ..physicalSize = narrow ? const Size(320, 4000) : const Size(800, 3000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final auth = _MockAuth();
    when(() => auth.currentUser).thenReturn(null);
    container = ProviderContainer(
      overrides: [
        localeSeedProvider.overrideWithValue(seed),
        appVersionProvider.overrideWith((ref) async => 'v1.1.0 (build 2)'),
        authRepositoryProvider.overrideWithValue(auth),
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        accountRepositoryProvider.overrideWithValue(_MockAccount()),
        pushRepositoryProvider.overrideWithValue(_MockPush()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: buildTheme(Brightness.light),
            locale: ref.watch(localeControllerProvider),
            supportedLocales: supportedAppLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            localeResolutionCallback: (device, supported) {
              for (final s in supported) {
                if (s.languageCode == device?.languageCode) return s;
              }
              return const Locale('en');
            },
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: const SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String option) async {
    await tester.tap(find.byKey(const Key('settings_language')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('language_option_$option')));
    await tester.pumpAndSettle();
  }

  testWidgets('row sits above Version with the device default as subtitle', (
    tester,
  ) async {
    await pump(tester);
    final language = tester.getTopLeft(
      find.byKey(const Key('settings_language')),
    );
    final version = tester.getTopLeft(
      find.byKey(const Key('settings_app_version')),
    );
    expect(language.dy, lessThan(version.dy));
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('System default'), findsOneWidget);
    expect(find.byIcon(Icons.language_rounded), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('settings_language'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('picking Francais switches Settings to French live', (
    tester,
  ) async {
    await pump(tester);
    await choose(tester, 'fr');
    expect(find.byKey(const Key('language_picker')), findsNothing);
    expect(find.text('Réglages'), findsOneWidget);
    expect(find.text('Langue'), findsOneWidget);
    expect(find.text('Français'), findsOneWidget);
    expect(container.read(localeControllerProvider), const Locale('fr'));

    await choose(tester, 'en');
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('the choice is saved and restored by a fresh container', (
    tester,
  ) async {
    await pump(tester);
    await choose(tester, 'fr');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(localePrefsKey), 'fr');
    expect(await readSavedLocale(), const Locale('fr'));

    // A fresh app start: the old tree and container are gone.
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pumpAndSettle();
    await pump(tester, seed: await readSavedLocale());
    expect(find.text('Réglages'), findsOneWidget);

    await choose(tester, 'system');
    expect(prefs.getString(localePrefsKey), isNull);
    expect(await readSavedLocale(), isNull);
  });

  testWidgets('System default follows the device language', (tester) async {
    await pump(tester, seed: const Locale('en'));
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    await choose(tester, 'system');
    expect(find.text('Réglages'), findsOneWidget);
    expect(find.text('Langue du système'), findsOneWidget);

    tester.platformDispatcher.localesTestValue = const [Locale('de')];
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('the selected option is announced as selected', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, seed: const Locale('fr'));
    await tester.tap(find.byKey(const Key('settings_language')));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.byKey(const Key('language_option_fr'))),
      matchesSemantics(
        label: 'Français',
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
        isEnabled: true,
        hasEnabledState: true,
        hasSelectedState: true,
        isSelected: true,
        hasCheckedState: true,
        isChecked: true,
        isInMutuallyExclusiveGroup: true,
      ),
    );
    final system = tester.widget<RadioListTile<String?>>(
      find.byKey(const Key('language_option_system')),
    );
    expect(system.value, isNull);
    expect(
      tester.getSize(find.byKey(const Key('language_option_en'))).height,
      greaterThanOrEqualTo(48),
    );
    handle.dispose();
  });

  for (final seed in const [Locale('en'), Locale('fr')]) {
    testWidgets('no overflow at 320 px / 2.0x in ${seed.languageCode}', (
      tester,
    ) async {
      await pump(tester, seed: seed, narrow: true, textScale: 2);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('settings_language')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('language_picker')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
