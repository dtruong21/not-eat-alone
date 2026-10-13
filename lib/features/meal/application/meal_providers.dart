import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/features/meal/data/repositories/meal_repository_impl.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/repositories/meal_repository.dart';

final mealRepositoryProvider = Provider<MealRepository>((ref) => MealRepositoryImpl());

/// Live `meals/{id}`: `null` once the meal is deleted or hidden. The detail
/// screen shows the meal it was opened with until the first snapshot.
final mealStreamProvider = StreamProvider.autoDispose.family<Meal?, String>(
  (ref, id) => ref.watch(mealRepositoryProvider).watchMeal(id),
);
