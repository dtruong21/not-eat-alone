import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/meal/application/restaurant_search_controller.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
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
}
