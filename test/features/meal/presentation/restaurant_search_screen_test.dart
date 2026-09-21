import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/meal/application/restaurant_search_controller.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/meal/presentation/restaurant_search_screen.dart';

/// Serves a fixed result list instead of hitting a real
/// [RestaurantSearchRepository] — this screen only needs to prove it renders
/// whatever `AsyncValue<List<Restaurant>>` the controller reports and wires
/// row taps to navigation, not that search actually filters.
class FakeRestaurantSearchController extends RestaurantSearchController {
  FakeRestaurantSearchController(this._restaurants);

  final List<Restaurant> _restaurants;
  String? lastQuery;

  @override
  Future<List<Restaurant>> build() async => _restaurants;

  @override
  Future<void> search(String query) async {
    lastQuery = query;
    state = AsyncValue.data(_restaurants);
  }
}

const _restaurantA = Restaurant(
  placeId: 'p1',
  name: 'Le Comptoir du Relais',
  address: "9 Carrefour de l'Odéon, 75006 Paris",
  lat: 48.8517,
  lng: 2.3389,
);

const _restaurantB = Restaurant(
  placeId: 'p2',
  name: 'Bistrot Paul Bert',
  address: '18 Rue Paul Bert, 75011 Paris',
  lat: 48.8534,
  lng: 2.3839,
);

/// `analytics.track()` drops to `debugPrint` in debug builds — intercept it
/// here rather than mocking analytics directly, mirroring
/// `signin_screen_test.dart`.
Future<List<String>> _captureDebugLogs(Future<void> Function() body) async {
  final logs = <String>[];
  final original = debugPrint;
  debugPrint = (message, {wrapWidth}) {
    if (message != null) logs.add(message);
  };
  try {
    await body();
  } finally {
    debugPrint = original;
  }
  return logs;
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required RestaurantSearchController Function() controller,
}) async {
  final router = GoRouter(
    initialLocation: '/meals/new',
    routes: [
      GoRoute(
        path: '/meals/new',
        builder: (context, state) => const RestaurantSearchScreen(),
      ),
      GoRoute(
        path: createMealDetailsRoutePath,
        builder: (context, state) {
          final restaurant = state.extra! as Restaurant;
          return Scaffold(body: Text('details:${restaurant.name}'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        restaurantSearchControllerProvider.overrideWith(controller),
      ],
      child: MaterialApp.router(
        theme: buildTheme(Brightness.light),
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets(
    'renders each restaurant\'s name and address from the controller',
    (tester) async {
      await _pumpScreen(
        tester,
        controller: () =>
            FakeRestaurantSearchController([_restaurantA, _restaurantB]),
      );

      expect(find.text(_restaurantA.name), findsOneWidget);
      expect(find.text(_restaurantA.address), findsOneWidget);
      expect(find.text(_restaurantB.name), findsOneWidget);
      expect(find.text(_restaurantB.address), findsOneWidget);
    },
  );

  testWidgets('an empty result set renders "No matches"', (tester) async {
    await _pumpScreen(
      tester,
      controller: () => FakeRestaurantSearchController(const []),
    );

    expect(find.text('No matches'), findsOneWidget);
  });

  testWidgets(
    'tapping a row fires restaurant_selected and navigates to '
    '/meals/new/details with the tapped restaurant',
    (tester) async {
      await _pumpScreen(
        tester,
        controller: () =>
            FakeRestaurantSearchController([_restaurantA, _restaurantB]),
      );

      final logs = await _captureDebugLogs(() async {
        await tester.tap(find.text(_restaurantB.name));
        await tester.pumpAndSettle();
      });

      expect(find.text('details:${_restaurantB.name}'), findsOneWidget);
      expect(
        logs.any((l) => l.contains('restaurant_selected')),
        isTrue,
      );
    },
  );
}
