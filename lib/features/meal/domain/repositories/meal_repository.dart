import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';

abstract class MealRepository {
  Future<String> createMeal(Meal meal);

  /// Streams `open` meals whose `geohash` starts with [geohashPrefix].
  Stream<List<Meal>> watchDiscoverable({required String geohashPrefix});
}
