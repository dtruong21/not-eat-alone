import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/meal/application/restaurant_providers.dart';
import 'package:not_eat_alone/features/meal/application/restaurant_search_controller.dart';
import 'package:not_eat_alone/features/meal/data/datasources/fake_restaurant_search_datasource.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/meal/domain/repositories/restaurant_search_repository.dart';

/// Holds every non-empty query open until [gate] completes, so a test can
/// close the picker (drop the only listener) while a search is in flight.
class _GatedSearchRepository implements RestaurantSearchRepository {
  final gate = Completer<void>();

  @override
  Future<List<Restaurant>> search(String query) async {
    if (query.isNotEmpty) await gate.future;
    return const [];
  }
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        restaurantSearchRepositoryProvider.overrideWithValue(
          FakeRestaurantSearchDataSource(),
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('build() seeds state with the full restaurant list', () async {
    final restaurants =
        await container.read(restaurantSearchControllerProvider.future);
    expect(restaurants.length, greaterThan(10));
  });

  test("search('zzzzz') returns an empty list", () async {
    // Ensure the initial build has settled before mutating state.
    await container.read(restaurantSearchControllerProvider.future);

    await container
        .read(restaurantSearchControllerProvider.notifier)
        .search('zzzzz');

    final state = container.read(restaurantSearchControllerProvider);
    expect(state.hasError, isFalse);
    expect(state.value, isEmpty);
  });

  test("search('') returns the full list (>10)", () async {
    await container.read(restaurantSearchControllerProvider.future);

    await container
        .read(restaurantSearchControllerProvider.notifier)
        .search('');

    final state = container.read(restaurantSearchControllerProvider);
    expect(state.hasError, isFalse);
    expect(state.value!.length, greaterThan(10));
  });

  // Regression: a search still in flight when the picker closed used to throw
  // UnmountedRefException from its trailing `state =`. A query (unlike an
  // action) has no one left to deliver results to, so it drops them.
  test('search() completes without throwing when its listener unmounts '
      'mid-search', () async {
    final repository = _GatedSearchRepository();
    final gated = ProviderContainer(
      overrides: [
        restaurantSearchRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(gated.dispose);

    final sub = gated.listen(restaurantSearchControllerProvider, (_, _) {});
    await gated.read(restaurantSearchControllerProvider.future);
    final inFlight = gated
        .read(restaurantSearchControllerProvider.notifier)
        .search('bistro');
    sub.close();
    await gated.pump();
    repository.gate.complete();

    await expectLater(inFlight, completes);
  });
}
