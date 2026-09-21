/// Restaurant search controller — Riverpod `AsyncNotifier` over
/// [RestaurantSearchRepository].
///
/// Pattern (master spec idiom #1): `build()` seeds the initial state with
/// the full restaurant list (empty query); `search()` sets
/// `state = const AsyncValue.loading()` then
/// `state = await AsyncValue.guard(() => ...)` so errors land in
/// `state.error` instead of throwing. Inside methods after `build()`, use
/// `ref.read` only.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:not_eat_alone/features/meal/application/restaurant_providers.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';

part 'restaurant_search_controller.g.dart';

@riverpod
class RestaurantSearchController extends _$RestaurantSearchController {
  @override
  Future<List<Restaurant>> build() =>
      ref.read(restaurantSearchRepositoryProvider).search('');

  /// Searches for [query] and replaces the state with the results.
  Future<void> search(String query) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(restaurantSearchRepositoryProvider).search(query),
    );
  }
}
