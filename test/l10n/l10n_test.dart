import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/widgets/error_state.dart';
import 'package:not_eat_alone/core/locale/locale_controller.dart';
import 'package:not_eat_alone/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/pump_localized.dart';

Widget _probe() => Builder(builder: (c) => Text(c.l10n.commonTryAgain));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('context.l10n falls back to English without delegates', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: _probe()));
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('context.l10n is French under pumpLocalized(fr)', (tester) async {
    await pumpLocalized(tester, _probe());
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('ErrorState button follows the locale', (tester) async {
    await pumpLocalized(
      tester,
      ErrorState(onRetry: () {}),
      locale: const Locale('en'),
    );
    expect(find.text('Try again'), findsOneWidget);
    await pumpLocalized(tester, ErrorState(onRetry: () {}));
    await tester.pump();
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('switching the LocaleController rebuilds visible text live', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            locale: ref.watch(localeControllerProvider),
            supportedLocales: supportedAppLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(body: _probe()),
          ),
        ),
      ),
    );
    expect(find.text('Try again'), findsOneWidget);
    await container
        .read(localeControllerProvider.notifier)
        .setLocale(const Locale('fr'));
    await tester.pumpAndSettle();
    expect(find.text('Réessayer'), findsOneWidget);
    await container.read(localeControllerProvider.notifier).setLocale(null);
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
  });
}
