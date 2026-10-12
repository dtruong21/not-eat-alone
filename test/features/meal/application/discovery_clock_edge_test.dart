import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/location/location_providers.dart';
import 'package:not_eat_alone/core/location/location_service.dart';
import 'package:not_eat_alone/features/meal/application/discovery_controller.dart';
import 'package:not_eat_alone/features/meal/application/meal_providers.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
import 'package:not_eat_alone/features/meal/domain/repositories/meal_repository.dart';
import 'package:not_eat_alone/features/safety/application/block_providers.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';

class _MockMeals extends Mock implements MealRepository {}

const LatLng _loc = (lat: 48.8566, lng: 2.3522);

Meal _meal(String id, DateTime at) => Meal(
  id: id,
  hostId: 'host',
  restaurant: const Restaurant(
    placeId: 'p',
    name: 'Bistro',
    address: 'a',
    lat: 48.857,
    lng: 2.3522,
  ),
  dateTime: at,
  geohash: 'u09t',
);

/// QA sweep 2026-10-09 (edge cases 3 and 6: date rollover, large data). The
/// feed is derived only when Firestore emits, so a meal whose time passes while
/// the screen stays open must drop out by itself (fixed: the controller
/// schedules a re-check at the next start time).
/// docs/bugs/closed/2026-10-09-discovery-feed-stale-and-unbounded.md
void main() {
  late _MockMeals repo;
  late StreamController<List<Meal>> snapshots;

  setUp(() {
    repo = _MockMeals();
    snapshots = StreamController<List<Meal>>.broadcast();
    when(
      () => repo.watchDiscoverable(geohashPrefix: any(named: 'geohashPrefix')),
    ).thenAnswer((_) => snapshots.stream);
  });

  tearDown(() => snapshots.close());

  Future<void> untilSubscribed() async {
    for (var i = 0; i < 100 && !snapshots.hasListener; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        locationProvider.overrideWith((ref) async => _loc),
        currentUserDocProvider.overrideWith(
          (ref) => Stream.value(AppUser(uid: 'me', dob: DateTime.utc(1990))),
        ),
        mealRepositoryProvider.overrideWithValue(repo),
        blockedUserIdsProvider.overrideWith(
          (ref) => Stream.value(const <String>{}),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'a listed meal is dropped once its start time passes (no new snapshot)',
    () async {
      final c = container();
      c.listen(discoveryControllerProvider, (_, __) {});
      await untilSubscribed();
      snapshots.add([
        _meal('soon', DateTime.now().add(const Duration(seconds: 1))),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(c.read(discoveryControllerProvider).value, hasLength(1));

      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(c.read(discoveryControllerProvider).value, isEmpty);
    },
  );

  test('only the meals that have started are dropped; later ones stay', () async {
    final c = container();
    c.listen(discoveryControllerProvider, (_, __) {});
    await untilSubscribed();
    snapshots.add([
      _meal('soon', DateTime.now().add(const Duration(milliseconds: 600))),
      _meal('later', DateTime.now().add(const Duration(hours: 2))),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(c.read(discoveryControllerProvider).value, hasLength(2));

    await Future<void>.delayed(const Duration(milliseconds: 1000));
    expect(
      c.read(discoveryControllerProvider).value!.map((d) => d.meal.id),
      ['later'],
    );
  });

  test('re-emitting the same feed does not count another discovery view', () async {
    final logged = <String>[];
    analytics.debugSetForceSend(true);
    analytics.debugSetLogSink((name, params) async => logged.add(name));
    addTearDown(analytics.debugResetAnalytics);

    final c = container();
    c.listen(discoveryControllerProvider, (_, __) {});
    await untilSubscribed();
    final meals = [
      _meal('a', DateTime.now().add(const Duration(hours: 1))),
    ];
    snapshots.add(meals);
    snapshots.add(meals);
    snapshots.add([...meals, _meal('b', DateTime.now().add(const Duration(hours: 2)))]);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(logged.where((n) => n == 'discovery_viewed'), hasLength(2));
  });

  test('300 open meals in the cell are mapped and sorted', () async {
    final c = container();
    c.listen(discoveryControllerProvider, (_, __) {});
    await untilSubscribed();
    snapshots.add([
      for (var i = 0; i < 300; i++)
        _meal('m$i', DateTime.now().add(Duration(hours: 1 + i))),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(c.read(discoveryControllerProvider).value, hasLength(300));
  });
}
