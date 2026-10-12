import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/meal/application/meal_providers.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';

/// The meal behind a match, by [matchId] — matches are created 1:1 with
/// meals, so `matchId == mealId`. Used for the rating prompt's `dateTime`.
final matchMealProvider = FutureProvider.autoDispose.family<Meal?, String>((
  ref,
  matchId,
) async {
  // Wait for auth, and yield nothing when signed out (sign-out resets this).
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return null;
  return ref.watch(mealRepositoryProvider).getMeal(matchId);
});
