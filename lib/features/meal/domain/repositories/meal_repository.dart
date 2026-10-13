import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';

abstract class MealRepository {
  Future<String> createMeal(Meal meal);

  /// Streams `open` meals whose `geohash` starts with [geohashPrefix].
  Stream<List<Meal>> watchDiscoverable({required String geohashPrefix});

  /// Reads `meals/{id}` once, or `null` if it doesn't exist.
  Future<Meal?> getMeal(String id);

  /// Streams `meals/{id}` live. Emits `null` when the meal is missing or the
  /// rules no longer let the viewer read it; any other failure is a stream
  /// error.
  Stream<Meal?> watchMeal(String id);
}
