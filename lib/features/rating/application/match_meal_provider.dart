import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/features/meal/application/meal_providers.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';

/// The meal behind a match, by [matchId] — matches are created 1:1 with
/// meals, so `matchId == mealId`. Used for the rating prompt's `dateTime`.
final matchMealProvider = FutureProvider.family<Meal?, String>(
  (ref, matchId) => ref.watch(mealRepositoryProvider).getMeal(matchId),
);
