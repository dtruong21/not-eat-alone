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
  /// Monotonic id of the latest search; a slower, older response must not
  /// overwrite a newer one now that results come over the network.
  int _searchId = 0;

  @override
  Future<List<Restaurant>> build() =>
      ref.read(restaurantSearchRepositoryProvider).search('');

  /// Searches for [query] and replaces the state with the results.
  Future<void> search(String query) async {
    final searchId = ++_searchId;
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(
      () => ref.read(restaurantSearchRepositoryProvider).search(query),
    );
    // A query, not an action: if the picker closed mid-search nobody wants
    // the results, so drop them rather than keep the provider alive (and
    // rather than throw UnmountedRefException on a disposed ref).
    if (!ref.mounted || searchId != _searchId) return;
    state = result;
  }
}
