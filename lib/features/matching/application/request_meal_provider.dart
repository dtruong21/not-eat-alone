import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/features/meal/application/meal_providers.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';

/// The meal a join request targets, by `mealId`. Used by the host's request
/// inbox to show which meal each request is for and whether it has passed.
/// Cached per id, so many requests on one meal cost one read.
final requestMealProvider = FutureProvider.family<Meal?, String>(
  (ref, mealId) => ref.watch(mealRepositoryProvider).getMeal(mealId),
);
