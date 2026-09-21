/// Create-meal controller — Riverpod `AsyncNotifier` orchestrating meal
/// creation across [MealRepository] and [AuthRepository].
///
/// No domain of its own here (pragmatic Clean Architecture, same shape as
/// `ProfileController`): it reads [mealRepositoryProvider] and
/// [authRepositoryProvider] directly rather than owning a repository
/// interface.
///
/// Pattern (master spec idiom #1): `build()` returns `AsyncData(null)`,
/// nothing in flight. `create()` sets `state = const AsyncValue.loading()`
/// then `state = await AsyncValue.guard(() => ...)` — errors propagate into
/// `state.error` automatically instead of throwing. `meal_created` fires
/// only after the write succeeds (inside the guarded block, so a failure
/// never fires it). Inside methods after `build()`, use `ref.read` only.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/meal/application/meal_providers.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';

part 'create_meal_controller.g.dart';

@riverpod
class CreateMealController extends _$CreateMealController {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  /// Creates a meal hosted by the current user and fires `meal_created` on
  /// success. The repository fills in the server-generated `id` and
  /// `geohash`.
  Future<void> create({
    required Restaurant restaurant,
    required DateTime dateTime,
    String? note,
    required bool womenOnly,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(authRepositoryProvider).currentUser!.uid;
      final meal = Meal(
        id: '',
        hostId: uid,
        restaurant: restaurant,
        dateTime: dateTime,
        geohash: '',
        note: note,
        womenOnly: womenOnly,
      );
      await ref.read(mealRepositoryProvider).createMeal(meal);
      await analytics.track(MealCreated(womenOnly: womenOnly));
    });
  }
}
