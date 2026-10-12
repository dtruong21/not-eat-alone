import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/meal/application/meal_providers.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';

/// The meal a join request targets, by `mealId`. Used by the host's request
/// inbox to show which meal each request is for and whether it has passed.
/// Cached per id while a screen shows it (auto-disposed after, and reset on
/// sign-out), so many requests on one meal cost one read.
final requestMealProvider = FutureProvider.autoDispose.family<Meal?, String>((
  ref,
  mealId,
) async {
  // Wait for auth, and yield nothing when signed out (sign-out resets this).
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return null;
  return ref.watch(mealRepositoryProvider).getMeal(mealId);
});
