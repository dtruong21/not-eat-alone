import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/meal/application/restaurant_search_controller.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/meal/presentation/restaurant_search_screen.dart';

import '../../../helpers/load_app_fonts.dart';
import '../../../support/pump_localized.dart';

class _EmptyController extends RestaurantSearchController {
  @override
  Future<List<Restaurant>> build() async => const [];

  @override
  Future<void> search(String query) async {
    state = const AsyncValue.data([]);
  }
}

class _FailingController extends RestaurantSearchController {
  @override
  Future<List<Restaurant>> build() async => throw StateError('boom');
}

void main() {
  setUpAll(loadAppFonts);

  Future<void> pump(
    WidgetTester tester, {
    RestaurantSearchController Function()? controller,
    bool narrow = false,
    double? textScale,
  }) async {
    if (narrow) {
      tester.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await pumpLocalized(
      tester,
      ProviderScope(
        overrides: [
          restaurantSearchControllerProvider.overrideWith(
            controller ?? _EmptyController.new,
          ),
        ],
        child: const RestaurantSearchScreen(),
      ),
      size: narrow ? const Size(320, 640) : null,
      textScale: textScale,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> type(WidgetTester tester, String query) async {
    await tester.enterText(
      find.byKey(const Key('restaurant_search_field')),
      query,
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  testWidgets('title, hint and empty copy are French', (tester) async {
    await pump(tester);

    expect(find.text('Trouver un restaurant'), findsOneWidget);
    expect(find.text('Chercher un restaurant'), findsOneWidget);
    expect(
      find.text('Aucun restaurant à afficher pour l’instant.'),
      findsOneWidget,
    );
    expect(find.text('Find a restaurant'), findsNothing);
    expect(find.text('Search restaurants'), findsNothing);
  });

  testWidgets('the no-match copy carries a query with an apostrophe', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, "L'Ami Jean");

    expect(
      find.text(
        "Aucun restaurant ne s’appelle «\u00a0L'Ami Jean\u00a0». "
        'Essaie un autre nom.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('No restaurant called'), findsNothing);
  });

  testWidgets('the no-match copy keeps a typographic apostrophe and quotes', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, 'Chez l’Ami "Louis" {x}');

    expect(
      find.text(
        'Aucun restaurant ne s’appelle «\u00a0Chez l’Ami "Louis" {x}\u00a0». '
        'Essaie un autre nom.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a failed search shows the French error block', (tester) async {
    await pump(tester, controller: _FailingController.new);

    expect(find.text('Chargement impossible'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('no overflow at 320 px and 2.0x with a long no-match query', (
    tester,
  ) async {
    await pump(tester, narrow: true, textScale: 2);
    await type(tester, "Le Grand Restaurant de l'Ami Jean et des Cousins");

    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow at 320 px and 2.0x in the empty state', (
    tester,
  ) async {
    await pump(tester, narrow: true, textScale: 2);

    expect(tester.takeException(), isNull);
  });
}
