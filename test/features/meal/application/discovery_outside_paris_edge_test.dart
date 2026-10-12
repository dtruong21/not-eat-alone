import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/location/location_providers.dart';
import 'package:not_eat_alone/core/location/location_service.dart';
import 'package:not_eat_alone/core/util/geohash.dart';
import 'package:not_eat_alone/features/meal/application/discovery_controller.dart';
import 'package:not_eat_alone/features/meal/application/meal_providers.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/repositories/meal_repository.dart';
import 'package:not_eat_alone/features/safety/application/block_providers.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';

class _MockMeals extends Mock implements MealRepository {}

/// QA sweep 2026-10-12: v1 is Paris-only ("enforced by defaulting location
/// fallback to Paris center", PRD). The fallback only covers a denied
/// permission or a failed fix; a device that reports a real position outside
/// Île-de-France (an App Store / Play reviewer in California, a tourist's home
/// city, an emulator's default Mountain View location) queries its own
/// geohash cell, finds none of the Paris meals and sees "No meals near you
/// yet" with no way to evaluate matching.
/// Bug: docs/bugs/2026-10-12-feed-is-empty-for-any-device-outside-paris.md
const _bug = 'docs/bugs/2026-10-12-feed-is-empty-for-any-device-outside-paris.md';

void main() {
  Future<String> requestedPrefix(LatLng where) async {
    final repo = _MockMeals();
    when(
      () => repo.watchDiscoverable(geohashPrefix: any(named: 'geohashPrefix')),
    ).thenAnswer((_) => Stream<List<Meal>>.value(const []));
    final c = ProviderContainer(
      overrides: [
        locationProvider.overrideWith((ref) async => where),
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
    c.listen(discoveryControllerProvider, (_, __) {});
    for (var i = 0; i < 100; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      try {
        return verify(
          () => repo.watchDiscoverable(
            geohashPrefix: captureAny(named: 'geohashPrefix'),
          ),
        ).captured.last as String;
      } on Object {
        // not subscribed yet
      }
    }
    fail('discovery never queried the repository');
  }

  final paris = encodeGeohash(parisCenter.lat, parisCenter.lng, precision: 3);

  test('a device in Paris queries the Paris cell (harness check)', () async {
    expect(await requestedPrefix((lat: 48.86, lng: 2.34)), paris);
  });

  test('a device in San Francisco is still served the Paris feed', () async {
    expect(await requestedPrefix((lat: 37.77, lng: -122.42)), paris);
  }, skip: 'open bug: $_bug');

  test('a device in New York is still served the Paris feed', () async {
    expect(await requestedPrefix((lat: 40.71, lng: -74.0)), paris);
  }, skip: 'open bug: $_bug');
}
