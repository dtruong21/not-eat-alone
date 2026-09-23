/// Discovery controller — streams nearby, joinable meals for the current
/// viewer.
///
/// Composes [locationProvider] (device location, Paris fallback) and
/// [currentUserDocProvider] (the viewer's uid + gender) into a geohash-
/// bounded `MealRepository.watchDiscoverable` query, then reduces each
/// emitted `List<Meal>` into a sorted `List<DiscoverableMeal>`:
///  - future meals only (`dateTime.isAfter(now)`)
///  - not hosted by the viewer
///  - women-only meals hidden unless the viewer is a woman
///  - sorted ascending by distance from the viewer (nearest first)
///
/// Plain `StreamProvider` (same shape as `currentUserDocProvider`), not a
/// `@riverpod` class — this provider has no methods, just a derived stream.
///
/// While either upstream dependency ([locationProvider] or
/// [currentUserDocProvider]) hasn't resolved yet, this stays in
/// `AsyncLoading` rather than emitting an empty/wrong list: a
/// `Stream.empty()` completes without ever emitting a data event, so a
/// `StreamProvider` watching it never leaves `AsyncLoading`. Once both
/// resolve, this provider is watching them, so it rebuilds and returns the
/// real, geohash-scoped meal stream. Errors on either upstream provider are
/// forwarded as a `Stream.error` so they surface as `AsyncError` here too,
/// instead of leaving the provider stuck loading.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/core/location/location_providers.dart';
import 'package:not_eat_alone/core/util/distance.dart';
import 'package:not_eat_alone/core/util/geohash.dart';
import 'package:not_eat_alone/features/meal/application/meal_providers.dart';
import 'package:not_eat_alone/features/meal/domain/entities/discoverable_meal.dart';
import 'package:not_eat_alone/features/safety/application/block_providers.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';

final discoveryControllerProvider =
    StreamProvider<List<DiscoverableMeal>>((ref) {
  final locationAsync = ref.watch(locationProvider);
  final viewerAsync = ref.watch(currentUserDocProvider);
  final blocked = ref.watch(blockedUserIdsProvider).value ?? <String>{};

  if (locationAsync.hasError) {
    return Stream.error(
      locationAsync.error!,
      locationAsync.stackTrace ?? StackTrace.current,
    );
  }
  if (viewerAsync.hasError) {
    return Stream.error(
      viewerAsync.error!,
      viewerAsync.stackTrace ?? StackTrace.current,
    );
  }

  final loc = locationAsync.value;
  final viewer = viewerAsync.value;
  if (loc == null || viewer == null) {
    // Still loading — see file header for why `Stream.empty()` keeps this
    // provider in `AsyncLoading` rather than emitting anything.
    return const Stream.empty();
  }

  // Precision 3 (~156km cell) covers all of Paris + Île-de-France in a
  // single cell, so no meals are missed near a cell boundary. Finer,
  // multi-cell neighbour queries are the multi-city scale-up (see the
  // discovery design spec §3/§11).
  final prefix = encodeGeohash(loc.lat, loc.lng, precision: 3);

  return ref
      .watch(mealRepositoryProvider)
      .watchDiscoverable(geohashPrefix: prefix)
      .map((meals) {
    final now = DateTime.now();
    final result = meals
        .where((m) => m.dateTime.isAfter(now))
        .where((m) => m.hostId != viewer.uid)
        .where((m) => !(m.womenOnly && viewer.gender != Gender.woman))
        .where((m) => !blocked.contains(m.hostId))
        .map(
          (m) => DiscoverableMeal(
            meal: m,
            distanceMeters: distanceMeters(
              loc.lat,
              loc.lng,
              m.restaurant.lat,
              m.restaurant.lng,
            ),
          ),
        )
        .toList()
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    // Fire-and-forget, guarded against a rebuild loop: `track()` doesn't
    // touch `ref`/provider state, so firing per emission just logs each
    // refreshed feed rather than causing another rebuild.
    unawaited(analytics.track(DiscoveryViewed(count: result.length)));

    return result;
  });
});
