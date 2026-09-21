import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/location/location_providers.dart';
import 'package:not_eat_alone/core/location/location_service.dart';
import 'package:not_eat_alone/features/meal/application/discovery_controller.dart';
import 'package:not_eat_alone/features/meal/application/meal_providers.dart';
import 'package:not_eat_alone/features/meal/domain/entities/discoverable_meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/meal/domain/repositories/meal_repository.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';

class MockMealRepository extends Mock implements MealRepository {}

/// Waits for [discoveryControllerProvider] to settle on its first
/// `AsyncData`/`AsyncError`.
///
/// `discoveryControllerProvider` deliberately swaps its underlying stream
/// mid-flight — `Stream.empty()` while location/viewer are loading, then the
/// real `watchDiscoverable` stream once both resolve (see the controller's
/// doc comment). `provider.future` ties itself to whichever stream was live
/// on the *first* build and doesn't follow that swap, so it never completes
/// here; listening for the state change (same mechanism a widget's
/// `ref.watch(...)` uses) does.
Future<List<DiscoverableMeal>> _awaitDiscoveryResult(
  ProviderContainer container,
) {
  final completer = Completer<List<DiscoverableMeal>>();
  final sub = container.listen(discoveryControllerProvider, (prev, next) {
    next.when(
      data: (data) {
        if (!completer.isCompleted) completer.complete(data);
      },
      error: (error, stackTrace) {
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      },
      loading: () {},
    );
  }, fireImmediately: true);
  return completer.future.whenComplete(sub.close);
}

// Viewer sits at Paris centre; the three restaurants below step further
// away in that order, so ascending-distance sort must read
// near -> womenOnly -> far.
const LatLng _viewerLoc = (lat: 48.8566, lng: 2.3522);

const _nearRestaurant = Restaurant(
  placeId: 'near',
  name: 'Near bistro',
  address: 'near',
  lat: 48.8570,
  lng: 2.3522,
);

const _womenOnlyRestaurant = Restaurant(
  placeId: 'women_only',
  name: 'Women-only bistro',
  address: 'women_only',
  lat: 48.8600,
  lng: 2.3522,
);

const _farRestaurant = Restaurant(
  placeId: 'far',
  name: 'Far bistro',
  address: 'far',
  lat: 48.9000,
  lng: 2.4000,
);

final DateTime _future = DateTime.now().add(const Duration(days: 1));
final DateTime _past = DateTime.now().subtract(const Duration(days: 1));

Meal _meal({
  required String id,
  required String hostId,
  required Restaurant restaurant,
  required DateTime dateTime,
  bool womenOnly = false,
}) =>
    Meal(
      id: id,
      hostId: hostId,
      restaurant: restaurant,
      dateTime: dateTime,
      geohash: 'u09t',
      womenOnly: womenOnly,
    );

void main() {
  late MockMealRepository mealRepository;

  final meals = <Meal>[
    // Past — excluded regardless of viewer.
    _meal(
      id: 'past',
      hostId: 'other',
      restaurant: _farRestaurant,
      dateTime: _past,
    ),
    // Hosted by the viewer — excluded regardless of viewer.
    _meal(
      id: 'own',
      hostId: 'viewer_1',
      restaurant: _nearRestaurant,
      dateTime: _future,
    ),
    // Women-only — excluded for a man viewer, included for a woman viewer.
    _meal(
      id: 'women_only',
      hostId: 'other',
      restaurant: _womenOnlyRestaurant,
      dateTime: _future,
      womenOnly: true,
    ),
    // Far — always eligible; used to check distance ordering.
    _meal(
      id: 'far',
      hostId: 'other',
      restaurant: _farRestaurant,
      dateTime: _future,
    ),
    // Near — always eligible; used to check distance ordering.
    _meal(
      id: 'near',
      hostId: 'other',
      restaurant: _nearRestaurant,
      dateTime: _future,
    ),
  ];

  setUp(() {
    mealRepository = MockMealRepository();
    when(
      () => mealRepository.watchDiscoverable(
        geohashPrefix: any(named: 'geohashPrefix'),
      ),
    ).thenAnswer((_) => Stream.value(meals));
  });

  ProviderContainer buildContainer(AppUser viewer) => ProviderContainer(
        overrides: [
          locationProvider.overrideWith((ref) async => _viewerLoc),
          currentUserDocProvider.overrideWith((ref) => Stream.value(viewer)),
          mealRepositoryProvider.overrideWithValue(mealRepository),
        ],
      );

  test(
    "excludes past meals, the viewer's own meal, and (for a man viewer) "
    'women-only meals, sorting the rest by distance ascending',
    () async {
      final container = buildContainer(
        AppUser(uid: 'viewer_1', dob: DateTime.utc(1990), gender: Gender.man),
      );
      addTearDown(container.dispose);

      final result = await _awaitDiscoveryResult(container);

      expect(result.map((d) => d.meal.id), ['near', 'far']);
      expect(result[0].distanceMeters, lessThan(result[1].distanceMeters));
    },
  );

  test(
    'includes a women-only meal for a woman viewer, still sorted by '
    'distance ascending',
    () async {
      final container = buildContainer(
        AppUser(
          uid: 'viewer_1',
          dob: DateTime.utc(1990),
          gender: Gender.woman,
        ),
      );
      addTearDown(container.dispose);

      final result = await _awaitDiscoveryResult(container);

      expect(result.map((d) => d.meal.id), ['near', 'women_only', 'far']);
      expect(
        result.map((d) => d.distanceMeters),
        orderedEquals(
          [...result.map((d) => d.distanceMeters)]..sort(),
        ),
      );
    },
  );
}
