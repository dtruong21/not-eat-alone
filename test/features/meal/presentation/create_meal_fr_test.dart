import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:not_eat_alone/features/meal/application/create_meal_controller.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/meal/presentation/create_meal_screen.dart';
import 'package:not_eat_alone/l10n/l10n.dart';

import '../../../helpers/load_app_fonts.dart';
import '../../../support/pump_localized.dart';

class _IdleController extends CreateMealController {
  @override
  Future<void> create({
    required Restaurant restaurant,
    required DateTime dateTime,
    required bool womenOnly,
    String? note,
  }) async {}
}

class _FailingController extends CreateMealController {
  @override
  Future<void> create({
    required Restaurant restaurant,
    required DateTime dateTime,
    required bool womenOnly,
    String? note,
  }) async {
    state = AsyncValue.error(StateError('boom'), StackTrace.empty);
  }
}

class _SucceedingController extends CreateMealController {
  @override
  Future<void> create({
    required Restaurant restaurant,
    required DateTime dateTime,
    required bool womenOnly,
    String? note,
  }) async {
    state = const AsyncLoading();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    state = const AsyncData(null);
  }
}

const _restaurant = Restaurant(
  placeId: 'p1',
  name: "Restaurant Le Comptoir du Relais de l'Odéon",
  address: "9 Carrefour de l'Odéon, 75006 Paris",
  lat: 48.8517,
  lng: 2.3389,
);

void main() {
  setUpAll(loadAppFonts);

  final screenKey = GlobalKey<CreateMealScreenState>();

  Future<void> pump(
    WidgetTester tester, {
    CreateMealController Function()? controller,
    bool narrow = false,
    double? textScale,
  }) async {
    if (narrow) {
      tester.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              CreateMealScreen(key: screenKey, restaurant: _restaurant),
        ),
        GoRoute(
          path: '/discover',
          builder: (context, state) => const Scaffold(body: Text('home')),
        ),
      ],
    );
    await pumpLocalized(
      tester,
      ProviderScope(
        overrides: [
          createMealControllerProvider.overrideWith(
            controller ?? _IdleController.new,
          ),
        ],
        child: Router.withConfig(config: router),
      ),
      size: narrow ? const Size(320, 640) : null,
      textScale: textScale,
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('every visible string is French', (tester) async {
    await pump(tester);

    expect(find.text('Créer un repas'), findsOneWidget);
    expect(find.text('Choisir la date et l’heure'), findsOneWidget);
    expect(find.text('Note (facultative)'), findsOneWidget);
    expect(find.text('Entre femmes'), findsOneWidget);
    expect(find.text('Publier le repas'), findsOneWidget);
    expect(find.text('Create a meal'), findsNothing);
    expect(find.text('Pick date & time'), findsNothing);
    expect(find.text('Women only'), findsNothing);
  });

  testWidgets('a picked date renders in French', (tester) async {
    await pump(tester);

    screenKey.currentState!.debugSetSelectedDateTime(
      DateTime(2031, 3, 4, 8, 5),
    );
    await tester.pump();

    expect(find.textContaining('mars'), findsOneWidget);
    expect(find.textContaining('08:05'), findsOneWidget);
    expect(find.text('Choisir la date et l’heure'), findsNothing);
  });

  testWidgets('a failed create shows the shared French error', (tester) async {
    await pump(tester, controller: _FailingController.new);

    screenKey.currentState!.debugSetSelectedDateTime(
      DateTime.now().add(const Duration(days: 3)),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('create_meal_submit_button')));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Oups, un problème est survenu. Réessaie.'),
      findsOneWidget,
    );
  });

  testWidgets('a posted meal shows the French confirmation', (tester) async {
    await pump(tester, controller: _SucceedingController.new);

    screenKey.currentState!.debugSetSelectedDateTime(
      DateTime.now().add(const Duration(days: 3)),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('create_meal_submit_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    expect(
      find.text(
        'Repas publié. Tu recevras les demandes dans l’onglet Demandes.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the too-soon message uses the lead in French', (tester) async {
    await pump(tester);
    final context = tester.element(find.byType(CreateMealScreen));

    expect(
      context.l10n.createMealTooSoon(5),
      'Choisis une heure à au moins 5 minutes d’ici.',
    );
  });

  testWidgets('no overflow at 320 px and 2.0x, with the error visible', (
    tester,
  ) async {
    await pump(
      tester,
      controller: _FailingController.new,
      narrow: true,
      textScale: 2,
    );
    screenKey.currentState!.debugSetSelectedDateTime(
      DateTime(2031, 12, 24, 20),
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const Key('create_meal_submit_button')),
    );
    await tester.tap(find.byKey(const Key('create_meal_submit_button')));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
