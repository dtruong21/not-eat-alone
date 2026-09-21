import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';

abstract class MealRepository {
  Future<String> createMeal(Meal meal);
}
